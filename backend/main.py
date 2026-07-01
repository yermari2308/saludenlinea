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
from routers import auth, doctors, appointments, patients, leads, admin, payments, google_auth, chat, password_reset, urgent, medical_record

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
            # Fase 2: expediente clínico — la tabla se crea via create_all, pero columnas opcionales
            "ALTER TABLE medical_records ADD COLUMN IF NOT EXISTS salud_femenina TEXT",
        ]
        for sql in migrations:
            try:
                conn.execute(__import__("sqlalchemy").text(sql))
                conn.commit()
            except Exception as e:
                logger.warning("Migración omitida: %s — %s", sql[:60], e)

_run_migrations()

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


@app.get("/api")
def root():
    return {"mensaje": "SaludEnLínea API activa", "docs": "/docs"}

# Servir Flutter web build como frontend (debe ir AL FINAL, después de todas las rutas API)
_flutter_build = os.path.join(os.path.dirname(__file__), "..", "flutter_app", "build", "web")
if os.path.isdir(_flutter_build):
    app.mount("/", StaticFiles(directory=_flutter_build, html=True), name="frontend")
