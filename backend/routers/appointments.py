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
from models import Appointment, Doctor, Payment, ConsultSession, Subscription
from schemas import AppointmentCreate, AppointmentOut, NotasUpdate, SessionOut, RescheduleRequest
from utils.auth import require_patient, require_doctor, get_current_user

from utils.video import video_url as _jitsi_url  # Daily.co con fallback a Jitsi

router = APIRouter(prefix="/api", tags=["appointments"])


def _suscripcion_activa_con_cupo(paciente_id: int, db: Session):
    """Retorna la suscripción activa con consultas disponibles, o None."""
    ahora = datetime.utcnow()
    sub = db.query(Subscription).filter(
        Subscription.paciente_id == paciente_id,
        Subscription.estado == "activo",
        Subscription.fin >= ahora,
    ).first()
    if sub and (sub.consultas_incluidas == 0 or sub.consultas_usadas < sub.consultas_incluidas):
        return sub
    return None


def _verificar_pago_o_suscripcion(cita: Appointment, db: Session):
    """
    Bloquea el ingreso a la consulta si la cita no está pagada.
    Excepciones: consultas urgentes (Botón Rojo) y suscripción activa con cupo
    (en cuyo caso se consume una consulta del plan automáticamente).
    """
    pago = db.query(Payment).filter(Payment.cita_id == cita.id).first()

    if pago and pago.estado == "exitoso":
        return
    if pago and pago.metodo == "urgente":
        return  # urgencias se cobran aparte, no se bloquea la atención

    sub = _suscripcion_activa_con_cupo(cita.paciente_id, db)
    if sub:
        sub.consultas_usadas += 1
        if pago:
            pago.estado = "exitoso"
            pago.metodo = "suscripcion"
        else:
            db.add(Payment(cita_id=cita.id, monto=0.0, metodo="suscripcion", estado="exitoso"))
        db.commit()
        return

    raise HTTPException(
        status_code=402,
        detail="Debes completar el pago antes de entrar a la consulta.",
    )


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
        return db.query(Appointment).filter(
            Appointment.paciente_id == uid,
            (Appointment.oculta_paciente == False) | (Appointment.oculta_paciente.is_(None)),  # noqa: E712
        ).all()
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

    # ── El paciente debe haber aceptado el consentimiento y pagado ────────────
    if role == "patient":
        from routers.legal import paciente_acepto_telemedicina
        if not paciente_acepto_telemedicina(uid, db):
            raise HTTPException(
                status_code=451,
                detail="Debes aceptar el consentimiento informado de telemedicina antes de tu primera consulta.",
            )
        _verificar_pago_o_suscripcion(cita, db)

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


@router.get("/appointments/{appointment_id}/pago")
def estado_pago_cita(
    appointment_id: int,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """La app consulta esto antes de entrar: ¿requiere pago o ya está cubierta?"""
    cita = db.query(Appointment).filter(
        Appointment.id == appointment_id,
        Appointment.paciente_id == int(current["sub"]),
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")

    doctor = db.query(Doctor).filter(Doctor.id == cita.doctor_id).first()
    pago = db.query(Payment).filter(Payment.cita_id == cita.id).first()

    # Si el pago ONVO sigue pendiente, verificar en vivo contra su API
    if pago and pago.metodo == "onvo" and pago.estado != "exitoso" and pago.referencia_externa:
        try:
            from routers.payments import _onvo_get, ONVO_SECRET_KEY
            if ONVO_SECRET_KEY:
                session = _onvo_get(f"/checkout/sessions/{pago.referencia_externa}")
                if session.get("paymentStatus") == "paid" or session.get("status") == "complete":
                    pago.estado = "exitoso"
                    pago.verificado_en = datetime.utcnow()
                    db.commit()
        except Exception:
            pass  # si ONVO no responde, se mantiene el estado actual

    cubierta = bool(
        (pago and pago.estado == "exitoso")
        or (pago and pago.metodo == "urgente")
        or _suscripcion_activa_con_cupo(cita.paciente_id, db)
    )
    return {
        "requiere_pago": not cubierta,
        "estado_pago": pago.estado if pago else "sin_pago",
        "metodo": pago.metodo if pago else "",
        "monto": doctor.tarifa if doctor else 0.0,
        "doctor_nombre": doctor.nombre if doctor else "",
    }


@router.post("/appointments/{appointment_id}/ocultar")
def ocultar_cita(
    appointment_id: int,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """Oculta una cita finalizada o cancelada del historial del paciente.
    El registro médico se conserva (recetas, notas y pagos siguen existiendo)."""
    cita = db.query(Appointment).filter(
        Appointment.id == appointment_id,
        Appointment.paciente_id == int(current["sub"]),
    ).first()
    if not cita:
        raise HTTPException(status_code=404, detail="Cita no encontrada")
    if cita.estado == "programada":
        raise HTTPException(
            status_code=400,
            detail="No puedes ocultar una cita programada. Cancélala primero.",
        )
    cita.oculta_paciente = True
    db.commit()
    return {"message": "Cita ocultada de tu historial"}


# Documentos que el Reglamento de Telesalud del CMC prohíbe emitir por teleconsulta
_CERTIFICADOS_PROHIBIDOS = (
    "certificado de defunción", "certificado de defuncion",
    "dictamen de defunción", "dictamen de defuncion",
    "licencia de conducir", "dictamen para licencia",
    "portación de armas", "portacion de armas",
)


def _validar_certificados_prohibidos(*textos: str):
    for texto in textos:
        if not texto:
            continue
        bajo = texto.lower()
        for frase in _CERTIFICADOS_PROHIBIDOS:
            if frase in bajo:
                raise HTTPException(
                    status_code=400,
                    detail="Por teleconsulta no se pueden emitir certificados de defunción, "
                           "dictámenes para licencia de conducir ni certificados de portación "
                           "de armas (Reglamento de Telesalud, Colegio de Médicos CR).",
                )


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
    _validar_certificados_prohibidos(data.notas_texto or "", data.receta_texto or "")
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
    doctor = db.query(Doctor).filter(Doctor.id == cita.doctor_id).first()
    return {
        "appointment_id": appointment_id,
        "receta": cita.receta_texto,
        "notas": cita.notas_texto,
        "fecha": cita.fecha_hora,
        "doctor_nombre": doctor.nombre if doctor else "",
        "codigo_medico": (doctor.codigo_medico or "") if doctor else "",
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
