#!/usr/bin/env bash
# create-ci.sh - Crea carpeta /opt/ravenguard/ci con scripts y plantilla de workflow
# Uso: sudo bash /opt/ravenguard/scripts/create-ci.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard/ci"
WORKFLOWS="$BASE/.github_workflows"
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
ensure "$WORKFLOWS"

write "$BASE/run-ci-tests.sh" '#!/usr/bin/env bash
# run-ci-tests.sh - Ejecuta tests locales (smoke + unit) para CI
set -euo pipefail
sudo /opt/ravenguard/tests/smoke.sh
sudo /opt/ravenguard/tests/test_raven_tools.sh
echo "Todos los tests ejecutados (plantilla)."
'
write "$WORKFLOWS/ci-template.yml" 'name: RavenGuard CI (template)

on:
  push:
    paths:
      - "*/**"
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.x"
      - name: Run tests (placeholder)
        run: |
          echo "CI placeholder - run lint/tests here"
'
sudo chmod 755 /opt/ravenguard/ci/run-ci-tests.sh 2>/dev/null || true
echo "CI templates creados en $BASE"