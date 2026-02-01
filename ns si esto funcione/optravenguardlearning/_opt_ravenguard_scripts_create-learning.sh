#!/usr/bin/env bash
# create-learning.sh - Crea la estructura y archivos iniciales en /opt/ravenguard/learning
# Uso: sudo bash /opt/ravenguard/scripts/create-learning.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/learning"
TUTORIALS="$BASE/tutorials"
LABS="$BASE/labs"
CHALLENGES="$BASE/challenges"
ASSETS="$BASE/assets"
SCRIPTS="$BASE/scripts"
META="$BASE/metadata"

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
	# permisos: scripts ejecutables, otros 644
	if [[ "$path" == *.sh || "$path" == */run || "$path" == */validator.py ]]; then
		sudo chmod 755 "$path"
	else
		sudo chmod 644 "$path"
	fi
	sudo chown root:root "$path"
}

ensure_dir "$BASE"
ensure_dir "$TUTORIALS"
ensure_dir "$LABS"
ensure_dir "$CHALLENGES"
ensure_dir "$ASSETS"
ensure_dir "$SCRIPTS"
ensure_dir "$META"

# Tutoriales de ejemplo (Markdown con frontmatter YAML)
write_file "$TUTORIALS/rg-01-intro.md" '---
id: rg-01-intro
title: "Introducción a RavenGuard en Kali"
level: Principiante
duration: 00:20
tags: [inicio, guia, interfaz]
---

# Introducción a RavenGuard

Bienvenido a RavenGuard. Este tutorial explica los primeros pasos para usar la capa RavenGuard sobre Kali Linux.

Objetivos:
- Entender la estructura en /opt/ravenguard
- Ejecutar el dashboard local
- Ver y usar el generador de chistes
- Ejecutar un tutorial básico
'

write_file "$TUTORIALS/rg-02-recon.md" '---
id: rg-02-recon
title: "Reconocimiento básico con Nmap"
level: Principiante
duration: 00:30
tags: [reconocimiento, nmap, redes]
---

# Reconocimiento básico

Este tutorial muestra comandos básicos de nmap y cómo interpretar resultados.
- Comando ejemplo: `nmap -sC -sV <objetivo>`
- Objetivo: aprender a ejecutar scans seguros en un entorno controlado.
'

# Lab de ejemplo: lab-01-docker (contenedor seguro de práctica)
ensure_dir "$LABS/lab-01-docker"
write_file "$LABS/lab-01-docker/README.md" 'Lab 01 - Contenedor Docker de práctica

Instrucciones:
1. Construir la imagen: sudo docker build -t rg-lab-01 .
2. Ejecutar: sudo docker run --rm -p 8081:80 rg-lab-01

La imagen sirve una página simple para practicar escaneo local.
'
write_file "$LABS/lab-01-docker/Dockerfile" 'FROM nginx:stable-alpine
COPY index.html /usr/share/nginx/html/index.html
'
write_file "$LABS/lab-01-docker/index.html" '<!doctype html>
<html>
<head><title>RavenGuard Lab 01</title></head>
<body><h1>Lab 01 - Practica</h1><p>Contenedor para pruebas locales.</p></body>
</html>
'
write_file "$LABS/lab-01-docker/run" '#!/usr/bin/env bash
# run - Construye y ejecuta el lab en docker (script de conveniencia)
set -euo pipefail
docker build -t rg-lab-01 "$(dirname "$0")"
docker run --rm -p 8081:80 rg-lab-01
'

# Challenge de ejemplo con flag y validador
ensure_dir "$CHALLENGES/challenge-01"
write_file "$CHALLENGES/challenge-01/README.md" 'Challenge 01 - Encuentra la bandera

Objetivo: localizar la bandera almacenada localmente y validarla con el script validator.py
Reglas: entorno local, no ataques a terceros.
'
write_file "$CHALLENGES/challenge-01/FLAG.txt" 'RG{ejemplo_bandera_12345}'
write_file "$CHALLENGES/challenge-01/validator.py" '#!/usr/bin/env python3
# validator.py - Valida la bandera proporcionada en el argumento
import sys, os
if len(sys.argv) != 2:
	print("Uso: validator.py <flag>")
	sys.exit(2)
flag=sys.argv[1].strip()
expected=None
try:
	with open(os.path.join(os.path.dirname(__file__), "FLAG.txt"), "r", encoding="utf-8") as f:
		expected=f.read().strip()
except Exception as e:
	print("ERROR: no se pudo leer FLAG.txt:", e)
	sys.exit(3)
if flag == expected:
	print("FLAG correcta")
	sys.exit(0)
else:
	print("FLAG incorrecta")
	sys.exit(1)
'

# Assets placeholder
write_file "$ASSETS/README.md" 'Assets para tutoriales y labs (imágenes, datasets). Coloque aquí archivos necesarios para labs.'
# Metadata index
write_file "$META/index.json" '{
  "version": "0.1",
  "tutorials": [
    {"id":"rg-01-intro","file":"tutorials/rg-01-intro.md","level":"Principiante"},
    {"id":"rg-02-recon","file":"tutorials/rg-02-recon.md","level":"Principiante"}
  ],
  "labs": [
    {"id":"lab-01-docker","path":"labs/lab-01-docker","description":"Contenedor nginx de práctica"}
  ],
  "challenges": [
    {"id":"challenge-01","path":"challenges/challenge-01","difficulty":"Beginner"}
  ]
}'

# Scripts: validate tutorial frontmatter (simple)
write_file "$SCRIPTS/validate-tutorials.py" '#!/usr/bin/env python3
"""
validate-tutorials.py - Valida que los tutoriales tengan frontmatter YAML mínimo (id,title,level)
"""
import sys, os, re, json
BASE="/opt/ravenguard/learning/tutorials"
required=["id","title","level"]
ok=True
for fn in os.listdir(BASE):
	if not fn.endswith(".md"):
		continue
	path=os.path.join(BASE,fn)
	with open(path,"r",encoding="utf-8") as f:
		content=f.read()
	m=re.search(r"^---\\n(.*?)\\n---\\n", content, re.S)
	if not m:
		print(f"ERROR: {fn} no tiene frontmatter YAML")
		ok=False
		continue
	block=m.group(1)
	for r in required:
		if re.search(r"^"+r+r":", block, re.M) is None:
			print(f"ERROR: {fn} falta campo {r} en frontmatter")
			ok=False
if not ok:
	print("\\nValidación fallida.")
	sys.exit(2)
print("Validación completada: OK")
'

write_file "$SCRIPTS/list-learning.sh" '#!/usr/bin/env bash
# list-learning.sh - Lista tutoriales, labs y challenges
set -euo pipefail
echo "Tutoriales:"
ls -1 /opt/ravenguard/learning/tutorials 2>/dev/null || echo "  (ninguno)"
echo ""
echo "Labs:"
ls -1 /opt/ravenguard/learning/labs 2>/dev/null || echo "  (ninguno)"
echo ""
echo "Challenges:"
ls -1 /opt/ravenguard/learning/challenges 2>/dev/null || echo "  (ninguno)"
'

echo "Creación completada: /opt/ravenguard/learning (tutorials, labs, challenges, assets, metadata, scripts)."
echo "Validar tutoriales: sudo /opt/ravenguard/learning/scripts/validate-tutorials.py"