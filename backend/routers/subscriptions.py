"""
Planes de suscripción mensual.

Planes disponibles:
  basico    — 2 consultas/mes  — $9.99/mes
  premium   — 5 consultas/mes  — $19.99/mes
  ilimitado — sin límite       — $39.99/mes
"""
import os
import logging
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Header, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel
from database import get_db
from models import Subscription, Patient
from utils.auth import require_patient

logger = logging.getLogger("saludenlinea")

router = APIRouter(prefix="/api/subscriptions", tags=["subscriptions"])

ADMIN_KEY = os.getenv("ADMIN_KEY", "saludenlinea-admin-2025")

STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")
STRIPE_WEBHOOK_SECRET_SUB = os.getenv("STRIPE_WEBHOOK_SECRET_SUB", "")
BASE_URL = os.getenv("BASE_URL", "https://saludenlinea-production.up.railway.app")

try:
    import stripe as stripe_lib
    STRIPE_AVAILABLE = True
except ImportError:
    STRIPE_AVAILABLE = False

# ── Catálogo de planes ────────────────────────────────────────────────────────

PLANES = {
    "basico": {
        "nombre": "Plan Básico",
        "descripcion": "2 consultas por mes",
        "consultas": 2,
        "monto_usd": 9.99,
        "monto_crc": 5199,   # ₡5,199 (ref. julio 2026 ≈ 520 CRC/USD)
    },
    "premium": {
        "nombre": "Plan Premium",
        "descripcion": "5 consultas por mes",
        "consultas": 5,
        "monto_usd": 19.99,
        "monto_crc": 10395,
    },
    "ilimitado": {
        "nombre": "Plan Ilimitado",
        "descripcion": "Consultas ilimitadas",
        "consultas": 0,      # 0 = ilimitado
        "monto_usd": 39.99,
        "monto_crc": 20795,
    },
}


# ── Pydantic ──────────────────────────────────────────────────────────────────

class SubscribeRequest(BaseModel):
    plan: str        # basico|premium|ilimitado
    metodo: str      # stripe|sinpe


# ── Helpers ───────────────────────────────────────────────────────────────────

def _plan_activo(paciente_id: int, db: Session):
    ahora = datetime.utcnow()
    return db.query(Subscription).filter(
        Subscription.paciente_id == paciente_id,
        Subscription.estado == "activo",
        Subscription.fin >= ahora,
    ).first()


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/planes")
def listar_planes():
    """Devuelve el catálogo de planes en USD y CRC."""
    return [{"id": k, **v} for k, v in PLANES.items()]


@router.get("/me")
def mi_suscripcion(
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """Retorna la suscripción activa del paciente (o null si no tiene)."""
    sub = _plan_activo(int(current["sub"]), db)
    if not sub:
        return {"activo": False, "suscripcion": None}

    plan_info = PLANES.get(sub.plan, {})
    return {
        "activo": True,
        "suscripcion": {
            "id": sub.id,
            "plan": sub.plan,
            "nombre_plan": plan_info.get("nombre", sub.plan),
            "estado": sub.estado,
            "consultas_incluidas": sub.consultas_incluidas,
            "consultas_usadas": sub.consultas_usadas,
            "consultas_restantes": (
                None if sub.consultas_incluidas == 0
                else max(0, sub.consultas_incluidas - sub.consultas_usadas)
            ),
            "inicio": sub.inicio.isoformat(),
            "fin": sub.fin.isoformat(),
            "monto": sub.monto,
            "moneda": sub.moneda,
        },
    }


@router.post("/subscribe/stripe")
def suscribir_stripe(
    data: SubscribeRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """Crea sesión de Stripe Checkout para activar suscripción."""
    if not STRIPE_AVAILABLE or not STRIPE_SECRET_KEY:
        raise HTTPException(status_code=503, detail="Stripe no configurado")

    plan_info = PLANES.get(data.plan)
    if not plan_info:
        raise HTTPException(status_code=400, detail="Plan no válido")

    stripe_lib.api_key = STRIPE_SECRET_KEY
    paciente_id = int(current["sub"])

    session = stripe_lib.checkout.Session.create(
        payment_method_types=["card"],
        line_items=[{
            "price_data": {
                "currency": "usd",
                "product_data": {"name": plan_info["nombre"], "description": plan_info["descripcion"]},
                "unit_amount": int(plan_info["monto_usd"] * 100),
            },
            "quantity": 1,
        }],
        mode="payment",
        success_url=f"{BASE_URL}/api/subscriptions/stripe/success?session_id={{CHECKOUT_SESSION_ID}}",
        cancel_url=f"{BASE_URL}/api/subscriptions/stripe/cancel",
        metadata={"paciente_id": str(paciente_id), "plan": data.plan},
        customer_email=current["email"],
    )

    return {"checkout_url": session.url, "session_id": session.id}


@router.post("/stripe/webhook")
async def stripe_sub_webhook(request: Request, db: Session = Depends(get_db)):
    """Stripe notifica aquí cuando se completa el pago de suscripción."""
    if not STRIPE_AVAILABLE or not STRIPE_WEBHOOK_SECRET_SUB:
        return {"status": "ignored"}

    stripe_lib.api_key = STRIPE_SECRET_KEY
    payload = await request.body()
    sig = request.headers.get("stripe-signature", "")

    try:
        event = stripe_lib.Webhook.construct_event(
            payload, sig, STRIPE_WEBHOOK_SECRET_SUB)
    except Exception:
        raise HTTPException(status_code=400, detail="Firma inválida")

    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        meta = session.get("metadata", {})
        paciente_id = int(meta.get("paciente_id", 0))
        plan = meta.get("plan")
        if paciente_id and plan and plan in PLANES:
            _activar_plan(paciente_id, plan, db)

    return {"status": "ok"}


@router.get("/stripe/success")
def stripe_sub_success(session_id: str, db: Session = Depends(get_db)):
    """Stripe redirige aquí tras pago exitoso de suscripción."""
    if not STRIPE_AVAILABLE or not STRIPE_SECRET_KEY:
        return {"mensaje": "Pago recibido. Activando plan..."}

    stripe_lib.api_key = STRIPE_SECRET_KEY
    try:
        session = stripe_lib.checkout.Session.retrieve(session_id)
        if session.payment_status == "paid":
            meta = session.metadata or {}
            paciente_id = int(meta.get("paciente_id", 0))
            plan = meta.get("plan")
            if paciente_id and plan:
                _activar_plan(paciente_id, plan, db)
    except Exception as e:
        logger.warning("Error verificando sesión Stripe suscripción: %s", e)

    return {"mensaje": "¡Plan activado! Ya puedes agendar consultas con tu suscripción.", "exito": True}


@router.get("/stripe/cancel")
def stripe_sub_cancel():
    return {"mensaje": "Suscripción cancelada. Puedes intentar de nuevo.", "exito": False}


def _activar_plan(paciente_id: int, plan: str, db: Session):
    plan_info = PLANES[plan]
    ahora = datetime.utcnow()
    sub = _plan_activo(paciente_id, db)
    if sub:
        # Extiende el mes actual
        sub.fin = sub.fin + timedelta(days=30)
        sub.consultas_incluidas = plan_info["consultas"]
        sub.consultas_usadas = 0
        sub.plan = plan
        sub.monto = plan_info["monto_usd"]
    else:
        sub = Subscription(
            paciente_id=paciente_id,
            plan=plan,
            estado="activo",
            consultas_incluidas=plan_info["consultas"],
            consultas_usadas=0,
            inicio=ahora,
            fin=ahora + timedelta(days=30),
            monto=plan_info["monto_usd"],
            moneda="USD",
        )
        db.add(sub)
    db.commit()
    logger.info("Plan activado paciente_id=%s plan=%s", paciente_id, plan)


# ── Admin: activar plan manualmente (ej. tras SINPE) ─────────────────────────

@router.post("/admin/activate")
def admin_activar_plan(
    paciente_id: int,
    plan: str,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="No autorizado")
    if plan not in PLANES:
        raise HTTPException(status_code=400, detail="Plan no válido")
    _activar_plan(paciente_id, plan, db)
    return {"mensaje": f"Plan {plan} activado para paciente {paciente_id}"}


@router.post("/admin/cancel/{paciente_id}")
def admin_cancelar_plan(
    paciente_id: int,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="No autorizado")
    sub = _plan_activo(paciente_id, db)
    if not sub:
        raise HTTPException(status_code=404, detail="Sin suscripción activa")
    sub.estado = "cancelado"
    db.commit()
    return {"mensaje": "Suscripción cancelada"}
