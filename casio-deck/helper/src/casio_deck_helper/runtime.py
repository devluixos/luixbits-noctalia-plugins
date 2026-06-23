from __future__ import annotations

import argparse
from typing import Protocol

from .adapters.abl100.runtime import Abl100Adapter
from .model_types import CasioModelAdapter
from .models import ABL100WE


class WatchRuntime(Protocol):
    model: CasioModelAdapter

    async def scan_only(self, args: argparse.Namespace) -> int:
        ...

    async def setup_pairing(self, args: argparse.Namespace) -> int:
        ...

    async def run_connected_session(self, args: argparse.Namespace) -> bool:
        ...


def get_runtime(model: CasioModelAdapter) -> WatchRuntime:
    if model.id == ABL100WE.id:
        return Abl100Adapter(model)
    raise ValueError(f"model {model.id!r} has no helper runtime")
