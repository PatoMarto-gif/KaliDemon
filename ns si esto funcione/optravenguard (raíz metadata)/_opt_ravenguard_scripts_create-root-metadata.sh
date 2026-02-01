#!/usr/bin/env bash
# create-root-metadata.sh - Crea README.md, LICENSE, CHANGELOG.md, VERSION en /opt/ravenguard
# Uso: sudo bash /opt/ravenguard/scripts/create-root-metadata.sh [--force]
set -euo pipefail

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
	FORCE=1
fi

BASE="/opt/ravenguard"
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

write "$BASE/README.md" "# RavenGuard OS\n\nCapa adicional para Kali Linux instalada en /opt/ravenguard.\n\nEstructura principal:\n- bin/\n- tools-database/\n- configs/\n- learning/\n- ai-modules/\n- wallpapers/\n- dashboard/\n- scripts/\n\nLea los scripts en /opt/ravenguard/scripts para instalador y mantenimiento.\n"
write "$BASE/VERSION" "0.1.0\n"
write "$BASE/CHANGELOG.md" "# Changelog\n\n- 0.1.0: Inicial (plantillas y estructura)\n"
write "$BASE/LICENSE" "MIT License\n\nCopyright (c) $(date +%Y) RavenGuard\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the \"Software\"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\n[...standard MIT text elided for brevity...]\n"
echo "Archivos metadata creados en $BASE"