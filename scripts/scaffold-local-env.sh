#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)/iqpe-demo-workspace"
GITHUB_ORG="orbsfoc"
USE_HTTPS=false
SKIP_CLONE=false
SKIP_CHECKS=false
EDITOR_MODE="auto"
INSTALL_EDITOR_EXTENSIONS=false
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM=""

REPOS=(
  "iqpe-governance-workflow"
  "iqpe-mcp-runtime"
  "iqpe-skill-pack"
  "iqpe-architecture-standards"
  "iqpe-library-catalog"
  "iqpe-product-template"
)

usage() {
  cat <<'EOF'
Usage: scaffold-local-env.sh [options]

Options:
  --root <path>      Target workspace root (default: ./iqpe-demo-workspace)
  --org <name>       GitHub org/user for repository cloning (default: orbsfoc)
  --editor <mode>    Editor setup mode: auto|vscode|cursor|both|none (default: auto)
  --install-editor-extensions  Install recommended extensions when editor CLIs exist
  --https            Use HTTPS clone URLs (default: SSH)
  --skip-clone       Skip repository clone/pull operations
  --skip-checks      Skip Go/runtime validation checks
  --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --org)
      GITHUB_ORG="$2"
      shift 2
      ;;
    --editor)
      EDITOR_MODE="$2"
      shift 2
      ;;
    --install-editor-extensions)
      INSTALL_EDITOR_EXTENSIONS=true
      shift
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

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
}

print_header() {
  local msg="$1"
  echo
  echo "==> $msg"
}

warn() {
  echo "Warning: $*" >&2
}

abspath() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
    return
  fi
  echo "$(pwd)/$path"
}

detect_platform() {
  local uname_out
  uname_out="$(uname -s)"

  case "$uname_out" in
    Linux)
      PLATFORM="linux"
      echo "Detected platform: Linux"
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
          warn "script is optimized for Ubuntu 24.04; detected ${ID:-unknown} ${VERSION_ID:-unknown}."
        else
          echo "Ubuntu 24.04 detected."
        fi
      fi
      ;;
    Darwin)
      PLATFORM="darwin"
      echo "Detected platform: macOS"
      ;;
    *)
      echo "Unsupported platform: $uname_out" >&2
      exit 1
      ;;
  esac
}

repo_url() {
  local repo="$1"
  if [[ "$USE_HTTPS" == true ]]; then
    echo "https://github.com/${GITHUB_ORG}/${repo}.git"
  else
    echo "git@github.com:${GITHUB_ORG}/${repo}.git"
  fi
}

clone_or_update_repo() {
  local repo="$1"
  local target="$ROOT_DIR/repos/$repo"

  if [[ -d "$target/.git" ]]; then
    echo "Updating $repo"
    git -C "$target" pull --ff-only
  else
    echo "Cloning $repo"
    git clone "$(repo_url "$repo")" "$target"
  fi
}

generate_workspace_file() {
  local workspace_file="$ROOT_DIR/iqpe-portfolio.code-workspace"
  cat >"$workspace_file" <<EOF
{
  "folders": [
    { "path": "repos/iqpe-governance-workflow" },
    { "path": "repos/iqpe-mcp-runtime" },
    { "path": "repos/iqpe-skill-pack" },
    { "path": "repos/iqpe-architecture-standards" },
    { "path": "repos/iqpe-library-catalog" },
    { "path": "repos/iqpe-product-template" }
  ],
  "settings": {
    "files.exclude": {
      "**/.git": true
    }
  }
}
EOF
  echo "Created $workspace_file"
}

run_editor_setup() {
  if [[ "$EDITOR_MODE" == "none" ]]; then
    echo "Skipping editor setup by request."
    return
  fi

if [[ ! -x "$SCRIPT_DIR/setup-editor.sh" ]]; then
    warn "setup-editor.sh is not executable; attempting to run with bash"
  fi

  local args=(
    --root "$ROOT_DIR"
    --editor "$EDITOR_MODE"
  )

  if [[ "$INSTALL_EDITOR_EXTENSIONS" == true ]]; then
    args+=(--install-extensions)
  fi

  bash "$SCRIPT_DIR/setup-editor.sh" "${args[@]}"
}

run_checks() {
  local runtime_docflow="$ROOT_DIR/repos/iqpe-mcp-runtime/Tooling/docflow"
  local demo_report="$ROOT_DIR/repos/iqpe-product-template/demo-project-v3/artifacts/v2-demo-readiness-report.yaml"

  require_cmd go

  if [[ ! -d "$runtime_docflow" ]]; then
    echo "Runtime docflow directory not found: $runtime_docflow" >&2
    exit 1
  fi

  print_header "Running runtime Go tests"
  (cd "$runtime_docflow" && go test ./...)

  print_header "Running v2 demo readiness"
  (
    cd "$runtime_docflow"
    go run ./cmd/docflow v2-demo-readiness \
      --demo-root ../../../iqpe-product-template/demo-project-v3 \
      --report ../../../iqpe-product-template/demo-project-v3/artifacts/v2-demo-readiness-report.yaml
  )

  echo "Readiness report: $demo_report"
}

main() {
  print_header "Checking prerequisites"
  require_cmd bash
  require_cmd git
  detect_platform
  ROOT_DIR="$(abspath "$ROOT_DIR")"

  case "$EDITOR_MODE" in
    auto|vscode|cursor|both|none)
      ;;
    *)
      echo "Invalid --editor value: $EDITOR_MODE" >&2
      usage
      exit 1
      ;;
  esac

  print_header "Preparing workspace"
  mkdir -p "$ROOT_DIR/repos" "$ROOT_DIR/logs"

  if [[ "$SKIP_CLONE" == false ]]; then
    print_header "Cloning/updating IQPE repositories"
    for repo in "${REPOS[@]}"; do
      clone_or_update_repo "$repo"
    done
  else
    echo "Skipping clone/update by request."
  fi

  print_header "Generating VS Code workspace file"
  generate_workspace_file

  print_header "Configuring editor setup"
  run_editor_setup

  if [[ "$SKIP_CHECKS" == false ]]; then
    run_checks
  else
    echo "Skipping validation checks by request."
  fi

  print_header "Scaffold complete"
  echo "Workspace root: $ROOT_DIR"
  echo "Open in VS Code: code \"$ROOT_DIR/iqpe-portfolio.code-workspace\""
  echo "Open in Cursor: cursor \"$ROOT_DIR/iqpe-portfolio.code-workspace\""
}

main
