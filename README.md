# iqpe-demo

Demo helper repository for scaffolding a local IQPE testing environment on:

- Ubuntu 24.04 (Linux)
- macOS

## What it does

The scaffold script:

1. Detects platform (`linux`/`darwin`) and validates support assumptions.
2. Creates a local workspace structure.
3. Clones (or updates) IQPE repositories used for testing.
4. Generates a VS Code workspace file for quick opening.
5. Runs optional validation checks, including `v2-demo-readiness`.

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

### Useful flags

- `--root <path>`: workspace target directory (default: `./iqpe-demo-workspace`)
- `--org <github-org>`: GitHub org/user (default: `orbsfoc`)
- `--https`: use HTTPS clone URLs (default is SSH)
- `--skip-clone`: do not clone/update repos
- `--skip-checks`: do not run `go test` and readiness checks
- `--help`: show usage

## Default cloned repos

- `iqpe-governance-workflow`
- `iqpe-mcp-runtime`
- `iqpe-skill-pack`
- `iqpe-architecture-standards`
- `iqpe-library-catalog`
- `iqpe-product-template`
