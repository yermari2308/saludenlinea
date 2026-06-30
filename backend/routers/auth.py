import logging
from collections import defaultdict
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session
from database import get_db
from models import Patient, Doctor
from schemas import PatientCreate, DoctorCreate, LoginRequest, TokenResponse
from utils.auth import hash_password, verify_password, create_token

logger = logging.getLogger("saludenlinea.auth")
limiter = Limiter(key_func=get_remote_address)
router = APIRouter(prefix="/api", tags=["auth"])

# Rastreo de intentos fallidos por IP (en memoria, se resetea al reiniciar)
_failed_attempts: dict[str, list] = defaultdict(list)
ALERT_THRESHOLD = 5  # alertar si hay 5+ fallos en 10 minutos


def _track_failed_login(ip: str, email: str):
    now = datetime.utcnow()
    cutoff = now - timedelta(minutes=10)
    _failed_attempts[ip] = [t for t in _failed_attempts[ip] if t > cutoff]
    _failed_attempts[ip].append(now)
    count = len(_failed_attempts[ip])
    if count >= ALERT_THRESHOLD:
        logger.critical(
            "ALERTA SEGURIDAD: %d intentos fallidos desde ip=%s ultimo_email=%s",
            count, ip, email
        )


@router.post("/register/patient", response_model=TokenResponse, status_code=201)
@limiter.limit("10/minute")
def register_patient(request: Request, data: PatientCreate, db: Session = Depends(get_db)):
    if db.query(Patient).filter(Patient.email == data.email).first():
        logger.warning("Registro fallido — email duplicado: %s ip=%s", data.email, get_remote_address(request))
        raise HTTPException(status_code=400, detail="Email ya registrado")
    patient = Patient(
        nombre=data.nombre,
        email=data.email,
        telefono=data.telefono,
        fecha_nacimiento=data.fecha_nacimiento,
        pass_hash=hash_password(data.password),
    )
    db.add(patient)
    db.commit()
    db.refresh(patient)
    logger.info("Registro exitoso id=%s email=%s ip=%s", patient.id, patient.email, get_remote_address(request))
    token = create_token({"sub": str(patient.id), "role": "patient", "email": patient.email})
    return TokenResponse(access_token=token, role="patient", user_id=patient.id, nombre=patient.nombre)


@router.post("/register/doctor", status_code=410)
def register_doctor_disabled():
    raise HTTPException(
        status_code=410,
        detail="El registro público de médicos está deshabilitado. Contacta al administrador."
    )


@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(request: Request, data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(Patient).filter(Patient.email == data.email).first()
    role = "patient"
    if not user:
        user = db.query(Doctor).filter(Doctor.email == data.email).first()
        role = "doctor"
    if not user or not verify_password(data.password, user.pass_hash):
        ip = get_remote_address(request)
        logger.warning("Login fallido email=%s ip=%s", data.email, ip)
        _track_failed_login(ip, data.email)
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    logger.info("Login exitoso id=%s email=%s role=%s ip=%s", user.id, user.email, role, get_remote_address(request))
    token = create_token({"sub": str(user.id), "role": role, "email": user.email})
    return TokenResponse(access_token=token, role=role, user_id=user.id, nombre=user.nombre)
