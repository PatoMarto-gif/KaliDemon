#!/usr/bin/env bash
# create-wallpapers.sh - Crea /opt/ravenguard/wallpapers con imagen por defecto (SVG) y metadatos
# Uso: sudo bash /opt/ravenguard/scripts/create-wallpapers.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/wallpapers"
DEFAULT="$BASE/default"
USER_UP="$BASE/user-uploaded"

ensure_dir() {
	local d="$1"
	if [[ ! -d "$d" ]]; then
		sudo mkdir -p "$d"
		sudo chown root:root "$d"
		sudo chmod 755 "$d"
	fi
}

write_file() {
	local path="$1"
	local content="$2"
	if [[ -f "$path" && $FORCE -ne 1 ]]; then
		echo "SKIP: $path (ya existe). Usa --force para sobrescribir."
		return
	fi
	echo "CREANDO $path"
	sudo tee "$path" > /dev/null <<'EOF'
$content
EOF
	sudo chmod 644 "$path"
	sudo chown root:root "$path"
}

ensure_dir "$DEFAULT"
ensure_dir "$USER_UP"

# Raven SVG placeholder (vector image, seguro para crear)
write_file "$DEFAULT/raven-default.svg" '<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Raven">
  <title>RavenGuard - Raven</title>
  <rect width="100%" height="100%" fill="#1e1e2e"/>
  <g fill="#89b4fa" transform="translate(2,2) scale(0.9)">
    <path d="M21 10c0 5-5 8-10 8-1 0-2-.2-3-.6 0 0-2 2-2 4 0 .6-.7 1-1.2.6C3 21 2.4 20 3 19c.6-1 2-3 2-3s-2 .2-3-1c-1.1-1.6 1.6-3.4 4-3.6C7 10.7 8.8 9 12 9c4 0 9 1 9 1z"/>
  </g>
</svg>
'

# thumbnails metadata
write_file "$DEFAULT/thumbnails.json" '{
  "default": "raven-default.svg",
  "items": [
    {
      "file": "raven-default.svg",
      "author": "RavenGuard",
      "license": "CC0",
      "description": "Imagen por defecto del tema Raven (SVG placeholder)"
    }
  ]
}'

# ensure user-uploaded dir exists and is writable by root with safe perms
sudo chown root:root "$USER_UP"
sudo chmod 755 "$USER_UP"

echo "Creado: $DEFAULT/raven-default.svg y $DEFAULT/thumbnails.json"
echo "Directorio user-uploaded listo: $USER_UP"