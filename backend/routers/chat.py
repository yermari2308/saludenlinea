from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Dict, List
import json
from datetime import datetime

from database import get_db
from models import ChatMessage, Appointment

router = APIRouter(prefix="/api/chat", tags=["chat"])

# Conexiones activas: {cita_id: [WebSocket, ...]}
_conexiones: Dict[int, List[WebSocket]] = {}


async def _broadcast(cita_id: int, data: dict):
    for ws in _conexiones.get(cita_id, []):
        try:
            await ws.send_text(json.dumps(data))
        except Exception:
            pass


@router.websocket("/ws/{cita_id}/{remitente}/{remitente_id}")
async def chat_ws(
    websocket: WebSocket,
    cita_id: int,
    remitente: str,
    remitente_id: int,
    db: Session = Depends(get_db),
):
    if remitente not in ("paciente", "doctor"):
        await websocket.close(code=1008)
        return

    await websocket.accept()

    if cita_id not in _conexiones:
        _conexiones[cita_id] = []
    _conexiones[cita_id].append(websocket)

    # Enviar historial al conectarse
    historial = (
        db.query(ChatMessage)
        .filter(ChatMessage.cita_id == cita_id)
        .order_by(ChatMessage.enviado_en)
        .all()
    )
    for msg in historial:
        await websocket.send_text(json.dumps({
            "id": msg.id,
            "remitente": msg.remitente,
            "remitente_id": msg.remitente_id,
            "mensaje": msg.mensaje,
            "enviado_en": msg.enviado_en.isoformat(),
        }))

    try:
        while True:
            texto = await websocket.receive_text()
            data = json.loads(texto)
            mensaje_texto = data.get("mensaje", "").strip()
            if not mensaje_texto:
                continue

            msg = ChatMessage(
                cita_id=cita_id,
                remitente=remitente,
                remitente_id=remitente_id,
                mensaje=mensaje_texto,
            )
            db.add(msg)
            db.commit()
            db.refresh(msg)

            await _broadcast(cita_id, {
                "id": msg.id,
                "remitente": msg.remitente,
                "remitente_id": msg.remitente_id,
                "mensaje": msg.mensaje,
                "enviado_en": msg.enviado_en.isoformat(),
            })
    except WebSocketDisconnect:
        _conexiones[cita_id].remove(websocket)
        if not _conexiones[cita_id]:
            del _conexiones[cita_id]


@router.get("/{cita_id}")
def get_historial(cita_id: int, db: Session = Depends(get_db)):
    mensajes = (
        db.query(ChatMessage)
        .filter(ChatMessage.cita_id == cita_id)
        .order_by(ChatMessage.enviado_en)
        .all()
    )
    return [
        {
            "id": m.id,
            "remitente": m.remitente,
            "remitente_id": m.remitente_id,
            "mensaje": m.mensaje,
            "enviado_en": m.enviado_en.isoformat(),
        }
        for m in mensajes
    ]
