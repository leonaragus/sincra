@echo off
chcp 65001 >nul
title Robot Paritarias Sanidad (FATSA)

echo.
echo ========================================================
echo    ROBOT DE ACTUALIZACION - SANIDAD (FATSA)
echo    CCT 122/75 y 108/75 - 24 Jurisdicciones
echo ========================================================
echo.

cd /d "c:\Users\PC\elevar_liquidacion\elevar_liquidacion"

echo Ejecutando actualizacion de paritarias...
echo.

node update_paritarias_sanidad.js

echo.
echo ========================================================
echo    Proceso finalizado
echo ========================================================
echo.

pause
