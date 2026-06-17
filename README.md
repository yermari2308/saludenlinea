# SaludEnLínea — MVP Telemedicina

App móvil de telemedicina para Latinoamérica. Backend FastAPI + SQLite. Frontend Flutter.

## Estructura

```
SaludEnLinea/
├── backend/          ← API FastAPI
└── flutter_app/      ← App Flutter (Android/iOS)
```

## 1. Levantar el Backend

```bash
cd backend

# Crear entorno virtual
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # Mac/Linux

# Instalar dependencias
pip install -r requirements.txt

# Poblar base de datos con médicos de prueba
python seed.py

# Iniciar servidor
uvicorn main:app --reload --port 8000
```

API disponible en: http://localhost:8000  
Documentación interactiva: http://localhost:8000/docs

### Credenciales de prueba
| Rol      | Email                | Contraseña |
|----------|----------------------|------------|
| Paciente | paciente@demo.com    | demo1234   |
| Médico   | maria@demo.com       | demo1234   |

## 2. Levantar la App Flutter

Requiere Flutter SDK instalado: https://flutter.dev/docs/get-started/install

```bash
cd flutter_app

# Instalar paquetes
flutter pub get

# Correr en emulador Android (el baseUrl ya apunta a 10.0.2.2:8000)
flutter run

# O generar APK
flutter build apk --release
```

> Para dispositivo físico: cambiar `baseUrl` en `lib/services/api_service.dart` a la IP local de tu máquina (ej. `http://192.168.1.X:8000`).

## Endpoints principales

| Método | Endpoint                          | Descripción              |
|--------|-----------------------------------|--------------------------|
| POST   | /api/register/patient             | Registro de paciente     |
| POST   | /api/login                        | Login (paciente/médico)  |
| GET    | /api/doctors?especialidad=...     | Lista médicos            |
| GET    | /api/doctors/{id}                 | Detalle médico           |
| POST   | /api/appointments                 | Agendar cita             |
| GET    | /api/appointments                 | Mis citas                |
| POST   | /api/cancel/{id}                  | Cancelar cita            |
| GET    | /api/consultation/{id}            | Token de videollamada    |
| PUT    | /api/consultation/{id}/notes      | Médico guarda receta     |
| GET    | /api/receta/{id}                  | Paciente descarga receta |

## Próximos pasos (v1)

- [ ] Integrar Agora SDK para videollamadas reales
- [ ] Integrar Mercado Pago para cobros en LatAm
- [ ] Notificaciones push con Firebase Cloud Messaging
- [ ] Panel de médico (gestión de agenda)
- [ ] Exportar receta como PDF
