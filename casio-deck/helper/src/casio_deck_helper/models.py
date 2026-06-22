from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CasioModelAdapter:
    id: str
    aliases: tuple[str, ...]
    display_name: str
    module_number: str
    support: str
    scan_keywords: tuple[str, ...]
    triggers: tuple[str, ...]
    capabilities: tuple[str, ...]

    def matches_name(self, name: str) -> bool:
        upper = (name or "").upper()
        if not upper:
            return False
        return any(keyword in upper for keyword in self.scan_keywords)


ABL100WE = CasioModelAdapter(
    id="casio_abl100we_3565",
    aliases=("abl100we", "abl100", "casio_abl100we", "casio_abl100we_3565", "module_3565"),
    display_name="Casio ABL-100WE-1A",
    module_number="3565",
    support="experimental",
    scan_keywords=("ABL", "ABL-100", "3565", "CASIO"),
    triggers=("lower_left", "lower_right", "timeplace", "finder", "unknown"),
    capabilities=("ble_connection", "button_events", "timeplace", "finder"),
)

MODELS: dict[str, CasioModelAdapter] = {
    ABL100WE.id: ABL100WE,
}

ALIASES: dict[str, str] = {
    alias: model.id for model in MODELS.values() for alias in model.aliases
}


def normalize_model_id(value: str) -> str:
    normalized = (value or "").strip().lower().replace("-", "_").replace(" ", "_")
    return ALIASES.get(normalized, normalized)


def get_model(value: str) -> CasioModelAdapter:
    model_id = normalize_model_id(value)
    try:
        return MODELS[model_id]
    except KeyError as exc:
        known = ", ".join(sorted({*MODELS.keys(), *ALIASES.keys()}))
        raise ValueError(f"unsupported model {value!r}; known models: {known}") from exc


def cli_model_choices() -> list[str]:
    choices = set(MODELS.keys())
    choices.update(ALIASES.keys())
    return sorted(choices)


def emit_model_lines(emit, model: CasioModelAdapter) -> None:
    display = model.display_name.replace(" ", "_")
    emit("model", model.id, display, f"module={model.module_number}", f"support={model.support}")
    emit("capabilities", model.id, ",".join(model.triggers))
