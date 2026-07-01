"""
Router: Botón Rojo — consultas urgentes sin agendar.
Cola: paciente entra → médico disponible toma → Jitsi automático.
"""
import os
import re
import secrets
import json
from datetime import datetime
from typing import Dict, List

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database import get_db
from models import ConsultQueue, Doctor, Appointment, ConsultSession, Payment
from utils.auth import require_patient, require_doctor, get_current_user

router = APIRouter(prefix="/api/urgent", tags=["urgent"])

JITSI_HOST = os.getenv("JITSI_HOST", "meet.jit.si")

# WebSocket: paciente_id → lista de conexiones esperando notificación
_ws_pacientes: Dict[int, List[WebSocket]] = {}


def _jitsi_url(token: str, display_name: str = "") -> str:
    room = re.sub(r"[^a-zA-Z0-9]", "", token)[:32]
    room = f"SaludEnLineaUrgente{room}"
    base = f"https://{JITSI_HOST}/{room}"
    if display_name:
        safe = display_name.replace(" ", "%20")
        return f"{base}#userInfo.displayName=\"{safe}\""
    return base


async def _notify_patient(paciente_id: int, payload: dict):
    """Envía notificación WebSocket al paciente cuando su cola cambia de estado."""
    for ws in _ws_pacientes.get(paciente_id, []):
        try:
            await ws.send_text(json.dumps(payload))
        except Exception:
            pass


# ── Schemas ───────────────────────────────────────────────────────────────────

class JoinQueueRequest(BaseModel):
    especialidad: str = Field("medicina_general", max_length=100)


class ToggleDisponibleRequest(BaseModel):
    disponible: bool


# ── Endpoints paciente ────────────────────────────────────────────────────────

@router.post("/join", status_code=201)
def join_queue(
    data: JoinQueueRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])

    # No permitir duplicados activos
    existing = db.query(ConsultQueue).filter(
        ConsultQueue.paciente_id == paciente_id,
        ConsultQueue.estado.in_(["esperando", "asignada", "en_curso"]),
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Ya estás en la cola de espera")

    entrada = ConsultQueue(
        paciente_id=paciente_id,
        especialidad=data.especialidad,
        estado="esperando",
        prioridad=0,
    )
    db.add(entrada)
    db.commit()
    db.refresh(entrada)

    # Posición en cola
    posicion = db.query(ConsultQueue).filter(
        ConsultQueue.estado == "esperando",
        ConsultQueue.id <= entrada.id,
    ).count()

    # Tiempo estimado: 8 min por persona adelante
    tiempo_estimado = (posicion - 1) * 8

    return {
        "queue_id": entrada.id,
        "posicion": posicion,
        "tiempo_estimado_min": tiempo_estimado,
        "estado": "esperando",
    }


@router.get("/status")
def get_queue_status(
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])

    entrada = db.query(ConsultQueue).filter(
        ConsultQueue.paciente_id == paciente_id,
        ConsultQueue.estado.in_(["esperando", "asignada", "en_curso"]),
    ).order_by(ConsultQueue.id.desc()).first()

    if not entrada:
        raise HTTPException(status_code=404, detail="No estás en ninguna cola activa")

    posicion = 0
    jitsi_url = None
    appointment_id = None

    if entrada.estado == "esperando":
        posicion = db.query(ConsultQueue).filter(
            ConsultQueue.estado == "esperando",
            ConsultQueue.id <= entrada.id,
        ).count()
    elif entrada.estado in ("asignada", "en_curso"):
        # Buscar la cita creada para esta entrada de cola
        cita = db.query(Appointment).filter(
            Appointment.paciente_id == paciente_id,
            Appointment.doctor_id == entrada.doctor_id,
            Appointment.estado == "programada",
        ).order_by(Appointment.id.desc()).first()
        if cita and entrada.sala_token:
            appointment_id = cita.id
            jitsi_url = _jitsi_url(entrada.sala_token, entrada.paciente.nombre)

    return {
        "queue_id": entrada.id,
        "estado": entrada.estado,
        "posicion": posicion,
        "tiempo_estimado_min": max(0, (posicion - 1) * 8),
        "doctor_nombre": entrada.doctor.nombre if entrada.doctor else None,
        "jitsi_url": jitsi_url,
        "appointment_id": appointment_id,
    }


@router.post("/cancel")
def cancel_queue(
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])

    entrada = db.query(ConsultQueue).filter(
        ConsultQueue.paciente_id == paciente_id,
        ConsultQueue.estado.in_(["esperando"]),
    ).first()

    if not entrada:
        raise HTTPException(status_code=404, detail="No hay cola activa que cancelar")

    entrada.estado = "cancelada"
    db.commit()
    return {"message": "Saliste de la cola"}


# ── Endpoints médico ──────────────────────────────────────────────────────────

@router.get("/queue")
def get_queue(
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    """Ver la cola de espera ordenada por prioridad DESC, luego antigüedad ASC."""
    items = (
        db.query(ConsultQueue)
        .filter(ConsultQueue.estado == "esperando")
        .order_by(ConsultQueue.prioridad.desc(), ConsultQueue.creado_en.asc())
        .all()
    )
    return [
        {
            "queue_id": e.id,
            "paciente_nombre": e.paciente.nombre,
            "especialidad": e.especialidad,
            "prioridad": e.prioridad,
            "espera_min": int((datetime.utcnow() - e.creado_en).total_seconds() / 60),
        }
        for e in items
    ]


@router.post("/take/{queue_id}")
async def take_patient(
    queue_id: int,
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    """Médico toma el siguiente paciente de la cola."""
    doctor_id = int(current["sub"])
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Médico no encontrado")
    if not doctor.disponible_urgente:
        raise HTTPException(status_code=403, detail="Debes estar disponible para urgencias")

    entrada = db.query(ConsultQueue).filter(
        ConsultQueue.id == queue_id,
        ConsultQueue.estado == "esperando",
    ).first()
    if not entrada:
        raise HTTPException(status_code=404, detail="Entrada no encontrada o ya tomada")

    # Crear appointment automático
    cita = Appointment(
        paciente_id=entrada.paciente_id,
        doctor_id=doctor_id,
        fecha_hora=datetime.utcnow(),
        estado="programada",
    )
    db.add(cita)
    db.flush()

    # Pago pendiente (tarifa del médico)
    pago = Payment(
        cita_id=cita.id,
        monto=doctor.tarifa,
        metodo="urgente",
        estado="pendiente",
    )
    db.add(pago)

    # Crear ConsultSession con token Jitsi
    sala_token = secrets.token_urlsafe(32)
    sesion = ConsultSession(
        cita_id=cita.id,
        token_sala=sala_token,
        inicio=datetime.utcnow(),
    )
    db.add(sesion)

    # Actualizar cola
    entrada.estado = "asignada"
    entrada.doctor_id = doctor_id
    entrada.asignada_en = datetime.utcnow()
    entrada.sala_token = sala_token

    db.commit()
    db.refresh(cita)

    jitsi_url = _jitsi_url(sala_token, doctor.nombre)

    # Notificar al paciente por WebSocket
    await _notify_patient(entrada.paciente_id, {
        "event": "asignada",
        "doctor_nombre": doctor.nombre,
        "appointment_id": cita.id,
        "jitsi_url": _jitsi_url(sala_token, entrada.paciente.nombre),
    })

    return {
        "appointment_id": cita.id,
        "paciente_nombre": entrada.paciente.nombre,
        "jitsi_url": jitsi_url,
        "sala_token": sala_token,
    }


@router.post("/toggle-disponible")
def toggle_disponible(
    data: ToggleDisponibleRequest,
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    """Toggle disponibilidad del médico para urgencias."""
    doctor_id = int(current["sub"])
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Médico no encontrado")
    doctor.disponible_urgente = data.disponible
    db.commit()
    return {"disponible_urgente": doctor.disponible_urgente}


@router.get("/my-status")
def get_my_doctor_status(
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    """Estado de disponibilidad del médico autenticado."""
    doctor_id = int(current["sub"])
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Médico no encontrado")
    return {"disponible_urgente": doctor.disponible_urgente}


# ── WebSocket de notificación (paciente espera asignación) ────────────────────

@router.websocket("/ws/{paciente_id}")
async def urgent_ws(
    websocket: WebSocket,
    paciente_id: int,
):
    """WebSocket para que el paciente reciba notificación al ser asignado."""
    await websocket.accept()
    if paciente_id not in _ws_pacientes:
        _ws_pacientes[paciente_id] = []
    _ws_pacientes[paciente_id].append(websocket)
    try:
        while True:
            # Mantener conexión viva — cliente puede enviar pings
            await websocket.receive_text()
    except WebSocketDisconnect:
        _ws_pacientes[paciente_id].remove(websocket)
        if not _ws_pacientes[paciente_id]:
            del _ws_pacientes[paciente_id]
