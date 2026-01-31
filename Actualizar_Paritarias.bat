@echo off
title Robot Elevar - Actualización de Paritarias
echo 🤖 Iniciando proceso de actualización federal...
echo.
cd /d "%~dp0"
npm run update-paritarias
echo.
echo ---------------------------------------------------
echo ✅ Proceso finalizado. 
echo Presiona cualquier tecla para cerrar esta ventana.
pause > nul
