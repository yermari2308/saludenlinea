@echo off
title SaludEnLinea — Servidor
color 0A

echo.
echo  ========================================
echo    SaludEnLinea - Iniciando...
echo  ========================================
echo.

:: Usar WSL para iniciar el servidor (mas confiable)
wsl -e bash -c "cd '/c/Users/yermari flores valle/SaludEnLinea/backend' && source venv/Scripts/activate && uvicorn main:app --host 0.0.0.0 --port 9000 --reload &> /tmp/server.log & sleep 3 && lt --port 9000 --subdomain saludenlinea &>> /tmp/tunnel.log &"

timeout /t 5 /nobreak >nul

echo  ✓ App:    http://localhost:9000
echo  ✓ API:    http://localhost:9000/api
echo  ✓ Docs:   http://localhost:9000/docs
echo  ✓ Admin:  http://localhost:9000/admin/leads?key=saludenlinea-admin-2025
echo.
echo  URL publica (tunnel, puede cambiar cada sesion):
echo  Revisar consola WSL para la URL del tunnel
echo.

start "" "http://localhost:9000"
echo.
pause
