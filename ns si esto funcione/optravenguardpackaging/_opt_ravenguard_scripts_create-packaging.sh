#!/usr/bin/env bash
# create-packaging.sh - Crea plantilla para empaquetado (.deb) en /opt/ravenguard/packaging
# Uso: sudo bash /opt/ravenguard/scripts/create-packaging.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/packaging"
DEB="$BASE/debian"
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
	sudo chmod 644 "$path"
	sudo chown root:root "$path"
}

ensure "$BASE"
ensure "$DEB"

write "$DEB/control" 'Source: ravenguard
Section: utils
Priority: optional
Maintainer: RavenGuard <devnull@example.com>
Build-Depends: debhelper (>= 11)
Standards-Version: 4.5.0
Package: ravenguard
Architecture: all
Depends: ${misc:Depends}, bash, python3
Description: RavenGuard OS layer - templates and configs
 RavenGuard is a non-invasive layer for Kali Linux providing tooling, themes and learning content.
'

write "$DEB/changelog" 'ravenguard (0.1.0) unstable; urgency=medium

  * Initial packaging template

 -- RavenGuard <devnull@example.com>  Thu, 01 Jan 1970 00:00:00 +0000
'

write "$DEB/dirs" '/opt/ravenguard
/opt/ravenguard/bin
/opt/ravenguard/configs
'

write "$BASE/README.md" "# Packaging\n\nPlantilla para crear un paquete .deb de RavenGuard. Edite los archivos en packaging/debian antes de construir.\n"

write "$SCRIPTS/package-build.sh" '#!/usr/bin/env bash
# package-build.sh - Construye paquete .deb desde /opt/ravenguard (plantilla)
# Uso: sudo /opt/ravenguard/scripts/package-build.sh
set -euo pipefail

# No empaqueta por defecto: preparar directorios y control
WORKDIR="/tmp/ravenguard-deb"
sudo rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/DEBIAN"
mkdir -p "$WORKDIR/opt/ravenguard"

echo "Copiando archivos (plantilla)..."
sudo cp -a /opt/ravenguard/* "$WORKDIR/opt/ravenguard/" 2>/dev/null || true
# Copiar control files
if [[ -d /opt/ravenguard/packaging/debian ]]; then
	sudo cp /opt/ravenguard/packaging/debian/control "$WORKDIR/DEBIAN/control" 2>/dev/null || true
else
	echo "Faltan archivos de control en /opt/ravenguard/packaging/debian"
	exit 1
fi

# Ajustar permisos mínimos
sudo chmod -R 755 "$WORKDIR/opt/ravenguard"
sudo chmod 644 "$WORKDIR/DEBIAN/control"

echo "Construyendo paquete .deb (plantilla)..."
dpkg-deb --build "$WORKDIR" "/tmp/ravenguard-$(date +%s).deb"
echo "Paquete generado en /tmp"
'

sudo chmod 755 /opt/ravenguard/scripts/package-build.sh 2>/dev/null || true
echo "Plantilla de packaging creada."