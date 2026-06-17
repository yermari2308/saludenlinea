@echo off
title SaludEnLinea - Build y Deploy
color 0B
echo.
echo  ============================================
echo    Compilando Flutter con URL de produccion
echo  ============================================
echo.

cd /d "C:\Users\yermari flores valle\SaludEnLinea\flutter_app"

:: Usar flutter del directorio del usuario
set FLUTTER="C:\Users\yermari flores valle\flutter\bin\flutter.bat"

echo [1/3] Compilando Flutter web...
call %FLUTTER% build web --release
if errorlevel 1 (
    echo ERROR: Fallo el build de Flutter
    pause
    exit /b 1
)

echo.
echo [2/3] Build completado. Subiendo a Netlify...
cd /d "C:\Users\yermari flores valle\SaludEnLinea\flutter_app"
call netlify deploy --prod --dir=build\web

echo.
echo [3/3] Listo! Revisa la URL de Netlify arriba.
echo.
pause
