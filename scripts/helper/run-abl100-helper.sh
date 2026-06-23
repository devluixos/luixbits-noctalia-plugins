#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
helper_dir="$repo_root/casio-deck/helper"

if command -v uv >/dev/null 2>&1; then
  exec uv run --project "$helper_dir" python -m casio_deck_helper.cli "$@"
fi

if command -v nix >/dev/null 2>&1; then
  exec nix shell nixpkgs#uv nixpkgs#bluez --command \
    uv run --project "$helper_dir" python -m casio_deck_helper.cli "$@"
fi

cat >&2 <<'EOF'
error: neither uv nor nix is available.

Install uv, or run on Nix/NixOS with nix available:
  nix shell nixpkgs#uv nixpkgs#bluez
EOF
exit 127
