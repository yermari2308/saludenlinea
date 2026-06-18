from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Patient
from schemas import PatientOut
from utils.auth import require_patient

router = APIRouter(prefix="/api/patients", tags=["patients"])


@router.get("/me", response_model=PatientOut)
def get_my_profile(
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    patient = db.query(Patient).filter(Patient.id == int(current["sub"])).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")
    return patient


@router.put("/me/historial")
def update_historial(
    historial: str,
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    patient = db.query(Patient).filter(Patient.id == int(current["sub"])).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")
    patient.historial_texto = historial
    db.commit()
    return {"message": "Historial actualizado"}
