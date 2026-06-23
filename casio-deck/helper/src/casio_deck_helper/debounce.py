from __future__ import annotations

import time
from dataclasses import dataclass


@dataclass
class TriggerDebouncer:
    debounce_seconds: float
    last_trigger: str = ""
    last_emit_at: float = 0.0

    def reset(self) -> None:
        self.last_trigger = ""

    def should_emit(self, trigger: str) -> bool:
        if not trigger:
            self.reset()
            return False

        now = time.monotonic()
        if trigger == self.last_trigger:
            return False
        if now - self.last_emit_at < self.debounce_seconds:
            return False

        self.last_trigger = trigger
        self.last_emit_at = now
        return True
