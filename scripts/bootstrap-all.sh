#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)/iqpe-demo-workspace"
EDITOR_MODE="auto"
STRICT_DOCTOR=true
INSTALL_EDITOR_EXTENSIONS=false
USE_HTTPS=false
SKIP_CLONE=false
SKIP_CHECKS=false

usage() {
  cat <<'EOF'
Usage: bootstrap-all.sh [options]

Runs:
  1) doctor.sh
  2) scaffold-local-env.sh

Options:
  --root <path>        Workspace root (default: ./iqpe-demo-workspace)
  --editor <mode>      auto|vscode|cursor|both|none (default: auto)
  --org <name>         GitHub org/user (default: orbsfoc)
  --https              Use HTTPS clone URLs
  --skip-clone         Skip clone/update during scaffold
  --skip-checks        Skip Go/runtime checks during scaffold
  --install-editor-extensions  Install recommended editor extensions
  --no-strict-doctor   Do not fail fast when doctor finds required issues
  --help               Show this help
EOF
}

ORG_ARG=(--org "orbsfoc")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --editor)
      EDITOR_MODE="$2"
      shift 2
      ;;
    --org)
      ORG_ARG=(--org "$2")
      shift 2
      ;;
    --https)
      USE_HTTPS=true
      shift
      ;;
    --skip-clone)
      SKIP_CLONE=true
      shift
      ;;
    --skip-checks)
      SKIP_CHECKS=true
      shift
      ;;
    --install-editor-extensions)
      INSTALL_EDITOR_EXTENSIONS=true
      shift
      ;;
    --no-strict-doctor)
      STRICT_DOCTOR=false
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

print_header() {
  local msg="$1"
  echo
  echo "==> $msg"
}

main() {
  print_header "Step 1/2: Running doctor checks"
  local doctor_args=(--editor "$EDITOR_MODE")
  if [[ "$STRICT_DOCTOR" == true ]]; then
    doctor_args+=(--strict)
  fi
  bash "$SCRIPT_DIR/doctor.sh" "${doctor_args[@]}"

  print_header "Step 2/2: Running scaffold"
  local scaffold_args=(
    --root "$ROOT_DIR"
    --editor "$EDITOR_MODE"
    "${ORG_ARG[@]}"
  )

  if [[ "$USE_HTTPS" == true ]]; then
    scaffold_args+=(--https)
  fi
  if [[ "$SKIP_CLONE" == true ]]; then
    scaffold_args+=(--skip-clone)
  fi
  if [[ "$SKIP_CHECKS" == true ]]; then
    scaffold_args+=(--skip-checks)
  fi
  if [[ "$INSTALL_EDITOR_EXTENSIONS" == true ]]; then
    scaffold_args+=(--install-editor-extensions)
  fi

  bash "$SCRIPT_DIR/scaffold-local-env.sh" "${scaffold_args[@]}"

  print_header "Bootstrap summary"
  echo "Doctor status: PASS"
  echo "Scaffold status: PASS"
  echo "Workspace: $(cd "$ROOT_DIR" 2>/dev/null && pwd || echo "$ROOT_DIR")"
}

main
