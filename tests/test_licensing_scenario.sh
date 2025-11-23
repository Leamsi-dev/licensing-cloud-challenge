#!/bin/bash

set -e  # Arrête à la première erreur

# === Configuration ===
BASE_URL="http://localhost:8000"
TENANT_ID="acme-test"
MAX_APPS=2
MAX_EXEC=5  # Réduit à 5 pour le test rapide (au lieu de 100)

TOKEN=""
APP1="app-alpha"
APP2="app-beta"
APP3="app-gamma"

echo "🚀 Démarrage du scénario de test Licensing Cloud Challenge"
echo "⏳ Vérification que l'API est prête..."

# Attente que l'API soit prête (max 30s)
RETRY=0
until curl -s "$BASE_URL" >/dev/null || [ $RETRY -eq 30 ]; do
  sleep 1
  RETRY=$((RETRY+1))
  echo -n "."
done

if [ $RETRY -eq 30 ]; then
  echo "❌ API non disponible après 30s"
  exit 1
fi

echo -e "\n✅ API prête !"

# === ÉTAPE 1 : Créer une licence ===
echo -e "\n--- ÉTAPE 1 : Création de la licence ---"
LICENSE_BODY=$(cat <<EOF
{
  "tenant_id": "$TENANT_ID",
  "max_apps": $MAX_APPS,
  "max_executions_per_24h": $MAX_EXEC,
  "valid_from": "2025-11-01T00:00:00Z",
  "valid_to": "2025-12-01T00:00:00Z"
}
EOF
)

RESPONSE=$(curl -s -X POST "$BASE_URL/v1/licenses" \
  -H "Content-Type: application/json" \
  -d "$LICENSE_BODY")

TOKEN=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")

if [ -z "$TOKEN" ]; then
  echo "❌ Échec création licence"
  echo "$RESPONSE"
  exit 1
fi

echo "✅ Licence créée avec token : ${TOKEN:0:32}..."

# === ÉTAPE 2 : Enregistrer apps ===
echo -e "\n--- ÉTAPE 2 : Enregistrement des applications ---"

# App 1
RESP1=$(curl -s -X POST "$BASE_URL/v1/apps/register" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"app_name\": \"$APP1\"}")

if echo "$RESP1" | grep -q '"success":true'; then
  echo "✅ Application '$APP1' enregistrée"
else
  echo "❌ Échec enregistrement '$APP1'"
  echo "$RESP1"
  exit 1
fi

# App 2
RESP2=$(curl -s -X POST "$BASE_URL/v1/apps/register" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"app_name\": \"$APP2\"}")

if echo "$RESP2" | grep -q '"success":true'; then
  echo "✅ Application '$APP2' enregistrée"
else
  echo "❌ Échec enregistrement '$APP2'"
  echo "$RESP2"
  exit 1
fi

# App 3 → doit échouer
RESP3=$(curl -s -X POST "$BASE_URL/v1/apps/register" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"app_name\": \"$APP3\"}")

if echo "$RESP3" | grep -q '"success":false' && echo "$RESP3" | grep -q "Max apps"; then
  echo "✅ Refus correct de la 3ᵉ application (limite $MAX_APPS atteinte)"
else
  echo "❌ La 3ᵉ application aurait dû être refusée !"
  echo "$RESP3"
  exit 1
fi

# === ÉTAPE 3 : Exécutions (jobs) ===
echo -e "\n--- ÉTAPE 3 : Lancement des jobs ---"

# Lancer MAX_EXEC jobs autorisés
for i in $(seq 1 $MAX_EXEC); do
  JOB_RESP=$(curl -s -X POST "$BASE_URL/v1/jobs/start" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"app_name\": \"$APP1\"}")
  
  if echo "$JOB_RESP" | grep -q '"success":true'; then
    echo "✅ Job $i/$MAX_EXEC lancé"
  else
    echo "❌ Échec au job $i"
    echo "$JOB_RESP"
    exit 1
  fi
done

# Job MAX_EXEC+1 → doit échouer
OVER_JOB=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/v1/jobs/start" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"app_name\": \"$APP1\"}")

HTTP_CODE="${OVER_JOB: -3}"
JOB_BODY="${OVER_JOB%???}"

if [ "$HTTP_CODE" = "429" ]; then
  echo "✅ Refus correct du job $((MAX_EXEC+1)) (quota 24h atteint)"
else
  echo "❌ Le job $((MAX_EXEC+1)) aurait dû être refusé avec code 429 !"
  echo "Code reçu : $HTTP_CODE"
  echo "Réponse : $JOB_BODY"
  exit 1
fi

# === ÉTAPE 4 : Tests de sécurité ===
echo -e "\n--- ÉTAPE 4 : Tests de sécurité ---"

# Mauvais token
BAD_TOKEN_RESP=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/v1/apps/register" \
  -H "Authorization: Bearer mauvais.token.here" \
  -H "Content-Type: application/json" \
  -d "{\"app_name\": \"test\"}")

BAD_HTTP="${BAD_TOKEN_RESP: -3}"
if [ "$BAD_HTTP" = "401" ]; then
  echo "✅ Mauvais token correctement rejeté (401)"
else
  echo "❌ Mauvais token n'a pas été rejeté !"
  exit 1
fi

# Licence expirée
EXPIRED_LICENSE=$(curl -s -X POST "$BASE_URL/v1/licenses" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "expired-test",
    "max_apps": 1,
    "max_executions_per_24h": 5,
    "valid_from": "2024-01-01T00:00:00Z",
    "valid_to": "2024-01-02T00:00:00Z"
  }')

EXPIRED_TOKEN=$(echo "$EXPIRED_LICENSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', ''))")

if [ -n "$EXPIRED_TOKEN" ]; then
  EXPIRED_RESP=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/v1/apps/register" \
    -H "Authorization: Bearer $EXPIRED_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"app_name": "test-expired"}')
  
  EXPIRED_HTTP="${EXPIRED_RESP: -3}"
  if [ "$EXPIRED_HTTP" = "403" ]; then
    echo "✅ Licence expirée correctement bloquée (403)"
  else
    echo "❌ Licence expirée n'a pas été bloquée !"
    exit 1
  fi
else
  echo "❌ Impossible de créer une licence expirée pour le test"
  exit 1
fi

# === FIN ===
echo -e "\n🎉 Tous les tests ont réussi !"
echo "✅ Le système Licensing Cloud fonctionne conformément aux exigences."
echo
echo "Résumé :"
echo "- Licence créée avec quotas maxApps=$MAX_APPS, maxExecutionsPer24h=$MAX_EXEC"
echo "- Applications : 2 acceptées, 1 refusée (limite respectée)"
echo "- Jobs : $MAX_EXEC acceptés, 1 refusé (quota 24h respecté)"
echo "- Sécurité : tokens invalides et licences expirées bloquées"