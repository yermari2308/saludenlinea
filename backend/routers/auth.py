import logging
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
    return TokenResponse(access_token=token, role="patient", user_id=patient.id)


@router.post("/register/doctor", response_model=TokenResponse, status_code=201)
@limiter.limit("10/minute")
def register_doctor(request: Request, data: DoctorCreate, db: Session = Depends(get_db)):
    if db.query(Doctor).filter(Doctor.email == data.email).first():
        logger.warning("Registro médico fallido — email duplicado: %s ip=%s", data.email, get_remote_address(request))
        raise HTTPException(status_code=400, detail="Email ya registrado")
    doctor = Doctor(
        nombre=data.nombre,
        email=data.email,
        especialidad=data.especialidad,
        credenciales=data.credenciales or "",
        tarifa=data.tarifa or 15.0,
        pass_hash=hash_password(data.password),
    )
    db.add(doctor)
    db.commit()
    db.refresh(doctor)
    logger.info("Registro médico exitoso id=%s email=%s ip=%s", doctor.id, doctor.email, get_remote_address(request))
    token = create_token({"sub": str(doctor.id), "role": "doctor", "email": doctor.email})
    return TokenResponse(access_token=token, role="doctor", user_id=doctor.id)


@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(request: Request, data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(Patient).filter(Patient.email == data.email).first()
    role = "patient"
    if not user:
        user = db.query(Doctor).filter(Doctor.email == data.email).first()
        role = "doctor"
    if not user or not verify_password(data.password, user.pass_hash):
        logger.warning("Login fallido email=%s ip=%s", data.email, get_remote_address(request))
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    logger.info("Login exitoso id=%s email=%s role=%s ip=%s", user.id, user.email, role, get_remote_address(request))
    token = create_token({"sub": str(user.id), "role": role, "email": user.email})
    return TokenResponse(access_token=token, role=role, user_id=user.id)
