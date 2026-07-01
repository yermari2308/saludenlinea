from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text, Boolean
from sqlalchemy.orm import relationship
from database import Base




class Patient(Base):
    __tablename__ = "patients"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    email = Column(String(150), unique=True, nullable=False)
    telefono = Column(String(20))
    fecha_nacimiento = Column(String(20))
    historial_texto = Column(Text, default="")
    pass_hash = Column(String(255), nullable=False)
    activo = Column(Boolean, default=True)
    creado_en = Column(DateTime, default=datetime.utcnow)

    citas = relationship("Appointment", back_populates="paciente")



class Doctor(Base):
    __tablename__ = "doctors"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    especialidad = Column(String(100), nullable=False)
    foto_url = Column(String(255), default="")
    credenciales = Column(Text, default="")
    horario_json = Column(Text, default="{}")  # JSON string con disponibilidad
    tarifa = Column(Float, default=15.0)
    email = Column(String(150), unique=True, nullable=False)
    pass_hash = Column(String(255), nullable=False)
    activo = Column(Boolean, default=True)
    calificacion = Column(Float, default=5.0)
    disponible_urgente = Column(Boolean, default=False)
    creado_en = Column(DateTime, default=datetime.utcnow)

    citas = relationship("Appointment", back_populates="doctor")
    cola_items = relationship("ConsultQueue", back_populates="doctor", foreign_keys="ConsultQueue.doctor_id")


class Appointment(Base):
    __tablename__ = "appointments"

    id = Column(Integer, primary_key=True, index=True)
    paciente_id = Column(Integer, ForeignKey("patients.id"), nullable=False)
    doctor_id = Column(Integer, ForeignKey("doctors.id"), nullable=False)
    fecha_hora = Column(DateTime, nullable=False)
    estado = Column(String(30), default="programada")  # programada|completada|cancelada
    notas_texto = Column(Text, default="")
    receta_texto = Column(Text, default="")
    receta_archivo_nombre = Column(String(255), default="")
    receta_archivo_b64 = Column(Text, default="")
    creado_en = Column(DateTime, default=datetime.utcnow)

    paciente = relationship("Patient", back_populates="citas")
    doctor = relationship("Doctor", back_populates="citas")
    pago = relationship("Payment", back_populates="cita", uselist=False)
    sesion = relationship("ConsultSession", back_populates="cita", uselist=False)
    mensajes = relationship("ChatMessage", back_populates="cita")


class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    cita_id = Column(Integer, ForeignKey("appointments.id"), nullable=False)
    monto = Column(Float, nullable=False)
    metodo = Column(String(50), default="tarjeta")
    estado = Column(String(30), default="pendiente")  # pendiente|exitoso|fallido
    referencia_externa = Column(String(255), default="")
    fecha_pago = Column(DateTime, default=datetime.utcnow)

    cita = relationship("Appointment", back_populates="pago")


class DoctorLead(Base):
    """Solicitudes de médicos que quieren unirse a la plataforma."""
    __tablename__ = "doctor_leads"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    especialidad = Column(String(100), nullable=False)
    email = Column(String(150), nullable=False)
    telefono = Column(String(30), nullable=False)
    pais = Column(String(60), nullable=False)
    credenciales = Column(Text, default="")
    anos_experiencia = Column(Integer, default=0)
    mensaje = Column(Text, default="")
    estado = Column(String(20), default="pendiente")  # pendiente|contactado|activo|rechazado
    creado_en = Column(DateTime, default=datetime.utcnow)


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    cita_id = Column(Integer, ForeignKey("appointments.id"), nullable=False)
    remitente = Column(String(10), nullable=False)  # "paciente" | "doctor"
    remitente_id = Column(Integer, nullable=False)
    mensaje = Column(Text, nullable=False)
    enviado_en = Column(DateTime, default=datetime.utcnow)

    cita = relationship("Appointment", back_populates="mensajes")


class ConsultSession(Base):
    __tablename__ = "consult_sessions"

    id = Column(Integer, primary_key=True, index=True)
    cita_id = Column(Integer, ForeignKey("appointments.id"), nullable=False)
    token_sala = Column(String(255), unique=True, nullable=False)
    inicio = Column(DateTime)
    fin = Column(DateTime)
    detalle_calidad = Column(String(50), default="")

    cita = relationship("Appointment", back_populates="sesion")


class MedicalRecord(Base):
    """Expediente clínico completo del paciente — una fila por paciente."""
    __tablename__ = "medical_records"

    id = Column(Integer, primary_key=True, index=True)
    paciente_id = Column(Integer, ForeignKey("patients.id"), unique=True, nullable=False)
    # Secciones como JSON en Text (compatible con SQLite dev y PostgreSQL prod)
    datos_personales = Column(Text, default="{}")   # tipo_sangre, estado_civil, ocupacion, contacto_emergencia
    somatometria = Column(Text, default="{}")        # peso, altura, imc, presion_arterial, frecuencia_cardiaca
    patologicos = Column(Text, default="{}")         # enfermedades_cronicas[], cirugias[], alergias[], medicamentos_actuales[]
    no_patologicos = Column(Text, default="{}")      # tabaquismo, alcohol, ejercicio, alimentacion
    vacunacion = Column(Text, default="[]")          # [{nombre, fecha}]
    salud_femenina = Column(Text, nullable=True)     # fecha_ultima_menstruacion, embarazos, metodo_anticonceptivo
    completitud_pct = Column(Integer, default=0)
    actualizado_en = Column(DateTime, default=datetime.utcnow)

    paciente = relationship("Patient", foreign_keys=[paciente_id])


class ConsultQueue(Base):
    """Cola de consultas urgentes (Botón Rojo)."""
    __tablename__ = "consult_queue"

    id = Column(Integer, primary_key=True, index=True)
    paciente_id = Column(Integer, ForeignKey("patients.id"), nullable=False)
    especialidad = Column(String(100), default="medicina_general")
    estado = Column(String(20), default="esperando")  # esperando|asignada|en_curso|finalizada|cancelada
    doctor_id = Column(Integer, ForeignKey("doctors.id"), nullable=True)
    prioridad = Column(Integer, default=0)
    sala_token = Column(String(255), nullable=True)
    creado_en = Column(DateTime, default=datetime.utcnow)
    asignada_en = Column(DateTime, nullable=True)

    paciente = relationship("Patient", foreign_keys=[paciente_id])
    doctor = relationship("Doctor", back_populates="cola_items", foreign_keys=[doctor_id])


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id = Column(Integer, primary_key=True, index=True)
    token = Column(String(64), unique=True, nullable=False, index=True)
    email = Column(String(150), nullable=False)
    role = Column(String(20), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False)
    creado_en = Column(DateTime, default=datetime.utcnow)
