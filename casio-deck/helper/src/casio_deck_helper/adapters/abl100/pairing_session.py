from __future__ import annotations

import argparse

from ...bluez import bluez_device_info, trust_bluez_device
from ...model_types import CasioModelAdapter
from ...protocol import emit, emit_state, emit_trace, log, safe_field
from .app_connection import connect_app_watch, disconnect_watch
from .session_common import complete_app_info_handshake
from .time_sync import write_current_time_direct
from .triggers import read_pressed_trigger


async def setup_pairing_session(args: argparse.Namespace, model: CasioModelAdapter) -> int:
    """Run the explicit Pair/Setup flow."""
    emit_state("setup_pairing")
    connection_api = await connect_app_watch(args, model)
    if connection_api is None:
        emit_state("waiting")
        log("setup pairing could not connect to a compatible Casio watch", debug=args.debug)
        return 1

    connection, api = connection_api
    address = safe_field(getattr(connection, "address", ""), "")
    watch_name = model.display_name.replace(" ", "_")
    completed = False

    try:
        emit_state("initializing")
        emit_trace("setup_pairing", "app_info_request")
        if not await complete_app_info_handshake(connection, args):
            emit_trace("setup_pairing", "app_info_failed")
            emit_state("app_handshake_failed")
            return 1

        emit_trace("setup_pairing", "app_info_ok")
        emit_trace("setup_pairing", "button_pressed_request")
        trigger = await read_pressed_trigger(api, args)
        if trigger is None:
            emit_trace("setup_pairing", "button_pressed_result", "timeout_or_error")
        else:
            emit_trace("setup_pairing", "button_pressed_result", trigger or "no_button")

        if args.sync_time_on_connect and trigger != "finder":
            emit_trace("setup_pairing", "sync_time", f"button={safe_field(trigger, 'no_button')}")
            if not await write_current_time_direct(connection, args):
                emit_trace("setup_pairing", "sync_time_failed")
                emit_state("action_failed")
                return 1

        trust_bluez_device(address)
        bluez_info = bluez_device_info(address)
        emit_trace(
            "pairing_result",
            f"paired={bluez_info.get('paired', 'unknown')}",
            f"bonded={bluez_info.get('bonded', 'unknown')}",
            f"trusted={bluez_info.get('trusted', 'unknown')}",
            f"connected={bluez_info.get('connected', 'unknown')}",
        )
        emit("paired", model.id, watch_name, safe_field(address, "unknown"))
        completed = True
        return 0
    finally:
        client = getattr(connection, "client", None)
        if client is not None and getattr(client, "is_connected", False):
            await disconnect_watch(connection)
        else:
            emit("disconnect")
            emit_state("disconnected")
        if completed:
            emit_state("pairing_complete")
