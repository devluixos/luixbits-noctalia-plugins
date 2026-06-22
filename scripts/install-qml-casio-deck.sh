#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root/casio-deck/qml"
target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins/casio-deck"

if [[ ! -d "$source_dir" ]]; then
  echo "missing QML plugin directory: $source_dir" >&2
  exit 1
fi

mkdir -p "$(dirname "$target_dir")"

if [[ -e "$target_dir" && ! -L "$target_dir" ]]; then
  echo "refusing to replace non-symlink path: $target_dir" >&2
  echo "move it away first if you want to install the local Casio Deck QML UI" >&2
  exit 1
fi

ln -sfn "$source_dir" "$target_dir"

echo "installed Casio Deck QML UI:"
echo "$target_dir -> $source_dir"
echo
echo "Restart/reload Noctalia, then add the 'casio-deck' QML plugin bar widget if your Noctalia build supports QML plugins."
