@echo off
cd /d "C:\Users\yermari flores valle\SaludEnLinea\backend"
call venv\Scripts\activate.bat
start "Backend-8003" cmd /k "uvicorn main:app --host 0.0.0.0 --port 8003"
timeout /t 3 /nobreak >nul
echo Servidor iniciado en puerto 8003
