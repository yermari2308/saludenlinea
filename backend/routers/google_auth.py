"""
Google OAuth 2.0 — flujo web completo
1. GET  /api/auth/google          → redirige al login de Google
2. GET  /api/auth/google/callback → intercambia code por token, crea usuario, devuelve JWT
"""
import os
import logging
import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse
from database import get_db
from models import Patient
from utils.auth import create_token
from sqlalchemy.orm import Session
from fastapi import Depends

logger = logging.getLogger("saludenlinea.google_auth")
router = APIRouter(prefix="/api/auth", tags=["google-auth"])

GOOGLE_CLIENT_ID     = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "")
BASE_URL             = os.getenv("BASE_URL", "http://localhost:9000")
REDIRECT_URI         = f"{BASE_URL}/api/auth/google/callback"

GOOGLE_AUTH_URL  = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_USER_URL  = "https://www.googleapis.com/oauth2/v3/userinfo"

SCOPES = "openid email profile"


@router.get("/google")
def google_login():
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Google OAuth no configurado. Agrega GOOGLE_CLIENT_ID en .env")
    url = (
        f"{GOOGLE_AUTH_URL}"
        f"?client_id={GOOGLE_CLIENT_ID}"
        f"&redirect_uri={REDIRECT_URI}"
        f"&response_type=code"
        f"&scope={SCOPES}"
        f"&access_type=offline"
        f"&prompt=select_account"
    )
    return RedirectResponse(url)


@router.get("/google/callback")
async def google_callback(code: str = None, error: str = None, db: Session = Depends(get_db)):
    if error or not code:
        logger.warning("Google OAuth error: %s", error)
        return RedirectResponse(f"{BASE_URL}/?auth_error=google_cancelado")

    # Intercambiar code por access_token
    async with httpx.AsyncClient() as client:
        token_res = await client.post(GOOGLE_TOKEN_URL, data={
            "code": code,
            "client_id": GOOGLE_CLIENT_ID,
            "client_secret": GOOGLE_CLIENT_SECRET,
            "redirect_uri": REDIRECT_URI,
            "grant_type": "authorization_code",
        })
        if token_res.status_code != 200:
            logger.error("Error obteniendo token de Google: %s", token_res.text)
            return RedirectResponse(f"{BASE_URL}/?auth_error=token_fallido")

        tokens = token_res.json()
        access_token = tokens.get("access_token")

        # Obtener datos del usuario
        user_res = await client.get(GOOGLE_USER_URL, headers={"Authorization": f"Bearer {access_token}"})
        if user_res.status_code != 200:
            return RedirectResponse(f"{BASE_URL}/?auth_error=perfil_fallido")

        guser = user_res.json()

    email  = guser.get("email", "")
    nombre = guser.get("name", email.split("@")[0])

    if not email:
        return RedirectResponse(f"{BASE_URL}/?auth_error=sin_email")

    # Buscar o crear paciente
    patient = db.query(Patient).filter(Patient.email == email).first()
    if not patient:
        patient = Patient(
            nombre=nombre,
            email=email,
            pass_hash="GOOGLE_OAUTH",  # Sin contraseña local
            activo=True,
        )
        db.add(patient)
        db.commit()
        db.refresh(patient)
        logger.info("Nuevo paciente via Google: id=%s email=%s", patient.id, email)
    else:
        logger.info("Login Google existente: id=%s email=%s", patient.id, email)

    jwt = create_token({"sub": str(patient.id), "role": "patient", "email": patient.email})
    # Redirigir al frontend con el token en la URL
    return RedirectResponse(f"{BASE_URL}/?google_token={jwt}")
