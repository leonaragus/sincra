@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo ========================================================
echo ROBOT: Elevar Actualizacion de Convenios
echo ========================================================
echo.

:: Cargar variables desde .env
if not exist .env (
    echo [ERROR] No se encontro el archivo .env
    pause
    exit /b
)

for /f "tokens=1* delims==" %%a in ('type .env') do (
    set "%%a=%%b"
)

if "%SUPABASE_URL%"=="" (
    echo [ERROR] No se encontro SUPABASE_URL en .env
    pause
    exit /b
)

if "%SUPABASE_SERVICE_ROLE_KEY%"=="" (
    echo [ADVERTENCIA] No se encontro SUPABASE_SERVICE_ROLE_KEY en .env. Usando ANON KEY.
    set "SUPABASE_KEY=%SUPABASE_ANON_KEY%"
) else (
    set "SUPABASE_KEY=%SUPABASE_SERVICE_ROLE_KEY%"
)

echo [1/3] Iniciando proceso de recoleccion de datos...
:: Simulacion de scraping
echo Simulando scraping de CCT...
timeout /t 2 > nul

echo [2/3] Generando payload para Supabase...
(
echo [
echo   {
echo     "codigo": "122/75",
echo     "nombre": "FATSA Sanidad",
echo     "sector": "Sanidad",
echo     "version_actual": 2026,
echo     "fecha_actualizacion": "%date%",
echo     "activo": true
echo   }
echo ]
) > payload_temp.json

echo [3/3] Enviando datos a Supabase (Tabla cct_master)...
curl.exe -X POST "%SUPABASE_URL%/rest/v1/cct_master" ^
  -H "apikey: %SUPABASE_KEY%" ^
  -H "Authorization: Bearer %SUPABASE_KEY%" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: resolution=merge-duplicates" ^
  -d @payload_temp.json

if %errorlevel% equ 0 (
    echo.
    echo [EXITO] Convenios actualizados correctamente en la nube.
) else (
    echo.
    echo [ERROR] Fallo al conectar con Supabase.
)

del payload_temp.json
echo.
pause
