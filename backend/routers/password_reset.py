import os
import secrets
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from database import get_db
from models import Patient, Doctor
from utils.auth import hash_password
import httpx

limiter = Limiter(key_func=get_remote_address)
router = APIRouter(prefix="/api/auth", tags=["password-reset"])

RESEND_API_KEY = os.getenv("RESEND_API_KEY", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", "onboarding@resend.dev")
BASE_URL = os.getenv("BASE_URL", "https://saludenlinea-production.up.railway.app")

# Almacenamiento en memoria (suficiente para MVP)
# token -> {email, role, expires}
_reset_tokens: dict[str, dict] = {}


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


def _send_reset_email(to_email: str, nombre: str, token: str):
    reset_link = f"saludenlinea://reset-password?token={token}"
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto;">
      <div style="background: #1a3a5c; padding: 24px; border-radius: 8px 8px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 22px;">SaludEnLínea</h1>
      </div>
      <div style="background: #f4f6f8; padding: 32px; border-radius: 0 0 8px 8px;">
        <h2 style="color: #1a3a5c;">Recuperar contraseña</h2>
        <p>Hola <strong>{nombre}</strong>,</p>
        <p>Recibimos una solicitud para restablecer tu contraseña. Usa el código de abajo en la app:</p>
        <div style="background: white; border: 2px solid #2ecc71; border-radius: 8px; padding: 20px; text-align: center; margin: 24px 0;">
          <p style="font-size: 13px; color: #666; margin: 0 0 8px 0;">Tu código de recuperación:</p>
          <code style="font-size: 28px; font-weight: bold; color: #1a3a5c; letter-spacing: 4px;">{token[:8].upper()}</code>
        </div>
        <p style="color: #666; font-size: 13px;">Este código expira en <strong>1 hora</strong>. Si no solicitaste esto, ignora este correo.</p>
        <hr style="border: none; border-top: 1px solid #ddd; margin: 24px 0;">
        <p style="color: #999; font-size: 12px; text-align: center;">SaludEnLínea — Telemedicina para Costa Rica</p>
      </div>
    </div>
    """

    if not RESEND_API_KEY:
        return  # silently skip in dev

    import httpx
    httpx.post(
        "https://api.resend.com/emails",
        headers={"Authorization": f"Bearer {RESEND_API_KEY}"},
        json={
            "from": f"SaludEnLínea <{FROM_EMAIL}>",
            "to": [to_email],
            "subject": "Recuperar contraseña — SaludEnLínea",
            "html": html,
        },
        timeout=10,
    )


@router.post("/forgot-password")
@limiter.limit("3/minute")
def forgot_password(request: Request, data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(Patient).filter(Patient.email == data.email).first()
    role = "patient"
    if not user:
        user = db.query(Doctor).filter(Doctor.email == data.email).first()
        role = "doctor"

    # Siempre responder OK para no revelar si el email existe
    if not user:
        return {"message": "Si el correo existe, recibirás instrucciones."}

    token = secrets.token_hex(16)
    _reset_tokens[token] = {
        "email": data.email,
        "role": role,
        "expires": datetime.utcnow() + timedelta(hours=1),
    }

    _send_reset_email(data.email, user.nombre, token)
    return {"message": "Si el correo existe, recibirás instrucciones."}


@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    if len(data.new_password) < 6:
        raise HTTPException(status_code=400, detail="La contraseña debe tener al menos 6 caracteres")

    # Buscar token (exacto o por prefijo de 8 chars en mayúscula)
    entry = _reset_tokens.get(data.token)
    if not entry:
        # Buscar por código corto (los primeros 8 chars en hex)
        code = data.token.lower()
        for tok, val in _reset_tokens.items():
            if tok[:8] == code:
                entry = val
                token_key = tok
                break
        else:
            raise HTTPException(status_code=400, detail="Código inválido o expirado")
        token_key = [t for t in _reset_tokens if t[:8] == code][0]
    else:
        token_key = data.token

    if datetime.utcnow() > entry["expires"]:
        del _reset_tokens[token_key]
        raise HTTPException(status_code=400, detail="El código ha expirado")

    email = entry["email"]
    role = entry["role"]

    if role == "patient":
        user = db.query(Patient).filter(Patient.email == email).first()
    else:
        user = db.query(Doctor).filter(Doctor.email == email).first()

    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    user.pass_hash = hash_password(data.new_password)
    db.commit()
    del _reset_tokens[token_key]

    return {"message": "Contraseña actualizada correctamente"}
