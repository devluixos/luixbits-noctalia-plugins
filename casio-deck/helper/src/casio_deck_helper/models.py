from __future__ import annotations

from .adapters.abl100.model import MODEL as ABL100WE
from .model_types import CasioModelAdapter

# Helper model registry.
#
# Add future watch adapters by importing their MODEL here and appending it to
# REGISTERED_MODELS. The Noctalia UI model list is separately declared in
# casio-deck/data/models.deck.
REGISTERED_MODELS: tuple[CasioModelAdapter, ...] = (
    ABL100WE,
)

MODELS: dict[str, CasioModelAdapter] = {
    model.id: model for model in REGISTERED_MODELS
}

ALIASES: dict[str, str] = {
    alias: model.id for model in REGISTERED_MODELS for alias in model.aliases
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
