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
  --runtime-local-path <path>  Use local iqpe-mcp-runtime repo path instead of cloning from GitHub
  --allow-external-spec  Allow SPEC_DIR to be outside target root
  --mcp-bin-dir <path>   Install iqpe-localmcp into this absolute path
  --mcp-transport <mode> MCP transport mode: stdio|http (default: stdio)
  --mcp-http-start       When using --mcp-transport http, start local Docker Compose MCP stack
  --keep-tmp             Keep temporary clone directory for inspection
  -h, --help             Show this help

This script fetches from GitHub repos by default:
  - iqpe-governance-workflow (prompt pack)
  - iqpe-skill-pack (required skills)
  - iqpe-mcp-runtime (localmcp binary build source)

When --runtime-local-path is set, iqpe-mcp-runtime is copied from that local path.
EOF
}

TARGET_ROOT=""
SPEC_DIR=""
ORG="orbsfoc"
REF="main"
ALLOW_EXTERNAL_SPEC=false
MCP_BIN_DIR=""
KEEP_TMP=false
RUNTIME_LOCAL_PATH=""
MCP_TRANSPORT="stdio"
MCP_HTTP_START=false

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
    --runtime-local-path)
      RUNTIME_LOCAL_PATH="${2:-}"
      shift 2
      ;;
    --allow-external-spec)
      ALLOW_EXTERNAL_SPEC=true
      shift
      ;;
    --mcp-bin-dir)
      MCP_BIN_DIR="${2:-}"
      shift 2
      ;;
    --keep-tmp)
      KEEP_TMP=true
      shift
      ;;
    --mcp-transport)
      MCP_TRANSPORT="${2:-}"
      shift 2
      ;;
    --mcp-http-start)
      MCP_HTTP_START=true
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

if [[ "$MCP_TRANSPORT" != "stdio" && "$MCP_TRANSPORT" != "http" ]]; then
  echo "invalid --mcp-transport value: $MCP_TRANSPORT (expected stdio|http)" >&2
  exit 1
fi

if [[ "$MCP_HTTP_START" == true && "$MCP_TRANSPORT" != "http" ]]; then
  echo "--mcp-http-start requires --mcp-transport http" >&2
  exit 1
fi

if [[ -n "$RUNTIME_LOCAL_PATH" && ! -d "$RUNTIME_LOCAL_PATH" ]]; then
  echo "runtime local path does not exist: $RUNTIME_LOCAL_PATH" >&2
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
if [[ -n "$RUNTIME_LOCAL_PATH" ]]; then
  RUNTIME_LOCAL_PATH="$(cd "$RUNTIME_LOCAL_PATH" && pwd)"
fi

if [[ "$ALLOW_EXTERNAL_SPEC" != true ]]; then
  case "$SPEC_DIR" in
    "$TARGET_ROOT"/*) ;;
    *)
      echo "SPEC_DIR must be inside target root unless --allow-external-spec is set." >&2
      echo "target root: $TARGET_ROOT" >&2
      echo "spec dir:    $SPEC_DIR" >&2
      exit 1
      ;;
  esac
fi

if [[ -z "$MCP_BIN_DIR" ]]; then
  MCP_BIN_DIR="$TARGET_ROOT/.iqpe/bin"
fi

if [[ ! -d "$MCP_BIN_DIR" ]]; then
  mkdir -p "$MCP_BIN_DIR"
fi
MCP_BIN_DIR="$(cd "$MCP_BIN_DIR" && pwd)"
MCP_BIN="$MCP_BIN_DIR/iqpe-localmcp"

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
if [[ -n "$RUNTIME_LOCAL_PATH" ]]; then
  echo "[3/6] Using local MCP runtime source: $RUNTIME_LOCAL_PATH"
  cp -R "$RUNTIME_LOCAL_PATH" "$TMP_DIR/iqpe-mcp-runtime"
else
  git clone --depth 1 --branch "$REF" "$RUNTIME_REPO_URL" "$TMP_DIR/iqpe-mcp-runtime"
fi

echo "[4/8] Installing iqpe-localmcp binary..."
(
  cd "$TMP_DIR/iqpe-mcp-runtime/Tooling/docflow"
  go build -o "$MCP_BIN" ./cmd/localmcp
)

if [[ ! -x "$MCP_BIN" ]]; then
  echo "failed to install executable: $MCP_BIN" >&2
  exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  if command -v xattr >/dev/null 2>&1; then
    xattr -d com.apple.quarantine "$MCP_BIN" >/dev/null 2>&1 || true
  fi
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$MCP_BIN" >/dev/null 2>&1 || true
  fi
fi

echo "[5/8] Installing workflow prompts and required skills into target project..."
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

echo "[6/8] Writing deterministic MCP config with absolute command path..."
mkdir -p "$TARGET_ROOT/.vscode"
if [[ "$MCP_TRANSPORT" == "stdio" ]]; then
  cat > "$TARGET_ROOT/.vscode/mcp.json" <<EOF
{
  "servers": {
    "repo-read-local": {
      "transport": "stdio",
      "command": "$MCP_BIN",
      "args": ["--server", "repo-read", "--workspace", "$TARGET_ROOT"]
    },
    "docflow-actions-local": {
      "transport": "stdio",
      "command": "$MCP_BIN",
      "args": ["--server", "docflow-actions", "--workspace", "$TARGET_ROOT"]
    },
    "docs-graph-local": {
      "transport": "stdio",
      "command": "$MCP_BIN",
      "args": ["--server", "docs-graph", "--workspace", "$TARGET_ROOT"]
    },
    "policy-local": {
      "transport": "stdio",
      "command": "$MCP_BIN",
      "args": ["--server", "policy", "--workspace", "$TARGET_ROOT"]
    }
  }
}
EOF
else
  cat > "$TARGET_ROOT/.vscode/mcp.json" <<EOF
{
  "servers": {
    "repo-read-local": {
      "transport": "http",
      "url": "http://127.0.0.1:18080"
    },
    "docflow-actions-local": {
      "transport": "http",
      "url": "http://127.0.0.1:18081"
    },
    "docs-graph-local": {
      "transport": "http",
      "url": "http://127.0.0.1:18082"
    },
    "policy-local": {
      "transport": "http",
      "url": "http://127.0.0.1:18083"
    }
  }
}
EOF

  mkdir -p "$TARGET_ROOT/.iqpe/mcp-http"
  rm -rf "$TARGET_ROOT/.iqpe/mcp-http/docflow"
  cp -R "$TMP_DIR/iqpe-mcp-runtime/Tooling/docflow" "$TARGET_ROOT/.iqpe/mcp-http/docflow"

  cat > "$TARGET_ROOT/.iqpe/mcp-http/docker-compose.yml" <<EOF
services:
  repo-read-local:
    image: golang:1.24
    working_dir: /opt/docflow
    command: ["go", "run", "./cmd/localmcp", "--server", "repo-read", "--transport", "http", "--host", "0.0.0.0", "--port", "18080", "--workspace", "/workspace"]
    volumes:
      - ./docflow:/opt/docflow
      - ${TARGET_ROOT}:/workspace
    ports:
      - "18080:18080"
    restart: unless-stopped

  docflow-actions-local:
    image: golang:1.24
    working_dir: /opt/docflow
    command: ["go", "run", "./cmd/localmcp", "--server", "docflow-actions", "--transport", "http", "--host", "0.0.0.0", "--port", "18081", "--workspace", "/workspace"]
    volumes:
      - ./docflow:/opt/docflow
      - ${TARGET_ROOT}:/workspace
    ports:
      - "18081:18081"
    restart: unless-stopped

  docs-graph-local:
    image: golang:1.24
    working_dir: /opt/docflow
    command: ["go", "run", "./cmd/localmcp", "--server", "docs-graph", "--transport", "http", "--host", "0.0.0.0", "--port", "18082", "--workspace", "/workspace"]
    volumes:
      - ./docflow:/opt/docflow
      - ${TARGET_ROOT}:/workspace
    ports:
      - "18082:18082"
    restart: unless-stopped

  policy-local:
    image: golang:1.24
    working_dir: /opt/docflow
    command: ["go", "run", "./cmd/localmcp", "--server", "policy", "--transport", "http", "--host", "0.0.0.0", "--port", "18083", "--workspace", "/workspace"]
    volumes:
      - ./docflow:/opt/docflow
      - ${TARGET_ROOT}:/workspace
    ports:
      - "18083:18083"
    restart: unless-stopped
EOF

  if [[ "$MCP_HTTP_START" == true ]]; then
    if ! command -v docker >/dev/null 2>&1; then
      echo "docker is required for --mcp-http-start" >&2
      exit 1
    fi
    echo "Starting MCP HTTP services via Docker Compose..."
    (
      cd "$TARGET_ROOT/.iqpe/mcp-http"
      docker compose -f docker-compose.yml up -d

      if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required to verify MCP HTTP readiness" >&2
        exit 1
      fi

      endpoints=(18080 18081 18082 18083)
      for port in "${endpoints[@]}"; do
        ready=false
        for _ in $(seq 1 40); do
          if curl -sS -X POST "http://127.0.0.1:${port}" \
            -H 'Content-Type: application/json' \
            -H 'Accept: application/json, text/event-stream' \
            -d '{"jsonrpc":"2.0","id":"bootstrap-init","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"iqpe-bootstrap","version":"1.0.0"}}}' >/dev/null 2>&1; then
            ready=true
            break
          fi
          sleep 1
        done

        if [[ "$ready" != true ]]; then
          echo "MCP HTTP endpoint not ready: http://127.0.0.1:${port}" >&2
          docker compose -f docker-compose.yml ps >&2 || true
          docker compose -f docker-compose.yml logs --tail=80 >&2 || true
          exit 1
        fi
      done
    )
  else
    echo "HTTP MCP config written, but services are not auto-started."
    echo "Start them with: (cd \"$TARGET_ROOT/.iqpe/mcp-http\" && docker compose -f docker-compose.yml up -d)"
  fi
fi

echo "[7/8] Initializing mandatory MCP usage evidence file..."
mkdir -p "$TARGET_ROOT/docs/tooling"
if [[ ! -f "$TARGET_ROOT/docs/tooling/mcp-usage-evidence.md" ]]; then
  cp "$TMP_DIR/iqpe-governance-workflow/prompts/productWorkflowPack/mcp-usage-evidence-template.md" "$TARGET_ROOT/docs/tooling/mcp-usage-evidence.md"
fi

echo "[8/8] Running local bootstrap+preflight evidence generator..."
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
- $MCP_BIN
- $TARGET_ROOT/docs/tooling/bootstrap-report.md
- $TARGET_ROOT/docs/tooling/workflow-preflight.json
- $TARGET_ROOT/docs/tooling/spec-tech-detect.json
- $TARGET_ROOT/docs/tooling/mcp-usage-evidence.md

Next steps in your target project:
1) Open the repo in VS Code/Cursor.
2) Start at .iqpe-workflow/productWorkflowPack/00-orchestrator.md
3) Keep docs/tooling/mcp-usage-evidence.md updated as phases execute.
EOF

if [[ "$KEEP_TMP" == true ]]; then
  echo "Temporary clones retained at: $TMP_DIR"
fi
