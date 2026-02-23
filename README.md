# iqpe-demo

Demo helper repository for scaffolding a local IQPE testing environment on:

- Ubuntu 24.04 (Linux)
- macOS

## What it does

The scaffold script:

1. Detects platform (`linux`/`darwin`) and validates support assumptions.
2. Creates a local workspace structure.
3. Clones (or updates) IQPE repositories used for testing.
4. Configures editor setup for VS Code, Cursor, or both.
5. Generates a workspace file and helper open scripts.
6. Runs optional validation checks, including `v2-demo-readiness`.

## OS and shell-tool compatibility

- Script logic avoids GNU-only flags (for example, no `readlink -f`).
- Path normalization is done in Bash for Linux/macOS parity.
- Linux flow is tuned for Ubuntu 24.04, with warnings for other Linux variants.
- macOS flow runs with default Bash + standard CLI behavior.

## Prerequisites

- `bash`
- `git`
- `go` (required for runtime checks)
- Access to the IQPE repos on GitHub

## Usage

```bash
chmod +x scripts/scaffold-local-env.sh
./scripts/scaffold-local-env.sh
```

## One-command bootstrap

Run doctor + scaffold in sequence:

```bash
chmod +x scripts/bootstrap-all.sh
./scripts/bootstrap-all.sh
```

## New clean project bootstrap (from GitHub)

Use this when you already have a fresh target repo and a PRD/spec directory.
The script fetches workflow prompts and required skills from GitHub repos (no local file copy).

```bash
chmod +x scripts/bootstrap-new-project.sh
./scripts/bootstrap-new-project.sh --target-root /abs/path/to/new-project --spec-dir /abs/path/to/new-project/prd
```

Useful options:

- `--org <github-org>` (default: `orbsfoc`)
- `--ref <branch-or-tag>` (default: `main`)
- `--keep-tmp` (retain temporary clone workspace)

Useful options:

- `--editor auto|vscode|cursor|both|none`
- `--install-editor-extensions`
- `--https`
- `--skip-clone`
- `--skip-checks`
- `--no-strict-doctor`

## Environment doctor

Run prerequisite diagnostics (Linux/macOS aware):

```bash
chmod +x scripts/doctor.sh
./scripts/doctor.sh
```

Useful options:

- `--strict`: exit non-zero when required checks fail
- `--editor auto|vscode|cursor|both|none`: editor-aware checks

## Status report

Generate a markdown summary of local tooling, cloned repos, and readiness report state:

```bash
chmod +x scripts/status-report.sh
./scripts/status-report.sh
```

Useful options:

- `--root <path>`: workspace root to inspect
- `--out <file>`: custom markdown output path

## Teardown / reset

```bash
chmod +x scripts/destroy-local-env.sh
./scripts/destroy-local-env.sh --yes
```

Useful options:

- `--root <path>`: remove a non-default workspace location
- `--keep-logs`: preserve `logs/` while removing the rest
- `--yes`: skip confirmation prompt

### Useful flags

- `--root <path>`: workspace target directory (default: `./iqpe-demo-workspace`)
- `--org <github-org>`: GitHub org/user (default: `orbsfoc`)
- `--editor <mode>`: `auto|vscode|cursor|both|none` (default: `auto`)
- `--install-editor-extensions`: attempt to install recommended extensions
- `--https`: use HTTPS clone URLs (default is SSH)
- `--skip-clone`: do not clone/update repos
- `--skip-checks`: do not run `go test` and readiness checks
- `--help`: show usage

## Editor setup script

You can run editor setup independently:

```bash
./scripts/setup-editor.sh --root ./iqpe-demo-workspace --editor both
```

Generated helpers:

- `iqpe-demo-workspace/open-vscode.sh`
- `iqpe-demo-workspace/open-cursor.sh`

## Default cloned repos

- `iqpe-governance-workflow`
- `iqpe-mcp-runtime`
- `iqpe-skill-pack`
- `iqpe-architecture-standards`
- `iqpe-library-catalog`
- `iqpe-product-template`
