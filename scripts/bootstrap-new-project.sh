#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Bootstrap a new clean project from GitHub-hosted IQPE workflow assets.

Usage:
  bootstrap-new-project.sh --target-root <absolute-path> --spec-dir <absolute-path> [options]

Required:
  --target-root <path>   Absolute path to target project repository root
  --spec-dir <path>      Absolute path to PRD/spec directory for this run

Options:
  --org <name>           GitHub org/user (default: orbsfoc)
  --ref <git-ref>        Branch/tag to fetch from each repo (default: main)
  --keep-tmp             Keep temporary clone directory for inspection
  -h, --help             Show this help

This script fetches from GitHub repos (no local source copy):
  - iqpe-governance-workflow (prompt pack)
  - iqpe-skill-pack (required skills)
  - iqpe-mcp-runtime (mcp.example.json)
EOF
}

TARGET_ROOT=""
SPEC_DIR=""
ORG="orbsfoc"
REF="main"
KEEP_TMP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-root)
      TARGET_ROOT="${2:-}"
      shift 2
      ;;
    --spec-dir)
      SPEC_DIR="${2:-}"
      shift 2
      ;;
    --org)
      ORG="${2:-}"
      shift 2
      ;;
    --ref)
      REF="${2:-}"
      shift 2
      ;;
    --keep-tmp)
      KEEP_TMP=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_ROOT" || -z "$SPEC_DIR" ]]; then
  echo "Missing required arguments." >&2
  usage
  exit 1
fi

if [[ ! -d "$TARGET_ROOT" ]]; then
  echo "target root does not exist: $TARGET_ROOT" >&2
  exit 1
fi

if [[ ! -d "$SPEC_DIR" ]]; then
  echo "spec dir does not exist: $SPEC_DIR" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but not found" >&2
  exit 1
fi

if ! command -v go >/dev/null 2>&1; then
  echo "go is required but not found" >&2
  exit 1
fi

TARGET_ROOT="$(cd "$TARGET_ROOT" && pwd)"
SPEC_DIR="$(cd "$SPEC_DIR" && pwd)"

TMP_DIR="$(mktemp -d)"
if [[ "$KEEP_TMP" != true ]]; then
  trap 'rm -rf "$TMP_DIR"' EXIT
fi

GOV_REPO_URL="https://github.com/$ORG/iqpe-governance-workflow.git"
SKILL_REPO_URL="https://github.com/$ORG/iqpe-skill-pack.git"
RUNTIME_REPO_URL="https://github.com/$ORG/iqpe-mcp-runtime.git"

echo "[1/6] Cloning workflow pack from GitHub..."
git clone --depth 1 --branch "$REF" "$GOV_REPO_URL" "$TMP_DIR/iqpe-governance-workflow"

echo "[2/6] Cloning skills pack from GitHub..."
git clone --depth 1 --branch "$REF" "$SKILL_REPO_URL" "$TMP_DIR/iqpe-skill-pack"

echo "[3/6] Cloning MCP runtime from GitHub..."
git clone --depth 1 --branch "$REF" "$RUNTIME_REPO_URL" "$TMP_DIR/iqpe-mcp-runtime"

echo "[4/6] Installing workflow prompts and required skills into target project..."
mkdir -p "$TARGET_ROOT/.iqpe-workflow"
rm -rf "$TARGET_ROOT/.iqpe-workflow/productWorkflowPack"
cp -R "$TMP_DIR/iqpe-governance-workflow/prompts/productWorkflowPack" "$TARGET_ROOT/.iqpe-workflow/productWorkflowPack"

REQUIRED_SKILLS=(
  "local-mcp-setup"
  "project-bootstrap"
  "workflow-preflight-check"
  "spec-tech-detect"
)

mkdir -p "$TARGET_ROOT/.github/skills"
for skill in "${REQUIRED_SKILLS[@]}"; do
  src="$TMP_DIR/iqpe-skill-pack/.github/skills/$skill"
  if [[ ! -d "$src" ]]; then
    echo "missing required skill in source repo: $skill" >&2
    exit 1
  fi
  rm -rf "$TARGET_ROOT/.github/skills/$skill"
  cp -R "$src" "$TARGET_ROOT/.github/skills/$skill"
done

echo "[5/6] Writing MCP config template if missing..."
mkdir -p "$TARGET_ROOT/.vscode"
if [[ ! -f "$TARGET_ROOT/.vscode/mcp.json" ]]; then
  cp "$TMP_DIR/iqpe-mcp-runtime/Tooling/mcp-local/mcp.example.json" "$TARGET_ROOT/.vscode/mcp.json"
fi

echo "[6/6] Running local bootstrap+preflight evidence generator..."
(
  cd "$TARGET_ROOT"
  go run ./.github/skills/local-mcp-setup/bootstrap_preflight.go --target-root "$TARGET_ROOT" --spec-dir "$SPEC_DIR"
)

cat <<EOF

Bootstrap complete.

Target project: $TARGET_ROOT
Spec directory: $SPEC_DIR
Fetched from org: $ORG (ref: $REF)

Generated/ensured files:
- $TARGET_ROOT/.iqpe-workflow/productWorkflowPack/00-orchestrator.md
- $TARGET_ROOT/.github/skills/local-mcp-setup
- $TARGET_ROOT/.vscode/mcp.json
- $TARGET_ROOT/docs/tooling/bootstrap-report.md
- $TARGET_ROOT/docs/tooling/workflow-preflight.json
- $TARGET_ROOT/docs/tooling/spec-tech-detect.json

Next steps in your target project:
1) Open the repo in VS Code/Cursor.
2) Start at .iqpe-workflow/productWorkflowPack/00-orchestrator.md
3) Keep docs/tooling/mcp-usage-evidence.md updated as phases execute.
EOF

if [[ "$KEEP_TMP" == true ]]; then
  echo "Temporary clones retained at: $TMP_DIR"
fi
