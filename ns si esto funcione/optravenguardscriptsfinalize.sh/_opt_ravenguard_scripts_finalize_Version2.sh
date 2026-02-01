#!/usr/bin/env bash
# finalize.sh - Orquestador final para aplicar permisos, instalar units, empaquetar y ejecutar tests (safe, con dry-run)
# Uso: sudo bash /opt/ravenguard/scripts/finalize.sh [--dry-run] [--force] [--enable-services]
set -euo pipefail

DRY=0
FORCE=0
ENABLE_SERVICES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --force) FORCE=1; shift ;;
    --enable-services) ENABLE_SERVICES=1; shift ;;
    -h|--help) echo "Uso: $0 [--dry-run] [--force] [--enable-services]"; exit 0 ;;
    *) break ;;
  esac
done

SCRIPTS="/opt/ravenguard/scripts"
MODDIR="$SCRIPTS/modular"

run_or_echo() {
  if [[ $DRY -eq 1 ]]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

echo "1) Crear usuario/grupo y permisos"
if [[ -x "$MODDIR/user-and-perms.sh" ]]; then
  run_or_echo "bash $MODDIR/user-and-perms.sh"
else
  echo "Skip: $MODDIR/user-and-perms.sh no encontrado"
fi

echo "2) Preparar themes & wallpapers"
if [[ -x "$MODDIR/themes-and-wallpapers.sh" ]]; then
  run_or_echo "bash $MODDIR/themes-and-wallpapers.sh $( [[ $FORCE -eq 1 ]] && echo --force || true )"
fi

echo "3) Crear/instalar systemd units (copia solo)"
if [[ -x "$MODDIR/systemd-and-services.sh" ]]; then
  run_or_echo "bash $MODDIR/systemd-and-services.sh"
fi

echo "4) Construir paquete .deb y checksums (plantilla)"
if [[ -x "$MODDIR/packaging-and-release.sh" ]]; then
  run_or_echo "bash $MODDIR/packaging-and-release.sh"
fi

echo "5) Generar releases/checksums"
if [[ -x "$SCRIPTS/create-releases.sh" ]]; then
  run_or_echo "bash $SCRIPTS/create-releases.sh $( [[ $FORCE -eq 1 ]] && echo --force || true )"
fi

echo "6) Ejecutar tests básicos"
if [[ -x /opt/ravenguard/tests/smoke.sh ]]; then
  run_or_echo "sudo /opt/ravenguard/tests/smoke.sh"
fi
if [[ -x /opt/ravenguard/tests/test_raven_tools.sh ]]; then
  run_or_echo "sudo /opt/ravenguard/tests/test_raven_tools.sh"
fi

if [[ $ENABLE_SERVICES -eq 1 && $DRY -eq 0 ]]; then
  echo "7) Habilitar servicios systemd (se copiaron unit files antes) — habilitando y arrancando"
  for u in /etc/systemd/system/ravenguard-*.service /etc/systemd/system/ravenguard-*.service; do
    [[ -f "$u" ]] || continue
    echo "systemctl daemon-reload && systemctl enable --now $(basename "$u")"
    systemctl daemon-reload
    systemctl enable --now "$(basename "$u")"
  done
else
  echo "7) No se habilitaron servicios (use --enable-services sin --dry-run para habilitarlos manualmente)."
fi

echo "Finalizado (modo $( [[ $DRY -eq 1 ]] && echo DRY-RUN || echo LIVE )). Revise salidas anteriores."