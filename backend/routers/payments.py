"""
Pagos: Mercado Pago, SINPE Móvil y Stripe.

Flujos:
  MercadoPago: POST /preference → redirige al usuario → webhook confirma
  SINPE Móvil: POST /sinpe → paciente sube comprobante → admin verifica en /admin/payments/verify/{id}
  Stripe:      POST /stripe/checkout → crea sesión → webhook confirma
"""
import os
import hmac
import hashlib
import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Request, Header
from sqlalchemy.orm import Session
from pydantic import BaseModel, field_validator
from typing import Optional
from database import get_db
from models import Appointment, Payment, Doctor
from utils.auth import require_patient

logger = logging.getLogger("saludenlinea")

try:
    import mercadopago
    MP_AVAILABLE = True
except ImportError:
    MP_AVAILABLE = False

try:
    import stripe as stripe_lib
    STRIPE_AVAILABLE = True
except ImportError:
    STRIPE_AVAILABLE = False

router = APIRouter(prefix="/api/payments", tags=["payments"])

MP_ACCESS_TOKEN   = os.getenv("MP_ACCESS_TOKEN", "TEST-XXXXXXXX")
MP_WEBHOOK_SECRET = os.getenv("MP_WEBHOOK_SECRET", "")
STRIPE_SECRET_KEY       = os.getenv("STRIPE_SECRET_KEY", "")
STRIPE_WEBHOOK_SECRET   = os.getenv("STRIPE_WEBHOOK_SECRET", "")
BASE_URL = os.getenv("BASE_URL", "https://saludenlinea-production.up.railway.app")
ADMIN_KEY = os.getenv("ADMIN_KEY", "saludenlinea-admin-2025")

# ── Pydantic ──────────────────────────────────────────────────────────────────

class PreferenceRequest(BaseModel):
    appointment_id: int


class SinpeRequest(BaseModel):
    appointment_id: int
    sinpe_referencia: str          # últimos 4 dígitos o código de confirmación
    sinpe_telefono: str            # teléfono del que envió
    comprobante_b64: Optional[str] = None  # imagen base64 del comprobante (opcional)

    @field_validator("sinpe_referencia")
    @classmethod
    def ref_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("La referencia SINPE no puede estar vacía")
        return v

    @field_validator("sinpe_telefono")
    @classmethod
    def tel_format(cls, v: str) -> str:
        v = v.strip().replace("-", "").replace(" ", "")
        if len(v) < 8:
            raise ValueError("Teléfono SINPE inválido")
        return v


class StripeCheckoutRequest(BaseModel):
    appointment_id: int


# ── Helpers ───────────────────────────────────────────────────────────────────

def _get_cita_owned(appointment_id: int, paciente_id: int, db: Session) -> Appointment:
    cita = db.query(Appointment).filter(
        Appointment.id == appointment_id,
        Appointment.paciente_id == paciente_id,
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    return cita


def _get_or_create_pago(cita: Appointment, monto: float, metodo: str, db: Session) -> Payment:
    pago = db.query(Payment).filter(Payment.cita_id == cita.id).first()
    if pago:
        pago.metodo = metodo
        pago.monto = monto
    else:
        pago = Payment(cita_id=cita.id, monto=monto, metodo=metodo, estado="pendiente")
        db.add(pago)
    return pago


# ── MercadoPago ───────────────────────────────────────────────────────────────

@router.post("/preference")
def create_preference(
    data: PreferenceRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    if not MP_AVAILABLE:
        raise HTTPException(status_code=503, detail="SDK de Mercado Pago no instalado")

    cita = _get_cita_owned(data.appointment_id, int(current["sub"]), db)
    doctor = db.query(Doctor).filter(Doctor.id == cita.doctor_id).first()

    sdk = mercadopago.SDK(MP_ACCESS_TOKEN)
    preference_data = {
        "items": [{
            "id": str(cita.id),
            "title": f"Consulta con {doctor.nombre} — {doctor.especialidad}",
            "quantity": 1,
            "unit_price": float(doctor.tarifa),
            "currency_id": "USD",
        }],
        "payer": {"email": current["email"]},
        "back_urls": {
            "success": f"{BASE_URL}/api/payments/resultado/success",
            "failure": f"{BASE_URL}/api/payments/resultado/failure",
            "pending": f"{BASE_URL}/api/payments/resultado/pending",
        },
        "auto_return": "approved",
        "external_reference": str(cita.id),
        "notification_url": f"{BASE_URL}/api/payments/webhook",
        "marketplace_fee": round(float(doctor.tarifa) * 0.15, 2),
    }

    result = sdk.preference().create(preference_data)
    response = result["response"]
    if result["status"] not in [200, 201]:
        raise HTTPException(status_code=400, detail=f"Error MP: {response}")

    pago = _get_or_create_pago(cita, doctor.tarifa, "mercadopago", db)
    pago.referencia_externa = response["id"]
    db.commit()

    return {
        "preference_id": response["id"],
        "init_point": response["init_point"],
        "sandbox_init_point": response["sandbox_init_point"],
    }


@router.post("/webhook")
async def mp_webhook(request: Request, db: Session = Depends(get_db)):
    body = await request.body()

    if MP_WEBHOOK_SECRET:
        sig_header = request.headers.get("x-signature", "")
        req_id = request.headers.get("x-request-id", "")
        expected = hmac.new(
            MP_WEBHOOK_SECRET.encode(),
            f"{req_id}:{body.decode()}".encode(),
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(sig_header, f"ts={req_id},v1={expected}"):
            raise HTTPException(status_code=401, detail="Firma inválida")

    data = await request.json()
    topic = data.get("type") or data.get("topic")

    if topic in ("payment", "merchant_order") and MP_AVAILABLE:
        payment_id = data.get("data", {}).get("id") or data.get("id")
        if payment_id:
            sdk = mercadopago.SDK(MP_ACCESS_TOKEN)
            result = sdk.payment().get(payment_id)
            mp_payment = result["response"]
            status = mp_payment.get("status")
            cita_id = mp_payment.get("external_reference")
            if cita_id:
                pago = db.query(Payment).filter(Payment.cita_id == int(cita_id)).first()
                if pago:
                    pago.estado = "exitoso" if status == "approved" else status
                    db.commit()

    return {"status": "ok"}


def _pagina_retorno(exito: bool, titulo: str, mensaje: str) -> str:
    """Página HTML que se muestra al volver del checkout, con botón para reabrir la app."""
    icono = "✅" if exito else ("⏳" if "confirma" in mensaje else "❌")
    color = "#00C896" if exito else "#F59E0B"
    return f"""<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{titulo} — SaludEnLínea</title>
<style>
 body {{ font-family:'Segoe UI',system-ui,sans-serif; background:#0B2545; color:#fff;
        display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; }}
 .box {{ text-align:center; padding:40px 28px; max-width:400px; }}
 .ic {{ font-size:64px; }}
 h1 {{ font-size:24px; margin:16px 0 8px; }}
 p {{ color:rgba(255,255,255,.75); line-height:1.6; font-size:15px; }}
 a.btn {{ display:inline-block; margin-top:28px; background:{color}; color:#06283d;
        font-weight:700; padding:15px 36px; border-radius:12px; text-decoration:none; font-size:16px; }}
 .peq {{ margin-top:14px; font-size:12px; color:rgba(255,255,255,.5); }}
</style></head>
<body><div class="box">
 <div class="ic">{icono}</div>
 <h1>{titulo}</h1>
 <p>{mensaje}</p>
 <a class="btn" href="saludenlinea://pago">Volver a SaludEnLínea</a>
 <p class="peq">Si el botón no funciona, abrí la app manualmente — tu pago ya quedó registrado.</p>
</div>
<script>setTimeout(function(){{ window.location.href = "saludenlinea://pago"; }}, 1500);</script>
</body></html>"""


from fastapi.responses import HTMLResponse


@router.get("/resultado/{estado}", response_class=HTMLResponse)
def resultado_pago(estado: str):
    paginas = {
        "success": (True, "¡Pago exitoso!", "Tu cita ha sido confirmada. Ya puedes volver a la app."),
        "failure": (False, "Pago no completado", "El pago fue cancelado o rechazado. Puedes intentarlo de nuevo desde la app."),
        "pending": (False, "Pago pendiente", "Tu pago está en proceso. Se confirmará en unos minutos."),
    }
    exito, titulo, msg = paginas.get(estado, (False, "Estado desconocido", "Volvé a la app para ver el estado de tu pago."))
    return _pagina_retorno(exito, titulo, msg)


# ── SINPE Móvil ───────────────────────────────────────────────────────────────

NUMERO_SINPE = os.getenv("SINPE_NUMERO", "88529543")   # número receptor configurado en Railway

@router.get("/sinpe/info")
def sinpe_info():
    """Retorna el número SINPE de la plataforma para que el paciente transfiera."""
    return {
        "numero": NUMERO_SINPE,
        "nombre": "SaludEnLínea S.A.",
        "instrucciones": (
            "Transfiere el monto exacto al número SINPE indicado. "
            "Luego ingresa el código de confirmación (4 últimos dígitos del número de referencia) "
            "y adjunta la captura del comprobante."
        ),
    }


@router.post("/sinpe")
def reportar_sinpe(
    data: SinpeRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """Paciente reporta que realizó el pago por SINPE Móvil."""
    cita = _get_cita_owned(data.appointment_id, int(current["sub"]), db)
    doctor = db.query(Doctor).filter(Doctor.id == cita.doctor_id).first()

    pago = _get_or_create_pago(cita, doctor.tarifa if doctor else 0.0, "sinpe", db)
    pago.sinpe_referencia = data.sinpe_referencia
    pago.sinpe_telefono = data.sinpe_telefono
    if data.comprobante_b64:
        pago.comprobante_b64 = data.comprobante_b64
    pago.estado = "pendiente_verificacion"
    db.commit()

    logger.info("SINPE reportado cita_id=%s paciente_id=%s ref=%s",
                cita.id, current["sub"], data.sinpe_referencia)

    return {
        "mensaje": "Pago SINPE reportado. Un administrador lo verificará en breve.",
        "pago_id": pago.id,
        "estado": pago.estado,
    }


@router.get("/sinpe/status/{appointment_id}")
def estado_sinpe(
    appointment_id: int,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """Paciente consulta el estado de verificación de su SINPE."""
    cita = _get_cita_owned(appointment_id, int(current["sub"]), db)
    pago = db.query(Payment).filter(Payment.cita_id == cita.id).first()
    if not pago:
        return {"estado": "sin_pago"}
    return {
        "estado": pago.estado,
        "metodo": pago.metodo,
        "verificado_en": pago.verificado_en.isoformat() if pago.verificado_en else None,
    }


# ── Admin: verificar SINPE ────────────────────────────────────────────────────

@router.post("/admin/verify/{payment_id}")
def admin_verify_sinpe(
    payment_id: int,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    """Admin confirma el pago SINPE → activa la cita."""
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="No autorizado")

    pago = db.query(Payment).filter(Payment.id == payment_id).first()
    if not pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado")
    if pago.estado == "exitoso":
        return {"mensaje": "Ya estaba verificado", "pago_id": pago.id}

    pago.estado = "exitoso"
    pago.verificado_en = datetime.utcnow()
    db.commit()

    logger.info("SINPE verificado admin pago_id=%s cita_id=%s", pago.id, pago.cita_id)
    return {"mensaje": "Pago SINPE verificado correctamente", "pago_id": pago.id}


@router.get("/admin/pending")
def admin_list_pending(
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    """Admin lista pagos SINPE pendientes de verificación."""
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="No autorizado")

    pagos = db.query(Payment).filter(
        Payment.estado == "pendiente_verificacion",
        Payment.metodo == "sinpe",
    ).order_by(Payment.fecha_pago).all()

    return [
        {
            "id": p.id,
            "cita_id": p.cita_id,
            "monto": p.monto,
            "sinpe_referencia": p.sinpe_referencia,
            "sinpe_telefono": p.sinpe_telefono,
            "tiene_comprobante": bool(p.comprobante_b64),
            "fecha_pago": p.fecha_pago.isoformat() if p.fecha_pago else None,
        }
        for p in pagos
    ]


@router.get("/admin/comprobante/{payment_id}")
def admin_ver_comprobante(
    payment_id: int,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    """Admin descarga el comprobante base64 de un pago SINPE."""
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="No autorizado")
    pago = db.query(Payment).filter(Payment.id == payment_id).first()
    if not pago or not pago.comprobante_b64:
        raise HTTPException(status_code=404, detail="Comprobante no disponible")
    return {"comprobante_b64": pago.comprobante_b64}


# ── ONVO Pay (tarjetas — pasarela de Costa Rica) ──────────────────────────────

ONVO_SECRET_KEY = os.getenv("ONVO_SECRET_KEY", "")
ONVO_API = "https://api.onvopay.com/v1"


def _onvo_post(path: str, payload: dict) -> dict:
    import requests as _rq
    r = _rq.post(
        f"{ONVO_API}{path}",
        json=payload,
        headers={"Authorization": f"Bearer {ONVO_SECRET_KEY}"},
        timeout=20,
    )
    if r.status_code not in (200, 201):
        logger.warning("ONVO error %s: %s", r.status_code, r.text[:300])
        raise HTTPException(status_code=502, detail="Error creando el pago con ONVO")
    return r.json()


def _onvo_get(path: str) -> dict:
    import requests as _rq
    r = _rq.get(
        f"{ONVO_API}{path}",
        headers={"Authorization": f"Bearer {ONVO_SECRET_KEY}"},
        timeout=20,
    )
    if r.status_code != 200:
        raise HTTPException(status_code=502, detail="Error consultando el pago con ONVO")
    return r.json()


class OnvoCheckoutRequest(BaseModel):
    appointment_id: int


@router.post("/onvo/checkout")
def onvo_checkout(
    data: OnvoCheckoutRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """Crea un link de pago ONVO (tarjeta) para una cita."""
    if not ONVO_SECRET_KEY:
        raise HTTPException(status_code=503, detail="Pagos con tarjeta no configurados aún")

    cita = _get_cita_owned(data.appointment_id, int(current["sub"]), db)
    doctor = db.query(Doctor).filter(Doctor.id == cita.doctor_id).first()

    session = _onvo_post("/checkout/sessions/one-time-link", {
        "lineItems": [{
            "quantity": 1,
            "unitAmount": int(round(float(doctor.tarifa) * 100)),  # centavos
            "currency": "USD",
            "description": f"Consulta con {doctor.nombre} — {doctor.especialidad}",
        }],
        "customerEmail": current["email"],
        "redirectUrl": f"{BASE_URL}/api/payments/onvo/success?cita_id={cita.id}",
        "cancelUrl": f"{BASE_URL}/api/payments/resultado/failure",
        "metadata": {"cita_id": str(cita.id)},
    })

    pago = _get_or_create_pago(cita, doctor.tarifa, "onvo", db)
    pago.referencia_externa = session.get("id", "")
    db.commit()

    return {"checkout_url": session.get("url"), "session_id": session.get("id")}


@router.get("/onvo/success", response_class=HTMLResponse)
def onvo_success(cita_id: int, db: Session = Depends(get_db)):
    """ONVO redirige aquí tras el pago. Verificamos el estado real contra su API."""
    pago = db.query(Payment).filter(
        Payment.cita_id == cita_id, Payment.metodo == "onvo",
    ).first()
    if not pago or not pago.referencia_externa:
        return _pagina_retorno(False, "Pago no encontrado", "No encontramos este pago. Volvé a la app e intentá de nuevo.")

    if pago.estado != "exitoso" and ONVO_SECRET_KEY:
        session = _onvo_get(f"/checkout/sessions/{pago.referencia_externa}")
        if session.get("status") == "complete":
            pago.estado = "exitoso"
            pago.verificado_en = datetime.utcnow()
            db.commit()
            logger.info("ONVO pago exitoso cita_id=%s session=%s", cita_id, pago.referencia_externa)

    if pago.estado == "exitoso":
        return _pagina_retorno(True, "¡Pago exitoso!", "Tu cita ha sido confirmada. Ya podés entrar a la consulta desde la app.")
    return _pagina_retorno(False, "Pago pendiente", "El pago aún no se confirma. Si ya pagaste, se reflejará en unos minutos.")


# ── Stripe ────────────────────────────────────────────────────────────────────

@router.post("/stripe/checkout")
def stripe_checkout(
    data: StripeCheckoutRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """Crea sesión de Checkout de Stripe y retorna la URL de pago."""
    if not STRIPE_AVAILABLE or not STRIPE_SECRET_KEY:
        raise HTTPException(status_code=503, detail="Stripe no configurado")

    stripe_lib.api_key = STRIPE_SECRET_KEY

    cita = _get_cita_owned(data.appointment_id, int(current["sub"]), db)
    doctor = db.query(Doctor).filter(Doctor.id == cita.doctor_id).first()

    session = stripe_lib.checkout.Session.create(
        payment_method_types=["card"],
        line_items=[{
            "price_data": {
                "currency": "usd",
                "product_data": {
                    "name": f"Consulta con {doctor.nombre}",
                    "description": doctor.especialidad,
                },
                "unit_amount": int(doctor.tarifa * 100),  # centavos
            },
            "quantity": 1,
        }],
        mode="payment",
        success_url=f"{BASE_URL}/api/payments/resultado/success?session_id={{CHECKOUT_SESSION_ID}}",
        cancel_url=f"{BASE_URL}/api/payments/resultado/failure",
        metadata={"cita_id": str(cita.id)},
        customer_email=current["email"],
    )

    pago = _get_or_create_pago(cita, doctor.tarifa, "stripe", db)
    pago.referencia_externa = session.id
    db.commit()

    return {"checkout_url": session.url, "session_id": session.id}


@router.post("/stripe/webhook")
async def stripe_webhook(request: Request, db: Session = Depends(get_db)):
    """Stripe notifica aquí el resultado del pago."""
    if not STRIPE_AVAILABLE or not STRIPE_WEBHOOK_SECRET:
        raise HTTPException(status_code=503, detail="Stripe webhook no configurado")

    stripe_lib.api_key = STRIPE_SECRET_KEY
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature", "")

    try:
        event = stripe_lib.Webhook.construct_event(payload, sig_header, STRIPE_WEBHOOK_SECRET)
    except stripe_lib.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Firma Stripe inválida")

    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        cita_id = session.get("metadata", {}).get("cita_id")
        if cita_id:
            pago = db.query(Payment).filter(Payment.cita_id == int(cita_id)).first()
            if pago:
                pago.estado = "exitoso"
                pago.verificado_en = datetime.utcnow()
                db.commit()
                logger.info("Stripe pago exitoso cita_id=%s session=%s", cita_id, session.get("id"))

    return {"status": "ok"}
