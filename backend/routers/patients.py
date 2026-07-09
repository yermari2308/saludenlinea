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


@router.delete("/me")
def delete_my_account(
    db: Session = Depends(get_db),
    current=Depends(require_patient),
):
    """
    Derecho de supresión (Ley 8968): anonimiza los datos identificativos y
    desactiva la cuenta. Los registros clínicos y de pago se conservan
    (anonimizados) por el plazo que exige la normativa sanitaria.
    """
    patient = db.query(Patient).filter(Patient.id == int(current["sub"])).first()
    if not patient:
        raise HTTPException(status_code=404, detail="Paciente no encontrado")

    patient.nombre = "Usuario eliminado"
    patient.email = f"eliminado_{patient.id}@saludenlinea.invalid"
    patient.telefono = ""
    patient.fecha_nacimiento = ""
    patient.pass_hash = "!"  # imposible de igualar por bcrypt → bloquea el login
    patient.activo = False
    db.commit()
    return {"mensaje": "Cuenta eliminada. Tus datos personales fueron anonimizados."}


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
