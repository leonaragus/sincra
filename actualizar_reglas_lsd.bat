@echo off
chcp 65001 >nul
cls
echo ========================================================
echo      ROBOT DE ACTUALIZACION - VALIDADOR LSD ARCA
echo ========================================================
echo.
echo Cargando variables de entorno desde .env...

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
    echo [ADVERTENCIA] No se encontro SUPABASE_SERVICE_ROLE_KEY en .env. Usando ANON KEY (Solo lectura posible).
    set "SUPABASE_KEY=%SUPABASE_ANON_KEY%"
) else (
    set "SUPABASE_KEY=%SUPABASE_SERVICE_ROLE_KEY%"
)

echo.
echo URL: %SUPABASE_URL%
echo KEY: [Configurada]
echo.

set /p VERSION="Ingrese version (ej. 20260301): "
set /p TOPE_MIN="Ingrese Tope Minimo (ej. 180000): "
set /p TOPE_MAX="Ingrese Tope Maximo (ej. 2800000): "
set /p MSG="Mensaje de actualizacion: "

echo.
echo Generando payload...

:: Crear archivo temporal JSON para evitar problemas de escaping
(
echo {
echo   "version": %VERSION%,
echo   "config_json": {
echo     "version": %VERSION%,
echo     "topes": {
echo       "min": %TOPE_MIN%,
echo       "max": %TOPE_MAX%
echo     },
echo     "mensaje": "%MSG%",
echo     "reglas_activas": ["base4_vs_base8", "cuil_mod11", "aportes_diff"]
echo   }
echo }
) > payload_temp.json

echo.
echo Subiendo a Supabase...

curl -X POST "%SUPABASE_URL%/rest/v1/lsd_rules_config" ^
  -H "apikey: %SUPABASE_KEY%" ^
  -H "Authorization: Bearer %SUPABASE_KEY%" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: return=minimal" ^
  -d @payload_temp.json

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [EXITO] Reglas actualizadas correctamente.
) else (
    echo.
    echo [ERROR] Fallo al subir las reglas.
)

:: Limpiar
del payload_temp.json

pause
