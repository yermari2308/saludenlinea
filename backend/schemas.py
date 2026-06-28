from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, field_validator


# ── Auth ──────────────────────────────────────────────────────────────────────

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str  # "patient" | "doctor"
    user_id: int = 0
    nombre: str = ""


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


# ── Patients ──────────────────────────────────────────────────────────────────

class PatientCreate(BaseModel):
    nombre: str
    email: EmailStr
    password: str
    telefono: Optional[str] = None
    fecha_nacimiento: Optional[str] = None

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 6:
            raise ValueError("La contraseña debe tener al menos 6 caracteres")
        return v

    @field_validator("nombre")
    @classmethod
    def nombre_not_empty(cls, v):
        if not v.strip():
            raise ValueError("El nombre no puede estar vacío")
        return v.strip()


class PatientOut(BaseModel):
    id: int
    nombre: str
    email: str
    telefono: Optional[str]
    fecha_nacimiento: Optional[str]
    historial_texto: str

    model_config = {"from_attributes": True}


# ── Doctors ───────────────────────────────────────────────────────────────────

class DoctorCreate(BaseModel):
    nombre: str
    email: EmailStr
    password: str
    especialidad: str
    credenciales: Optional[str] = ""
    tarifa: Optional[float] = 15.0


class DoctorOut(BaseModel):
    id: int
    nombre: str
    especialidad: str
    foto_url: str
    credenciales: str
    tarifa: float
    calificacion: float

    model_config = {"from_attributes": True}


# ── Appointments ──────────────────────────────────────────────────────────────

class AppointmentCreate(BaseModel):
    doctor_id: int
    fecha_hora: datetime
    metodo_pago: str = "tarjeta"


class AppointmentOut(BaseModel):
    id: int
    paciente_id: int
    doctor_id: int
    fecha_hora: datetime
    estado: str
    notas_texto: str
    receta_texto: str
    creado_en: datetime

    model_config = {"from_attributes": True}


class NotasUpdate(BaseModel):
    notas_texto: Optional[str] = ""
    receta_texto: Optional[str] = ""


# ── Payments ──────────────────────────────────────────────────────────────────

class PaymentOut(BaseModel):
    id: int
    cita_id: int
    monto: float
    metodo: str
    estado: str
    fecha_pago: datetime

    model_config = {"from_attributes": True}


# ── Sessions ──────────────────────────────────────────────────────────────────

class SessionOut(BaseModel):
    id: int
    cita_id: int
    token_sala: str
    jitsi_url: str = ""

    model_config = {"from_attributes": True}
