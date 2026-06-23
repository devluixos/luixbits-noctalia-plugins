from __future__ import annotations

import argparse
import asyncio
import contextlib
import sys
import traceback
from typing import Any

from ...bluez import (
    bluez_device_info,
    is_bluez_paired,
    paired_model_address,
    remove_bluez_device,
    trust_bluez_device,
)
from ...model_types import CasioModelAdapter
from ...protocol import await_library, emit, emit_state, emit_trace, log, safe_field
from .device import watch_name_filter


async def connect_watch(args: argparse.Namespace, model: CasioModelAdapter) -> tuple[Any, Any] | None:
    try:
        from gshock_api.connection import Connection
        from gshock_api.gshock_api import GshockAPI
        from gshock_api.watch_info import watch_info
    except Exception as exc:  # pragma: no cover - depends on optional runtime deps
        emit("error", f"missing gshock-api dependency: {exc}")
        print(f"missing gshock-api dependency: {exc}", file=sys.stderr, flush=True)
        return None

    address = args.address.strip() or None
    connection = Connection(address=address)
    emit_state("listening" if getattr(args, "listener", False) else "connecting")
    log("waiting for ABL-100WE connection...", debug=args.debug)
    connected = await await_library(connection.connect(watch_name_filter(args)))
    if not connected:
        return None

    api = GshockAPI(connection)
    watch_name = safe_field(getattr(watch_info, "name", ""), "unknown")
    watch_address = safe_field(
        getattr(watch_info, "address", "") or connection.address or address,
        "unknown",
    )
    emit("connect")
    emit("watch", model.id, watch_name, watch_address)
    emit_state("connected")
    return connection, api


async def connect_app_watch(args: argparse.Namespace, model: CasioModelAdapter) -> tuple[Any, Any] | None:
    try:
        from gshock_api import message_dispatcher
        from bleak import BleakClient, BleakScanner
        from gshock_api.casio_constants import CasioConstants
        from gshock_api.connection import Connection
        from gshock_api.gshock_api import GshockAPI
        from gshock_api.scanner import scanner
        from gshock_api.watch_info import watch_info
    except Exception as exc:  # pragma: no cover - depends on optional runtime deps
        emit("error", f"missing gshock-api dependency: {exc}")
        print(f"missing gshock-api dependency: {exc}", file=sys.stderr, flush=True)
        return None

    saved_address = args.address.strip() or paired_model_address(model)
    if args.repair_pairing and saved_address:
        emit_trace("bluez_repair", f"remove={saved_address}")
        if remove_bluez_device(saved_address):
            emit_trace("bluez_repair", "removed")
        else:
            emit_trace("bluez_repair", "remove_failed")

    address = args.address.strip()
    if address == "" and not args.repair_pairing:
        address = saved_address
    if address == "":
        address = None

    connection = Connection(address=address)
    original_write = connection.write
    session: dict[str, Any] = {"app_info_future": None}
    connection.casio_deck_session = session

    async def quiet_write(handle: int, data: bytes | str) -> None:
        emit_trace("write", f"handle=0x{handle:02x}", f"data={safe_field(data)}")
        with contextlib.redirect_stdout(sys.stderr):
            await original_write(handle, data)

    def notification_handler(characteristic: Any, data: bytearray) -> None:
        uuid = safe_field(getattr(characteristic, "uuid", characteristic), "unknown")
        payload = bytes(data).hex()
        log(f"raw notify {uuid} {payload}", debug=args.debug)
        emit("raw", uuid, payload)
        emit_trace("notify", uuid, payload)
        if data and data[0] == 0xFF:
            rejected = f"{data[-1]:02X}" if len(data) >= 3 else "unknown"
            emit_trace("watch_error", f"rejected={rejected}", payload)
        if data and data[0] == 0x22:
            future = session.get("app_info_future")
            if future is not None and not future.done():
                future.set_result(bytes(data))
            return

        try:
            message_dispatcher.MessageDispatcher.on_received(data)
        except Exception as exc:
            log(f"dispatcher ignored raw packet {payload}: {exc}", debug=args.debug)
            emit_trace("dispatcher_ignored", payload, str(exc))

    connection.write = quiet_write
    connection.notification_handler = notification_handler

    emit_state("listening" if getattr(args, "listener", False) else "connecting")
    if address:
        bluez_info = bluez_device_info(address)
        emit_trace(
            "bluez_device",
            f"address={address}",
            f"paired={bluez_info.get('paired', 'unknown')}",
            f"bonded={bluez_info.get('bonded', 'unknown')}",
            f"trusted={bluez_info.get('trusted', 'unknown')}",
            f"connected={bluez_info.get('connected', 'unknown')}",
        )
    emit_trace("connect_start", f"model={model.id}", f"address={safe_field(address, 'scan')}")
    log("waiting for ABL-100WE app-session connection...", debug=args.debug)

    if connection.address is None:
        emit_trace("scan_start", f"model={model.id}")
        device = await await_library(scanner.scan(watch_filter=watch_name_filter(args)))
        if device is None:
            emit_trace("scan_result", "not_found")
            return None
        connection.address = device.address
        emit_trace("scan_result", safe_field(getattr(device, "name", ""), "unknown"), connection.address)

    async def connect_client(pair: bool) -> bool:
        emit_trace("ble_connect_start", f"pair={pair}", f"address={connection.address}")
        emit_trace("ble_find_start", f"address={connection.address}", f"timeout={args.scan_timeout}")
        device = await await_library(
            BleakScanner.find_device_by_address(
                connection.address,
                timeout=max(args.scan_timeout, 1.0),
            )
        )
        if device is None:
            emit_trace("ble_find_result", "not_found")
            return False

        emit_trace(
            "ble_find_result",
            safe_field(getattr(device, "name", ""), "unknown"),
            safe_field(getattr(device, "address", ""), "unknown"),
        )
        emit_state("pairing" if pair else "connecting")
        connection.client = BleakClient(
            device,
            pair=pair,
            timeout=max(args.connect_timeout, 1.0),
        )
        await asyncio.wait_for(
            await_library(connection.client.connect()),
            timeout=max(args.connect_timeout, 1.0),
        )
        connected = getattr(connection.client, "is_connected", False)
        emit_trace("ble_connect_result", f"pair={pair}", f"connected={connected}")
        return connected

    paired = is_bluez_paired(safe_field(connection.address, ""))
    emit_trace("pair_decision", f"already_paired={paired}", f"pair_requested={args.pair}")

    connected = False
    if args.pair and not paired:
        emit_state("pairing")
        try:
            connected = await connect_client(pair=True)
        except Exception as exc:
            emit_trace("pair_failed", str(exc))
            log(f"pair/connect failed, retrying without OS pairing: {exc}", debug=args.debug)
            if args.debug:
                traceback.print_exc(file=sys.stderr)

    if not connected:
        if not getattr(args, "listener", False):
            emit_state("connecting")
        try:
            connected = await connect_client(pair=False)
        except Exception as exc:
            emit("error", f"app-session connection failed: {exc}")
            log(f"app-session connection failed: {exc}", debug=args.debug)
            if args.debug:
                traceback.print_exc(file=sys.stderr)
            return None

    if not connected or connection.client is None:
        emit_trace("connect_result", "failed")
        return None

    emit_trace("ble_settle_wait", "1.0s")
    await asyncio.sleep(1.0)

    trust_bluez_device(safe_field(connection.address, ""))
    post_connect_bluez_info = bluez_device_info(safe_field(connection.address, ""))
    emit_trace(
        "bluez_after_connect",
        f"paired={post_connect_bluez_info.get('paired', 'unknown')}",
        f"bonded={post_connect_bluez_info.get('bonded', 'unknown')}",
        f"trusted={post_connect_bluez_info.get('trusted', 'unknown')}",
        f"connected={post_connect_bluez_info.get('connected', 'unknown')}",
    )

    await await_library(connection.init_characteristics_map())
    emit_trace("characteristics", f"count={len(connection.characteristics_map)}")
    for uuid in sorted(connection.characteristics_map.keys()):
        emit_trace("characteristic", uuid)
    await await_library(
        connection.client.start_notify(
            CasioConstants.CASIO_ALL_FEATURES_CHARACTERISTIC_UUID,
            connection.notification_handler,
        )
    )
    emit_trace("notify_enabled", CasioConstants.CASIO_ALL_FEATURES_CHARACTERISTIC_UUID)

    api = GshockAPI(connection)
    watch_name = safe_field(getattr(watch_info, "name", ""), model.display_name.replace(" ", "_"))
    watch_address = safe_field(
        getattr(watch_info, "address", "") or connection.address or address,
        "unknown",
    )
    emit("connect")
    emit("watch", model.id, watch_name, watch_address)
    emit_state("connected")
    emit_trace("connect_result", "gatt_connected", watch_name, watch_address)
    return connection, api


async def disconnect_watch(connection: Any) -> None:
    try:
        await await_library(connection.disconnect())
    finally:
        emit("disconnect")
        emit_state("disconnected")
