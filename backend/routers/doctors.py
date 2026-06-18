from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Doctor
from schemas import DoctorOut
from utils.auth import get_current_user

router = APIRouter(prefix="/api/doctors", tags=["doctors"])


@router.get("", response_model=List[DoctorOut])
def list_doctors(
    especialidad: Optional[str] = None,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(Doctor).filter(Doctor.activo == True)
    if especialidad:
        query = query.filter(Doctor.especialidad.ilike(f"%{especialidad}%"))
    return query.all()


@router.get("/{doctor_id}", response_model=DoctorOut)
def get_doctor(
    doctor_id: int,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id, Doctor.activo == True).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="Médico no encontrado")
    return doctor
