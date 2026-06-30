"""
Integración con Mercado Pago.
Flujo:
  1. POST /api/payments/preference  → crea preferencia y retorna init_point (URL de pago)
  2. MP redirige al webhook /api/payments/webhook con resultado
  3. El backend actualiza el estado de la cita según el resultado
"""
import os
import hmac
import hashlib
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel
from database import get_db
from models import Appointment, Payment, Doctor
from utils.auth import require_patient

# pip install mercadopago
try:
    import mercadopago
    MP_AVAILABLE = True
except ImportError:
    MP_AVAILABLE = False

router = APIRouter(prefix="/api/payments", tags=["payments"])

MP_ACCESS_TOKEN = os.getenv("MP_ACCESS_TOKEN", "TEST-XXXXXXXX")  # ← Railway env var
MP_WEBHOOK_SECRET = os.getenv("MP_WEBHOOK_SECRET", "")
BASE_URL = os.getenv("BASE_URL", "http://localhost:8001")  # URL pública del servidor


class PreferenceRequest(BaseModel):
    appointment_id: int


@router.post("/preference")
def create_preference(
    data: PreferenceRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """
    Crea una preferencia de pago en Mercado Pago.
    Retorna la URL donde el paciente completa el pago.
    """
    if not MP_AVAILABLE:
        raise HTTPException(status_code=503, detail="Mercado Pago SDK no instalado. Ejecuta: pip install mercadopago")

    cita = db.query(Appointment).filter(
        Appointment.id == data.appointment_id,
        Appointment.paciente_id == int(current["sub"]),
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")

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
        "payer": {
            "email": current["email"],
        },
        "back_urls": {
            "success": f"{BASE_URL}/api/payments/resultado/success",
            "failure": f"{BASE_URL}/api/payments/resultado/failure",
            "pending": f"{BASE_URL}/api/payments/resultado/pending",
        },
        "auto_return": "approved",
        "external_reference": str(cita.id),
        "notification_url": f"{BASE_URL}/api/payments/webhook",
        # Comisión de la plataforma: 15% del valor
        "marketplace_fee": round(float(doctor.tarifa) * 0.15, 2),
    }

    result = sdk.preference().create(preference_data)
    response = result["response"]

    if result["status"] not in [200, 201]:
        raise HTTPException(status_code=400, detail=f"Error MP: {response}")

    # Guardar referencia del pago
    pago = db.query(Payment).filter(Payment.cita_id == cita.id).first()
    if pago:
        pago.referencia_externa = response["id"]
    else:
        pago = Payment(
            cita_id=cita.id,
            monto=doctor.tarifa,
            metodo="mercadopago",
            estado="pendiente",
            referencia_externa=response["id"],
        )
        db.add(pago)
    db.commit()

    return {
        "preference_id": response["id"],
        "init_point": response["init_point"],        # URL de pago real
        "sandbox_init_point": response["sandbox_init_point"],  # URL de prueba
    }


@router.post("/webhook")
async def mp_webhook(request: Request, db: Session = Depends(get_db)):
    """
    Mercado Pago notifica aquí cuando un pago cambia de estado.
    """
    body = await request.body()

    # Siempre verificar firma — rechazar si no hay secret configurado
    if not MP_WEBHOOK_SECRET:
        raise HTTPException(status_code=503, detail="Webhook no configurado")

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

    if topic in ("payment", "merchant_order"):
        payment_id = data.get("data", {}).get("id") or data.get("id")
        if not payment_id:
            return {"status": "ignored"}

        if not MP_AVAILABLE:
            return {"status": "sdk_not_installed"}

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


@router.get("/resultado/{estado}")
def resultado_pago(estado: str):
    """Página de resultado tras el pago (MP redirige aquí)."""
    mensajes = {
        "success": "¡Pago exitoso! Tu cita ha sido confirmada.",
        "failure": "El pago no se pudo completar. Intenta de nuevo.",
        "pending": "Pago pendiente. Te notificaremos cuando se confirme.",
    }
    return {"resultado": estado, "mensaje": mensajes.get(estado, "Estado desconocido")}
