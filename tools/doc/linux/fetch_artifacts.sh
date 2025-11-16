#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOWNLOAD_DIR="$SCRIPT_DIR/download"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
PLANTUML_VERSION=${PLANTUML_VERSION:-1.2024.7}
PLANTUML_URL="https://github.com/plantuml/plantuml/releases/download/v${PLANTUML_VERSION}/plantuml-${PLANTUML_VERSION}.jar"

usage() {
  cat <<'USAGE'
Usage: tools/doc/linux/fetch_artifacts.sh [--download-dir PATH] [--plantuml-version VERSION]

Downloads Python wheels and plantuml.jar into the download directory.
This script requires internet access; setup.sh installs only from the download cache.

Options:
  --download-dir PATH      Target directory for downloads (default: tools/doc/linux/download)
  --plantuml-version VER   PlantUML release version (default: 1.2024.7)
  -h, --help               Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --download-dir)
      DOWNLOAD_DIR="$2"; shift 2 ;;
    --plantuml-version)
      PLANTUML_VERSION="$2"; PLANTUML_URL="https://github.com/plantuml/plantuml/releases/download/v${PLANTUML_VERSION}/plantuml-${PLANTUML_VERSION}.jar"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac

done

mkdir -p "$DOWNLOAD_DIR"

if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
  echo "[ERROR] requirements file missing: $REQUIREMENTS_FILE" >&2
  exit 1
fi

echo "[INFO] Downloading Python wheels to $DOWNLOAD_DIR"
python3 -m pip download --dest "$DOWNLOAD_DIR" --requirement "$REQUIREMENTS_FILE"

echo "[INFO] Downloading PlantUML ${PLANTUML_VERSION}"
curl -fL "$PLANTUML_URL" -o "$DOWNLOAD_DIR/plantuml-${PLANTUML_VERSION}.jar"

echo "[INFO] Downloads complete in $DOWNLOAD_DIR"
