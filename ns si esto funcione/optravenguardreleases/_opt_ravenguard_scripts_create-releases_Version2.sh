#!/usr/bin/env bash
# create-releases.sh - Crea /opt/ravenguard/releases con plantilla de release y checksums
# Uso: sudo bash /opt/ravenguard/scripts/create-releases.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/releases"
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

# sample release notes
write "$BASE/RELEASE-0.1.0.txt" "RavenGuard 0.1.0 - Initial template release\n\nIncludes structure templates and example scripts.\n"

# placeholder tarball note (no binary payload)
write "$BASE/README.md" "# Releases\n\nColoque aquí archivos release (tar.gz, deb) con checksums. No subir binarios sin firmar.\n"

# sample checksums file (empty placeholders)
write "$BASE/checksums.txt" "sha256sum  ravenguard-0.1.0.tar.gz  # replace with real sums\n"

echo "Releases directory creada en $BASE (placeholders)"