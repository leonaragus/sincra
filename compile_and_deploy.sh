#!/bin/bash
set -e

export FIREBASE_PROJECT_ID="sincra"
export KEY_PATH="/tmp/firebase-key.json"
cd /workspaces/sincra/

echo "🔐 Preparando credenciales..."
# Escribimos el secreto directamente al archivo sin procesar con Python
echo "$FIREBASE_SERVICE_ACCOUNT" > "$KEY_PATH"

echo "🧹 Limpieza..."
flutter clean
flutter pub get

echo "🔨 Compilando (Flutter 3.38)..."
# COMANDO MODIFICADO: Eliminado --base-href "/" para que funcione con setPathUrlStrategy()
flutter build web --release

echo "🔑 Generando token..."
export PATH="$PATH:$HOME/google-cloud-sdk/bin"
# Activamos la cuenta y silenciamos errores de gcloud si ya está instalada
gcloud auth activate-service-account --key-file="$KEY_PATH" --project="$FIREBASE_PROJECT_ID" || true
ACCESS_TOKEN=$(gcloud auth print-access-token)

echo "🚀 Subiendo a Firebase..."
# Usamos npx para ejecutar firebase-tools localmente con el token de acceso
npx firebase-tools deploy --only hosting --project $FIREBASE_PROJECT_ID --token "$ACCESS_TOKEN" --non-interactive

echo "✅ ¡TERMINADO!"
rm -f "$KEY_PATH"
