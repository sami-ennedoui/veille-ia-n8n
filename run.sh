#!/usr/bin/env bash
# Lance n8n en local et importe le workflow de veille IA.
# Fonctionne avec podman (par defaut ici) ou docker.
# Prerequis: la variable HF_TOKEN doit etre exportee dans le shell.
#
# Usage:
#   export HF_TOKEN=hf_xxx
#   ./run.sh up        # demarre n8n et importe le workflow
#   ./run.sh import    # reimporte le workflow seulement
#   ./run.sh down      # arrete et supprime le conteneur
#   ./run.sh logs      # suit les logs

set -euo pipefail

cd "$(dirname "$0")"

ENGINE="${ENGINE:-podman}"
IMAGE="n8nio/n8n:latest"
NAME="veille-ia-n8n"

mkdir -p data n8n-data

ensure_token() {
  if [ -z "${HF_TOKEN:-}" ]; then
    echo "HF_TOKEN n'est pas defini. Exportez le token avant de lancer."
    echo "  export HF_TOKEN=hf_xxx"
    exit 1
  fi
}

start() {
  ensure_token
  echo "Demarrage de n8n avec ${ENGINE}..."
  "${ENGINE}" run -d --name "${NAME}" \
    -p 5678:5678 \
    -e NODE_FUNCTION_ALLOW_BUILTIN=fs \
    -e HF_TOKEN="${HF_TOKEN}" \
    -e GENERIC_TIMEZONE=Europe/Paris \
    -e N8N_DIAGNOSTICS_ENABLED=false \
    -e N8N_PERSONALIZATION_ENABLED=false \
    -v "$(pwd)/n8n-data:/home/node/.n8n:Z" \
    -v "$(pwd)/data:/data:Z" \
    -v "$(pwd)/workflows:/workflows:ro,Z" \
    "${IMAGE}"
  echo "n8n demarre. Interface: http://localhost:5678"
  sleep 8
  import
}

import() {
  echo "Import du workflow..."
  "${ENGINE}" exec "${NAME}" n8n import:workflow --input=/workflows/veille-ia.json
  echo "Workflow importe."
}

case "${1:-up}" in
  up) start ;;
  import) import ;;
  down) "${ENGINE}" rm -f "${NAME}" ;;
  logs) "${ENGINE}" logs -f "${NAME}" ;;
  *) echo "Commande inconnue: ${1}. Utiliser up, import, down ou logs."; exit 1 ;;
esac
