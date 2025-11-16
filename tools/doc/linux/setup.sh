#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC_ROOT="$SCRIPT_DIR"
BIN_DIR="$DOC_ROOT/bin"
TEMP_DIR="$DOC_ROOT/temp"
DOWNLOAD_DIR="$DOC_ROOT/download"
REQ_FILE="$DOC_ROOT/requirements.txt"

echo "[doc-setup] DOC_ROOT:     $DOC_ROOT"
echo "[doc-setup] BIN_DIR:      $BIN_DIR"
echo "[doc-setup] TEMP_DIR:     $TEMP_DIR"
echo "[doc-setup] DOWNLOAD_DIR: $DOWNLOAD_DIR"

# ---- Hole alle LFS-Dateien --------------------------------------------------
./scripts/setup_lfs.sh
# ---- Helper: check if downloads match requirements.txt ----------------------

downloads_ok() {
  if [ ! -d "$DOWNLOAD_DIR" ]; then
    return 1
  fi
  if [ ! -f "$REQ_FILE" ]; then
    echo "[doc-setup] requirements.txt fehlt unter $REQ_FILE"
    return 1
  fi
  local checksum_file="$DOWNLOAD_DIR/.req_checksum"
  local current
  current="$(sha256sum "$REQ_FILE" | awk '{print $1}')"
  if [ ! -f "$checksum_file" ]; then
    return 1
  fi
  local stored
  stored="$(cat "$checksum_file")"
  if [ "$stored" != "$current" ]; then
    return 1
  fi
  return 0
}

# ---- Helper: perform downloads into DOWNLOAD_DIR ----------------------------

perform_downloads() {
  echo "[doc-setup] (Re)creating download directory..."
  rm -rf "$DOWNLOAD_DIR"
  mkdir -p "$DOWNLOAD_DIR"

  if [ ! -f "$REQ_FILE" ]; then
    echo "[doc-setup] ERROR: requirements.txt nicht gefunden unter $REQ_FILE"
    exit 1
  fi

  echo "[doc-setup] Downloading Python wheels according to requirements.txt..."
  python3 -m pip download -r "$REQ_FILE" -d "$DOWNLOAD_DIR"

  echo "[doc-setup] Downloading plantuml.jar..."
  # Hinweis: URL ggf. anpassen, falls sich das Release-Schema ändert.
  curl -L -o "$DOWNLOAD_DIR/plantuml.jar"     "https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar"

  echo "[doc-setup] Storing checksum for requirements.txt..."
  sha256sum "$REQ_FILE" | awk '{print $1}' > "$DOWNLOAD_DIR/.req_checksum"
}

# ---- Helper: interactive system package management via apt ------------------

ensure_system_packages() {
  echo "[doc-setup] Checking for system package updates..."
  sudo apt-get update

  # Die für die Toolchain relevanten Pakete
  local pkgs=(python3 python3-venv python3-pip graphviz doxygen default-jre)

  # Liste potentiell upgradbarer Pakete
  local upgradable
  upgradable="$(apt list --upgradable 2>/dev/null | grep -E '^(python3/|python3-venv/|python3-pip/|graphviz/|doxygen/|default-jre/)' || true)"

  if [ -n "$upgradable" ]; then
    # Rot + fett
    echo -e "\033[1;31mDie folgenden Systempakete haben Updates:\033[0m"
    echo "$upgradable"
    echo

    # Prompt in Rot, Default = Y
    read -r -p $'\033[1;31mUpdates installieren [Y,n]? \033[0m' answer
    case "$answer" in
      [Nn]* )
        echo "[doc-setup] Systempaket-Updates werden übersprungen."
        # Sicherstellen, dass Pakete zumindest installiert sind (ohne erzwungenes Upgrade)
        sudo apt-get install -y "${pkgs[@]}"
        return 0
        ;;
      * )
        echo "[doc-setup] Installiere/aktualisiere Systempakete..."
        sudo apt-get install -y "${pkgs[@]}"
        return 0
        ;;
    esac
  else
    echo "[doc-setup] Keine Updates für Systempakete erforderlich."
    # Sicherstellen, dass sie zumindest installiert sind
    sudo apt-get install -y "${pkgs[@]}"
  fi
}

# ---- Helper: install toolchain into target directory ------------------------

install_to_target() {
  local TARGET="$1"
  local VENV_DIR="$TARGET/venv"
  local SPHINX_DIR="$TARGET/sphinx"
  local SPHINX_SRC_DIR="$SPHINX_DIR/source"

  echo "[doc-setup] Installing into target: $TARGET"
  rm -rf "$TARGET"
  mkdir -p "$SPHINX_SRC_DIR"

  # Virtualenv
  python3 -m venv "$VENV_DIR"
  # shellcheck source=/dev/null
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip wheel

  echo "[doc-setup] Installing Python packages from local wheels..."
  pip install --no-index --find-links="$DOWNLOAD_DIR" -r "$REQ_FILE"

  # Minimal Sphinx-Konfiguration
  cat > "$SPHINX_SRC_DIR/conf.py" << 'EOF'
import os
import sys
from datetime import datetime

# Pfad zum Projekt (bei Bedarf anpassen)
sys.path.insert(0, os.path.abspath('../..'))

project = 'Project Documentation'
author = 'Your Team'
current_year = datetime.now().year
copyright = f"{current_year}, {author}"

extensions = [
    'breathe',
    'sphinxcontrib.plantuml',
    'sphinxcontrib.mermaid',
]

templates_path = ['_templates']
exclude_patterns = []

html_theme = 'sphinx_rtd_theme'

html_static_path = ['_static']

# PlantUML-Konfiguration: erwartet plantuml.jar im download-Verzeichnis
this_dir = os.path.abspath(os.path.dirname(__file__))
plantuml_jar = os.path.abspath(os.path.join(this_dir, '..', '..', '..', 'download', 'plantuml.jar'))
plantuml = f'java -jar {plantuml_jar}'
plantuml_output_format = 'svg'
EOF

  cat > "$SPHINX_SRC_DIR/index.rst" << 'EOF'
Welcome to Project Documentation's documentation!
=================================================

.. toctree::
   :maxdepth: 2
   :caption: Inhalt:



EOF

  cat > "$SPHINX_DIR/Makefile" << 'EOF'
# Minimal Makefile for Sphinx documentation

SPHINXBUILD   = sphinx-build
SOURCEDIR     = source
BUILDDIR      = build

.PHONY: help clean html

help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)"

clean:
	rm -rf "$(BUILDDIR)"

html:
	$(SPHINXBUILD) -M html "$(SOURCEDIR)" "$(BUILDDIR)"
EOF

  # Doxygen-Konfiguration
  local DOXYFILE="$TARGET/Doxyfile"
  doxygen -g "$DOXYFILE"
  sed -i 's/^PROJECT_NAME.*/PROJECT_NAME           = "Project Documentation"/' "$DOXYFILE"
  sed -i 's/^OUTPUT_DIRECTORY.*/OUTPUT_DIRECTORY       = docs\//g' "$DOXYFILE"
  sed -i 's/^GENERATE_HTML.*/GENERATE_HTML           = YES/' "$DOXYFILE"
  sed -i 's/^HAVE_DOT.*/HAVE_DOT               = YES/' "$DOXYFILE"
  sed -i 's/^CALL_GRAPH.*/CALL_GRAPH             = YES/' "$DOXYFILE"
  sed -i 's/^CALLER_GRAPH.*/CALLER_GRAPH           = YES/' "$DOXYFILE"
  sed -i 's/^UML_LOOK.*/UML_LOOK               = YES/' "$DOXYFILE"

  echo "[doc-setup] Installation in $TARGET completed."
}

# ---- Helper: Python-Update-Check ausführen ----------------------------------

run_python_update_check() {
  local CHECK_SCRIPT="$DOC_ROOT/check-python-updates.sh"
  if [ -x "$CHECK_SCRIPT" ]; then
    echo "[doc-setup] Starte Python-Update-Check..."
    "$CHECK_SCRIPT" || true
  else
    echo "[doc-setup] Hinweis: check-python-updates.sh ist nicht ausführbar oder fehlt."
  fi
}

# -----------------------------------------------------------------------------
# Hauptlogik
# -----------------------------------------------------------------------------

NEED_DOWNLOADS=0

if ! downloads_ok; then
  echo "[doc-setup] Downloads sind nicht aktuell oder fehlen."
  NEED_DOWNLOADS=1
fi

if [ -d "$TEMP_DIR" ]; then
  echo "[doc-setup] TEMP_DIR existiert, Downloads werden vorsichtshalber erneuert."
  NEED_DOWNLOADS=1
fi

if [ "$NEED_DOWNLOADS" -eq 1 ]; then
  echo "[doc-setup] Lösche BIN_DIR und erneuere Downloads..."
  rm -rf "$BIN_DIR"
  ensure_system_packages
  perform_downloads
else
  echo "[doc-setup] Downloads sind aktuell."
  ensure_system_packages
fi

# Nach diesem Punkt gelten: download/ vorhanden & laut requirements.txt befüllt

# 2. Falls download ok und BIN_DIR nicht existiert:
#    -> Probeinstallation in TEMP_DIR.
if downloads_ok && [ ! -d "$BIN_DIR" ]; then
  echo "[doc-setup] BIN_DIR existiert nicht, starte Probeinstallation in TEMP_DIR..."
  rm -rf "$TEMP_DIR"
  mkdir -p "$TEMP_DIR"

  if ! install_to_target "$TEMP_DIR"; then
    echo "[doc-setup] FEHLER: Probeinstallation in $TEMP_DIR fehlgeschlagen."
    echo "[doc-setup] TEMP_DIR bleibt zur Analyse erhalten."
    exit 1
  fi

  echo "[doc-setup] Probeinstallation erfolgreich."
  echo "[doc-setup] Entferne TEMP_DIR und installiere nach BIN_DIR..."
  rm -rf "$TEMP_DIR"
  install_to_target "$BIN_DIR"
  echo "[doc-setup] Installation in BIN_DIR erfolgreich abgeschlossen."

  run_python_update_check
  exit 0
fi

# 3. Falls download ok, kein TEMP_DIR, aber BIN_DIR existiert:
#    -> Nichts zu tun.
if downloads_ok && [ -d "$BIN_DIR" ] && [ ! -d "$TEMP_DIR" ]; then
  echo "[doc-setup] Alles ist bereits installiert. Nichts zu tun."
  run_python_update_check
  exit 0
fi

echo "[doc-setup] Unerwarteter Zustand. Bitte Verzeichnisse prüfen."
exit 1
