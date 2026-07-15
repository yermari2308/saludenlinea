import os
import logging
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from database import engine
from models import Base
from routers import auth, doctors, appointments, patients, leads, admin, payments, google_auth, chat, password_reset, urgent, medical_record, hra, subscriptions, pharmacy, health_metrics, benefits, legal

load_dotenv()

_handlers = [logging.StreamHandler()]
try:
    _handlers.append(logging.FileHandler("saludenlinea.log", encoding="utf-8"))
except OSError:
    pass
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=_handlers,
)
logger = logging.getLogger("saludenlinea")

Base.metadata.create_all(bind=engine)

# Migraciones manuales: agregar columnas nuevas si no existen (PostgreSQL)
def _run_migrations():
    with engine.connect() as conn:
        migrations = [
            "ALTER TABLE appointments ADD COLUMN IF NOT EXISTS receta_archivo_nombre VARCHAR(255) DEFAULT ''",
            "ALTER TABLE appointments ADD COLUMN IF NOT EXISTS receta_archivo_b64 TEXT DEFAULT ''",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS disponible_urgente BOOLEAN DEFAULT FALSE",
            "ALTER TABLE consult_queue ADD COLUMN IF NOT EXISTS sala_token VARCHAR(255)",
            "ALTER TABLE consult_queue ADD COLUMN IF NOT EXISTS asignada_en TIMESTAMP",
            # Fase 2: expediente clínico
            "ALTER TABLE medical_records ADD COLUMN IF NOT EXISTS salud_femenina TEXT",
            # Fase 4: pagos SINPE + Stripe
            "ALTER TABLE payments ADD COLUMN IF NOT EXISTS sinpe_referencia VARCHAR(100)",
            "ALTER TABLE payments ADD COLUMN IF NOT EXISTS sinpe_telefono VARCHAR(20)",
            "ALTER TABLE payments ADD COLUMN IF NOT EXISTS comprobante_b64 TEXT",
            "ALTER TABLE payments ADD COLUMN IF NOT EXISTS verificado_por INTEGER",
            "ALTER TABLE payments ADD COLUMN IF NOT EXISTS verificado_en TIMESTAMP",
            "ALTER TABLE appointments ADD COLUMN IF NOT EXISTS oculta_paciente BOOLEAN DEFAULT FALSE",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS codigo_medico VARCHAR(30) DEFAULT ''",
        ]
        for sql in migrations:
            try:
                conn.execute(__import__("sqlalchemy").text(sql))
                conn.commit()
            except Exception as e:
                logger.warning("Migración omitida: %s — %s", sql[:60], e)

_run_migrations()

# Seed inicial de farmacia (solo si el catálogo está vacío)
def _seed_pharmacy():
    from database import SessionLocal
    db = SessionLocal()
    try:
        pharmacy.seed_products(db)
        benefits.seed_benefits(db)
    except Exception as e:
        logger.warning("Seed omitido: %s", e)
    finally:
        db.close()

_seed_pharmacy()

limiter = Limiter(key_func=get_remote_address)

ENV = os.getenv("ENV", "production")

app = FastAPI(
    title="SaludEnLínea API",
    description="Backend de telemedicina para Latinoamérica",
    version="1.0.0",
    docs_url="/docs" if ENV != "production" else None,
    redoc_url="/redoc" if ENV != "production" else None,
    openapi_url="/openapi.json" if ENV != "production" else None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

ALLOWED_ORIGINS = [
    "https://saludenlinea.onrender.com",
    "https://saludenlinea-production.up.railway.app",
    "http://localhost:8000",
    "http://localhost:3000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "frame-ancestors 'none'"
    )
    return response


@app.middleware("http")
async def log_requests(request: Request, call_next):
    response = await call_next(request)
    if request.url.path.startswith("/api"):
        logger.info("%s %s → %s ip=%s", request.method, request.url.path, response.status_code, get_remote_address(request))
    return response

app.include_router(auth.router)
app.include_router(doctors.router)
app.include_router(appointments.router)
app.include_router(patients.router)
app.include_router(leads.router)
app.include_router(admin.router)
app.include_router(payments.router)
app.include_router(google_auth.router)
app.include_router(chat.router)
app.include_router(password_reset.router)
app.include_router(urgent.router)
app.include_router(medical_record.router)
app.include_router(hra.router)
app.include_router(subscriptions.router)
app.include_router(pharmacy.router)
app.include_router(health_metrics.router)
app.include_router(benefits.router)
app.include_router(legal.router)


@app.get("/api")
def root():
    return {"mensaje": "SaludEnLínea API activa", "docs": "/docs"}

# Servir Flutter web build como frontend (debe ir AL FINAL, después de todas las rutas API)
_flutter_build = os.path.join(os.path.dirname(__file__), "..", "flutter_app", "build", "web")
if os.path.isdir(_flutter_build):
    app.mount("/", StaticFiles(directory=_flutter_build, html=True), name="frontend")
else:
    # Landing page (el contenedor de Railway solo incluye el backend)
    from fastapi.responses import HTMLResponse

    _LANDING = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SaludEnLínea — Telemedicina en Costa Rica</title>
<meta name="description" content="Plataforma de telemedicina que conecta pacientes con médicos certificados en Costa Rica: videoconsultas, expediente clínico, farmacia con entrega a domicilio.">
<style>
  * { margin:0; box-sizing:border-box; font-family:'Segoe UI',system-ui,sans-serif; }
  body { color:#1a2b3c; background:#fff; }
  .hero { background:linear-gradient(135deg,#0B2545 0%,#13315C 60%,#134074 100%); color:#fff;
          padding:72px 24px 84px; text-align:center; }
  .hero .logo { font-size:52px; }
  .hero h1 { font-size:clamp(30px,6vw,44px); margin:12px 0 10px; letter-spacing:-0.5px; }
  .hero h1 span { color:#00C896; }
  .hero p { max-width:560px; margin:0 auto 28px; font-size:17px; line-height:1.6; opacity:.85; }
  .btn { display:inline-block; background:#00C896; color:#06283d; font-weight:700;
         padding:14px 32px; border-radius:12px; text-decoration:none; font-size:16px; }
  .btn.sec { background:transparent; color:#fff; border:1.5px solid rgba(255,255,255,.4); margin-left:10px; }
  .features { max-width:960px; margin:-40px auto 0; padding:0 24px 60px;
              display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:16px; }
  .card { background:#fff; border-radius:16px; padding:26px 22px;
          box-shadow:0 10px 34px rgba(11,37,69,.12); }
  .card .ic { font-size:30px; }
  .card h3 { margin:10px 0 6px; font-size:16px; }
  .card p { font-size:13.5px; color:#5a6b7c; line-height:1.55; }
  footer { border-top:1px solid #e7ecf1; padding:26px 24px; text-align:center;
           font-size:13px; color:#7b8a99; }
  footer a { color:#134074; }
</style>
</head>
<body>
  <section class="hero">
    <div class="logo">🩺</div>
    <h1>Salud<span>En</span>Línea</h1>
    <p>Consultas médicas por video con profesionales certificados, expediente clínico digital,
       atención urgente 24/7 y farmacia con entrega a domicilio — desde tu celular, en Costa Rica.</p>
    <a class="btn" href="/descargar">📲 Descargar app (Android)</a>
  </section>
  <section class="features">
    <div class="card"><div class="ic">🎥</div><h3>Videoconsultas</h3>
      <p>Atención médica por videollamada cifrada con médicos generales y especialistas, con receta digital al finalizar.</p></div>
    <div class="card"><div class="ic">🚨</div><h3>Botón de urgencia</h3>
      <p>Cola de atención inmediata: un médico disponible te atiende en minutos, sin cita previa.</p></div>
    <div class="card"><div class="ic">📋</div><h3>Expediente clínico</h3>
      <p>Tu historial médico completo y evaluación de salud (HRA) siempre disponibles y protegidos.</p></div>
    <div class="card"><div class="ic">💊</div><h3>Farmacia en línea</h3>
      <p>Pedí medicamentos y productos de salud con entrega a domicilio. Validación de recetas incluida.</p></div>
    <div class="card"><div class="ic">💳</div><h3>Pagos locales</h3>
      <p>Pagá con SINPE Móvil o tarjeta de crédito/débito de forma segura. Planes de suscripción desde $9.99/mes.</p></div>
    <div class="card"><div class="ic">🔒</div><h3>Datos protegidos</h3>
      <p>Cifrado SSL en todas las comunicaciones, autenticación segura y datos alojados con respaldo.</p></div>
  </section>
  <footer>
    SaludEnLínea · Costa Rica · <a href="mailto:yermariflores081@gmail.com">Contacto</a>
    · <a href="/api">API</a>
  </footer>
</body>
</html>"""

    @app.get("/", response_class=HTMLResponse, include_in_schema=False)
    def landing():
        return _LANDING

    @app.get("/descargar", include_in_schema=False)
    def descargar_apk():
        """
        Redirige directo al .apk del último release de GitHub, sin pasar
        por la página HTML del release (que en algunos navegadores/apps
        embebidas como WhatsApp exige iniciar sesión en GitHub aunque el
        archivo sea público).
        """
        import requests
        from fastapi.responses import RedirectResponse

        fallback = "https://github.com/yermari2308/saludenlinea/releases/latest/download/SaludEnLinea.apk"
        try:
            r = requests.get(
                "https://api.github.com/repos/yermari2308/saludenlinea/releases/latest",
                timeout=8,
            )
            r.raise_for_status()
            assets = r.json().get("assets", [])
            apk = next((a for a in assets if a["name"].endswith(".apk")), None)
            url = apk["browser_download_url"] if apk else fallback
        except Exception as e:
            logger.warning("No se pudo resolver el release más reciente: %s", e)
            url = fallback
        return RedirectResponse(url=url, status_code=302)
