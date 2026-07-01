"""
Router: Expediente Clínico Completo (Fase 2).
- Paciente: lee y actualiza su propio expediente.
- Médico: solo lectura, SOLO si tiene cita con ese paciente.
- Completitud calculada en cada PUT.
"""
import json
import math
from datetime import datetime
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database import get_db
from models import MedicalRecord, Appointment
from utils.auth import require_patient, require_doctor

router = APIRouter(prefix="/api/medical-record", tags=["medical-record"])

# ── Secciones y sus campos para calcular completitud ─────────────────────────

_SECTION_FIELDS: Dict[str, list] = {
    "datos_personales": ["tipo_sangre", "estado_civil", "ocupacion", "contacto_emergencia"],
    "somatometria":     ["peso", "altura", "presion_arterial", "frecuencia_cardiaca"],
    "patologicos":      ["enfermedades_cronicas", "cirugias", "alergias", "medicamentos_actuales"],
    "no_patologicos":   ["tabaquismo", "alcohol", "ejercicio", "alimentacion"],
    "vacunacion":       ["_lista"],   # lista no vacía = completo
}

SECCIONES_VALIDAS = set(_SECTION_FIELDS.keys()) | {"salud_femenina"}


def _calc_completitud(record: MedicalRecord) -> int:
    """Calcula % de campos llenos sobre el total de campos definidos."""
    total = 0
    llenos = 0

    for seccion, campos in _SECTION_FIELDS.items():
        raw = getattr(record, seccion, None) or "{}"
        try:
            data = json.loads(raw)
        except Exception:
            data = {}

        for campo in campos:
            total += 1
            if campo == "_lista":
                # Vacunación: lista no vacía
                if isinstance(data, list) and len(data) > 0:
                    llenos += 1
                elif isinstance(data, dict) and data.get("vacunas"):
                    llenos += 1
            else:
                val = data.get(campo)
                if val is not None and val != "" and val != [] and val != {}:
                    llenos += 1

    # salud_femenina (opcional, cuenta si tiene datos)
    if record.salud_femenina:
        try:
            sf = json.loads(record.salud_femenina)
            if sf:
                total += 1
                llenos += 1
        except Exception:
            pass

    if total == 0:
        return 0
    return math.floor((llenos / total) * 100)


def _section_completitud(raw: Optional[str], campos: list) -> int:
    """Completitud de una sola sección (0-100)."""
    if not raw:
        return 0
    try:
        data = json.loads(raw)
    except Exception:
        return 0
    if not campos:
        return 0
    llenos = 0
    for campo in campos:
        if campo == "_lista":
            if isinstance(data, list) and len(data) > 0:
                llenos += 1
        else:
            val = data.get(campo)
            if val is not None and val != "" and val != [] and val != {}:
                llenos += 1
    return math.floor((llenos / len(campos)) * 100)


def _get_or_create(paciente_id: int, db: Session) -> MedicalRecord:
    record = db.query(MedicalRecord).filter(
        MedicalRecord.paciente_id == paciente_id
    ).first()
    if not record:
        record = MedicalRecord(paciente_id=paciente_id)
        db.add(record)
        db.commit()
        db.refresh(record)
    return record


def _serialize(record: MedicalRecord) -> dict:
    """Serializa el expediente incluyendo % por sección."""
    secciones_out = {}
    for sec, campos in _SECTION_FIELDS.items():
        raw = getattr(record, sec, None) or ("{}" if sec != "vacunacion" else "[]")
        try:
            datos = json.loads(raw)
        except Exception:
            datos = {} if sec != "vacunacion" else []
        secciones_out[sec] = {
            "datos": datos,
            "completitud_pct": _section_completitud(raw, campos),
        }

    # salud_femenina
    sf_raw = record.salud_femenina
    try:
        sf_datos = json.loads(sf_raw) if sf_raw else {}
    except Exception:
        sf_datos = {}
    secciones_out["salud_femenina"] = {
        "datos": sf_datos,
        "completitud_pct": 100 if sf_datos else 0,
    }

    return {
        "id": record.id,
        "paciente_id": record.paciente_id,
        "completitud_pct": record.completitud_pct,
        "actualizado_en": record.actualizado_en.isoformat() if record.actualizado_en else None,
        "secciones": secciones_out,
    }


# ── Schemas ───────────────────────────────────────────────────────────────────

class UpdateSectionRequest(BaseModel):
    seccion: str = Field(..., max_length=50)
    datos: Any  # JSON libre validado por sección


# ── Endpoints paciente ────────────────────────────────────────────────────────

@router.get("/me")
def get_my_record(
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])
    record = _get_or_create(paciente_id, db)
    return _serialize(record)


@router.put("/me")
def update_my_record(
    req: UpdateSectionRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])

    if req.seccion not in SECCIONES_VALIDAS:
        raise HTTPException(
            status_code=400,
            detail=f"Sección inválida. Válidas: {sorted(SECCIONES_VALIDAS)}",
        )

    record = _get_or_create(paciente_id, db)

    # Guardar datos de la sección
    setattr(record, req.seccion, json.dumps(req.datos, ensure_ascii=False))

    # Recalcular IMC si hay peso y altura en somatometría
    if req.seccion == "somatometria":
        try:
            soma = req.datos if isinstance(req.datos, dict) else json.loads(req.datos)
            peso = float(soma.get("peso", 0))
            altura = float(soma.get("altura", 0))
            if peso > 0 and altura > 0:
                imc = round(peso / (altura ** 2), 1)
                soma["imc"] = imc
                record.somatometria = json.dumps(soma, ensure_ascii=False)
        except Exception:
            pass

    record.completitud_pct = _calc_completitud(record)
    record.actualizado_en = datetime.utcnow()
    db.commit()
    db.refresh(record)

    return {
        "message": "Sección actualizada",
        "completitud_pct": record.completitud_pct,
        "seccion": req.seccion,
    }


# ── Endpoint médico (solo lectura, con cita) ──────────────────────────────────

@router.get("/patient/{paciente_id}")
def get_patient_record(
    paciente_id: int,
    db: Session = Depends(get_db),
    current=Depends(require_doctor),
):
    doctor_id = int(current["sub"])

    # Verificar que el médico tiene al menos una cita con este paciente
    cita = db.query(Appointment).filter(
        Appointment.doctor_id == doctor_id,
        Appointment.paciente_id == paciente_id,
    ).first()
    if not cita:
        raise HTTPException(
            status_code=403,
            detail="Solo puedes ver el expediente de pacientes con quienes tienes cita",
        )

    record = _get_or_create(paciente_id, db)
    return _serialize(record)
