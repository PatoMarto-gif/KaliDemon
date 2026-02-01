#!/usr/bin/env bash
# create-tools-database.sh - Crea /opt/ravenguard/tools-database con archivos iniciales
# Uso: sudo bash create-tools-database.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/tools-database"
META="$BASE/metadata"
SCRIPTS="$BASE/scripts"

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
		echo "SKIP: $path (ya existe). Usa --force para sobrescribir)"
		return
	fi
	echo "CREANDO $path"
	sudo tee "$path" > /dev/null <<'EOF'
$content
EOF
	# permisos
	if [[ "$path" == *.sh || "$path" =~ /scripts/ ]]; then
		sudo chmod 755 "$path"
	else
		sudo chmod 644 "$path"
	fi
	sudo chown root:root "$path"
}

ensure_dir "$BASE"
ensure_dir "$META"
ensure_dir "$SCRIPTS"

# Escribir archivos individuales (contenido embebido)
write_file "$BASE/README.md" "# RavenGuard tools-database\n\nContiene índices y metadatos de herramientas (kali + extras). No modifiques sin validar.\n"
write_file "$BASE/schema/tool.schema.json" '{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "RavenGuard tool entry",
  "type": "object",
  "required": ["id", "name", "package_manager"],
  "properties": {
    "id": {
      "type": "string",
      "description": "Formato namespace:name (ej. kali:nmap o extra:httpx)"
    },
    "name": { "type": "string" },
    "package": { "type": "string" },
    "package_manager": {
      "type": "string",
      "enum": ["apt","pip","go","cargo","snap","local-script","manual","binary"]
    },
    "version": { "type": "string" },
    "category": { "type": "string" },
    "description": { "type": "string" },
    "homepage": { "type": "string" },
    "license": { "type": "string" },
    "install_cmd": { "type": "string" },
    "dependencies": {
      "type": "array",
      "items": { "type": "string" }
    },
    "origin": { "type": "string" }
  },
  "additionalProperties": false
}'
write_file "$BASE/kali-tools.json" '{
  "version": "0.1",
  "generated_at": "",
  "tools": [
    {
      "id": "kali:nmap",
      "name": "nmap",
      "package": "nmap",
      "package_manager": "apt",
      "version": "",
      "category": "reconocimiento",
      "description": "Nmap - scanner de red",
      "homepage": "https://nmap.org",
      "license": "GPL",
      "origin": "kali"
    },
    {
      "id": "kali:wireshark",
      "name": "wireshark",
      "package": "wireshark",
      "package_manager": "apt",
      "category": "analisis-red",
      "description": "Analizador de paquetes",
      "homepage": "https://www.wireshark.org",
      "origin": "kali"
    },
    {
      "id": "kali:sqlmap",
      "name": "sqlmap",
      "package": "sqlmap",
      "package_manager": "apt",
      "category": "analisis-web",
      "description": "Automatiza la detección y explotación de inyecciones SQL",
      "homepage": "https://sqlmap.org",
      "origin": "kali"
    }
  ]
}'
write_file "$BASE/extra-tools.json" '{
  "version": "0.1",
  "generated_at": "",
  "tools": [
    {
      "id": "extra:httpx",
      "name": "httpx",
      "package": "httpx",
      "package_manager": "go",
      "category": "analisis-web",
      "description": "HTTP toolkit rápido",
      "homepage": "https://github.com/projectdiscovery/httpx",
      "origin": "github"
    },
    {
      "id": "extra:nuclei",
      "name": "nuclei",
      "package": "nuclei",
      "package_manager": "go",
      "category": "analisis-web",
      "description": "Escáner basado en plantillas",
      "homepage": "https://github.com/projectdiscovery/nuclei",
      "origin": "github"
    },
    {
      "id": "extra:raven-joke",
      "name": "raven-joke",
      "package": "",
      "package_manager": "local-script",
      "category": "utilidades",
      "description": "Generador de chistes integrado (script local)",
      "homepage": "",
      "origin": "ravenguard"
    }
  ]
}'
write_file "$BASE/index.json" '{
  "version": "0.1",
  "generated_at": "",
  "sources": [
    "kali-tools.json",
    "extra-tools.json"
  ],
  "tools": [
    {
      "id": "kali:nmap",
      "name": "nmap",
      "package": "nmap",
      "package_manager": "apt",
      "category": "reconocimiento",
      "description": "Network scanner (Kali package)",
      "origin": "kali"
    },
    {
      "id": "extra:raven-joke",
      "name": "raven-joke",
      "package": "",
      "package_manager": "local-script",
      "category": "utilidades",
      "description": "Generador de chistes integrado (script local)",
      "origin": "ravenguard"
    }
  ]
}'
write_file "$BASE/categories.json" '{
  "version": "0.1",
  "categories": [
    {"id":"reconocimiento","name":"Reconocimiento","description":"Herramientas para descubrimiento y escaneo"},
    {"id":"analisis-web","name":"Análisis Web","description":"Scanners y fuzzers para aplicaciones web"},
    {"id":"pruebas-acceso","name":"Pruebas de Acceso","description":"Cracking y herramientas de acceso"},
    {"id":"analisis-red","name":"Análisis de Red","description":"Captura y análisis de tráfico"},
    {"id":"explotacion","name":"Explotación de Sistemas","description":"Frameworks y post-explotación"},
    {"id":"forense","name":"Forense","description":"Herramientas de análisis forense"},
    {"id":"movil","name":"Seguridad Móvil","description":"Herramientas Android/iOS"},
    {"id":"harden","name":"Hardening & Defensa","description":"Auditoría y monitoreo"},
    {"id":"reporting","name":"Reporting","description":"Generación de informes y documentación"},
    {"id":"utilidades","name":"Utilidades & Productividad","description":"Herramientas auxiliares y productividad"}
  ]
}'
write_file "$META/versions.json" '{"index_version":"0.1","kali_tools_version":"0.1","extra_tools_version":"0.1","generated_at":""}'
write_file "$META/README.md" "# Metadata\n\nMetadatos y versiones del índice de herramientas.\n"

# scripts: validate and helper
write_file "$SCRIPTS/validate-tools.py" '#!/usr/bin/env python3
"""
validate-tools.py - Valida que las entradas de kali-tools.json y extra-tools.json tengan campos mínimos.
No requiere dependencias externas (usa json estándar).
"""
import sys, json, os

BASE="/opt/ravenguard/tools-database"
files = ["kali-tools.json","extra-tools.json","index.json"]

required = ["id","name","package_manager"]

def load(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"ERROR leyendo {path}: {e}", file=sys.stderr)
        return None

ok = True
for fn in files:
    p = os.path.join(BASE, fn)
    data = load(p)
    if data is None:
        ok = False
        continue
    tools = data.get("tools", [])
    for t in tools:
        for r in required:
            if r not in t:
                print(f"ERROR: {fn}: herramienta sin campo requerido \"{r}\": {t.get('id','<no-id>')}")
                ok = False

if not ok:
    print("\\nValidación fallida.")
    sys.exit(2)
print("Validación completada: OK")
'
write_file "$SCRIPTS/validate-tools.sh" '#!/usr/bin/env bash
# validate-tools.sh - Wrapper de validación
set -euo pipefail
sudo /opt/ravenguard/tools-database/scripts/validate-tools.py
'

echo "tools-database creada en $BASE (usa --force para forzar sobrescrituras)."
echo "Ejecuta para validar:"
echo "  sudo $SCRIPTS/validate-tools.sh"
echo "Para listar herramientas indexadas:"
echo "  sudo /opt/ravenguard/bin/raven-tools --dry-run list"