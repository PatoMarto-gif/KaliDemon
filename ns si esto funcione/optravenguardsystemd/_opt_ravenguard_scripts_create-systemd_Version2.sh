#!/usr/bin/env bash
# create-systemd.sh - Crea unit files de systemd de ejemplo en /opt/ravenguard/systemd
# Uso: sudo bash /opt/ravenguard/scripts/create-systemd.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/systemd"
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

write "$BASE/ravenguard-dashboard.service" '[Unit]
Description=RavenGuard Dashboard (static server)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m http.server 8080 --directory /opt/ravenguard/dashboard/www --bind 127.0.0.1
Restart=on-failure
User=root
WorkingDirectory=/opt/ravenguard/dashboard/www

[Install]
WantedBy=multi-user.target
'

write "$BASE/ravenguard-ai.service" '[Unit]
Description=RavenGuard AI (fallback stub)
After=network.target

[Service]
Type=simple
ExecStart=/opt/ravenguard/ai-modules/scripts/run-local-llm-fallback.sh
Restart=on-failure
User=root
WorkingDirectory=/opt/ravenguard/ai-modules

[Install]
WantedBy=multi-user.target
'

write "$BASE/README.md" "# systemd units\n\nPlantilla con unit files. No habilite sin revisar: copie a /etc/systemd/system/ y luego use systemctl daemon-reload.\n"

write "$BASE/install-units.sh" '#!/usr/bin/env bash
# install-units.sh - Copia unit files a /etc/systemd/system (no habilita automáticamente)
set -euo pipefail
SRC="/opt/ravenguard/systemd"
for f in "$SRC"/*.service; do
	if [[ -f "$f" ]]; then
		sudo cp -n "$f" /etc/systemd/system/
		echo "Copiado: $f -> /etc/systemd/system/"
	fi
done
echo "Recuerde: sudo systemctl daemon-reload"
'

sudo chmod 755 /opt/ravenguard/scripts/create-systemd.sh 2>/dev/null || true
echo "Plantillas systemd creadas."