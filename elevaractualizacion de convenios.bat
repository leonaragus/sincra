@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo ========================================================
echo ROBOT: Elevar Actualizacion de Convenios
echo ========================================================
echo.

:: CONFIGURACION SUPABASE
set SUPABASE_URL=https://sstxhajsclwfktyvawmr.supabase.co
set SUPABASE_KEY=sb_publishable_BLRB7OgEcoA0TWZIiPNn-Q_vW7VovCZ
:: NOTA: Para escritura global, es posible que necesites la SERVICE_ROLE_KEY aqui si RLS bloquea la Anon Key.
:: set SUPABASE_KEY=TU_SERVICE_ROLE_KEY

echo [1/3] Iniciando proceso de recoleccion de datos...
:: Aqui iria la llamada a tu script de scraping (Python/Node)
:: python scrape_convenios.py > resultados.json
:: Por ahora simulamos que el scraping fue exitoso
echo Simulando scraping de CCT...
timeout /t 2 > nul

echo [2/3] Generando payload para Supabase...
:: Creamos un JSON temporal para prueba
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
:: Usamos CURL para actualizar. Nota: Esto requiere que la tabla tenga permisos de escritura para esta Key.
curl -X POST "%SUPABASE_URL%/rest/v1/cct_master" ^
  -H "apikey: %SUPABASE_KEY%" ^
  -H "Authorization: Bearer %SUPABASE_KEY%" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: resolution=merge-duplicates" ^
  -d @payload_temp.json

if %errorlevel% equ 0 (
    echo.
    echo [EXITO] Convenios actualizados correctamente en la nube.
    echo Verifica en la App: Home ^> Estado de Servicios.
) else (
    echo.
    echo [ERROR] Fallo al conectar con Supabase. Verifica la API KEY.
)

del payload_temp.json
echo.
pause
