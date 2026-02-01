#!/usr/bin/env bash
# create-tests.sh - Crea tests básicos en /opt/ravenguard/tests
# Uso: sudo bash /opt/ravenguard/scripts/create-tests.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/tests"
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
	if [[ "$path" == *.sh ]]; then
		sudo chmod 755 "$path"
	else
		sudo chmod 644 "$path"
	fi
	sudo chown root:root "$path"
}

ensure_dir "$BASE"

# smoke test: comprobar disponibilidad de binarios principales
write_file "$BASE/smoke.sh" '#!/usr/bin/env bash
# smoke.sh - Comprobaciones rápidas de salud
set -euo pipefail
OK=0
for f in /opt/ravenguard/bin/raven-tools /opt/ravenguard/bin/raven-joke /opt/ravenguard/bin/raven-dashboard; do
	if [[ -x "$f" ]]; then
		printf "%-30s OK\n" "$f"
		OK=$((OK+1))
	else
		printf "%-30s MISSING\n" "$f"
	fi
done
exit 0
'

# unit test example for raven-tools (dry-run)
write_file "$BASE/test_raven_tools.sh" '#!/usr/bin/env bash
# test_raven_tools.sh - Test simple de raven-tools --dry-run list
set -euo pipefail
if /opt/ravenguard/bin/raven-tools --dry-run list >/tmp/raven_tools_list.txt 2>&1; then
	echo "raven-tools list: OK"
	exit 0
else
	echo "raven-tools list: FAIL"
	cat /tmp/raven_tools_list.txt
	exit 2
fi
'

# CI hint file (instructions)
write_file "$BASE/README.md" "Tests básicos para RavenGuard\n\n- Ejecutar smoke test: sudo bash smoke.sh\n- Ejecutar test_raven_tools: sudo bash test_raven_tools.sh\n"
echo "Tests creados en $BASE"