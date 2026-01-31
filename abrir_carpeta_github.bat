@echo off
echo Abriendo carpeta con archivos listos para GitHub...
echo.
echo INSTRUCCIONES RÁPIDAS:
echo 1. Abre https://github.com/leonaragus/sincra en tu navegador
echo 2. Haz clic en "Add file" -> "Upload files"
echo 3. Arrastra TODOS los archivos de esta carpeta a GitHub
echo 4. Espera a que se suban todos los archivos
echo 5. Haz clic en "Commit changes"
echo.
echo Los archivos esenciales ya están en esta carpeta:
echo - lib/ (código Flutter)
echo - web/ (configuración web)  
echo - pubspec.yaml (dependencias)
echo - vercel.json (configuración Vercel)
echo - README.md (documentación)
echo - .gitignore (archivos a ignorar)
echo.
echo Presiona cualquier tecla para abrir la carpeta...
pause >nul
start .\temp_deploy