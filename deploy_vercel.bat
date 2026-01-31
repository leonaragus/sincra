@echo off
echo Preparando proyecto para deploy en Vercel...

REM Crear archivo temporal con los archivos necesarios
echo Copiando archivos importantes...

REM Crear directorio temporal
mkdir temp_deploy

REM Copiar archivos esenciales de Flutter
xcopy lib temp_deploy\lib\ /E /I /Y
xcopy web temp_deploy\web\ /E /I /Y
copy pubspec.yaml temp_deploy\
copy pubspec.lock temp_deploy\
copy README.md temp_deploy\
copy vercel.json temp_deploy\

echo Archivos copiados exitosamente!
echo Ahora puedes:
echo 1. Subir manualmente los archivos de temp_deploy a GitHub
echo 2. O usar GitHub Desktop para hacer commit y push
echo.
echo El proyecto está listo para deploy en Vercel!