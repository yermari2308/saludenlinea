"""
Router: HRA — Evaluación General de Salud (Fase 3).
Recibe respuestas del cuestionario, calcula puntajes semáforo y
genera recomendaciones personalizadas.
"""
import json
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database import get_db
from models import HealthAssessment
from utils.auth import require_patient

router = APIRouter(prefix="/api/hra", tags=["hra"])

# ── Constantes de semáforo ────────────────────────────────────────────────────
VERDE = 2
AMARILLO = 1
ROJO = 0


# ── Lógica de scoring ─────────────────────────────────────────────────────────

def _score_imc(peso_kg: Optional[float], altura_m: Optional[float]) -> tuple[int, float | None]:
    """Devuelve (score, imc_calculado)."""
    if not peso_kg or not altura_m or altura_m <= 0:
        return AMARILLO, None
    imc = round(peso_kg / (altura_m ** 2), 1)
    if 18.5 <= imc < 25:
        return VERDE, imc
    elif 17.0 <= imc < 30:
        return AMARILLO, imc
    else:
        return ROJO, imc


def _score_sueno(horas: Optional[float]) -> int:
    if horas is None:
        return AMARILLO
    if 7 <= horas <= 9:
        return VERDE
    elif 6 <= horas <= 10:
        return AMARILLO
    return ROJO


def _score_tabaco(valor: Optional[str]) -> int:
    mapping = {
        "no_fuma": VERDE,
        "ex_fumador": AMARILLO,
        "fumador_ocasional": ROJO,
        "fumador_frecuente": ROJO,
    }
    return mapping.get(valor or "", AMARILLO)


def _score_alcohol(valor: Optional[str]) -> int:
    mapping = {
        "no_consume": VERDE,
        "ocasional": VERDE,
        "moderado": AMARILLO,
        "frecuente": ROJO,
    }
    return mapping.get(valor or "", AMARILLO)


def _score_ejercicio(valor: Optional[str]) -> int:
    mapping = {
        "diario": VERDE,
        "3_4_dias": VERDE,
        "1_2_dias": AMARILLO,
        "sedentario": ROJO,
    }
    return mapping.get(valor or "", AMARILLO)


def _score_saturacion(pct: Optional[float]) -> int:
    if pct is None:
        return AMARILLO
    if pct >= 95:
        return VERDE
    elif pct >= 93:
        return AMARILLO
    return ROJO


def _color(score: int) -> str:
    return {VERDE: "verde", AMARILLO: "amarillo", ROJO: "rojo"}[score]


def _build_recomendaciones(
    peso_score, imc,
    sueno_score, sueno_h,
    tabaco_score, tabaco_val,
    alcohol_score, alcohol_val,
    ejercicio_score, ejercicio_val,
    saturacion_score, sat_pct,
) -> list:
    items = []

    # Peso / IMC
    if imc:
        if peso_score == VERDE:
            texto = f"Tu IMC es {imc} — peso saludable. ¡Sigue así!"
        elif peso_score == AMARILLO:
            texto = f"Tu IMC es {imc}. Considera ajustar tu alimentación o ejercicio."
        else:
            texto = f"Tu IMC es {imc}. Te recomendamos consultar con un médico o nutricionista."
    else:
        texto = "Ingresa tu peso y altura para calcular tu IMC."
    items.append({
        "parametro": "Peso / IMC",
        "color": _color(peso_score),
        "icono": "monitor_weight",
        "texto": texto,
        "requiere_cita": peso_score == ROJO,
    })

    # Sueño
    if sueno_score == VERDE:
        texto = f"Duermes {sueno_h}h — dentro del rango saludable (7-9h)."
    elif sueno_score == AMARILLO:
        texto = f"Duermes {sueno_h}h. Lo ideal son entre 7 y 9 horas por noche."
    else:
        texto = f"Solo duermes {sueno_h}h. La falta de sueño afecta tu salud. Consulta a un médico."
    items.append({
        "parametro": "Sueño",
        "color": _color(sueno_score),
        "icono": "bedtime",
        "texto": texto,
        "requiere_cita": sueno_score == ROJO,
    })

    # Tabaco
    labels = {
        "no_fuma": "No fumas",
        "ex_fumador": "Eres ex-fumador",
        "fumador_ocasional": "Fumas ocasionalmente",
        "fumador_frecuente": "Fumas frecuentemente",
    }
    lab = labels.get(tabaco_val or "", "")
    if tabaco_score == VERDE:
        texto = f"{lab} — excelente decisión para tu salud."
    elif tabaco_score == AMARILLO:
        texto = f"{lab} — evitar el tabaco reduce significativamente riesgos cardíacos."
    else:
        texto = f"{lab}. El tabaquismo es la principal causa evitable de enfermedad. Pide ayuda médica."
    items.append({
        "parametro": "Tabaquismo",
        "color": _color(tabaco_score),
        "icono": "smoke_free",
        "texto": texto,
        "requiere_cita": tabaco_score == ROJO,
    })

    # Alcohol
    labels_alc = {
        "no_consume": "No consumes alcohol",
        "ocasional": "Consumo ocasional",
        "moderado": "Consumo moderado",
        "frecuente": "Consumo frecuente",
    }
    lab_alc = labels_alc.get(alcohol_val or "", "")
    if alcohol_score == VERDE:
        texto = f"{lab_alc} — dentro de los rangos saludables."
    elif alcohol_score == AMARILLO:
        texto = f"{lab_alc}. El consumo moderado puede afectar hígado y presión arterial."
    else:
        texto = f"{lab_alc}. El alcohol en exceso daña múltiples órganos. Consulta con un médico."
    items.append({
        "parametro": "Alcohol",
        "color": _color(alcohol_score),
        "icono": "no_drinks",
        "texto": texto,
        "requiere_cita": alcohol_score == ROJO,
    })

    # Ejercicio
    labels_ej = {
        "diario": "Haces ejercicio diario",
        "3_4_dias": "Ejercicio 3-4 días/semana",
        "1_2_dias": "Ejercicio 1-2 días/semana",
        "sedentario": "Eres sedentario",
    }
    lab_ej = labels_ej.get(ejercicio_val or "", "")
    if ejercicio_score == VERDE:
        texto = f"{lab_ej} — nivel óptimo de actividad física."
    elif ejercicio_score == AMARILLO:
        texto = f"{lab_ej}. Lo recomendado son al menos 150 min/semana de actividad moderada."
    else:
        texto = f"{lab_ej}. El sedentarismo aumenta el riesgo de enfermedades crónicas. Empieza hoy."
    items.append({
        "parametro": "Actividad física",
        "color": _color(ejercicio_score),
        "icono": "directions_run",
        "texto": texto,
        "requiere_cita": ejercicio_score == ROJO,
    })

    # Saturación
    if sat_pct:
        if saturacion_score == VERDE:
            texto = f"Saturación de oxígeno {sat_pct}% — normal."
        elif saturacion_score == AMARILLO:
            texto = f"Saturación {sat_pct}% — levemente baja. Monitorea y evita esfuerzo intenso."
        else:
            texto = f"Saturación {sat_pct}% — por debajo del límite seguro. Consulta un médico HOY."
        items.append({
            "parametro": "Saturación O₂",
            "color": _color(saturacion_score),
            "icono": "air",
            "texto": texto,
            "requiere_cita": saturacion_score == ROJO,
        })

    return items


# ── Schemas ───────────────────────────────────────────────────────────────────

class HraRequest(BaseModel):
    peso_kg: Optional[float] = Field(None, gt=0, lt=500)
    altura_m: Optional[float] = Field(None, gt=0, lt=3)
    sueno_horas: Optional[float] = Field(None, ge=0, le=24)
    tabaco: Optional[str] = Field(None, max_length=30)
    alcohol: Optional[str] = Field(None, max_length=30)
    ejercicio: Optional[str] = Field(None, max_length=30)
    saturacion_pct: Optional[float] = Field(None, ge=0, le=100)


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("", status_code=201)
def crear_evaluacion(
    req: HraRequest,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])

    peso_score, imc = _score_imc(req.peso_kg, req.altura_m)
    sueno_score = _score_sueno(req.sueno_horas)
    tabaco_score = _score_tabaco(req.tabaco)
    alcohol_score = _score_alcohol(req.alcohol)
    ejercicio_score = _score_ejercicio(req.ejercicio)
    saturacion_score = _score_saturacion(req.saturacion_pct)

    puntaje_total = (
        peso_score + sueno_score + tabaco_score +
        alcohol_score + ejercicio_score + saturacion_score
    )

    recomendaciones = _build_recomendaciones(
        peso_score, imc,
        sueno_score, req.sueno_horas,
        tabaco_score, req.tabaco,
        alcohol_score, req.alcohol,
        ejercicio_score, req.ejercicio,
        saturacion_score, req.saturacion_pct,
    )

    evaluacion = HealthAssessment(
        paciente_id=paciente_id,
        peso_score=peso_score,
        sueno_score=sueno_score,
        tabaco_score=tabaco_score,
        alcohol_score=alcohol_score,
        ejercicio_score=ejercicio_score,
        saturacion_score=saturacion_score,
        puntaje_total=puntaje_total,
        recomendaciones=json.dumps(recomendaciones, ensure_ascii=False),
    )
    db.add(evaluacion)
    db.commit()
    db.refresh(evaluacion)

    max_posible = 12  # 6 parámetros × 2 puntos
    pct_salud = round((puntaje_total / max_posible) * 100)

    return {
        "id": evaluacion.id,
        "puntaje_total": puntaje_total,
        "puntaje_maximo": max_posible,
        "pct_salud": pct_salud,
        "nivel": "bueno" if pct_salud >= 75 else ("regular" if pct_salud >= 50 else "crítico"),
        "imc": imc,
        "recomendaciones": recomendaciones,
        "requiere_cita": any(r["requiere_cita"] for r in recomendaciones),
        "creado_en": evaluacion.creado_en.isoformat(),
    }


@router.get("/history")
def get_history(
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])
    items = (
        db.query(HealthAssessment)
        .filter(HealthAssessment.paciente_id == paciente_id)
        .order_by(HealthAssessment.creado_en.desc())
        .limit(10)
        .all()
    )
    result = []
    for e in items:
        max_posible = 12
        pct = round((e.puntaje_total / max_posible) * 100)
        try:
            recs = json.loads(e.recomendaciones)
        except Exception:
            recs = []
        result.append({
            "id": e.id,
            "puntaje_total": e.puntaje_total,
            "pct_salud": pct,
            "nivel": "bueno" if pct >= 75 else ("regular" if pct >= 50 else "crítico"),
            "recomendaciones": recs,
            "requiere_cita": any(r.get("requiere_cita") for r in recs),
            "creado_en": e.creado_en.isoformat(),
        })
    return result
