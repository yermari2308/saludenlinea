@echo off
:: Script de build con version automatica
:: Uso: build_and_deploy.bat

:: Generar version basada en fecha y hora
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set dt=%%I
set VERSION=%dt:~0,4%%dt:~4,2%%dt:~6,2%-%dt:~8,4%

echo === SaludEnLinea Build v%VERSION% ===

:: Estampar version en index.html
powershell -Command "(Get-Content web\index.html) -replace '__APP_VERSION__', '%VERSION%' | Set-Content web\index.html.tmp"
copy /Y web\index.html.tmp build\web\index.html 2>nul

:: Build Flutter
call flutter build web --no-pub --dart-define=APP_VERSION=%VERSION%
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build fallo
    exit /b 1
)

:: Restaurar index.html original
del web\index.html.tmp 2>nul

echo.
echo === Build completado v%VERSION% ===
echo Sube la carpeta build\web\ a Netlify o tu servidor
echo.
pause
