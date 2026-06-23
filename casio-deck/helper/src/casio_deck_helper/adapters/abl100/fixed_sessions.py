from __future__ import annotations

import argparse
import asyncio
import time

from ...model_types import CasioModelAdapter
from ...protocol import await_library, emit, emit_state, emit_trace, log, safe_field
from .app_connection import connect_app_watch, disconnect_watch
from .device import device_address, device_name
from .fixed_connection import connect_fixed_client, find_fixed_mode_device, subscribe_fixed_notifications
from .post_init import smart_sync_post_init_probe
from .session_common import complete_app_session
from .time_sync import write_current_time_direct


async def run_raw_probe_session(args: argparse.Namespace, model: CasioModelAdapter) -> bool:
    emit_state("waiting")
    device = await find_fixed_mode_device(args, model)
    if device is None:
        log("fixed mode did not find a compatible Casio watch", debug=args.debug)
        return False

    watch_name = safe_field(device_name(device), model.display_name.replace(" ", "_"))
    watch_address = device_address(device)
    emit("watch", model.id, watch_name, watch_address)

    client = await connect_fixed_client(args, device)
    if client is None:
        return False

    next_keepalive = time.monotonic() + max(args.keepalive_interval, 1.0)
    try:
        emit("connect")
        emit_state("connected")
        await subscribe_fixed_notifications(client, args)

        while getattr(client, "is_connected", False):
            now = time.monotonic()
            if now >= next_keepalive:
                emit_state("connected")
                next_keepalive = now + max(args.keepalive_interval, 1.0)
            await asyncio.sleep(max(args.poll_interval, 0.25))
    finally:
        try:
            if getattr(client, "is_connected", False):
                await await_library(client.disconnect())
        finally:
            emit("disconnect")
            emit_state("disconnected")

    return True


async def run_fixed_session(args: argparse.Namespace, model: CasioModelAdapter) -> bool:
    connection_api = await connect_app_watch(args, model)
    if connection_api is None:
        emit_state("waiting")
        log("no compatible Casio watch connected", debug=args.debug)
        return False

    connection, api = connection_api
    next_keepalive = time.monotonic() + max(args.keepalive_interval, 1.0)

    try:
        trigger, app_ready = await complete_app_session(connection, api, args)
        if not app_ready:
            emit_trace("init_result", "app_handshake_failed")
            return False

        await smart_sync_post_init_probe(api, args, trigger)

        should_sync_before_hold = trigger == "lower_right" or trigger == "" or args.sync_time_on_connect
        if should_sync_before_hold and trigger != "finder":
            emit_trace("hold_action", "sync_before_hold", f"button={safe_field(trigger, 'no_button')}")
            if not await write_current_time_direct(connection, args):
                emit_state("action_failed")
                emit_trace("hold_action", "failed")
                return False
        else:
            emit_trace("hold_action", "skip_sync_before_hold", f"button={safe_field(trigger, 'no_button')}")

        if trigger == "lower_left":
            emit_state("ble_held")
            emit_trace("init_result", "held_after_lower_left")
        elif trigger == "finder":
            emit_state("ble_held")
            emit_trace("init_result", "held_after_finder")
        elif trigger == "lower_right" or trigger == "":
            emit_state("ble_held")
            emit_trace("init_result", "held_after_sync", f"button={safe_field(trigger, 'no_button')}")
        else:
            emit_state("ble_held")
            emit_trace("init_result", "held_after_unknown", f"button={safe_field(trigger, 'unknown')}")

        while True:
            client = getattr(connection, "client", None)
            if client is None or not getattr(client, "is_connected", False):
                break

            now = time.monotonic()
            if now >= next_keepalive:
                emit_state("ble_held")
                next_keepalive = now + max(args.keepalive_interval, 1.0)

            await asyncio.sleep(max(args.poll_interval, 0.25))
    finally:
        client = getattr(connection, "client", None)
        if client is not None and getattr(client, "is_connected", False):
            await disconnect_watch(connection)
        else:
            emit("disconnect")
            emit_state("disconnected")

    return True
