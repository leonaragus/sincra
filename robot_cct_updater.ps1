# ========================================
# ROBOT CCT UPDATER - PowerShell Script
# ========================================

# Colores
$Host.UI.RawUI.ForegroundColor = "Green"

Write-Host ""
Write-Host "Iniciando actualización de CCT..." -ForegroundColor Cyan
Write-Host ""

# Leer configuración de Supabase
$configPath = ".\lib\config\supabase_config.dart"

if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] No se encontró supabase_config.dart" -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifica que el archivo existe en lib/config/" -ForegroundColor Yellow
    exit 1
}

# Extraer URL y ANON_KEY del archivo Dart
$configContent = Get-Content $configPath -Raw
$urlMatch = $configContent -match "url\s*=\s*['\"]([^'\"]+)['\"]"
$keyMatch = $configContent -match "anonKey\s*=\s*['\"]([^'\"]+)['\"]"

if (-not $urlMatch -or -not $keyMatch) {
    Write-Host "[ERROR] No se pudo leer la configuración de Supabase" -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifica que supabase_config.dart tenga url y anonKey" -ForegroundColor Yellow
    exit 1
}

$supabaseUrl = $Matches[1]
$supabaseKey = $Matches[1]

# Re-extraer correctamente
$urlMatch = [regex]::Match($configContent, "url\s*=\s*['\"]([^'\"]+)['\"]")
$keyMatch = [regex]::Match($configContent, "anonKey\s*=\s*['\"]([^'\"]+)['\"]")

$supabaseUrl = $urlMatch.Groups[1].Value
$supabaseKey = $keyMatch.Groups[1].Value

Write-Host "✓ Configuración cargada" -ForegroundColor Green
Write-Host "  URL: $supabaseUrl" -ForegroundColor Gray
Write-Host ""

# Leer archivo JSON
$jsonPath = ".\convenios_update.json"
$jsonData = Get-Content $jsonPath -Raw | ConvertFrom-Json

$updateDate = Get-Date -Format "yyyy-MM-dd"
$totalCCT = $jsonData.updates.Count
$processed = 0
$exitosa = $true

Write-Host "Procesando $totalCCT CCT..." -ForegroundColor Cyan
Write-Host ""

foreach ($update in $jsonData.updates) {
    $processed++
    $cctCodigo = $update.cct_codigo
    $version = $update.version
    
    Write-Host "[$processed/$totalCCT] Actualizando CCT $cctCodigo (v$version)..." -ForegroundColor White
    
    # Insertar en cct_actualizaciones
    $body = @{
        cct_codigo = $cctCodigo
        version = $version
        fecha_vigencia = $update.fecha_vigencia
        cambios = ($update.cambios | ConvertTo-Json -Compress)
    } | ConvertTo-Json
    
    try {
        $headers = @{
            "apikey" = $supabaseKey
            "Authorization" = "Bearer $supabaseKey"
            "Content-Type" = "application/json"
            "Prefer" = "return=minimal"
        }
        
        $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/cct_actualizaciones" `
                                      -Method Post `
                                      -Headers $headers `
                                      -Body $body `
                                      -ErrorAction Stop
        
        Write-Host "  ✓ Actualizado" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        $exitosa = $false
    }
    
    Write-Host ""
}

# Registrar ejecución
Write-Host "Registrando ejecución..." -ForegroundColor Cyan

$execBody = @{
    exitosa = $exitosa
    cct_procesados = $processed
} | ConvertTo-Json

try {
    $headers = @{
        "apikey" = $supabaseKey
        "Authorization" = "Bearer $supabaseKey"
        "Content-Type" = "application/json"
        "Prefer" = "return=minimal"
    }
    
    $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/cct_robot_ejecuciones" `
                                  -Method Post `
                                  -Headers $headers `
                                  -Body $execBody `
                                  -ErrorAction Stop
    
    Write-Host "✓ Ejecución registrada" -ForegroundColor Green
}
catch {
    Write-Host "✗ No se pudo registrar la ejecución" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RESUMEN" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Total procesados: $processed" -ForegroundColor White
Write-Host "  Estado: $(if ($exitosa) { 'EXITOSA' } else { 'CON ERRORES' })" -ForegroundColor $(if ($exitosa) { 'Green' } else { 'Red' })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $exitosa) {
    exit 1
}
