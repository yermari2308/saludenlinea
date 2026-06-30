import os
import re
import base64
import secrets
from typing import List
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import Response
from sqlalchemy.orm import Session
from database import get_db
from models import Appointment, Doctor, Payment, ConsultSession
from schemas import AppointmentCreate, AppointmentOut, NotasUpdate, SessionOut, RescheduleRequest
from utils.auth import require_patient, require_doctor, get_current_user

router = APIRouter(prefix="/api", tags=["appointments"])

JITSI_HOST = os.getenv("JITSI_HOST", "meet.jit.si")


def _jitsi_url(token_sala: str, display_name: str = "") -> str:
    # Convierte el token a un nombre de sala URL-seguro
    room = re.sub(r"[^a-zA-Z0-9]", "", token_sala)[:32]
    room = f"SaludEnLinea{room}"
    base = f"https://{JITSI_HOST}/{room}"
    if display_name:
        safe = display_name.replace(" ", "%20")
        return f"{base}#userInfo.displayName=\"{safe}\""
    return base


@router.post("/appointments", response_model=AppointmentOut, status_code=201)
def create_appointment(
    data: AppointmentCreate,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    doctor = db.query(Doctor).filter(Doctor.id == data.doctor_id, Doctor.activo == True).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Médico no encontrado")

    cita = Appointment(
        paciente_id=int(current["sub"]),
        doctor_id=data.doctor_id,
        fecha_hora=data.fecha_hora,
        estado="programada",
    )
    db.add(cita)
    db.flush()

    # Registrar pago pendiente
    pago = Payment(
        cita_id=cita.id,
        monto=doctor.tarifa,
        metodo=data.metodo_pago,
        estado="pendiente",
    )
    db.add(pago)
    db.commit()
    db.refresh(cita)
    return cita


@router.get("/appointments", response_model=List[AppointmentOut])
def list_appointments(
    db: Session = Depends(get_db),
    current=Depends(get_current_user),
):
    role = current["role"]
    uid = int(current["sub"])
    if role == "patient":
        return db.query(Appointment).filter(Appointment.paciente_id == uid).all()
    else:
        return db.query(Appointment).filter(Appointment.doctor_id == uid).all()


@router.post("/cancel/{appointment_id}")
def cancel_appointment(
    appointment_id: int,
    db: Session = Depends(get_db),
    current=Depends(get_current_user),
):
    cita = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    uid = int(current["sub"])
    if current["role"] == "patient" and cita.paciente_id != uid:
        raise HTTPException(status_code=403, detail="No autorizado")
    if cita.estado != "programada":
        raise HTTPException(status_code=400, detail="Solo se pueden cancelar citas programadas")
    cita.estado = "cancelada"
    db.commit()
    return {"message": "Cita cancelada"}


@router.get("/consultation/{appointment_id}", response_model=SessionOut)
def get_or_create_session(
    appointment_id: int,
    db: Session = Depends(get_db),
    current=Depends(get_current_user),
):
    cita = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    if cita.estado == "cancelada":
        raise HTTPException(status_code=400, detail="Cita cancelada")
    if cita.estado == "completada":
        raise HTTPException(status_code=400, detail="Esta consulta ya fue finalizada")

    uid = int(current["sub"])
    role = current["role"]
    if role == "patient" and cita.paciente_id != uid:
        raise HTTPException(status_code=403, detail="No autorizado")
    if role == "doctor" and cita.doctor_id != uid:
        raise HTTPException(status_code=403, detail="No autorizado")

    sesion = db.query(ConsultSession).filter(ConsultSession.cita_id == appointment_id).first()
    if not sesion:
        sesion = ConsultSession(
            cita_id=appointment_id,
            token_sala=secrets.token_urlsafe(32),
            inicio=datetime.utcnow(),
        )
        db.add(sesion)
        db.commit()
        db.refresh(sesion)

    display = cita.paciente.nombre if role == "patient" else cita.doctor.nombre
    sesion.jitsi_url = _jitsi_url(sesion.token_sala, display)
    return sesion


@router.put("/consultation/{appointment_id}/notes")
def update_notes(
    appointment_id: int,
    data: NotasUpdate,
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    cita = db.query(Appointment).filter(
        Appointment.id == appointment_id,
        Appointment.doctor_id == int(current["sub"]),
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    if data.notas_texto is not None:
        cita.notas_texto = data.notas_texto
    if data.receta_texto is not None:
        cita.receta_texto = data.receta_texto
    cita.estado = "completada"
    db.commit()
    return {"message": "Notas guardadas"}


@router.get("/receta/{appointment_id}")
def get_receta(
    appointment_id: int,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    cita = db.query(Appointment).filter(
        Appointment.id == appointment_id,
        Appointment.paciente_id == int(current["sub"]),
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    return {
        "appointment_id": appointment_id,
        "receta": cita.receta_texto,
        "notas": cita.notas_texto,
        "fecha": cita.fecha_hora,
    }


@router.post("/appointments/{appointment_id}/finalizar")
def finalizar_consulta(
    appointment_id: int,
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    cita = db.query(Appointment).filter(
        Appointment.id == appointment_id,
        Appointment.doctor_id == int(current["sub"]),
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    if cita.estado == "cancelada":
        raise HTTPException(status_code=400, detail="Cita cancelada")
    cita.estado = "completada"
    db.commit()
    return {"message": "Consulta finalizada"}


@router.put("/appointments/{appointment_id}/reagendar")
def reagendar_cita(
    appointment_id: int,
    data: RescheduleRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    cita = db.query(Appointment).filter(
        Appointment.id == appointment_id,
        Appointment.paciente_id == int(current["sub"]),
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    if cita.estado != "programada":
        raise HTTPException(status_code=400, detail="Solo se pueden reagendar citas programadas")
    if data.fecha_hora <= datetime.utcnow():
        raise HTTPException(status_code=400, detail="La nueva fecha debe ser en el futuro")
    cita.fecha_hora = data.fecha_hora
    db.commit()
    db.refresh(cita)
    return cita


@router.post("/appointments/{appointment_id}/receta-archivo")
async def subir_receta_archivo(
    appointment_id: int,
    archivo: UploadFile = File(...),
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    cita = db.query(Appointment).filter(
        Appointment.id == appointment_id,
        Appointment.doctor_id == int(current["sub"]),
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    if archivo.content_type not in ("application/pdf", "image/jpeg", "image/png"):
        raise HTTPException(status_code=400, detail="Solo se permiten PDF, JPG o PNG")
    contenido = await archivo.read()
    if len(contenido) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Archivo muy grande (máximo 5 MB)")
    cita.receta_archivo_nombre = archivo.filename or "receta.pdf"
    cita.receta_archivo_b64 = base64.b64encode(contenido).decode()
    db.commit()
    return {"message": "Archivo subido correctamente", "nombre": cita.receta_archivo_nombre}


@router.get("/appointments/{appointment_id}/receta-archivo")
def descargar_receta_archivo(
    appointment_id: int,
    db: Session = Depends(get_db),
    current=Depends(get_current_user),
):
    cita = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    uid = int(current["sub"])
    role = current["role"]
    if role == "patient" and cita.paciente_id != uid:
        raise HTTPException(status_code=403, detail="No autorizado")
    if role == "doctor" and cita.doctor_id != uid:
        raise HTTPException(status_code=403, detail="No autorizado")
    if not cita.receta_archivo_b64:
        raise HTTPException(status_code=404, detail="No hay archivo de receta")
    contenido = base64.b64decode(cita.receta_archivo_b64)
    nombre = cita.receta_archivo_nombre or "receta.pdf"
    content_type = "application/pdf" if nombre.endswith(".pdf") else "image/jpeg"
    return Response(
        content=contenido,
        media_type=content_type,
        headers={"Content-Disposition": f'attachment; filename="{nombre}"'},
    )
