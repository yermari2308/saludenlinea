from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from pydantic import BaseModel, Field
from database import get_db
from models import Doctor, Appointment, Patient, Payment
from schemas import DoctorOut
from utils.auth import get_current_user, require_doctor

router = APIRouter(prefix="/api/doctors", tags=["doctors"])


class DoctorProfileUpdate(BaseModel):
    especialidad: Optional[str] = Field(default=None, max_length=100)
    credenciales: Optional[str] = Field(default=None, max_length=3000)
    tarifa: Optional[float] = Field(default=None, gt=0, le=1000)
    foto_url: Optional[str] = Field(default=None, max_length=500)
    horario_json: Optional[str] = Field(default=None, max_length=2000)
    codigo_medico: Optional[str] = Field(default=None, max_length=30)


# ── Perfil propio del médico (antes de /{doctor_id} para no chocar) ──────────

@router.get("/me/profile")
def mi_perfil_doctor(
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    doc = db.query(Doctor).filter(Doctor.id == int(current["sub"])).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Médico no encontrado")
    return {
        "id": doc.id,
        "nombre": doc.nombre,
        "email": doc.email,
        "especialidad": doc.especialidad,
        "credenciales": doc.credenciales,
        "tarifa": doc.tarifa,
        "foto_url": doc.foto_url,
        "calificacion": doc.calificacion,
        "horario_json": doc.horario_json,
        "disponible_urgente": doc.disponible_urgente,
        "codigo_medico": doc.codigo_medico or "",
    }


@router.put("/me/profile")
def actualizar_mi_perfil(
    data: DoctorProfileUpdate,
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    doc = db.query(Doctor).filter(Doctor.id == int(current["sub"])).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Médico no encontrado")
    for campo, valor in data.model_dump(exclude_none=True).items():
        setattr(doc, campo, valor)
    db.commit()
    return {"mensaje": "Perfil actualizado"}


@router.get("/me/patients")
def mis_pacientes(
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    """Pacientes que han tenido citas con este médico, con resumen."""
    doctor_id = int(current["sub"])
    filas = (
        db.query(
            Patient.id,
            Patient.nombre,
            Patient.email,
            Patient.telefono,
            func.count(Appointment.id).label("total_citas"),
            func.max(Appointment.fecha_hora).label("ultima_cita"),
        )
        .join(Appointment, Appointment.paciente_id == Patient.id)
        .filter(Appointment.doctor_id == doctor_id)
        .group_by(Patient.id, Patient.nombre, Patient.email, Patient.telefono)
        .order_by(func.max(Appointment.fecha_hora).desc())
        .all()
    )
    resultado = []
    for f in filas:
        # última cita programada (para chat) y última cita en general
        cita_activa = db.query(Appointment).filter(
            Appointment.doctor_id == doctor_id,
            Appointment.paciente_id == f.id,
            Appointment.estado == "programada",
        ).order_by(Appointment.fecha_hora.desc()).first()
        ultima = db.query(Appointment).filter(
            Appointment.doctor_id == doctor_id,
            Appointment.paciente_id == f.id,
        ).order_by(Appointment.fecha_hora.desc()).first()
        resultado.append({
            "paciente_id": f.id,
            "nombre": f.nombre,
            "email": f.email,
            "telefono": f.telefono or "",
            "total_citas": f.total_citas,
            "ultima_cita": f.ultima_cita.isoformat() if f.ultima_cita else None,
            "cita_activa_id": cita_activa.id if cita_activa else None,
            "ultima_cita_id": ultima.id if ultima else None,
        })
    return resultado


@router.get("/me/ingresos")
def mis_ingresos(
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    """Resumen de ingresos del médico: pagos exitosos de sus citas."""
    doctor_id = int(current["sub"])
    pagos = (
        db.query(Payment)
        .join(Appointment, Appointment.id == Payment.cita_id)
        .filter(
            Appointment.doctor_id == doctor_id,
            Payment.estado == "exitoso",
        )
        .order_by(Payment.fecha_pago.desc())
        .all()
    )

    COMISION = 0.15  # comisión de la plataforma
    ahora = datetime.utcnow()
    total_historico = 0.0
    total_mes = 0.0
    por_mes: dict = {}
    detalle = []

    for p in pagos:
        neto = round(p.monto * (1 - COMISION), 2)
        total_historico += neto
        clave = p.fecha_pago.strftime("%Y-%m") if p.fecha_pago else "?"
        por_mes[clave] = round(por_mes.get(clave, 0) + neto, 2)
        if p.fecha_pago and p.fecha_pago.year == ahora.year and p.fecha_pago.month == ahora.month:
            total_mes += neto
        if len(detalle) < 30:
            detalle.append({
                "cita_id": p.cita_id,
                "monto_bruto": p.monto,
                "monto_neto": neto,
                "metodo": p.metodo,
                "fecha": p.fecha_pago.isoformat() if p.fecha_pago else None,
            })

    return {
        "total_mes": round(total_mes, 2),
        "total_historico": round(total_historico, 2),
        "consultas_cobradas": len(pagos),
        "comision_plataforma": COMISION,
        "por_mes": [{"mes": k, "total": v} for k, v in sorted(por_mes.items(), reverse=True)[:12]],
        "detalle": detalle,
    }


# ── Endpoints públicos ────────────────────────────────────────────────────────

@router.get("", response_model=List[DoctorOut])
def list_doctors(
    especialidad: Optional[str] = None,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(Doctor).filter(Doctor.activo == True)  # noqa: E712
    if especialidad:
        query = query.filter(Doctor.especialidad.ilike(f"%{especialidad}%"))
    return query.all()


@router.get("/{doctor_id}", response_model=DoctorOut)
def get_doctor(
    doctor_id: int,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id, Doctor.activo == True).first()  # noqa: E712
    if not doctor:
        raise HTTPException(status_code=404, detail="Médico no encontrado")
    return doctor
