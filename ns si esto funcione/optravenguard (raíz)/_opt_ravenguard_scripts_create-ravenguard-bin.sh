#!/usr/bin/env bash
# create-ravenguard-bin.sh - Crea los ejecutables básicos en /opt/ravenguard/bin
# Uso: sudo bash create-ravenguard-bin.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

TARGET_DIR="/opt/ravenguard/bin"
sudo mkdir -p "$TARGET_DIR"
sudo chown root:root /opt/ravenguard
sudo chmod 755 /opt/ravenguard

write_if_needed() {
	local path="$1"
	local content="$2"
	if [[ -f "$path" && $FORCE -ne 1 ]]; then
		echo "Ya existe $path (usa --force para sobrescribir)"
		return
	fi
	echo "Creando $path"
	sudo tee "$path" > /dev/null <<'EOF'
$content
EOF
	sudo chmod 755 "$path"
	sudo chown root:root "$path"
}

# Contenido de raven-joke (Bash, usa curl y devuelve texto plano)
RAVEN_JOKE_BASH='#!/usr/bin/env bash
# raven-joke - Generador de chistes (usa https://icanhazdadjoke.com/)
# Version: 0.1
set -euo pipefail

# Modo simple: devuelve chiste en texto plano
# Requiere: curl (viene por defecto en Kali)
API="https://icanhazdadjoke.com/"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
	echo "Uso: $0"
	echo "Devuelve un chiste aleatorio usando icanhazdadjoke.com"
	exit 0
fi

# Petición segura: cabecera Accept: text/plain para recibir solo el texto
curl -s -H "Accept: text/plain" "$API" || echo "Error obteniendo chiste. Comprueba tu conexión."'

# Contenido de raven-joke.py (Python, sin dependencias extra)
RAVEN_JOKE_PY='#!/usr/bin/env python3
# raven-joke.py - Generador de chistes (sin dependencias externas)
# Version: 0.1
import sys
import urllib.request
import urllib.error

API = "https://icanhazdadjoke.com/"

def main():
		req = urllib.request.Request(API, headers={"Accept": "text/plain", "User-Agent": "ravenguard-joke/0.1"})
		try:
			with urllib.request.urlopen(req, timeout=10) as r:
				body = r.read().decode("utf-8", errors="replace")
				print(body)
		except urllib.error.URLError as e:
			print("Error obteniendo chiste:", e, file=sys.stderr)
			sys.exit(1)

if __name__ == "__main__":
	main()'

# README corto para bin
README_BIN='RavenGuard binarios
===================
Ubicación: /opt/ravenguard/bin

Archivos:
- raven-joke       : script Bash para obtener chiste aleatorio
- raven-joke.py    : alternativa en Python (ejecutable)
- health-check     : chequear presencia de binarios

Permisos recomendados: 755
Propietario: root:root'

# health-check minimo (añadimos raven-joke)
HEALTH_CHECK='#!/usr/bin/env bash
set -euo pipefail

for f in raven-tools raven-ai raven-learn raven-dashboard raven-joke raven-joke.py; do
	if [[ -x /opt/ravenguard/bin/$f ]]; then
		printf "%-20s OK\n" "$f"
	else
		printf "%-20s MISSING\n" "$f"
	fi
done'

# Escribir archivos (usamos sudo tee en write_if_needed)
write_if_needed "$TARGET_DIR/raven-joke" "$RAVEN_JOKE_BASH"
write_if_needed "$TARGET_DIR/raven-joke.py" "$RAVEN_JOKE_PY"
write_if_needed "$TARGET_DIR/README" "$README_BIN"
write_if_needed "$TARGET_DIR/health-check" "$HEALTH_CHECK"

echo "Puesta en marcha completa. Ejecuta:"
echo "  sudo /opt/ravenguard/bin/health-check"
echo "Prueba el generador de chistes:"
echo "  /opt/ravenguard/bin/raven-joke"
echo "o (versión Python):"
echo "  /opt/ravenguard/bin/raven-joke.py"