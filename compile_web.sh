#!/bin/bash

echo "🚀 Iniciando compilación Flutter Web en Codespace"

# Configurar Flutter para web
flutter config --enable-web

# Limpiar cache y reinstalar dependencias
echo "🧹 Limpiando cache..."
flutter clean

# Forzar reinstalación de dependencias (evita problemas de RAM)
echo "📦 Reinstalando dependencias..."
flutter pub get --force

# Compilar para web (release mode)
echo "🔨 Compilando versión web release..."
flutter build web --release --no-pub

echo "✅ Compilación completada exitosamente!"
echo "📁 Los archivos están en: build/web/"
echo "🌐 Para probar localmente: flutter run -d web-server --web-port 5000"

# Mostrar información del build
ls -la build/web/ | head -10

echo "🚀 Iniciando deploy automático a Firebase..."

# Verificar si Firebase CLI está instalado
if ! command -v firebase &> /dev/null; then
    echo "📦 Instalando Firebase CLI..."
    npm install -g firebase-tools
fi

# Verificar si estamos logueados en Firebase
if ! firebase projects:list &> /dev/null; then
    echo "🔐 Iniciando sesión en Firebase..."
    echo "Por favor, abre la URL que aparece y autoriza el acceso:"
    firebase login --no-localhost
else
    echo "✅ Ya estás logueado en Firebase"
fi

# Hacer deploy a Firebase Hosting
echo "🌐 Haciendo deploy a Firebase Hosting..."
firebase deploy --only hosting --token "$FIREBASE_TOKEN" --project "sincra"

echo "🎉 DEPLOY COMPLETADO EXITOSAMENTE!"
echo "🌐 Tu app está disponible en: https://sincra.web.app"