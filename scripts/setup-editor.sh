#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)/iqpe-demo-workspace"
EDITOR_MODE="auto"
INSTALL_EXTENSIONS=false

VSCODE_EXTENSIONS=(
  "golang.go"
  "ms-vscode.makefile-tools"
  "redhat.vscode-yaml"
)

CURSOR_EXTENSIONS=(
  "golang.go"
  "redhat.vscode-yaml"
)

usage() {
  cat <<'EOF'
Usage: setup-editor.sh [options]

Options:
  --root <path>         Workspace root path
  --editor <mode>       auto|vscode|cursor|both|none (default: auto)
  --install-extensions  Install recommended extensions via editor CLIs
  --help                Show this help
EOF
}

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
    --install-extensions)
      INSTALL_EXTENSIONS=true
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

warn() {
  echo "Warning: $*" >&2
}

exists_cmd() {
  command -v "$1" >/dev/null 2>&1
}

first_cmd() {
  for candidate in "$@"; do
    if exists_cmd "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

write_recommendations() {
  local dir="$1"
  shift
  local -a exts=("$@")

  mkdir -p "$dir"
  {
    echo "{"
    echo "  \"recommendations\": ["
    local i
    for i in "${!exts[@]}"; do
      if [[ "$i" -lt $((${#exts[@]} - 1)) ]]; then
        echo "    \"${exts[$i]}\"," 
      else
        echo "    \"${exts[$i]}\""
      fi
    done
    echo "  ]"
    echo "}"
  } >"$dir/extensions.json"
}

install_extensions() {
  local cli="$1"
  shift
  local -a exts=("$@")

  local ext
  for ext in "${exts[@]}"; do
    "$cli" --install-extension "$ext" >/dev/null 2>&1 || warn "$cli failed to install extension: $ext"
  done
}

generate_open_scripts() {
  local workspace_file="$ROOT_DIR/iqpe-portfolio.code-workspace"

  cat >"$ROOT_DIR/open-vscode.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
code \"$workspace_file\"
EOF

  cat >"$ROOT_DIR/open-cursor.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cursor \"$workspace_file\"
EOF

  chmod +x "$ROOT_DIR/open-vscode.sh" "$ROOT_DIR/open-cursor.sh"
}

main() {
  ROOT_DIR="$(abspath "$ROOT_DIR")"

  case "$EDITOR_MODE" in
    auto|vscode|cursor|both|none)
      ;;
    *)
      echo "Invalid editor mode: $EDITOR_MODE" >&2
      usage
      exit 1
      ;;
  esac

  if [[ "$EDITOR_MODE" == "none" ]]; then
    echo "Editor setup disabled."
    return
  fi

  local vscode_cli=""
  local cursor_cli=""

  if vscode_cli="$(first_cmd code code-insiders)"; then
    :
  else
    vscode_cli=""
  fi

  if cursor_cli="$(first_cmd cursor)"; then
    :
  else
    cursor_cli=""
  fi

  local want_vscode=false
  local want_cursor=false

  case "$EDITOR_MODE" in
    auto)
      [[ -n "$vscode_cli" ]] && want_vscode=true
      [[ -n "$cursor_cli" ]] && want_cursor=true
      ;;
    vscode)
      want_vscode=true
      ;;
    cursor)
      want_cursor=true
      ;;
    both)
      want_vscode=true
      want_cursor=true
      ;;
  esac

  if [[ "$want_vscode" == true && -z "$vscode_cli" ]]; then
    warn "VS Code CLI not found (expected code or code-insiders)."
    [[ "$EDITOR_MODE" != "auto" ]] && exit 1
    want_vscode=false
  fi

  if [[ "$want_cursor" == true && -z "$cursor_cli" ]]; then
    warn "Cursor CLI not found (expected cursor)."
    [[ "$EDITOR_MODE" != "auto" ]] && exit 1
    want_cursor=false
  fi

  mkdir -p "$ROOT_DIR/.vscode" "$ROOT_DIR/.cursor"

  if [[ "$want_vscode" == true ]]; then
    write_recommendations "$ROOT_DIR/.vscode" "${VSCODE_EXTENSIONS[@]}"
    echo "Configured VS Code recommendations in $ROOT_DIR/.vscode/extensions.json"
    if [[ "$INSTALL_EXTENSIONS" == true ]]; then
      install_extensions "$vscode_cli" "${VSCODE_EXTENSIONS[@]}"
      echo "Attempted VS Code extension install via $vscode_cli"
    fi
  fi

  if [[ "$want_cursor" == true ]]; then
    write_recommendations "$ROOT_DIR/.cursor" "${CURSOR_EXTENSIONS[@]}"
    echo "Configured Cursor recommendations in $ROOT_DIR/.cursor/extensions.json"
    if [[ "$INSTALL_EXTENSIONS" == true ]]; then
      install_extensions "$cursor_cli" "${CURSOR_EXTENSIONS[@]}"
      echo "Attempted Cursor extension install via $cursor_cli"
    fi
  fi

  generate_open_scripts
  echo "Generated open scripts: $ROOT_DIR/open-vscode.sh and $ROOT_DIR/open-cursor.sh"
}

main
