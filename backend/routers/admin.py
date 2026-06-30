"""
Panel admin — protegido con HTTP Basic Auth (usuario: admin, contraseña: ADMIN_KEY).
Accesible en /admin/leads y /admin/doctors via navegador.
"""
import os
import secrets as secrets_lib
import bcrypt
from fastapi import APIRouter, Depends, HTTPException, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from sqlalchemy.orm import Session
from database import get_db
from models import DoctorLead, Doctor

router = APIRouter(prefix="/admin", tags=["admin"])
security = HTTPBasic()

ADMIN_KEY = os.getenv("ADMIN_KEY", "saludenlinea-admin-2025")


def check_key(credentials: HTTPBasicCredentials = Depends(security)):
    correct_user = secrets_lib.compare_digest(credentials.username.encode(), b"admin")
    correct_pass = secrets_lib.compare_digest(credentials.password.encode(), ADMIN_KEY.encode())
    if not (correct_user and correct_pass):
        raise HTTPException(
            status_code=401,
            detail="Clave inválida",
            headers={"WWW-Authenticate": "Basic"},
        )


@router.get("/leads", response_class=HTMLResponse)
def admin_leads(db: Session = Depends(get_db), _=Depends(check_key)):
    """Panel HTML para ver solicitudes de médicos sin necesidad de app."""
    leads = db.query(DoctorLead).order_by(DoctorLead.creado_en.desc()).all()

    colores = {
        "pendiente": "#FFA000",
        "contactado": "#1976D2",
        "activo": "#388E3C",
        "rechazado": "#D32F2F",
    }

    filas = ""
    for l in leads:
        color = colores.get(l.estado, "#999")
        filas += f"""
        <tr>
          <td>{l.id}</td>
          <td><b>{l.nombre}</b></td>
          <td>{l.especialidad}</td>
          <td><a href="mailto:{l.email}">{l.email}</a></td>
          <td><a href="https://wa.me/{l.telefono.replace('+','').replace(' ','').replace('-','')}">{l.telefono}</a></td>
          <td>{l.pais}</td>
          <td>{l.anos_experiencia} años</td>
          <td><span style="background:{color};color:#fff;padding:3px 10px;border-radius:12px;font-size:12px">{l.estado.upper()}</span></td>
          <td style="font-size:12px;color:#666">{str(l.creado_en)[:16]}</td>
          <td>
            <a href="/admin/leads/estado/{l.id}/contactado" style="color:#1976D2">✓ Contactado</a> |
            <a href="/admin/leads/estado/{l.id}/activo" style="color:#388E3C">✓ Activo</a> |
            <a href="/admin/leads/estado/{l.id}/rechazado" style="color:#D32F2F">✗ Rechazar</a>
          </td>
        </tr>"""

    total = len(leads)
    pendientes = sum(1 for l in leads if l.estado == "pendiente")

    return f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SaludEnLínea — Admin</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 0; background: #f5f5f5; }}
    .header {{ background: #1976D2; color: #fff; padding: 16px 24px; }}
    .header h1 {{ margin: 0; font-size: 22px; }}
    .stats {{ display: flex; gap: 16px; padding: 16px 24px; }}
    .stat {{ background: #fff; padding: 12px 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,.1); }}
    .stat .num {{ font-size: 28px; font-weight: bold; color: #1976D2; }}
    table {{ width: 100%; border-collapse: collapse; background: #fff; margin: 0 24px; width: calc(100% - 48px); border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.1); }}
    th {{ background: #1976D2; color: #fff; padding: 10px 12px; text-align: left; font-size: 13px; }}
    td {{ padding: 10px 12px; border-bottom: 1px solid #f0f0f0; font-size: 13px; vertical-align: middle; }}
    tr:hover {{ background: #f9f9f9; }}
    a {{ color: inherit; }}
  </style>
</head>
<body>
  <div class="header" style="display:flex;justify-content:space-between;align-items:center">
    <h1>🏥 SaludEnLínea — Solicitudes de Médicos</h1>
    <nav><a href="/admin/doctors" style="color:#fff;margin-left:16px;text-decoration:none">➕ Médicos</a></nav>
  </div>
  <div class="stats">
    <div class="stat"><div class="num">{total}</div><div>Total solicitudes</div></div>
    <div class="stat"><div class="num" style="color:#FFA000">{pendientes}</div><div>Pendientes</div></div>
    <div class="stat"><div class="num" style="color:#388E3C">{sum(1 for l in leads if l.estado == 'activo')}</div><div>Activos</div></div>
  </div>
  <table>
    <thead>
      <tr>
        <th>#</th><th>Nombre</th><th>Especialidad</th><th>Email</th><th>Teléfono</th>
        <th>País</th><th>Exp.</th><th>Estado</th><th>Fecha</th><th>Acciones</th>
      </tr>
    </thead>
    <tbody>{filas if filas else '<tr><td colspan="10" style="text-align:center;padding:40px;color:#999">No hay solicitudes aún</td></tr>'}</tbody>
  </table>
  <p style="text-align:center;color:#999;margin:20px;font-size:12px">
    Actualizar: <a href="/admin/leads">↺ Recargar</a>
  </p>
</body>
</html>"""


@router.get("/leads/estado/{lead_id}/{nuevo_estado}")
def cambiar_estado(
    lead_id: int,
    nuevo_estado: str,
    db: Session = Depends(get_db),
    _=Depends(check_key),
):
    lead = db.query(DoctorLead).filter(DoctorLead.id == lead_id).first()
    if not lead:
        raise HTTPException(status_code=404, detail="No encontrado")
    lead.estado = nuevo_estado
    db.commit()
    return RedirectResponse(url=f"/admin/leads")


# ──────────────────────────────────────────
#  PANEL DE MÉDICOS
# ──────────────────────────────────────────

@router.get("/doctors", response_class=HTMLResponse)
def admin_doctors(db: Session = Depends(get_db), _=Depends(check_key), msg: str = ""):
    doctors = db.query(Doctor).order_by(Doctor.creado_en.desc()).all()

    filas = ""
    for d in doctors:
        estado_color = "#388E3C" if d.activo else "#D32F2F"
        estado_txt = "Activo" if d.activo else "Inactivo"
        toggle_url = f"/admin/doctors/toggle/{d.id}"
        filas += f"""
        <tr>
          <td>{d.id}</td>
          <td><b>{d.nombre}</b></td>
          <td>{d.especialidad}</td>
          <td>{d.email}</td>
          <td>₡{d.tarifa:.0f}</td>
          <td>⭐ {d.calificacion:.1f}</td>
          <td><span style="background:{estado_color};color:#fff;padding:3px 10px;border-radius:12px;font-size:12px">{estado_txt}</span></td>
          <td style="font-size:12px;color:#666">{str(d.creado_en)[:16]}</td>
          <td><a href="{toggle_url}" style="color:#1976D2">{'Desactivar' if d.activo else 'Activar'}</a></td>
        </tr>"""

    alerta = f'<div style="background:#e8f5e9;border-left:4px solid #388E3C;padding:12px 16px;margin:16px 24px;border-radius:4px">{msg}</div>' if msg else ""

    return f"""<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SaludEnLínea — Médicos</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 0; background: #f5f5f5; }}
    .header {{ background: #1a3a5c; color: #fff; padding: 16px 24px; display:flex; justify-content:space-between; align-items:center; }}
    .header h1 {{ margin: 0; font-size: 22px; }}
    .nav a {{ color:#fff; margin-left:16px; text-decoration:none; font-size:14px; opacity:.85; }}
    .nav a:hover {{ opacity:1; }}
    .card {{ background:#fff; margin:16px 24px; padding:20px 24px; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,.1); }}
    .card h2 {{ margin:0 0 16px; font-size:16px; color:#1a3a5c; }}
    .form-row {{ display:flex; gap:12px; flex-wrap:wrap; margin-bottom:12px; }}
    .form-group {{ flex:1; min-width:180px; }}
    label {{ display:block; font-size:12px; color:#555; margin-bottom:4px; font-weight:bold; }}
    input, select {{ width:100%; box-sizing:border-box; padding:8px 10px; border:1px solid #ddd; border-radius:4px; font-size:14px; }}
    input:focus, select:focus {{ outline:none; border-color:#1a3a5c; }}
    .btn {{ background:#1a3a5c; color:#fff; border:none; padding:10px 24px; border-radius:4px; cursor:pointer; font-size:14px; }}
    .btn:hover {{ background:#2ecc71; }}
    table {{ width:100%; border-collapse:collapse; }}
    th {{ background:#1a3a5c; color:#fff; padding:10px 12px; text-align:left; font-size:13px; }}
    td {{ padding:10px 12px; border-bottom:1px solid #f0f0f0; font-size:13px; vertical-align:middle; }}
    tr:hover {{ background:#f9f9f9; }}
  </style>
</head>
<body>
  <div class="header">
    <h1>🏥 SaludEnLínea — Panel Admin</h1>
    <nav class="nav">
      <a href="/admin/doctors">Médicos</a>
      <a href="/admin/leads">Solicitudes</a>
    </nav>
  </div>

  {alerta}

  <div class="card">
    <h2>➕ Agregar Médico</h2>
    <form method="post" action="/admin/doctors/crear">
      <div class="form-row">
        <div class="form-group">
          <label>Nombre completo *</label>
          <input name="nombre" required placeholder="Dr. Juan Pérez">
        </div>
        <div class="form-group">
          <label>Especialidad *</label>
          <input name="especialidad" required placeholder="Medicina General">
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Email *</label>
          <input name="email" type="email" required placeholder="doctor@email.com">
        </div>
        <div class="form-group">
          <label>Contraseña temporal *</label>
          <input name="password" type="password" required placeholder="Mínimo 8 caracteres" minlength="8">
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Tarifa por consulta (₡ o $)</label>
          <input name="tarifa" type="number" value="15" min="0" step="0.5">
        </div>
        <div class="form-group">
          <label>Credenciales / descripción</label>
          <input name="credenciales" placeholder="Ej: Médico graduado UCR, 10 años experiencia">
        </div>
        <div class="form-group">
          <label>URL foto (opcional)</label>
          <input name="foto_url" placeholder="https://...">
        </div>
      </div>
      <button type="submit" class="btn">✔ Crear médico</button>
    </form>
  </div>

  <div class="card">
    <h2>👨‍⚕️ Médicos registrados ({len(doctors)})</h2>
    <table>
      <thead>
        <tr><th>#</th><th>Nombre</th><th>Especialidad</th><th>Email</th><th>Tarifa</th><th>Rating</th><th>Estado</th><th>Creado</th><th>Acción</th></tr>
      </thead>
      <tbody>{filas if filas else '<tr><td colspan="9" style="text-align:center;padding:40px;color:#999">No hay médicos aún</td></tr>'}</tbody>
    </table>
  </div>
</body>
</html>"""


@router.post("/doctors/crear")
def crear_doctor(
    db: Session = Depends(get_db),
    _=Depends(check_key),
    nombre: str = Form(...),
    especialidad: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    tarifa: float = Form(15.0),
    credenciales: str = Form(""),
    foto_url: str = Form(""),
):
    if db.query(Doctor).filter(Doctor.email == email).first():
        raise HTTPException(status_code=400, detail="Email ya registrado")
    pass_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    doctor = Doctor(
        nombre=nombre,
        especialidad=especialidad,
        email=email,
        pass_hash=pass_hash,
        tarifa=tarifa,
        credenciales=credenciales,
        foto_url=foto_url,
    )
    db.add(doctor)
    db.commit()
    return RedirectResponse(url=f"/admin/doctors&msg=Médico+{nombre}+creado+exitosamente", status_code=303)


@router.get("/doctors/toggle/{doctor_id}")
def toggle_doctor(doctor_id: int, db: Session = Depends(get_db), _=Depends(check_key)):
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    if not doctor:
        raise HTTPException(status_code=404, detail="No encontrado")
    doctor.activo = not doctor.activo
    db.commit()
    return RedirectResponse(url=f"/admin/doctors")
