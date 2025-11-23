#!/bin/sh
set -e

KEYS_DIR="/app/keys"
mkdir -p "$KEYS_DIR"

if [ ! -f "$KEYS_DIR/private_key.pem" ] || [ ! -f "$KEYS_DIR/public_key.pem" ]; then
  echo "🔑 Génération des clés JWT..."
  openssl genrsa -out "$KEYS_DIR/private_key.pem" 2048
  openssl rsa -in "$KEYS_DIR/private_key.pem" -pubout -out "$KEYS_DIR/public_key.pem"
  chmod 600 "$KEYS_DIR/private_key.pem"
  chmod 644 "$KEYS_DIR/public_key.pem"
fi

echo "🚀 Démarrage de l'API..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000