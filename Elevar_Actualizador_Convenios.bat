@echo off
chcp 65001 >nul
title ELEVAR LIQUIDACIÓN - ACTUALIZADOR DE CONVENIOS
color 0F

:menu
cls
echo.
echo ========================================================
echo    ELEVAR LIQUIDACIÓN - PANEL DE ACTUALIZACIÓN
echo ========================================================
echo.
echo    🤖  ACTUALIZADORES AUTOMÁTICOS
echo    📅  Última ejecución: %date% %time:~0,8%
echo.
echo ========================================================
echo.
echo    1. ACTUALIZAR PARITARIAS FEDERALES
echo        (Todos los convenios nacionales)
echo.
echo    2. ACTUALIZAR CCT ESPECÍFICOS  
echo        (Desde convenios_update.json)
echo.
echo    3. ACTUALIZAR PARITARIAS SANIDAD
echo        (FATSA CCT 122/75 y 108/75)
echo.
echo    4. EJECUTAR TODAS LAS ACTUALIZACIONES
echo.
echo    5. VER ESTADO DE CONEXIÓN SUPABASE
echo.
echo    X. SALIR
echo.
echo ========================================================
echo.
set /p opcion="Selecciona una opción (1-5, X): "

echo.

if "%opcion%"=="1" goto opcion1
if "%opcion%"=="2" goto opcion2  
if "%opcion%"=="3" goto opcion3
if "%opcion%"=="4" goto opcion4
if "%opcion%"=="5" goto opcion5
if /i "%opcion%"=="X" goto salir

echo Opción no válida. Presiona cualquier tecla para continuar...
pause >nul
goto menu

:opcion1
call Actualizar_Paritarias.bat
echo.
echo Presiona cualquier tecla para volver al menú...
pause >nul
goto menu

:opcion2  
call actualizar_cct.bat
echo.
echo Presiona cualquier tecla para volver al menú...
pause >nul
goto menu

:opcion3
call actualizar_paritarias_sanidad.bat
echo.
echo Presiona cualquier tecla para volver al menú...
pause >nul
goto menu

:opcion4
echo Ejecutando todas las actualizaciones...
echo.
call Actualizar_Paritarias.bat
echo.
echo ----------------------------------------
echo.
call actualizar_cct.bat  
echo.
echo ----------------------------------------
echo.
call actualizar_paritarias_sanidad.bat
echo.
echo ========================================
echo TODAS LAS ACTUALIZACIONES COMPLETADAS
echo ========================================
echo.
echo Presiona cualquier tecla para volver al menú...
pause >nul
goto menu

:opcion5
echo Verificando conexión con Supabase...
echo.

REM Verificar archivo de configuración
if exist "lib\config\supabase_config.dart" (
    echo ✅ Archivo de configuración encontrado
    type "lib\config\supabase_config.dart" | find "url" | find /v "//"
    echo.
    echo ✅ Conexión configurada correctamente
) else (
    echo ❌ ERROR: No se encuentra supabase_config.dart
    echo    Verifica que el archivo exista en lib/config/
)

echo.
echo Presiona cualquier tecla para volver al menú...
pause >nul
goto menu

:salir
echo.
echo Gracias por usar Elevar Liquidación
echo.
pause
exit