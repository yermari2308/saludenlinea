"""
Panel admin simple — accesible via navegador en /admin/leads
Protegido con API key en header o query param.
"""
import os
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from database import get_db
from models import DoctorLead

router = APIRouter(prefix="/admin", tags=["admin"])

ADMIN_KEY = os.getenv("ADMIN_KEY", "saludenlinea-admin-2025")


def check_key(key: str = Query(..., alias="key")):
    if key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="Clave inválida")


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
            <a href="/admin/leads/estado/{l.id}/contactado?key={ADMIN_KEY}" style="color:#1976D2">✓ Contactado</a> |
            <a href="/admin/leads/estado/{l.id}/activo?key={ADMIN_KEY}" style="color:#388E3C">✓ Activo</a> |
            <a href="/admin/leads/estado/{l.id}/rechazado?key={ADMIN_KEY}" style="color:#D32F2F">✗ Rechazar</a>
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
  <div class="header">
    <h1>🏥 SaludEnLínea — Solicitudes de Médicos</h1>
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
    Actualizar: <a href="/admin/leads?key={ADMIN_KEY}">↺ Recargar</a>
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
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url=f"/admin/leads?key={ADMIN_KEY}")
