@echo off
chcp 65001 > nul
title Syncra Admin Tools
cls

:menu
cls
echo ======================================================
echo             SYNCRA ARG - PANEL DE ADMINISTRACION
echo ======================================================
echo.
echo 1. Actualizar Reglas LSD (Robot)
echo 2. Actualizar Convenios (Robot)
echo 3. Verificar Conexion con Supabase
echo 4. Salir
echo.
set /p op="Seleccione una opcion: "

if "%op%"=="1" goto lsd
if "%op%"=="2" goto cct
if "%op%"=="3" goto check
if "%op%"=="4" goto exit

goto menu

:lsd
cls
call "actualizar_reglas_lsd.bat"
goto menu

:cct
cls
call "actualizar_convenios.bat"
goto menu

:check
cls
echo ======================================================
echo          VERIFICACION DE CONEXION SUPABASE
echo ======================================================
echo.

if not exist .env (
    echo [ERROR] No se encontro el archivo .env
    pause
    goto menu
)

for /f "tokens=1* delims==" %%a in ('type .env') do (
    set "%%a=%%b"
)

echo Probando conexion a: %SUPABASE_URL% ...
echo.

curl.exe -I "%SUPABASE_URL%"
if %errorlevel% equ 0 (
    echo.
    echo [OK] Conexion exitosa. El servidor responde.
) else (
    echo.
    echo [ERROR] No se pudo conectar. Verifique su internet o la URL.
)
echo.
pause
goto menu

:exit
exit
