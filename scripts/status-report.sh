#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)/iqpe-demo-workspace"
OUT_FILE=""

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
Usage: status-report.sh [options]

Options:
  --root <path>   Workspace root (default: ./iqpe-demo-workspace)
  --out <file>    Output markdown file path (default: <root>/status-report.md)
  --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --out)
      OUT_FILE="$2"
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

abspath() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    echo "$(pwd)/$path"
  fi
}

exists_cmd() {
  command -v "$1" >/dev/null 2>&1
}

tool_line() {
  local tool="$1"
  if exists_cmd "$tool"; then
    local v
    v="$($tool --version 2>/dev/null | head -n 1 || true)"
    if [[ -z "$v" ]]; then
      v="available"
    fi
    echo "- $tool: PASS ($v)"
  else
    echo "- $tool: FAIL (not found)"
  fi
}

repo_line() {
  local repo="$1"
  local path="$ROOT_DIR/repos/$repo"
  if [[ -d "$path/.git" ]]; then
    local branch
    local commit
    branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
    commit="$(git -C "$path" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
    echo "- $repo: PASS (branch=$branch, commit=$commit)"
  elif [[ -d "$path" ]]; then
    echo "- $repo: WARN (directory exists but not a git repo)"
  else
    echo "- $repo: FAIL (missing)"
  fi
}

readiness_section() {
  local report="$ROOT_DIR/repos/iqpe-product-template/demo-project-v3/artifacts/v2-demo-readiness-report.yaml"

  echo "## Demo Readiness"
  if [[ ! -f "$report" ]]; then
    echo "- status: UNKNOWN (report not found: $report)"
    echo
    return
  fi

  local status
  local missing
  local violations

  status="$(grep -E '^\s*status:' "$report" | head -n 1 | sed 's/^\s*status:\s*//')"
  missing="$(grep -E '^\s*missing_artifacts:' "$report" | head -n 1 | sed 's/^\s*missing_artifacts:\s*//')"
  violations="$(grep -E '^\s*schema_violations:' "$report" | head -n 1 | sed 's/^\s*schema_violations:\s*//')"

  echo "- report: $report"
  echo "- status: ${status:-UNKNOWN}"
  echo "- missing_artifacts: ${missing:-UNKNOWN}"
  echo "- schema_violations: ${violations:-UNKNOWN}"
  echo
}

main() {
  ROOT_DIR="$(abspath "$ROOT_DIR")"

  if [[ -z "$OUT_FILE" ]]; then
    OUT_FILE="$ROOT_DIR/status-report.md"
  else
    OUT_FILE="$(abspath "$OUT_FILE")"
  fi

  mkdir -p "$(dirname "$OUT_FILE")"

  {
    echo "# IQPE Demo Status Report"
    echo
    echo "- generated_at: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "- workspace_root: $ROOT_DIR"
    echo

    echo "## Tooling"
    tool_line bash
    tool_line git
    tool_line go
    tool_line gh
    tool_line ssh
    tool_line code
    tool_line cursor
    echo

    echo "## Repositories"
    for repo in "${REPOS[@]}"; do
      repo_line "$repo"
    done
    echo

    readiness_section
  } >"$OUT_FILE"

  echo "Status report written: $OUT_FILE"
}

main
