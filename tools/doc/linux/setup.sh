#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../.." && pwd)
DOWNLOAD_DIR="$SCRIPT_DIR/download"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
VENV_DIR="$SCRIPT_DIR/.venv"
PLANTUML_TARGET="$SCRIPT_DIR/plantuml.jar"

APT_PACKAGES=(\
  doxygen\
  graphviz\
  python3-venv\
  python3-pip\
  openjdk-21-jre-headless\
)

print_usage() {
  cat <<'USAGE'
Usage: tools/doc/linux/setup.sh [--download-dir PATH] [--venv-dir PATH] [--plantuml PATH] [--skip-apt]

Installs the documentation toolchain using only artifacts from the download directory plus apt system packages.

Options:
  --download-dir PATH  Path to pre-fetched artifacts (default: tools/doc/linux/download)
  --venv-dir PATH      Destination for the Python virtual environment (default: tools/doc/linux/.venv)
  --plantuml PATH      Target location for plantuml.jar (default: tools/doc/linux/plantuml.jar)
  --skip-apt           Skip apt operations (assumes system packages are present)
  -h, --help           Show this help
USAGE
}

require_file() {
  local file="$1"; local description="$2"
  if [[ ! -f "$file" ]]; then
    echo "[ERROR] Missing ${description}: $file" >&2
    exit 1
  fi
}

install_apt_packages() {
  echo "[INFO] Installing system packages via apt"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PACKAGES[@]}"
}

create_virtualenv() {
  if [[ ! -d "$VENV_DIR" ]]; then
    echo "[INFO] Creating virtual environment at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
  else
    echo "[INFO] Reusing existing virtual environment at $VENV_DIR"
  fi
}

install_python_packages() {
  echo "[INFO] Installing Python packages from $DOWNLOAD_DIR"
  require_file "$REQUIREMENTS_FILE" "requirements file"
  "$VENV_DIR/bin/python" -m pip install --no-index --find-links "$DOWNLOAD_DIR" -r "$REQUIREMENTS_FILE"
}

install_plantuml() {
  local jar_source=""
  jar_source=$(find "$DOWNLOAD_DIR" -maxdepth 1 -type f -name 'plantuml*.jar' | head -n1 || true)
  if [[ -z "$jar_source" ]]; then
    echo "[ERROR] No PlantUML JAR found in $DOWNLOAD_DIR" >&2
    exit 1
  fi
  echo "[INFO] Installing PlantUML from $jar_source"
  cp "$jar_source" "$PLANTUML_TARGET"
}

main() {
  local skip_apt=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --download-dir)
        DOWNLOAD_DIR="$2"; shift 2 ;;
      --venv-dir)
        VENV_DIR="$2"; shift 2 ;;
      --plantuml)
        PLANTUML_TARGET="$2"; shift 2 ;;
      --skip-apt)
        skip_apt=true; shift ;;
      -h|--help)
        print_usage; exit 0 ;;
      *)
        echo "Unknown argument: $1" >&2; print_usage; exit 1 ;;
    esac
  done

  if [[ ! -d "$DOWNLOAD_DIR" ]]; then
    echo "[ERROR] Download directory not found: $DOWNLOAD_DIR" >&2
    exit 1
  fi

  if [[ "$skip_apt" == false ]]; then
    install_apt_packages
  else
    echo "[INFO] Skipping apt installation as requested"
  fi

  create_virtualenv
  install_python_packages
  install_plantuml

  cat <<INFO
[INFO] Installation complete.
- Virtualenv: $VENV_DIR
- PlantUML:   $PLANTUML_TARGET

Activate the environment with:
  source "$VENV_DIR/bin/activate"
INFO
}

main "$@"
