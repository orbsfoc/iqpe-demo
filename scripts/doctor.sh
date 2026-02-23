#!/usr/bin/env bash
set -euo pipefail

STRICT=false
CHECK_EDITOR="auto"  # auto|vscode|cursor|both|none

usage() {
  cat <<'EOF'
Usage: doctor.sh [options]

Options:
  --strict           Exit non-zero if any required check fails
  --editor <mode>    auto|vscode|cursor|both|none (default: auto)
  --help             Show this help

Checks:
  Required: bash, git, go, gh, ssh
  Editor-aware: code (VS Code), cursor
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=true
      shift
      ;;
    --editor)
      CHECK_EDITOR="$2"
      shift 2
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

case "$CHECK_EDITOR" in
  auto|vscode|cursor|both|none)
    ;;
  *)
    echo "Invalid --editor value: $CHECK_EDITOR" >&2
    usage
    exit 1
    ;;
esac

PLATFORM="unknown"
PKG_HINT=""

os_detect() {
  local u
  u="$(uname -s)"
  case "$u" in
    Linux)
      PLATFORM="linux"
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        if [[ "${ID:-}" == "ubuntu" ]]; then
          PKG_HINT="sudo apt update && sudo apt install -y"
        else
          PKG_HINT="Use your distro package manager to install"
        fi
      else
        PKG_HINT="Use your distro package manager to install"
      fi
      ;;
    Darwin)
      PLATFORM="darwin"
      PKG_HINT="brew install"
      ;;
    *)
      PLATFORM="unknown"
      PKG_HINT="Install manually"
      ;;
  esac
}

exists_cmd() {
  command -v "$1" >/dev/null 2>&1
}

version_of() {
  local cmd="$1"
  if exists_cmd "$cmd"; then
    "$cmd" --version 2>/dev/null | head -n 1 || true
  fi
}

print_ok() {
  printf "[OK]   %s\n" "$1"
}

print_warn() {
  printf "[WARN] %s\n" "$1"
}

print_fail() {
  printf "[FAIL] %s\n" "$1"
}

hint_install() {
  local tool="$1"
  case "$tool" in
    bash)
      if [[ "$PLATFORM" == "darwin" ]]; then
        echo "brew install bash"
      else
        echo "$PKG_HINT bash"
      fi
      ;;
    git)
      echo "$PKG_HINT git"
      ;;
    go)
      if [[ "$PLATFORM" == "darwin" ]]; then
        echo "brew install go"
      else
        echo "$PKG_HINT golang-go"
      fi
      ;;
    gh)
      if [[ "$PLATFORM" == "darwin" ]]; then
        echo "brew install gh"
      else
        echo "$PKG_HINT gh"
      fi
      ;;
    ssh)
      if [[ "$PLATFORM" == "darwin" ]]; then
        echo "ssh is built in on macOS; ensure OpenSSH client is available"
      else
        echo "$PKG_HINT openssh-client"
      fi
      ;;
    code)
      echo "Install VS Code and enable Shell Command: 'code'"
      ;;
    cursor)
      echo "Install Cursor and enable CLI command: 'cursor'"
      ;;
    *)
      echo "Install $tool manually"
      ;;
  esac
}

require_gh_auth() {
  if ! exists_cmd gh; then
    return 1
  fi

  if gh auth status >/dev/null 2>&1; then
    print_ok "gh auth status: authenticated"
    return 0
  fi

  print_warn "gh auth status: not authenticated"
  echo "       remediation: gh auth login"
  return 1
}

require_ssh_agent() {
  if ! exists_cmd ssh; then
    return 1
  fi

  if ssh -T git@github.com </dev/null >/tmp/iqpe-demo-ssh-check.log 2>&1; then
    print_ok "ssh to github: reachable/authenticated"
    return 0
  fi

  if grep -qi "successfully authenticated" /tmp/iqpe-demo-ssh-check.log; then
    print_ok "ssh to github: authenticated (non-shell access)"
    return 0
  fi

  print_warn "ssh to github: not confirmed"
  echo "       remediation:"
  echo "         - ssh-keygen -t ed25519 -C \"you@example.com\""
  echo "         - eval \"\$(ssh-agent -s)\" && ssh-add ~/.ssh/id_ed25519"
  echo "         - gh ssh-key add ~/.ssh/id_ed25519.pub"
  return 1
}

check_tool() {
  local tool="$1"
  local required="$2"
  local fail_count_ref="$3"

  if exists_cmd "$tool"; then
    local v
    v="$(version_of "$tool")"
    if [[ -n "$v" ]]; then
      print_ok "$tool found ($v)"
    else
      print_ok "$tool found"
    fi
    return
  fi

  if [[ "$required" == "required" ]]; then
    print_fail "$tool not found"
    echo "       remediation: $(hint_install "$tool")"
    eval "$fail_count_ref=$(( $fail_count_ref + 1 ))"
  else
    print_warn "$tool not found"
    echo "       remediation: $(hint_install "$tool")"
  fi
}

main() {
  os_detect
  echo "Platform: $PLATFORM"

  local required_failures=0

  check_tool bash required required_failures
  check_tool git required required_failures
  check_tool go required required_failures
  check_tool gh required required_failures
  check_tool ssh required required_failures

  if [[ "$CHECK_EDITOR" != "none" ]]; then
    case "$CHECK_EDITOR" in
      auto)
        check_tool code optional required_failures
        check_tool cursor optional required_failures
        ;;
      vscode)
        check_tool code optional required_failures
        ;;
      cursor)
        check_tool cursor optional required_failures
        ;;
      both)
        check_tool code optional required_failures
        check_tool cursor optional required_failures
        ;;
    esac
  fi

  if ! require_gh_auth; then
    required_failures=$((required_failures + 1))
  fi

  if ! require_ssh_agent; then
    print_warn "SSH check did not fully pass; HTTPS mode may still work with scaffold script (--https)."
  fi

  echo
  if [[ "$required_failures" -eq 0 ]]; then
    echo "Doctor result: PASS"
    exit 0
  fi

  echo "Doctor result: FAIL ($required_failures required check(s) need attention)"
  if [[ "$STRICT" == true ]]; then
    exit 1
  fi
  exit 0
}

main
