#!/usr/bin/env bash
# gpg-sign.sh - Firma (detached) un archivo con gpg (placeholder seguro)
# Uso: sudo bash /opt/ravenguard/scripts/gpg-sign.sh <file> [--key KEYID] [--dry-run]
set -euo pipefail

if [[ "${1:-}" == "" ]]; then
  echo "Uso: $0 <file> [--key KEYID] [--dry-run]"
  exit 2
fi

FILE="$1"
shift

KEY=""
DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key) KEY="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) shift ;;
  esac
done

if [[ ! -f "$FILE" ]]; then
  echo "Archivo no encontrado: $FILE"
  exit 3
fi

if [[ $DRY -eq 1 ]]; then
  echo "[DRY-RUN] gpg --detach-sign -a ${KEY:+--local-user $KEY} $FILE"
  exit 0
fi

if ! command -v gpg >/dev/null 2>&1; then
  echo "gpg no instalado. Instale gnupg para firmar."
  exit 4
fi

if [[ -z "$KEY" ]]; then
  echo "Firmando con la clave por defecto del usuario (detached ASCII)"
  gpg --detach-sign -a "$FILE"
else
  gpg --local-user "$KEY" --detach-sign -a "$FILE"
fi

echo "Firma creada: ${FILE}.asc"