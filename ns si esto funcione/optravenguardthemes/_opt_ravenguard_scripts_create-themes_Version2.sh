#!/usr/bin/env bash
# create-themes.sh - Crea /opt/ravenguard/themes (icon packs y temas) (plantillas)
# Uso: sudo bash /opt/ravenguard/scripts/create-themes.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/themes"
ICONS="$BASE/icons"
GTK="$BASE/gtk"
SCRIPTS="/opt/ravenguard/scripts"

ensure() {
	local d="$1"
	if [[ ! -d "$d" ]]; then
		sudo mkdir -p "$d"
		sudo chown root:root "$d"
		sudo chmod 755 "$d"
	fi
}

write() {
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
	if [[ "$path" == *.sh ]]; then
		sudo chmod 755 "$path"
	else
		sudo chmod 644 "$path"
	fi
	sudo chown root:root "$path"
}

ensure "$BASE"
ensure "$ICONS"
ensure "$GTK"

# placeholder icon (SVG)
write "$ICONS/raven-icon.svg" '<?xml version="1.0" encoding="UTF-8"?>
<svg width="128" height="128" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" role="img">
  <rect width="100%" height="100%" fill="#1e1e2e"/>
  <circle cx="12" cy="12" r="8" fill="#89b4fa"/>
</svg>
'

# index metadata
write "$ICONS/index.json" '{
  "name": "ravenguard-icons",
  "version": "0.1",
  "files": ["raven-icon.svg"],
  "license": "CC0"
}'

# gtk theme placeholder
write "$GTK/gtk-README.md" "# RavenGuard GTK theme (placeholder)\n\nColoque archivos gtk CSS y assets aquí. No aplicar automáticamente sin revisar.\n"

# helper script to install icons to user
write "$SCRIPTS/install-icons.sh" '#!/usr/bin/env bash
# install-icons.sh - Copia iconos RavenGuard a $HOME/.icons (no forzar)
DEST="$HOME/.icons/ravenguard"
mkdir -p "$DEST"
cp -rn /opt/ravenguard/themes/icons/* "$DEST"/ || true
echo "Iconos copiados a $DEST (no sobrescritos si existían)"
'

echo "Themes/icons plantillas creadas en $BASE"