#!/usr/bin/env bash
# create-configs.sh - Crea la estructura y plantillas en /opt/ravenguard/configs
# Uso: sudo bash /opt/ravenguard/scripts/create-configs.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/configs"
BSPWM="$BASE/bspwm"
POLYBAR="$BASE/polybar"
ROFI="$BASE/rofi"
THEMES="$BASE/themes"
SCRIPTS="$BASE/scripts"

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
'"$content"'
EOF
	# permisos: scripts ejecutables, configs 644
	if [[ "$path" == *.sh ]]; then
		sudo chmod 755 "$path"
	else
		sudo chmod 644 "$path"
	fi
	sudo chown root:root "$path"
}

# Crear estructura
ensure "$BSPWM"
ensure "$POLYBAR/modules"
ensure "$ROFI"
ensure "$THEMES/raven"
ensure "$SCRIPTS"

# bspwmrc (plantilla, NO aplica por defecto)
write "$BSPWM/bspwmrc" '#!/usr/bin/env bash
# bspwmrc - Plantilla RavenGuard (no aplica sin confirmación)
# Recomendación: revisar antes de symlinkear
set -euo pipefail

# Ejemplo mínimo: ejecutar sxhkd
# Añade aquí tus configuraciones de ventanas (usa tabs para indentación)
# No sobrescribe ~/.config/bspwm/bspwmrc sin permiso
'

write "$BSPWM/sxhkdrc" '# sxhkdrc - Hotkeys de ejemplo (plantilla)
# Modifica según preferencias. No aplica automáticamente.
super + Return
	termite
super + w
	bspc node -c
'

write "$BSPWM/README" "Instalación bspwm (plantilla)\n\nPara aplicar los archivos:\n- Revisa $BSPWM/bspwmrc y $BSPWM/sxhkdrc\n- Usa /opt/ravenguard/configs/scripts/apply-configs.sh --bspwm --user para instalar sin sobrescribir\n"

# polybar config y módulos
write "$POLYBAR/config.ini" '[bar/ravenbar]
width = 100%
height = 28
modules-left = raven_workspace raven_active
modules-right = raven_network raven_ai raven_tools

[global]
; Plantilla mínima para Polybar - personalizar antes de aplicar
'

write "$POLYBAR/modules/module-ia.sh" '#!/usr/bin/env bash
# module-ia.sh - módulo Polybar (plantilla)
# Debe devolver texto corto en una línea
echo "AI: idle"
'

write "$POLYBAR/modules/module-network.sh" '#!/usr/bin/env bash
# module-network.sh - módulo Polybar (plantilla)
echo "NET: up"
'

write "$POLYBAR/modules/module-tools.sh" '#!/usr/bin/env bash
# module-tools.sh - estado herramientas (plantilla)
echo "TOOLS: OK"
'

# rofi theme and launcher
write "$ROFI/raven-rofi.rasi" '/* raven-rofi.rasi - Tema Rofi (plantilla) */
configuration {
  font: "monospace 10";
  background: #1e1e2e;
  foreground: #89b4fa;
}
'

write "$ROFI/raven-rofi-menu" '#!/usr/bin/env bash
# raven-rofi-menu - Lanzador simple (plantilla)
CHOICE=$(echo -e "Dashboard\nTutoriales\nHerramientas\nSalir" | rofi -dmenu -p "RavenGuard")
case "$CHOICE" in
	Dashboard) /opt/ravenguard/bin/raven-dashboard start ;;
	Tutoriales) /opt/ravenguard/bin/raven-learn list ;;
	Herramientas) /opt/ravenguard/bin/raven-tools --dry-run list ;;
	*) exit 0 ;;
esac
'

# themes (plantilla)
write "$THEMES/raven/gtk.css" '/* raven theme - plantilla */
.window {
	background: #1e1e2e;
	color: #89b4fa;
}
'

write "$THEMES/raven/install-theme.sh" '#!/usr/bin/env bash
# install-theme.sh - Copia tema Raven al directorio de usuario (no forzar)
DEST="$HOME/.themes/raven"
mkdir -p "$HOME/.themes"
cp -rn "$(dirname "$0")"/* "$DEST"/ || true
echo "Tema instalado en $DEST (no sobrescrito si existía)"
'

# scripts for applying/reverting configs
write "$SCRIPTS/apply-configs.sh" '#!/usr/bin/env bash
# apply-configs.sh - Aplica configs RavenGuard de forma no intrusiva
# Uso: sudo bash apply-configs.sh [--user]
set -euo pipefail

USER=0
if [[ "${1:-}" == "--user" ]]; then
	USER=1
fi

if [[ $USER -eq 1 ]]; then
	TARGET="$HOME/.config"
else
	TARGET="/etc/xdg"
fi

echo "Aplicando configs a $TARGET (copiado, sin sobrescribir)"
if [[ $USER -eq 1 ]]; then
	mkdir -p "$HOME/.config/ravenguard"
	cp -rn /opt/ravenguard/configs/* "$HOME/.config/ravenguard/" || true
else
	sudo mkdir -p /etc/xdg/ravenguard
	sudo cp -rn /opt/ravenguard/configs/* /etc/xdg/ravenguard/ || true
fi
echo "Listo. Revisa antes de reiniciar sesión gráfica."
'

write "$SCRIPTS/revert-configs.sh" '#!/usr/bin/env bash
# revert-configs.sh - Instrucciones para revertir manualmente
echo "Para revertir: eliminar los archivos/symlinks en ~/.config/ravenguard o /etc/xdg/ravenguard según corresponda."
'

echo "Creación completa: /opt/ravenguard/configs y archivos plantilla creados."
echo "Ejecuta para verificar: sudo ls -la /opt/ravenguard/configs"
echo "Para aplicar configs de usuario (no intrusivo): /opt/ravenguard/configs/scripts/apply-configs.sh --user"