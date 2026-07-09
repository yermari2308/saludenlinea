"""
Fase 7 — Convenios con comercios aliados (laboratorios, ópticas, etc.).

GET /api/benefits → lista de convenios activos
Admin CRUD con X-Admin-Key.
"""
import os
import logging
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field, field_validator
from database import get_db
from models import PartnerBenefit

logger = logging.getLogger("saludenlinea")

router = APIRouter(prefix="/api/benefits", tags=["benefits"])

ADMIN_KEY = os.getenv("ADMIN_KEY", "saludenlinea-admin-2025")

TIPOS = ["laboratorio", "optica", "farmacia", "gimnasio", "otro"]


class BenefitRequest(BaseModel):
    nombre_convenio: str = Field(min_length=2, max_length=150)
    tipo: str = Field(default="otro")
    descripcion: str = Field(default="", max_length=1000)
    descuento: str = Field(default="", max_length=50)
    logo_url: str = Field(default="", max_length=500)

    @field_validator("tipo")
    @classmethod
    def tipo_valido(cls, v: str) -> str:
        if v not in TIPOS:
            raise ValueError(f"Tipo debe ser uno de: {', '.join(TIPOS)}")
        return v


def _serialize(b: PartnerBenefit) -> dict:
    return {
        "id": b.id,
        "nombre_convenio": b.nombre_convenio,
        "tipo": b.tipo,
        "descripcion": b.descripcion,
        "descuento": b.descuento,
        "logo_url": b.logo_url,
    }


@router.get("")
def listar_convenios(db: Session = Depends(get_db)):
    """Convenios activos — público (se muestra en el Home de la app)."""
    rows = db.query(PartnerBenefit).filter(
        PartnerBenefit.activo == True  # noqa: E712
    ).order_by(PartnerBenefit.nombre_convenio).all()
    return [_serialize(b) for b in rows]


@router.post("/admin")
def crear_convenio(
    data: BenefitRequest,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="No autorizado")
    b = PartnerBenefit(**data.model_dump())
    db.add(b)
    db.commit()
    db.refresh(b)
    return _serialize(b)


@router.put("/admin/{benefit_id}")
def editar_convenio(
    benefit_id: int,
    data: BenefitRequest,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="No autorizado")
    b = db.query(PartnerBenefit).filter(PartnerBenefit.id == benefit_id).first()
    if not b:
        raise HTTPException(status_code=404, detail="Convenio no encontrado")
    for k, v in data.model_dump().items():
        setattr(b, k, v)
    db.commit()
    return _serialize(b)


@router.delete("/admin/{benefit_id}")
def desactivar_convenio(
    benefit_id: int,
    x_admin_key: str = Header(default=""),
    db: Session = Depends(get_db),
):
    if x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="No autorizado")
    b = db.query(PartnerBenefit).filter(PartnerBenefit.id == benefit_id).first()
    if not b:
        raise HTTPException(status_code=404, detail="Convenio no encontrado")
    b.activo = False
    db.commit()
    return {"mensaje": "Convenio desactivado"}


def seed_benefits(db: Session):
    """Convenios de ejemplo si la tabla está vacía (editables desde admin)."""
    if db.query(PartnerBenefit).first():
        return
    ejemplos = [
        ("Laboratorios Echandi", "laboratorio", "Exámenes de sangre y pruebas clínicas con descuento para usuarios de SaludEnLínea.", "15%"),
        ("Ópticas Visión", "optica", "Examen visual gratis y descuento en aros y lentes de contacto.", "20%"),
        ("Farmacia Sucre", "farmacia", "Descuento en medicamentos de marca presentando tu receta digital.", "10%"),
        ("Smart Fit", "gimnasio", "Primer mes con descuento en tu membresía para pacientes con plan activo.", "50% 1er mes"),
    ]
    for nombre, tipo, desc, descuento in ejemplos:
        db.add(PartnerBenefit(
            nombre_convenio=nombre, tipo=tipo,
            descripcion=desc, descuento=descuento,
        ))
    db.commit()
    logger.info("Seed de convenios: %d creados", len(ejemplos))
