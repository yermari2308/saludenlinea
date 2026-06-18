from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from database import get_db
from models import DoctorLead
from utils.auth import get_current_user

router = APIRouter(prefix="/api/leads", tags=["leads"])


class DoctorLeadCreate(BaseModel):
    nombre: str
    especialidad: str
    email: EmailStr
    telefono: str
    pais: str
    credenciales: str = ""
    anos_experiencia: int = 0
    mensaje: str = ""


class DoctorLeadOut(BaseModel):
    id: int
    nombre: str
    especialidad: str
    email: str
    telefono: str
    pais: str
    credenciales: str
    anos_experiencia: int
    mensaje: str
    estado: str

    model_config = {"from_attributes": True}


@router.post("", status_code=201)
def submit_lead(data: DoctorLeadCreate, db: Session = Depends(get_db)):
    """Cualquiera puede enviar su solicitud (sin login)."""
    lead = DoctorLead(**data.model_dump())
    db.add(lead)
    db.commit()
    return {"mensaje": "¡Gracias! Nos pondremos en contacto contigo pronto."}


@router.get("", response_model=List[DoctorLeadOut])
def list_leads(
    estado: str = None,
    db: Session = Depends(get_db),
    current=Depends(get_current_user),
):
    """Lista de solicitudes de médicos — accesible con cualquier token válido."""
    q = db.query(DoctorLead).order_by(DoctorLead.creado_en.desc())
    if estado:
        q = q.filter(DoctorLead.estado == estado)
    return q.all()


@router.get("/resumen")
def resumen_leads(db: Session = Depends(get_db), current=Depends(get_current_user)):
    """Resumen rápido de solicitudes por estado."""
    from sqlalchemy import func
    rows = db.query(DoctorLead.estado, func.count(DoctorLead.id)).group_by(DoctorLead.estado).all()
    return {estado: total for estado, total in rows}


@router.put("/{lead_id}/estado")
def update_lead_estado(
    lead_id: int,
    estado: str,
    db: Session = Depends(get_db),
    current=Depends(get_current_user),
):
    lead = db.query(DoctorLead).filter(DoctorLead.id == lead_id).first()
    if not lead:
        raise HTTPException(status_code=404, detail="Lead no encontrado")
    if estado not in ("pendiente", "contactado", "activo", "rechazado"):
        raise HTTPException(status_code=400, detail="Estado inválido")
    lead.estado = estado
    db.commit()
    return {"mensaje": f"Estado actualizado a {estado}"}
