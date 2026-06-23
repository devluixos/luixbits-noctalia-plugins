#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

script_roots=(
  "$repo_root/scripts"
)

for script_root in "${script_roots[@]}"; do
  [ -d "$script_root" ] || continue
  while IFS= read -r -d '' script; do
    bash -n "$script"
  done < <(find "$script_root" -type f -name '*.sh' -print0)
done

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

def split_deck_list(value):
    return [item.strip() for item in (value or "").split(",") if item.strip()]

def parse_deck_fields(parts, start_index):
    fields = {}
    for part in parts[start_index:]:
        key, separator, value = part.partition("=")
        if not separator:
            raise ValueError(f"invalid field {part!r}")
        if value == "true":
            fields[key] = True
        elif value == "false":
            fields[key] = False
        else:
            fields[key] = value
    return fields

def parse_deck_file(path):
    parsed = {
        "order": [],
        "models": {},
        "preset_order": [],
        "presets": {},
        "trigger_order": [],
        "triggers": {},
    }
    known = {"order", "model", "preset_order", "preset", "trigger_order", "trigger"}

    for lineno, line in enumerate(path.read_text().splitlines(), start=1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        kind = parts[0]
        if kind not in known:
            raise SystemExit(f"{path}:{lineno} unknown deck row type: {kind}")

        if kind == "order":
            parsed["order"] = split_deck_list(parts[1] if len(parts) > 1 else "")
        elif kind == "model":
            if len(parts) < 2 or not parts[1]:
                raise SystemExit(f"{path}:{lineno} model row is missing id")
            model = parse_deck_fields(parts, 2)
            model["id"] = parts[1]
            model["aliases"] = split_deck_list(model.get("aliases", ""))
            model["triggers"] = split_deck_list(model.get("triggers", ""))
            model["capabilities"] = split_deck_list(model.get("capabilities", ""))
            parsed["models"][parts[1]] = model
        elif kind == "preset_order":
            parsed["preset_order"] = split_deck_list(parts[1] if len(parts) > 1 else "")
        elif kind == "preset":
            if len(parts) < 2 or not parts[1]:
                raise SystemExit(f"{path}:{lineno} preset row is missing id")
            parsed["presets"][parts[1]] = parse_deck_fields(parts, 2)
        elif kind == "trigger_order":
            parsed["trigger_order"] = split_deck_list(parts[1] if len(parts) > 1 else "")
        elif kind == "trigger":
            if len(parts) < 2 or not parts[1]:
                raise SystemExit(f"{path}:{lineno} trigger row is missing id")
            parsed["triggers"][parts[1]] = parse_deck_fields(parts, 2)

    return parsed

catalog_path = root / "catalog.toml"
catalog = tomllib.loads(catalog_path.read_text())

for path in root.rglob("pyproject.toml"):
    tomllib.loads(path.read_text())

for path in root.rglob("manifest.json"):
    if "archive" in path.relative_to(root).parts:
        continue

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

    data_dir = plugin_dir / "data"
    deck_files = {}
    if data_dir.exists():
        for path in data_dir.glob("*.deck"):
            deck_files[path.name] = parse_deck_file(path)

    models_data = deck_files.get("models.deck")
    if models_data is not None:
        models = models_data.get("models", {})
        for model_id in models_data.get("order", []):
            if model_id not in models:
                raise SystemExit(f"{plugin_id} model order references unknown model: {model_id}")

    actions_data = deck_files.get("actions.deck")
    if actions_data is not None:
        presets = actions_data.get("presets", {})
        for preset_id in actions_data.get("preset_order", []):
            if preset_id not in presets:
                raise SystemExit(f"{plugin_id} action preset_order references unknown preset: {preset_id}")
        triggers = actions_data.get("triggers", {})
        for trigger_id in actions_data.get("trigger_order", []):
            if trigger_id not in triggers:
                raise SystemExit(f"{plugin_id} action trigger_order references unknown trigger: {trigger_id}")

    if models_data is not None and actions_data is not None:
        triggers = actions_data.get("triggers", {})
        for model_id, model in models_data.get("models", {}).items():
            for trigger_id in model.get("triggers", []):
                if trigger_id not in triggers:
                    raise SystemExit(
                        f"{plugin_id} model {model_id} references unknown trigger: {trigger_id}"
                    )

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

    preset_selects = []
    for setting in iter_settings(manifest):
        key = setting.get("key", "")
        if key.endswith("_preset") and setting.get("type") == "select":
            options = tuple(
                (option.get("value", ""), option.get("label", ""))
                for option in setting.get("options", [])
            )
            preset_selects.append((key, options))

    if preset_selects:
        reference_key, reference_options = preset_selects[0]
        for key, options in preset_selects[1:]:
            if options != reference_options:
                raise SystemExit(
                    f"{plugin_id} preset select {key} does not match {reference_key}"
                )

print("ok")
PY

if [ -d "$repo_root/casio-deck/helper/tests" ]; then
  PYTHONPATH="$repo_root/casio-deck/helper/src" \
    python -m unittest discover -s "$repo_root/casio-deck/helper/tests" -p 'test_*.py'
fi
