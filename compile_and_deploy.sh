#!/bin/bash

echo "🚀 INICIANDO COMPILACIÓN Y DEPLOY AUTOMÁTICO EN CODESPACES"
echo "============================================================"

# Cargar configuración automática si existe
if [ -f ".env.codespaces" ]; then
    echo "📋 Cargando configuración automática..."
    source .env.codespaces
    echo "✅ Configuración cargada desde .env.codespaces"
fi

# Configurar variables
echo "🎯 Configurando entorno con token..."
export FIREBASE_PROJECT_ID="sincra"

# Configurar Flutter para web
echo "🔧 Configurando Flutter Web..."
flutter config --enable-web

# Limpiar cache completamente
echo "🧹 Limpiando cache..."
flutter clean

# Instalar dependencias (forzado para evitar problemas)
echo "📦 Instalando dependencias..."
flutter pub get --force

# Compilar versión web release (sin resolución de dependencias)
echo "🔨 Compilando versión web release..."
flutter build web --release --no-pub

# Verificar que la compilación fue exitosa
if [ -d "build/web" ]; then
    echo "✅ Compilación EXITOSA!"
    
    # Configurar Firebase CLI
    echo "🔥 Configurando Firebase..."
    npm install -g firebase-tools
    
    # Usar el token directamente para autenticación
    echo "🔐 Autenticando con Firebase usando token..."
    echo "$FIREBASE_SERVICE_ACCOUNT" > /tmp/firebase-token.json
    
    # Hacer deploy DIRECTAMENTE con el token
    echo "🚀 Haciendo deploy DIRECTAMENTE a Firebase..."
    firebase deploy --only hosting --project $FIREBASE_PROJECT_ID --token "$(cat /tmp/firebase-token.json)"
    
    # Limpiar archivo temporal
    rm -f /tmp/firebase-token.json
    
    echo "🎉 DEPLOY COMPLETADO EXITOSAMENTE!"
    echo "🔗 Tu aplicación está disponible en: https://$FIREBASE_PROJECT_ID.web.app"
    echo "🌐 También en: https://$FIREBASE_PROJECT_ID.firebaseapp.com"
    
else
    echo "❌ ERROR: La compilación falló"
    exit 1
fi

echo ""
echo "✨ PROCESO COMPLETADO!"
echo "📋 Revisa Firebase Console: https://console.firebase.google.com/project/sincra/hosting"
echo "🕐 Tiempo estimado: 2-3 minutos después de abrir Codespaces"