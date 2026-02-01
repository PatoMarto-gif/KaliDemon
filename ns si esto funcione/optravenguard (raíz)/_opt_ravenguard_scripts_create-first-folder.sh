#!/usr/bin/env bash
# create-first-folder.sh
# Crea/actualiza el contenido inicial de /opt/ravenguard/bin y un índice mínimo en /opt/ravenguard/tools-database
# Uso: sudo bash create-first-folder.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard"
BIN="$BASE/bin"
DB="$BASE/tools-database"
DASH="$BASE/dashboard/www"
SCRIPTS_DIR="$BASE/scripts"

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

# Crear estructura
ensure_dir "$BASE"
ensure_dir "$BIN"
ensure_dir "$DB"
ensure_dir "$DASH"
ensure_dir "$SCRIPTS_DIR"

##### raven-tools (lee tools-database/index.json y soporta --dry-run, install/list) #####
RAVEN_TOOLS='#!/usr/bin/env bash
# raven-tools - Gestor básico de herramientas RavenGuard (plantilla funcional)
# Version: 0.2
set -euo pipefail

DB="/opt/ravenguard/tools-database/index.json"
DRY_RUN=0
YES=0

usage() {
	echo "Uso: $0 [--dry-run] [--yes] <comando>"
	echo "Comandos:"
	echo -e "\tlist\t\tListar herramientas del índice"
	echo -e "\tinfo <id>\tMostrar metadata de herramienta"
	echo -e "\tinstall <id>\tInstalar herramienta por id (usa package_manager)"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) DRY_RUN=1; shift ;;
		--yes) YES=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) break ;;
	esac
done

cmd=${1:-}
shift || true

# Dependencia: usamos python3 para parsear el JSON (evita jq como dependencia)
json_get() {
	python3 - <<PY
import json,sys
try:
	with open("$DB","r",encoding="utf-8") as f:
		data=json.load(f)
except Exception as e:
	print("ERROR: no se pudo leer $DB:", e,file=sys.stderr); sys.exit(2)
args=sys.argv[1:]
if args[0]=="list":
	for t in data.get("tools",[]):
		print(f"{t.get(\"id\",\"?\")}\t{t.get(\"name\",\"?\")}\t{t.get(\"package_manager\",\"?\")}")
elif args[0]=="info":
	id=args[1]
	for t in data.get("tools",[]):
		if t.get("id")==id:
			print(json.dumps(t,ensure_ascii=False,indent=2))
			sys.exit(0)
	sys.exit(3)
PY
}

do_list() {
	if [[ ! -f "$DB" ]]; then
		echo "Índice no encontrado: $DB"
		return 1
	fi
	json_get list
}

do_info() {
	if [[ -z "${1:-}" ]]; then echo "Falta id"; return 2; fi
	json_get info "$1" || { echo "No se encontró herramienta $1"; return 3; }
}

do_install() {
	local id="$1"
	if [[ -z "$id" ]]; then echo "Falta id"; return 2; fi
	if [[ ! -f "$DB" ]]; then echo "Índice no encontrado: $DB"; return 1; fi

	# Extraer metadata con python para seguridad
	python3 - <<PY
import json,sys,subprocess
with open("$DB","r",encoding="utf-8") as f:
	data=json.load(f)
tool=None
for t in data.get("tools",[]):
	if t.get("id")==sys.argv[1]:
		tool=t
		break
if not tool:
	print("NOTFOUND")
	sys.exit(3)
pm=tool.get("package_manager","")
pkg=tool.get("package","")
print(pm+"\t"+pkg)
PY "$id" > /tmp/raven_install_meta 2>/dev/null || { echo "Herramienta no encontrada: $id"; return 3; }
read -r PM PKG < /tmp/raven_install_meta
rm -f /tmp/raven_install_meta

	echo "Instalar: $id  (package_manager=$PM, package=$PKG)"
	if [[ $DRY_RUN -eq 1 ]]; then
		echo "[DRY-RUN] Comando que se ejecutaría:"
		if [[ "$PM" == "apt" ]]; then
			echo "apt-get update && apt-get install -y $PKG"
		elif [[ "$PM" == "pip" ]]; then
			echo "pip3 install --user $PKG"
		else
			echo "Comando de instalación no definido para package_manager=$PM"
		fi
		return 0
	fi

	if [[ "$YES" -ne 1 ]]; then
		read -p "Continuar e instalar $id? [y/N] " ans
		case "$ans" in [Yy]*) ;; *) echo "Cancelado"; return 4 ;; esac
	fi

	if [[ "$PM" == "apt" ]]; then
		sudo apt-get update
		sudo apt-get install -y $PKG
	elif [[ "$PM" == "pip" ]]; then
		pip3 install --user $PKG
	else
		echo "Sin instalador automático para package_manager=$PM"
		return 5
	fi
}

case "$cmd" in
	list) do_list ;;
	info) do_info "$1" ;;
	install) do_install "$1" ;;
	"") usage; exit 0 ;;
	*) echo "Comando desconocido: $cmd"; usage; exit 2 ;;
esac
'

##### raven-ai (plantilla) #####
RAVEN_AI='#!/usr/bin/env bash
# raven-ai - Launcher mínimo (plantilla)
set -euo pipefail

usage() {
	echo "Uso: $0 [start|stop|status]"
}

case "${1:-start}" in
	start)
		echo "raven-ai: modo plantilla. No inicia LLM real."
		;;
	stop)
		echo "raven-ai: stop (no implementado en plantilla)"
		;;
	status)
		echo "raven-ai: estado OK (plantilla)"
		;;
	*) usage; exit 2 ;;
esac
'

##### raven-learn (plantilla) #####
RAVEN_LEARN='#!/usr/bin/env bash
# raven-learn - CLI para tutoriales (plantilla)
set -euo pipefail

case "${1:-list}" in
	list)
		ls -1 /opt/ravenguard/learning/tutorials 2>/dev/null || echo "No hay tutoriales instalados."
		;;
	open)
		if [[ -z "${2:-}" ]]; then echo "Falta id"; exit 2; fi
		less /opt/ravenguard/learning/tutorials/${2}.md
		;;
	*) echo "Comando desconocido"; exit 2 ;;
esac
'

##### raven-dashboard (plantilla) #####
RAVEN_DASH='#!/usr/bin/env bash
# raven-dashboard - Servir /opt/ravenguard/dashboard/www en localhost
set -euo pipefail

PORT=8080
HOST=127.0.0.1
DIR=/opt/ravenguard/dashboard/www

if [[ "${1:-}" == "start" ]]; then
	if [[ ! -d "$DIR" || -z "$(ls -A "$DIR" 2>/dev/null)" ]]; then
		echo "El directorio $DIR está vacío. Copia contenidos en él primero."
		exit 1
	fi
	echo "Sirviendo dashboard en http://$HOST:$PORT (loopback)"
	python3 -m http.server --bind "$HOST" "$PORT" -d "$DIR"
else
	echo "Uso: $0 start"
fi
'

##### raven-joke (bash) #####
RAVEN_JOKE='#!/usr/bin/env bash
# raven-joke - Obtiene chiste aleatorio (icanhazdadjoke.com)
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
	echo "Se requiere curl. Instala curl con: sudo apt-get install -y curl"
	exit 2
fi

curl -s -H "Accept: text/plain" https://icanhazdadjoke.com/ || echo "Error obteniendo chiste."
'

##### raven-joke.py (python) #####
RAVEN_JOKE_PY='#!/usr/bin/env python3
# raven-joke.py - Obtiene chiste aleatorio (sin dependencias externas)
import sys,urllib.request,urllib.error
API="https://icanhazdadjoke.com/"
try:
	req=urllib.request.Request(API, headers={"Accept":"text/plain","User-Agent":"ravenguard-joke/0.1"})
	with urllib.request.urlopen(req, timeout=10) as r:
		print(r.read().decode("utf-8", errors="replace"))
except Exception as e:
	print("Error obteniendo chiste:", e, file=sys.stderr)
	sys.exit(1)
'

##### README y health-check #####
README_BIN='RavenGuard binarios
===================
Ubicación: /opt/ravenguard/bin

Archivos instalados: raven-tools, raven-ai, raven-learn, raven-dashboard, raven-joke, raven-joke.py, health-check
Permisos recomendados: 755
Propietario: root:root
'

HEALTH='#!/usr/bin/env bash
set -euo pipefail
for f in raven-tools raven-ai raven-learn raven-dashboard raven-joke raven-joke.py; do
	if [[ -x /opt/ravenguard/bin/$f ]]; then
		printf "%-20s OK\n" "$f"
	else
		printf "%-20s MISSING\n" "$f"
	fi
done
'

##### tools-database/index.json (mínimo con dos entradas) #####
INDEX_JSON='{
  "version": "0.1",
  "tools": [
    {
      "id": "kali:nmap",
      "name": "nmap",
      "package": "nmap",
      "package_manager": "apt",
      "origin": "kali",
      "description": "Network scanner (Kali package)"
    },
    {
      "id": "extra:raven-joke",
      "name": "raven-joke",
      "package": "",
      "package_manager": "local-script",
      "origin": "ravenguard",
      "description": "Generador de chistes integrado (script local)"
    }
  ]
}'

# Escribir archivos
write_if_needed "$BIN/raven-tools" "$RAVEN_TOOLS"
write_if_needed "$BIN/raven-ai" "$RAVEN_AI"
write_if_needed "$BIN/raven-learn" "$RAVEN_LEARN"
write_if_needed "$BIN/raven-dashboard" "$RAVEN_DASH"
write_if_needed "$BIN/raven-joke" "$RAVEN_JOKE"
write_if_needed "$BIN/raven-joke.py" "$RAVEN_JOKE_PY"
write_if_needed "$BIN/README" "$README_BIN"
write_if_needed "$BIN/health-check" "$HEALTH"

# index.json (si existe y no --force, no sobreescribe)
if [[ -f "$DB/index.json" && $FORCE -ne 1 ]]; then
	echo "SKIP: $DB/index.json (ya existe). Usa --force para sobrescribir."
else
	echo "CREANDO $DB/index.json"
	sudo tee "$DB/index.json" > /dev/null <<'EOF'
$INDEX_JSON
EOF
	sudo chown root:root "$DB/index.json"
	sudo chmod 644 "$DB/index.json"
fi

echo "Hecho. Archivos instalados en $BIN y índice en $DB/index.json"
echo "Pruebas:"
echo "  sudo $BIN/health-check"
echo "  $BIN/raven-tools --dry-run list"
echo "Para instalar nmap (ejemplo, se requiere apt):"
echo "  sudo $BIN/raven-tools install kali:nmap   # sin --dry-run pedirá confirmación"