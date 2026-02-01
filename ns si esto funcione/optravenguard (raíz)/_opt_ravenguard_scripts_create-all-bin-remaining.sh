#!/usr/bin/env bash
# create-all-bin-remaining.sh - Crea los scripts restantes en /opt/ravenguard/bin
# Uso: sudo bash create-all-bin-remaining.sh [--force]
# NOTA: scripts son plantillas seguras, no realizan cambios irreversibles sin confirmación.
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard"
BIN="$BASE/bin"
SCRIPTS_DIR="$BASE/scripts"
DB="$BASE/tools-database/index.json"

ensure_dir() {
	local d="$1"
	if [[ ! -d "$d" ]]; then
		sudo mkdir -p "$d"
		sudo chown root:root "$d"
		sudo chmod 755 "$d"
	fi
}

write_if_needed() {
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
	sudo chmod 755 "$path"
	sudo chown root:root "$path"
}

ensure_dir "$BASE"
ensure_dir "$BIN"
ensure_dir "$SCRIPTS_DIR"

##### raven-install (bootstrap installer seguro) #####
RAVEN_INSTALL='#!/usr/bin/env bash
# raven-install - Instalador bootstrap de RavenGuard (modo seguro)
# Opciones: --dry-run, --mode [recommended|full], --yes
set -euo pipefail

DRY_RUN=0
MODE="recommended"
YES=0

usage() {
	echo "Uso: $0 [--dry-run] [--mode recommended|full] [--yes]"
	echo "	--mode recommended: instala solo componentes esenciales (recomendado para principiantes)"
	echo "	--mode full: instala extras (puede tardar y usar mucho espacio)"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) DRY_RUN=1; shift ;;
		--mode) MODE="$2"; shift 2 ;;
		--yes) YES=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) break ;;
	esac
done

check_requirements() {
	echo "Comprobando requisitos..."
	if [[ -f /etc/os-release ]]; then
		. /etc/os-release
		echo "Detectado OS: ${PRETTY_NAME:-unknown}"
	fi
	# Espacio mínimo sugerido
	avail=$(df --output=avail -k /opt | tail -1 || echo "0")
	if [[ "$avail" -lt 20000000 ]]; then
		echo "Advertencia: menos de ~20GB disponibles en /opt (disponible: ${avail}K)"
	fi
}

do_install() {
	echo "Modo: $MODE"
	if [[ $DRY_RUN -eq 1 ]]; then
		echo "[DRY-RUN] Se crearían /opt/ravenguard y estructura básica"
		echo "[DRY-RUN] Se instalarían paquetes esenciales (ej: python3, curl) si faltan"
		return 0
	fi

	# Crear estructura mínima
	sudo mkdir -p /opt/ravenguard/{bin,tools-database,configs,learning,ai-modules,wallpapers,dashboard,scripts}
	sudo chown root:root /opt/ravenguard
	sudo chmod 755 /opt/ravenguard

	# Paquetes mínimos sugeridos
	if ! command -v python3 >/dev/null 2>&1; then
		echo "Instalando python3 (requerido)..."
		sudo apt-get update
		sudo apt-get install -y python3
	fi
	if ! command -v curl >/dev/null 2>&1; then
		echo "Instalando curl..."
		sudo apt-get install -y curl
	fi

	echo "Instalación bootstrap completada."
}

if [[ $DRY_RUN -eq 1 ]]; then
	check_requirements
	do_install
else
	if [[ $YES -ne 1 ]]; then
		read -p "Continuar con la instalación bootstrap de RavenGuard? [y/N] " ans
		case "$ans" in [Yy]*) ;; *) echo "Cancelado"; exit 1 ;; esac
	fi
	check_requirements
	do_install
fi
'

##### raven-update (actualiza índice y sugiere actualizaciones) #####
RAVEN_UPDATE='#!/usr/bin/env bash
# raven-update - Actualizador de índice y sugerencias de actualización
# Uso: raven-update [--dry-run] [--index-only]
set -euo pipefail

DRY_RUN=0
INDEX_ONLY=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) DRY_RUN=1; shift ;;
		--index-only) INDEX_ONLY=1; shift ;;
		-h|--help) echo "Uso: $0 [--dry-run] [--index-only]"; exit 0 ;;
		*) break ;;
	esac
done

update_index() {
	echo "Actualizando índice local (plantilla)..."
	if [[ $DRY_RUN -eq 1 ]]; then
		echo "[DRY-RUN] git pull o consulta remota para index.json"
		return 0
	fi
	# Placeholder: no accesos remotos por defecto
	echo "No hay index remoto configurado. Para agregar un remoto, coloque un script en /opt/ravenguard/scripts/"
}

update_packages() {
	echo "Revisando paquetes instalados (plantilla)..."
	if [[ $DRY_RUN -eq 1 ]]; then
		echo "[DRY-RUN] apt-get update && apt-get --just-print upgrade"
		return 0
	fi
	echo "Para evitar cambios automáticos, ejecute: sudo apt-get update && sudo apt-get upgrade -y"
}

update_index
if [[ $INDEX_ONLY -eq 0 ]]; then
	update_packages
fi
'

##### raven-uninstall (elimina RavenGuard bajo /opt con confirmación) #####
RAVEN_UNINSTALL='#!/usr/bin/env bash
# raven-uninstall - Elimina /opt/ravenguard (con confirmación)
set -euo pipefail

usage() {
	echo "Uso: $0 --yes  (requerido para proceder)"
	echo "Esto eliminará todos los archivos bajo /opt/ravenguard."
}

if [[ "${1:-}" != "--yes" ]]; then
	usage
	exit 2
fi

echo "Se eliminará /opt/ravenguard. Esto es irreversible."
read -p "¿Estás seguro? Escribe DELETE para confirmar: " conf
if [[ "$conf" != "DELETE" ]]; then
	echo "Confirmación no recibida. Abortando."
	exit 3
fi

sudo rm -rf /opt/ravenguard
echo "Eliminado /opt/ravenguard"
'

##### raven-config (gestiona symlinks de configs de manera no intrusiva) #####
RAVEN_CONFIG='#!/usr/bin/env bash
# raven-config - Aplicar o quitar configuraciones RavenGuard (symlinks seguros)
# Uso: raven-config [apply|revert] [--user]
set -euo pipefail

USER_MODE=0
if [[ "${1:-}" == "--user" ]]; then
	USER_MODE=1
	shift
fi

cmd="${1:-apply}"

apply() {
	target_dir="${HOME}/.config/ravenguard"
	if [[ $USER_MODE -eq 1 ]]; then
		echo "Modo usuario: instalando configs en $target_dir"
	else
		target_dir="/etc/xdg/ravenguard"
		echo "Modo system-wide: instalando configs en $target_dir (necesita sudo)"
	fi

	if [[ "$USER_MODE" -eq 1 ]]; then
		mkdir -p "$target_dir"
		cp -rn /opt/ravenguard/configs/* "$target_dir"/ 2>/dev/null || true
		echo "Configs copiados a $target_dir (no se sobrescribieron archivos existentes)"
	else
		sudo mkdir -p "$target_dir"
		sudo cp -rn /opt/ravenguard/configs/* "$target_dir"/ 2>/dev/null || true
		echo "Configs copiados a $target_dir (no se sobrescribieron archivos existentes)"
	fi
}

revert() {
	echo "Revert no implementado completamente. Manual: eliminar symlinks desde \$HOME/.config o /etc/xdg."
}

case "$cmd" in
	apply) apply ;;
	revert) revert ;;
	*) echo "Comando desconocido: $cmd"; exit 2 ;;
esac
'

##### raven-theme (aplica tema Raven sin forzar) #####
RAVEN_THEME='#!/usr/bin/env bash
# raven-theme - Aplicar tema Raven (plantilla)
# Uso: raven-theme apply [--user] [--dry-run]
set -euo pipefail

DRY_RUN=0
USER_MODE=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) DRY_RUN=1; shift ;;
		--user) USER_MODE=1; shift ;;
		apply) CMD="apply"; shift ;;
		*) break ;;
	esac
done

apply() {
	src="/opt/ravenguard/configs/themes/raven"
	if [[ ! -d "$src" ]]; then
		echo "Tema no encontrado en $src"
		return 1
	fi
	if [[ $DRY_RUN -eq 1 ]]; then
		echo "[DRY-RUN] Se copiaría $src a la ubicación de temas del usuario/system"
		return 0
	fi
	if [[ $USER_MODE -eq 1 ]]; then
		dest="$HOME/.themes/raven"
		mkdir -p "$HOME/.themes"
		cp -rn "$src" "$dest"
		echo "Tema copiado a $dest (no sobrescrito)"
	else
		sudo mkdir -p /usr/share/themes
		sudo cp -rn "$src" /usr/share/themes/
		echo "Tema copiado a /usr/share/themes (no sobrescrito)"
	fi
}

apply
'

##### raven-wallpaper (sube wallpaper a user-uploaded con checks) #####
RAVEN_WALLPAPER='#!/usr/bin/env bash
# raven-wallpaper - Subir wallpaper a /opt/ravenguard/wallpapers/user-uploaded
# Uso: raven-wallpaper add <ruta-al-archivo> [--user <usuario>]
set -euo pipefail

if [[ "${1:-}" != "add" || -z "${2:-}" ]]; then
	echo "Uso: $0 add <ruta-al-archivo> [--user <usuario>]"
	exit 2
fi

SRC="$2"
shift 2

if [[ ! -f "$SRC" ]]; then
	echo "Archivo no encontrado: $SRC"
	exit 2
fi

TARGET_DIR="/opt/ravenguard/wallpapers/user-uploaded"
sudo mkdir -p "$TARGET_DIR"
sudo chown root:root "$TARGET_DIR"
sudo chmod 755 "$TARGET_DIR"

BNAME=$(basename "$SRC")
# Comprobación de tamaño (limitar a 50MB por defecto)
SIZE=$(stat -c%s "$SRC")
if [[ "$SIZE" -gt 52428800 ]]; then
	echo "Archivo demasiado grande (>50MB). Abortando."
	exit 3
fi

sudo cp -n "$SRC" "$TARGET_DIR/$BNAME" || { echo "No se sobrescribió (ya existe)"; }
echo "Wallpaper subido a $TARGET_DIR/$BNAME (si no existía)"
'

##### raven-service (gestiona dashboard/ai de forma segura) #####
RAVEN_SERVICE='#!/usr/bin/env bash
# raven-service - Gestiona servicios RavenGuard (plantilla, no habilita servicios por defecto)
# Uso: raven-service <dashboard|ai> [start|stop|status]
set -euo pipefail

if [[ $# -lt 2 ]]; then
	echo "Uso: $0 <dashboard|ai> <start|stop|status>"
	exit 2
fi

svc="$1"
act="$2"

case "$svc" in
	dashboard)
		case "$act" in
			start)
				echo "Iniciando dashboard en foreground (usa --background en implementación real)"
				/opt/ravenguard/bin/raven-dashboard start
				;;
			stop)
				echo "Stop: detén procesos manualmente (pkill -f http.server) o reinicia sesión"
				;;
			status)
				echo "Estado: use netstat/ss para comprobar puerto 8080 (plantilla)"
				;;
		esac
		;;
	ai)
		case "$act" in
			start) echo "raven-ai start (plantilla)"; /opt/ravenguard/bin/raven-ai start ;;
			stop) echo "raven-ai stop (plantilla)"; /opt/ravenguard/bin/raven-ai stop ;;
			status) /opt/ravenguard/bin/raven-ai status ;;
		esac
		;;
	*) echo "Servicio desconocido: $svc"; exit 2 ;;
esac
'

##### raven-help (listado de ayudas y comandos) #####
RAVEN_HELP='#!/usr/bin/env bash
# raven-help - Ayuda consolidada RavenGuard
echo "RavenGuard - comandos disponibles en /opt/ravenguard/bin:"
echo "  raven-install   - Instalador bootstrap (sudo)"
echo "  raven-update    - Actualizador de índice/sugerencias"
echo "  raven-uninstall - Eliminar /opt/ravenguard (USE WITH CAUTION)"
echo "  raven-config    - Aplicar configs (user/system)"
echo "  raven-theme     - Aplicar tema Raven"
echo "  raven-wallpaper - Subir wallpaper"
echo "  raven-service   - Gestionar dashboard/ai (plantilla)"
echo "  raven-tools     - Gestor de herramientas (index.json)"
echo "  raven-joke      - Generador de chistes (script)"
echo "  raven-learn     - Acceso a tutoriales"
echo "  raven-dashboard - Servir dashboard en localhost"
echo ""
echo "Ejemplo: /opt/ravenguard/bin/raven-tools --dry-run list"
'

# Escribir los archivos en /opt/ravenguard/bin
write_if_needed "$BIN/raven-install" "$RAVEN_INSTALL"
write_if_needed "$BIN/raven-update" "$RAVEN_UPDATE"
write_if_needed "$BIN/raven-uninstall" "$RAVEN_UNINSTALL"
write_if_needed "$BIN/raven-config" "$RAVEN_CONFIG"
write_if_needed "$BIN/raven-theme" "$RAVEN_THEME"
write_if_needed "$BIN/raven-wallpaper" "$RAVEN_WALLPAPER"
write_if_needed "$BIN/raven-service" "$RAVEN_SERVICE"
write_if_needed "$BIN/raven-help" "$RAVEN_HELP"

echo "Archivos creados en $BIN (uso --force para sobrescribir existentes)."
echo "Ejecuta: sudo $BIN/health-check   para verificar presencia de binarios."