@echo off
cd /d "%~dp0"
echo Reiniciando servidor SaludEnLinea en puerto 8002...
call venv\Scripts\activate.bat
uvicorn main:app --host 0.0.0.0 --port 8002 --reload
