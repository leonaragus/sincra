@echo off
echo ========================================================
echo ROBOT DE ACTUALIZACION DE CONVENIOS (TEMPLATE)
echo ========================================================
echo.
echo Este script es una plantilla para conectar tu proceso de actualizacion
echo con las tablas de Supabase que usa la App.
echo.
echo Tablas requeridas:
echo 1. maestro_paritarias (Docentes)
echo    Campos clave: jurisdiccion, valor_indice, piso_salarial, updated_at
echo.
echo 2. maestro_paritarias_sanidad (Sanidad)
echo    Campos clave: jurisdiccion, basico_profesional, basico_tecnico, updated_at
echo.
echo 3. cct_master (General)
echo    Campos clave: codigo, json_estructura, updated_at
echo.
echo [TU LOGICA DE SCRAPING O ACTUALIZACION AQUI]
echo.
echo Ejemplo con CURL (si tienes la URL de tu Edge Function o API):
echo curl -X POST https://tu-proyecto.supabase.co/functions/v1/update-paritarias -H "Authorization: Bearer TU_KEY"
echo.
echo ========================================================
echo Proceso finalizado. Verifica en la App > Estado de Servicios.
pause
