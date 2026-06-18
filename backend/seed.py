"""Poblar la base de datos con médicos de prueba."""
from database import engine, SessionLocal
from models import Base, Doctor, Patient
from utils.auth import hash_password

Base.metadata.create_all(bind=engine)

db = SessionLocal()

doctors = [
    {"nombre": "Dra. María López", "especialidad": "Medicina General", "email": "maria@demo.com", "tarifa": 15.0, "credenciales": "MÉDICO CIRUJANO – Universidad de Costa Rica"},
    {"nombre": "Dr. Carlos Ramírez", "especialidad": "Pediatría", "email": "carlos@demo.com", "tarifa": 20.0, "credenciales": "PEDIATRA – CCSS certificado"},
    {"nombre": "Dra. Ana Torres", "especialidad": "Cardiología", "email": "ana@demo.com", "tarifa": 30.0, "credenciales": "CARDIÓLOGA – Hospital Nacional"},
    {"nombre": "Dr. Juan Vega", "especialidad": "Dermatología", "email": "juan@demo.com", "tarifa": 25.0, "credenciales": "DERMATÓLOGO – certificado AMA"},
    {"nombre": "Dra. Laura Mora", "especialidad": "Psicología", "email": "laura@demo.com", "tarifa": 20.0, "credenciales": "PSICÓLOGA CLÍNICA – UNA"},
]

for d in doctors:
    if not db.query(Doctor).filter(Doctor.email == d["email"]).first():
        db.add(Doctor(pass_hash=hash_password("demo1234"), calificacion=4.8, **d))

# Paciente de prueba
if not db.query(Patient).filter(Patient.email == "paciente@demo.com").first():
    db.add(Patient(
        nombre="Yermari Flores",
        email="paciente@demo.com",
        telefono="+50688888888",
        pass_hash=hash_password("demo1234"),
    ))

db.commit()
db.close()
print("Base de datos poblada correctamente.")
