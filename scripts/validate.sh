#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python - "$repo_root" <<'PY'
import json
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])

catalog_path = root / "catalog.toml"
catalog = tomllib.loads(catalog_path.read_text())
plugins = catalog.get("plugin", [])
if not plugins:
    raise SystemExit("catalog.toml does not contain any [[plugin]] entries")

seen = set()
for entry in plugins:
    plugin_id = entry.get("id", "")
    if "/" not in plugin_id:
        raise SystemExit(f"invalid plugin id in catalog: {plugin_id!r}")
    if plugin_id in seen:
        raise SystemExit(f"duplicate catalog plugin id: {plugin_id}")
    seen.add(plugin_id)

    plugin_dir = root / plugin_id.split("/", 1)[1]
    manifest_path = plugin_dir / "plugin.toml"
    if not manifest_path.exists():
        raise SystemExit(f"missing manifest for {plugin_id}: {manifest_path}")

    manifest = tomllib.loads(manifest_path.read_text())
    if manifest.get("id") != plugin_id:
        raise SystemExit(
            f"manifest id mismatch for {plugin_id}: {manifest.get('id')!r}"
        )

    for kind in ("widget", "service", "shortcut", "desktop_widget", "launcher_provider"):
        for item in manifest.get(kind, []):
            script = item.get("entry")
            if script and not (plugin_dir / script).exists():
                raise SystemExit(f"{plugin_id} {kind} entry missing script: {script}")

    translations_dir = plugin_dir / "translations"
    if translations_dir.exists():
        for path in translations_dir.glob("*.json"):
            json.loads(path.read_text())

print("ok")
PY
