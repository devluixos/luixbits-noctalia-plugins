#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python - "$repo_root" <<'PY'
import json
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])

ENTRY_KINDS = ("widget", "service", "shortcut", "desktop_widget", "launcher_provider")

def flatten_json(value, prefix=""):
    if isinstance(value, dict):
        flattened = {}
        for key, child in value.items():
            child_prefix = f"{prefix}.{key}" if prefix else key
            flattened.update(flatten_json(child, child_prefix))
        return flattened
    return {prefix: value}

def iter_settings(manifest):
    for setting in manifest.get("setting", []):
        yield setting
    for kind in ENTRY_KINDS:
        for item in manifest.get(kind, []):
            for setting in item.get("setting", []):
                yield setting

catalog_path = root / "catalog.toml"
catalog = tomllib.loads(catalog_path.read_text())

for path in root.rglob("pyproject.toml"):
    tomllib.loads(path.read_text())

for path in root.rglob("manifest.json"):
    manifest = json.loads(path.read_text())
    plugin_id = manifest.get("id", "")
    if not plugin_id:
        raise SystemExit(f"QML manifest has no id: {path}")

    entry_points = manifest.get("entryPoints", {})
    for key in ("main", "barWidget", "panel", "settings"):
        entry = entry_points.get(key)
        if not entry:
            raise SystemExit(f"{plugin_id} QML manifest missing entryPoints.{key}")
        if not (path.parent / entry).exists():
            raise SystemExit(f"{plugin_id} QML entryPoints.{key} missing file: {entry}")

    i18n_dir = path.parent / "i18n"
    if i18n_dir.exists():
        for translation_path in i18n_dir.glob("*.json"):
            json.loads(translation_path.read_text())

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

    for kind in ENTRY_KINDS:
        for item in manifest.get(kind, []):
            script = item.get("entry")
            if script and not (plugin_dir / script).exists():
                raise SystemExit(f"{plugin_id} {kind} entry missing script: {script}")

    translations = {}
    translations_dir = plugin_dir / "translations"
    if translations_dir.exists():
        for path in translations_dir.glob("*.json"):
            translations[path.stem] = flatten_json(json.loads(path.read_text()))

    required_keys = []
    for setting in iter_settings(manifest):
        for field in ("label_key", "description_key"):
            value = setting.get(field)
            if value:
                required_keys.append(value)

    if required_keys:
        english = translations.get("en")
        if english is None:
            raise SystemExit(f"{plugin_id} uses translation keys but has no translations/en.json")
        for key in sorted(set(required_keys)):
            if key not in english:
                raise SystemExit(f"{plugin_id} missing English translation key: {key}")

print("ok")
PY
