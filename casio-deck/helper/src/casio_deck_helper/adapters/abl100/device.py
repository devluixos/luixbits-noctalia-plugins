from __future__ import annotations

import argparse
import sys
from collections.abc import Callable
from typing import Any

from ...model_types import CasioModelAdapter
from ...protocol import await_library, emit, emit_trace, safe_field


def device_name(device: Any, advertisement_data: Any | None = None) -> str:
    name = getattr(device, "name", "") or ""
    if name:
        return str(name)
    if advertisement_data is not None:
        name = getattr(advertisement_data, "local_name", "") or ""
    return str(name or "")


def device_address(device: Any) -> str:
    return safe_field(getattr(device, "address", ""), "unknown")


def watch_name_filter(args: argparse.Namespace) -> Callable[[str], bool]:
    model = args.model_adapter

    def is_supported(name: str) -> bool:
        if not model.matches_name(name):
            return False
        try:
            from gshock_api.always_connected_watch_filter import (
                always_connected_watch_filter as watch_filter,
            )

            return watch_filter.connection_filter(name)
        except Exception:
            return True

    return is_supported


async def scan_only(args: argparse.Namespace) -> int:
    model: CasioModelAdapter = args.model_adapter
    try:
        from bleak import BleakScanner
    except Exception as exc:  # pragma: no cover - depends on optional runtime deps
        emit("error", f"missing bleak dependency: {exc}")
        print(f"missing bleak dependency: {exc}", file=sys.stderr, flush=True)
        return 1

    emit_trace("scan_only start", f"timeout={args.scan_timeout}")
    devices = await await_library(BleakScanner.discover(timeout=args.scan_timeout))
    for device in devices:
        name = device.name or "-"
        address = device.address or "-"
        print(f"scan {name} {address}", file=sys.stderr, flush=True)
        emit_trace("scan_seen", safe_field(name, "-"), safe_field(address, "-"))
        if model.matches_name(name):
            emit("scan", model.id, name, address, model.support)
    return 0
