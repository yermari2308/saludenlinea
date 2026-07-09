"""
Fase 6 — Métricas de salud desde wearables (Health Connect).

POST /api/health-metrics/sync  → la app envía un batch de días (upsert por fecha)
GET  /api/health-metrics       → últimos 30 días del paciente
"""
import logging
from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field, field_validator
from database import get_db
from models import HealthMetric
from utils.auth import require_patient

logger = logging.getLogger("saludenlinea")

router = APIRouter(prefix="/api/health-metrics", tags=["health-metrics"])


class MetricDay(BaseModel):
    fecha: str = Field(min_length=10, max_length=10)  # YYYY-MM-DD
    pasos: int = Field(default=0, ge=0, le=200000)
    calorias: float = Field(default=0, ge=0, le=20000)
    distancia: float = Field(default=0, ge=0, le=300000)  # metros
    fuente: str = Field(default="health_connect", max_length=50)

    @field_validator("fecha")
    @classmethod
    def fecha_valida(cls, v: str) -> str:
        datetime.strptime(v, "%Y-%m-%d")  # lanza ValueError si es inválida
        return v


class SyncRequest(BaseModel):
    dias: List[MetricDay] = Field(max_length=60)


@router.post("/sync")
def sync_metrics(
    data: SyncRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """Upsert por (paciente, fecha): actualiza si ya existe, crea si no."""
    if not data.dias:
        raise HTTPException(status_code=400, detail="Sin datos para sincronizar")

    paciente_id = int(current["sub"])
    actualizados = 0
    creados = 0
    for dia in data.dias:
        existente = db.query(HealthMetric).filter(
            HealthMetric.paciente_id == paciente_id,
            HealthMetric.fecha == dia.fecha,
        ).first()
        if existente:
            existente.pasos = dia.pasos
            existente.calorias = dia.calorias
            existente.distancia = dia.distancia
            existente.fuente = dia.fuente
            existente.actualizado_en = datetime.utcnow()
            actualizados += 1
        else:
            db.add(HealthMetric(
                paciente_id=paciente_id,
                fecha=dia.fecha,
                pasos=dia.pasos,
                calorias=dia.calorias,
                distancia=dia.distancia,
                fuente=dia.fuente,
            ))
            creados += 1
    db.commit()
    logger.info("Health sync paciente=%s creados=%d actualizados=%d",
                paciente_id, creados, actualizados)
    return {"creados": creados, "actualizados": actualizados}


@router.get("")
def listar_metrics(
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """Últimos 30 días de métricas del paciente, más recientes primero."""
    rows = db.query(HealthMetric).filter(
        HealthMetric.paciente_id == int(current["sub"])
    ).order_by(HealthMetric.fecha.desc()).limit(30).all()
    return [
        {
            "fecha": r.fecha,
            "pasos": r.pasos,
            "calorias": r.calorias,
            "distancia": r.distancia,
            "fuente": r.fuente,
        }
        for r in rows
    ]
