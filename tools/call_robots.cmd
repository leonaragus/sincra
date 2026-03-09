@echo off
setlocal ENABLEEXTENSIONS

if "%SUPABASE_URL%"=="" (
  echo Faltan variables de entorno SUPABASE_URL y SUPABASE_ANON_KEY o SERVICE_ROLE_KEY.
  exit /b 1
)

set FN_URL=%SUPABASE_URL%/functions/v1/robots_update_paritarias_sanidad

curl -s -X POST "%FN_URL%" -H "Authorization: Bearer %SUPABASE_SERVICE_ROLE_KEY%" -H "Content-Type: application/json" -d "{}"

echo.
echo Listo.
exit /b 0

