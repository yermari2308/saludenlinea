"""
Documentos legales + consentimientos informados.

GET  /api/legal/{doc}            → texto legal (terminos|privacidad|consentimiento)
GET  /api/consents/status        → consentimientos que el paciente ya aceptó
POST /api/consents/accept        → registra aceptación con versión, fecha e IP
"""
import logging
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel, field_validator
from database import get_db
from models import InformedConsent
from utils.auth import require_patient
import legal_texts

logger = logging.getLogger("saludenlinea")

router = APIRouter(prefix="/api", tags=["legal"])

_DOCS = {
    "terminos": ("Términos y Condiciones", legal_texts.TERMINOS_CONDICIONES, legal_texts.VERSION_TERMINOS),
    "privacidad": ("Política de Privacidad", legal_texts.POLITICA_PRIVACIDAD, legal_texts.VERSION_TERMINOS),
    "consentimiento": ("Consentimiento Informado", legal_texts.CONSENTIMIENTO_TELEMEDICINA, legal_texts.VERSION_CONSENTIMIENTO),
}

TIPOS_CONSENT = ("telemedicina", "terminos")


class AcceptRequest(BaseModel):
    tipo: str

    @field_validator("tipo")
    @classmethod
    def tipo_valido(cls, v: str) -> str:
        if v not in TIPOS_CONSENT:
            raise ValueError(f"Tipo debe ser uno de: {', '.join(TIPOS_CONSENT)}")
        return v


def paciente_acepto_telemedicina(paciente_id: int, db: Session) -> bool:
    return db.query(InformedConsent).filter(
        InformedConsent.paciente_id == paciente_id,
        InformedConsent.tipo == "telemedicina",
        InformedConsent.version_texto == legal_texts.VERSION_CONSENTIMIENTO,
    ).first() is not None


@router.get("/legal/{doc}")
def get_legal(doc: str):
    if doc not in _DOCS:
        raise HTTPException(status_code=404, detail="Documento no encontrado")
    titulo, texto, version = _DOCS[doc]
    return {"titulo": titulo, "texto": texto, "version": version}


@router.get("/consents/status")
def consent_status(
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])
    filas = db.query(InformedConsent).filter(
        InformedConsent.paciente_id == paciente_id
    ).all()
    aceptados = {f.tipo: f.version_texto for f in filas}
    return {
        "telemedicina_aceptado": aceptados.get("telemedicina") == legal_texts.VERSION_CONSENTIMIENTO,
        "version_actual": legal_texts.VERSION_CONSENTIMIENTO,
        "aceptados": aceptados,
    }


@router.post("/consents/accept")
def accept_consent(
    data: AcceptRequest,
    request: Request,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    paciente_id = int(current["sub"])
    version = (legal_texts.VERSION_CONSENTIMIENTO
               if data.tipo == "telemedicina" else legal_texts.VERSION_TERMINOS)

    ya = db.query(InformedConsent).filter(
        InformedConsent.paciente_id == paciente_id,
        InformedConsent.tipo == data.tipo,
        InformedConsent.version_texto == version,
    ).first()
    if ya:
        return {"mensaje": "Ya estaba aceptado", "version": version}

    ip = request.client.host if request.client else ""
    db.add(InformedConsent(
        paciente_id=paciente_id,
        tipo=data.tipo,
        version_texto=version,
        ip=ip,
    ))
    db.commit()
    logger.info("Consentimiento %s v%s aceptado paciente=%s ip=%s",
                data.tipo, version, paciente_id, ip)
    return {"mensaje": "Consentimiento registrado", "version": version}
