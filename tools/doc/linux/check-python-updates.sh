#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC_ROOT="$SCRIPT_DIR"
BIN_DIR="$DOC_ROOT/bin"
VENV_DIR="$BIN_DIR/venv"

echo "[python-updates] DOC_ROOT: $DOC_ROOT"
echo "[python-updates] BIN_DIR:  $BIN_DIR"

if [ ! -d "$VENV_DIR" ]; then
  echo "[python-updates] Kein Virtualenv unter $VENV_DIR gefunden. Überspringe Python-Update-Check."
  exit 0
fi

# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

echo
echo "------------------------------------------------------------"
echo "Verfügbare Python-Updates (basierend auf installiertem venv):"
echo "------------------------------------------------------------"
echo

# pip list --outdated zeigt alle Pakete mit neueren Versionen
if ! pip list --outdated; then
  echo "[python-updates] Hinweis: pip list --outdated konnte nicht ausgeführt werden."
  exit 0
fi

cat << 'EOF'

Hinweis:
- Dies ist nur eine Informationsausgabe.
- Um Pakete zu aktualisieren, passe requirements.txt an (Versionen anheben)
  und führe anschließend tools/doc/linux/setup.sh erneut aus.
- Die eigentliche Installation bleibt weiterhin über das Offline-Download-
  Verzeichnis (download/) und die Probeinstallation gesteuert.

EOF
