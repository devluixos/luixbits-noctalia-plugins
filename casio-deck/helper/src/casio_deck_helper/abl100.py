from __future__ import annotations

import argparse
import asyncio
import sys
import time
import traceback
from collections.abc import Callable
from typing import Any

from .models import CasioModelAdapter, cli_model_choices, emit_model_lines, get_model

VERSION = "0.1.0"


def emit(*parts: object) -> None:
    print(" ".join(str(part) for part in parts), flush=True)


def log(message: str, *, debug: bool = False) -> None:
    if debug:
        print(message, file=sys.stderr, flush=True)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Experimental Casio Bluetooth helper for Casio Deck."
    )
    parser.add_argument("--model", default="abl100we", choices=cli_model_choices())
    parser.add_argument("--address", default="", help="Optional BLE address to connect to.")
    parser.add_argument("--scan-only", action="store_true", help="Only scan and print candidate devices.")
    parser.add_argument("--once", action="store_true", help="Connect once and exit.")
    parser.add_argument("--loop", action="store_true", help="Keep waiting for watch connections.")
    parser.add_argument("--debug", action="store_true", help="Print detailed diagnostics to stderr.")
    parser.add_argument("--scan-timeout", type=float, default=10.0, help="Seconds for --scan-only.")
    parser.add_argument(
        "--button-timeout",
        type=float,
        default=10.0,
        help="Seconds to wait for gshock-api pressed-button decoding.",
    )
    return parser.parse_args(argv)


def selected_model(args: argparse.Namespace) -> CasioModelAdapter:
    return get_model(args.model)


async def scan_only(args: argparse.Namespace) -> int:
    model = selected_model(args)
    try:
        from bleak import BleakScanner
    except Exception as exc:  # pragma: no cover - depends on optional runtime deps
        emit("error", f"missing bleak dependency: {exc}")
        print(f"missing bleak dependency: {exc}", file=sys.stderr, flush=True)
        return 1

    devices = await BleakScanner.discover(timeout=args.scan_timeout)
    for device in devices:
        name = device.name or "-"
        address = device.address or "-"
        print(f"scan {name} {address}", file=sys.stderr, flush=True)
        if model.matches_name(name):
            emit("scan", model.id, name, address, model.support)
    return 0


def watch_name_filter(args: argparse.Namespace) -> Callable[[str], bool]:
    model = selected_model(args)

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


def button_to_trigger(button: Any) -> str:
    raw_name = getattr(button, "name", str(button))
    name = str(raw_name).upper()
    mapping = {
        "LOWER_LEFT": "lower_left",
        "LOWER_RIGHT": "lower_right",
        "FIND": "finder",
        "NO_BUTTON": "unknown",
        "INVALID": "unknown",
    }
    return mapping.get(name, "unknown")


async def read_watch_once(args: argparse.Namespace) -> bool:
    model = selected_model(args)
    try:
        from gshock_api.connection import Connection
        from gshock_api.gshock_api import GshockAPI
        from gshock_api.watch_info import watch_info
    except Exception as exc:  # pragma: no cover - depends on optional runtime deps
        emit("error", f"missing gshock-api dependency: {exc}")
        print(f"missing gshock-api dependency: {exc}", file=sys.stderr, flush=True)
        return False

    address = args.address.strip() or None
    connection = Connection(address=address)
    log("waiting for ABL-100WE connection...", debug=args.debug)
    connected = await connection.connect(watch_name_filter(args))
    if not connected:
        emit("error", "no compatible Casio watch connected")
        return False

    emit("connect")

    api = GshockAPI(connection)
    watch_name = getattr(watch_info, "name", "") or "unknown"
    watch_address = getattr(watch_info, "address", "") or connection.address or address or "unknown"
    emit("watch", model.id, watch_name, watch_address)

    try:
        button = await asyncio.wait_for(
            api.get_pressed_button(),
            timeout=args.button_timeout,
        )
        trigger = button_to_trigger(button)
        log(f"raw pressed button: {button!r} -> {trigger}", debug=args.debug)
    except Exception as exc:
        trigger = "unknown"
        emit("error", f"could not decode pressed button: {exc}")
        if args.debug:
            traceback.print_exc(file=sys.stderr)

    emit("press", trigger)

    try:
        await connection.disconnect()
    finally:
        emit("disconnect")
    return True


async def run(args: argparse.Namespace) -> int:
    model = selected_model(args)
    emit("ready", "casio-deck-helper", VERSION, model.id)
    emit_model_lines(emit, model)

    if args.scan_only:
        return await scan_only(args)

    loop = args.loop or not args.once
    while True:
        await read_watch_once(args)
        if not loop:
            return 0
        await asyncio.sleep(1)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    started = time.strftime("%Y-%m-%d %H:%M:%S")
    log(f"abl100 helper started at {started}", debug=args.debug)
    try:
        return asyncio.run(run(args))
    except KeyboardInterrupt:
        emit("disconnect")
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
