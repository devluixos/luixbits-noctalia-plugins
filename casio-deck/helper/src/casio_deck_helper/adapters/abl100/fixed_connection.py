from __future__ import annotations

import argparse
import sys
import traceback
from typing import Any

from ...model_types import CasioModelAdapter
from ...protocol import await_library, emit, emit_state, log, safe_field
from .device import device_name


async def find_fixed_mode_device(args: argparse.Namespace, model: CasioModelAdapter) -> Any | None:
    try:
        from bleak import BleakScanner
    except Exception as exc:  # pragma: no cover - depends on optional runtime deps
        emit("error", f"missing bleak dependency: {exc}")
        print(f"missing bleak dependency: {exc}", file=sys.stderr, flush=True)
        return None

    address = args.address.strip()
    if address:
        log(f"fixed mode scanning for address {address}", debug=args.debug)
        return await await_library(
            BleakScanner.find_device_by_address(address, timeout=args.scan_timeout)
        )

    def matches(device: Any, advertisement_data: Any) -> bool:
        return model.matches_name(device_name(device, advertisement_data))

    log("fixed mode scanning for ABL-100WE advertisement", debug=args.debug)
    return await await_library(
        BleakScanner.find_device_by_filter(matches, timeout=args.scan_timeout)
    )


async def connect_fixed_client(args: argparse.Namespace, device: Any) -> Any | None:
    try:
        from bleak import BleakClient
    except Exception as exc:  # pragma: no cover - depends on optional runtime deps
        emit("error", f"missing bleak dependency: {exc}")
        print(f"missing bleak dependency: {exc}", file=sys.stderr, flush=True)
        return None

    async def attempt(pair: bool) -> Any:
        client = BleakClient(device, timeout=max(args.scan_timeout, 10.0), pair=pair)
        await await_library(client.connect())
        return client

    if args.pair:
        emit_state("pairing")
        try:
            return await attempt(pair=True)
        except Exception as exc:
            log(f"pair/connect failed, retrying without pairing: {exc}", debug=args.debug)
            if args.debug:
                traceback.print_exc(file=sys.stderr)

    emit_state("connecting")
    try:
        return await attempt(pair=False)
    except Exception as exc:
        emit("error", f"fixed connection failed: {exc}")
        log(f"fixed connection failed: {exc}", debug=args.debug)
        if args.debug:
            traceback.print_exc(file=sys.stderr)
        return None


async def subscribe_fixed_notifications(client: Any, args: argparse.Namespace) -> int:
    services = getattr(client, "services", None)
    if services is None and hasattr(client, "get_services"):
        services = await await_library(client.get_services())

    subscribed = 0

    def on_notify(sender: Any, data: bytearray) -> None:
        uuid = safe_field(getattr(sender, "uuid", sender), "unknown")
        payload = bytes(data).hex()
        log(f"raw notify {uuid} {payload}", debug=args.debug)
        emit("raw", uuid, payload)

    for service in services or []:
        for characteristic in getattr(service, "characteristics", []):
            properties = set(getattr(characteristic, "properties", []) or [])
            if "notify" not in properties and "indicate" not in properties:
                continue
            try:
                await await_library(client.start_notify(characteristic, on_notify))
                subscribed += 1
                log(
                    f"subscribed to {getattr(characteristic, 'uuid', characteristic)}",
                    debug=args.debug,
                )
            except Exception as exc:
                log(
                    f"could not subscribe to {getattr(characteristic, 'uuid', characteristic)}: {exc}",
                    debug=args.debug,
                )

    if subscribed > 0:
        emit_state("subscribed")
    else:
        emit_state("connected")
        log("fixed mode found no notifiable characteristics", debug=args.debug)

    return subscribed
