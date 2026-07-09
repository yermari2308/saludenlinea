"""
Creación de salas de videollamada.

Proveedor principal: Daily.co (requiere DAILY_API_KEY, plan gratis 10k min/mes).
Fallback: Jitsi Meet (sin clave, gratis).

La sala se identifica por el token_sala de ConsultSession/ConsultQueue,
así ambos participantes de la misma cita reciben la misma URL.
"""
import os
import re
import time
import logging

logger = logging.getLogger("saludenlinea")

DAILY_API_KEY = os.getenv("DAILY_API_KEY", "")
DAILY_API = "https://api.daily.co/v1"
JITSI_HOST = os.getenv("JITSI_HOST", "meet.jit.si")

# Cache en memoria: token_sala -> url (evita llamadas repetidas a la API)
_room_cache: dict = {}


def _room_name(token_sala: str) -> str:
    """Nombre de sala válido para Daily (minúsculas, números, - y _)."""
    limpio = re.sub(r"[^a-zA-Z0-9_-]", "", token_sala).lower()[:38]
    return f"se-{limpio}"


def _jitsi_url(token_sala: str, display_name: str = "") -> str:
    room = re.sub(r"[^a-zA-Z0-9]", "", token_sala)[:32]
    base = f"https://{JITSI_HOST}/SaludEnLinea{room}"
    if display_name:
        safe = display_name.replace(" ", "%20")
        return f'{base}#userInfo.displayName="{safe}"'
    return base


def _daily_url(token_sala: str) -> str:
    """Crea (o recupera) una sala en Daily y retorna su URL."""
    if token_sala in _room_cache:
        return _room_cache[token_sala]

    import requests

    nombre = _room_name(token_sala)
    headers = {"Authorization": f"Bearer {DAILY_API_KEY}"}

    # Intentar crear la sala (expira en 24 h)
    r = requests.post(
        f"{DAILY_API}/rooms",
        json={
            "name": nombre,
            "privacy": "public",
            "properties": {
                "exp": int(time.time()) + 86400,
                "enable_chat": True,
                "enable_prejoin_ui": True,
                "eject_at_room_exp": True,
                "lang": "es",
            },
        },
        headers=headers,
        timeout=15,
    )
    if r.status_code == 200:
        url = r.json()["url"]
    elif r.status_code == 400 and "already exists" in r.text:
        # La sala ya existe — recuperarla
        g = requests.get(f"{DAILY_API}/rooms/{nombre}", headers=headers, timeout=15)
        g.raise_for_status()
        url = g.json()["url"]
    else:
        raise RuntimeError(f"Daily API {r.status_code}: {r.text[:200]}")

    _room_cache[token_sala] = url
    return url


def video_url(token_sala: str, display_name: str = "") -> str:
    """URL de la videollamada para esta sala. Daily si está configurado, si no Jitsi."""
    if DAILY_API_KEY:
        try:
            return _daily_url(token_sala)
        except Exception as e:
            logger.warning("Daily falló, usando Jitsi como respaldo: %s", e)
    return _jitsi_url(token_sala, display_name)
