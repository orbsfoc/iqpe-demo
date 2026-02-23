#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)/iqpe-demo-workspace"
ASSUME_YES=false
KEEP_LOGS=false

usage() {
  cat <<'EOF'
Usage: destroy-local-env.sh [options]

Options:
  --root <path>    Workspace root to remove (default: ./iqpe-demo-workspace)
  --yes            Skip confirmation prompt
  --keep-logs      Keep logs directory if present
  --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    --keep-logs)
      KEEP_LOGS=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

abspath() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    echo "$(pwd)/$path"
  fi
}

safety_check() {
  local path="$1"

  if [[ -z "$path" || "$path" == "/" ]]; then
    echo "Refusing to remove unsafe path: '$path'" >&2
    exit 1
  fi

  case "$path" in
    "/home"|"/Users"|"/tmp"|"/var"|"/opt"|"/usr"|"/bin"|"/sbin")
      echo "Refusing to remove top-level system path: '$path'" >&2
      exit 1
      ;;
  esac
}

confirm() {
  if [[ "$ASSUME_YES" == true ]]; then
    return
  fi

  echo "This will remove: $ROOT_DIR"
  read -r -p "Continue? [y/N] " reply
  case "$reply" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Cancelled."
      exit 0
      ;;
  esac
}

main() {
  ROOT_DIR="$(abspath "$ROOT_DIR")"
  safety_check "$ROOT_DIR"

  if [[ ! -d "$ROOT_DIR" ]]; then
    echo "Workspace path does not exist, nothing to remove: $ROOT_DIR"
    exit 0
  fi

  confirm

  if [[ "$KEEP_LOGS" == true && -d "$ROOT_DIR/logs" ]]; then
    local temp_logs
    temp_logs="$(mktemp -d)"
    cp -R "$ROOT_DIR/logs" "$temp_logs/"
    rm -rf "$ROOT_DIR"
    mkdir -p "$ROOT_DIR"
    mv "$temp_logs/logs" "$ROOT_DIR/logs"
    rm -rf "$temp_logs"
    echo "Removed workspace but preserved logs at: $ROOT_DIR/logs"
  else
    rm -rf "$ROOT_DIR"
    echo "Removed workspace: $ROOT_DIR"
  fi
}

main
