Write-Host "🚀 Iniciando compilación Flutter Web en Windows" -ForegroundColor Green

# Configurar Flutter para web
flutter config --enable-web

# Limpiar cache y reinstalar dependencias
Write-Host "🧹 Limpiando cache..." -ForegroundColor Yellow
flutter clean

# Forzar reinstalación de dependencias (evita problemas de RAM)
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