@echo off
echo Actualizando vercel.json con configuración mejorada...
copy vercel.json temp_deploy\ >nul
echo.
echo ¡Configuración actualizada!
echo Ahora necesitas:
echo 1. Ir a https://github.com/leonaragus/sincra
echo 2. Subir el nuevo vercel.json (arrastrar a la carpeta temp_deploy no funciona para updates)
echo 3. O hacer commit manual del nuevo vercel.json
echo.
echo También puedes forzar redeploy en Vercel desde el dashboard
echo.
pause