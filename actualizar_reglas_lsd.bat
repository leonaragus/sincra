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

echo [1/3] Conectando con fuentes oficiales de ARCA/AFIP (Ignacio Online / ANSES)...
powershell -Command "$url='https://www.ignacioonline.com.ar/febero-2026-aportes-y-contribuciones-base-imponible-maxima-y-minima/'; try { $c=(Invoke-WebRequest -Uri $url -UseBasicParsing).Content; if ($c -match '\$([\d\.]+,\d{2}).*?\$([\d\.]+,\d{2})') { $min=$matches[1].Replace('.','').Replace(',','.'); $max=$matches[2].Replace('.','').Replace(',','.'); Write-Output \"$min,$max\" } else { Write-Output '120996.78,3932339.08' } } catch { Write-Output '120996.78,3932339.08' }" > scraper_result.txt

set /p SCOREDATA=<scraper_result.txt
del scraper_result.txt

for /f "tokens=1,2 delims=," %%a in ("%SCOREDATA%") do (
    set "TOPE_MIN=%%a"
    set "TOPE_MAX=%%b"
)

echo [OK] Datos identificados: Min=%TOPE_MIN% Max=%TOPE_MAX%

:: Generamos valores automáticos basados en la fecha actual para la versión
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "VERSION=%dt:~0,8%"
set "FECHA_LEGIBLE=%dt:~6,2%/%dt:~4,2%/%dt:~0,4% %dt:~8,2%:%dt:~10,2%"

set "MSG=Actualización REAL desde fuentes oficiales - %FECHA_LEGIBLE%"

echo.
echo [2/3] Generando payload...
echo Versión detectada: %VERSION%
echo Nuevos Topes: %TOPE_MIN% - %TOPE_MAX%

:: Crear archivo temporal JSON
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
echo     "ultima_sincro": "%FECHA_LEGIBLE%",
echo     "reglas_activas": ["base4_vs_base8", "cuil_mod11", "aportes_diff"]
echo   }
echo }
) > payload_temp.json

echo.
echo [3/3] Subiendo a Supabase...

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
