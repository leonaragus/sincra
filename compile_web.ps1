# PowerShell script para compilación Flutter Web y deploy a Firebase

Write-Host "🚀 Iniciando compilación Flutter Web" -ForegroundColor Green

# Configurar Flutter para web
flutter config --enable-web

# Limpiar cache y reinstalar dependencias
Write-Host "🧹 Limpiando cache..." -ForegroundColor Yellow
flutter clean

# Forzar reinstalación de dependencias
Write-Host "📦 Reinstalando dependencias..." -ForegroundColor Yellow
flutter pub get

# Compilar para web (release mode)
Write-Host "🔨 Compilando versión web release..." -ForegroundColor Yellow
flutter build web --release --no-pub --pwa-strategy=none

Write-Host "✅ Compilación completada exitosamente!" -ForegroundColor Green
Write-Host "📁 Los archivos están en: build/web/" -ForegroundColor Cyan
Write-Host "🌐 Para probar localmente: flutter run -d web-server --web-port 5000" -ForegroundColor Cyan

# Mostrar información del build
Write-Host "📊 Contenido del directorio build/web/:" -ForegroundColor Yellow
Get-ChildItem build/web/ | Select-Object -First 10

Write-Host "🚀 Iniciando deploy automático a Firebase..." -ForegroundColor Green

# Verificar si Firebase CLI está instalado
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Instalando Firebase CLI..." -ForegroundColor Yellow
    npm install -g firebase-tools
}

# Verificar si estamos logueados en Firebase
try {
    firebase projects:list 2>$null
    Write-Host "✅ Ya estás logueado en Firebase" -ForegroundColor Green
} catch {
    Write-Host "🔐 Iniciando sesión en Firebase..." -ForegroundColor Yellow
    Write-Host "Por favor, abre la URL que aparece y autoriza el acceso:" -ForegroundColor Yellow
    firebase login --no-localhost
}

# Hacer deploy a Firebase Hosting
Write-Host "🌐 Haciendo deploy a Firebase Hosting..." -ForegroundColor Green

if ($env:FIREBASE_SERVICE_ACCOUNT) {
    $env:FIREBASE_SERVICE_ACCOUNT | Out-File -FilePath "$env:TEMP\firebase-sa.json" -Encoding utf8
    $env:GOOGLE_APPLICATION_CREDENTIALS = "$env:TEMP\firebase-sa.json"
    firebase deploy --only hosting --project "sincra"
    Remove-Item "$env:TEMP\firebase-sa.json" -ErrorAction SilentlyContinue
} elseif ($env:FIREBASE_TOKEN) {
    firebase deploy --only hosting --token $env:FIREBASE_TOKEN --project "sincra"
} else {
    Write-Host "❌ ERROR: No se encontró FIREBASE_SERVICE_ACCOUNT ni FIREBASE_TOKEN." -ForegroundColor Red
    Write-Host "💡 Configura las variables de entorno o usa 'firebase login'" -ForegroundColor Yellow
    exit 1
}

Write-Host "🎉 Deploy completado exitosamente!" -ForegroundColor Green