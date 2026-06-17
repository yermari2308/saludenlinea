@echo off
title SaludEnLinea - Tunnel Online
color 0A
echo.
echo  ============================================
echo    Servidor SaludEnLinea - ONLINE
echo    URL publica: https://saludenlinea.loca.lt
echo  ============================================
echo.

:: Matar tunnels anteriores
taskkill /F /IM "lt.exe" >nul 2>&1
taskkill /F /IM "node.exe" /FI "WINDOWTITLE eq SaludEnLinea*" >nul 2>&1
timeout /t 1 /nobreak >nul

echo Iniciando tunnel localtunnel en puerto 8002...
start "Tunnel" cmd /k "lt --port 8002 --subdomain saludenlinea"

echo.
echo  Backend local:  http://localhost:8002
echo  URL publica:    https://saludenlinea.loca.lt
echo  Admin panel:    https://saludenlinea.loca.lt/admin/leads?key=saludenlinea-admin-2025
echo  API docs:       https://saludenlinea.loca.lt/docs
echo.
echo  IMPORTANTE: Mantener esta ventana abierta para que el tunnel funcione.
echo  Si el subdomain ya esta ocupado, se asignara uno aleatorio.
echo.
pause
