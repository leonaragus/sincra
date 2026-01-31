@echo off
chcp 65001 >nul
title Actualizar CCT - Elevar Liquidación
color 0A

echo ========================================
echo    ROBOT CCT - ACTUALIZADOR AUTOMÁTICO
echo ========================================
echo.
echo Este script actualiza los CCT en Supabase
echo desde el archivo convenios_update.json
echo.
echo ========================================
echo.

REM Verificar si existe el archivo JSON
if not exist "convenios_update.json" (
    color 0C
    echo [ERROR] No se encontró convenios_update.json
    echo.
    echo Crea el archivo siguiendo el template:
    echo convenios_update_template.json
    echo.
    pause
    exit /b 1
)

echo [1/4] Verificando archivo JSON...
echo ✓ Archivo encontrado
echo.

echo [2/4] Validando formato JSON...
REM Intenta cargar el JSON con PowerShell
powershell -Command "try { Get-Content 'convenios_update.json' | ConvertFrom-Json | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1

if errorlevel 1 (
    color 0C
    echo [ERROR] El archivo JSON tiene errores de formato
    echo.
    echo Verifica la sintaxis en convenios_update.json
    echo.
    pause
    exit /b 1
)

echo ✓ JSON válido
echo.

echo [3/4] Conectando a Supabase...
echo.

REM Ejecutar el script de actualización usando PowerShell y la API de Supabase
powershell -ExecutionPolicy Bypass -File "%~dp0robot_cct_updater.ps1"

if errorlevel 1 (
    color 0C
    echo.
    echo [ERROR] Fallo en la actualización
    echo.
    pause
    exit /b 1
)

echo.
echo [4/4] Actualización completada
echo.
color 0A
echo ========================================
echo          ✓ CCT ACTUALIZADOS
echo ========================================
echo.
echo Los cambios ya están disponibles en la app
echo.
pause
