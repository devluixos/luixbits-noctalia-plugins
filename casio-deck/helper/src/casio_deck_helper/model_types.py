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
