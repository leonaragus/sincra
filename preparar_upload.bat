@echo off
echo Creando directorio temporal para archivos de deploy...
mkdir temp_deploy 2>nul

echo Copiando archivos esenciales...
xcopy lib temp_deploy\lib\ /E /I /H >nul
xcopy web temp_deploy\web\ /E /I /H >nul
copy pubspec.yaml temp_deploy\ >nul
copy pubspec.lock temp_deploy\ >nul
copy vercel.json temp_deploy\ >nul
copy README.md temp_deploy\ >nul
copy .gitignore temp_deploy\ >nul

echo ¡Archivos copiados exitosamente!
echo.
echo Ahora abre el explorador de archivos y:
echo 1. Navega a: C:\Users\PC\elevar_liquidacion\elevar_liquidacion\temp_deploy
echo 2. Selecciona todos los archivos y carpetas
echo 3. Súbelos a GitHub
echo.
echo Presiona cualquier tecla para abrir el directorio temporal...
pause >nul
start temp_deploy