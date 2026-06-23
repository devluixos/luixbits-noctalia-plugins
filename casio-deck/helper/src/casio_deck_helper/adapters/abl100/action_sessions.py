from __future__ import annotations

import argparse
import asyncio
import time

from ...debounce import TriggerDebouncer
from ...model_types import CasioModelAdapter
from ...protocol import emit, emit_state, emit_trace, log, safe_field
from .app_connection import connect_app_watch, connect_watch, disconnect_watch
from .session_common import complete_app_session
from .time_sync import maybe_sync_time, write_current_time_direct
from .triggers import read_pressed_trigger


async def run_timeserver_session(args: argparse.Namespace, model: CasioModelAdapter) -> bool:
    connection_api = await connect_app_watch(args, model)
    if connection_api is None:
        emit_state("waiting")
        log("no compatible Casio watch connected", debug=args.debug)
        return False

    connection, api = connection_api

    try:
        trigger, app_ready = await complete_app_session(connection, api, args)
        if not app_ready:
            emit_trace("init_result", "app_handshake_failed")
            return False

        if trigger == "finder":
            emit_state("action_complete")
            emit_trace("timeserver_action", "finder")
            return True

        emit_trace("timeserver_action", "set_time", f"button={safe_field(trigger, 'no_button')}")
        if not await write_current_time_direct(connection, args):
            emit_state("action_failed")
            emit_trace("timeserver_action", "failed")
            return False

        emit_state("session_complete")
        emit_trace("timeserver_action", "complete")
        return True
    finally:
        client = getattr(connection, "client", None)
        if client is not None and getattr(client, "is_connected", False):
            await disconnect_watch(connection)
        else:
            emit("disconnect")
            emit_state("disconnected")


async def run_action_session(args: argparse.Namespace, model: CasioModelAdapter) -> bool:
    connection_api = await connect_app_watch(args, model)
    if connection_api is None:
        emit_state("waiting")
        log("no compatible Casio watch connected", debug=args.debug)
        return False

    connection, api = connection_api

    try:
        trigger, app_ready = await complete_app_session(connection, api, args)
        if not app_ready:
            emit_trace("init_result", "app_handshake_failed")
            return False

        if args.sync_time_on_connect and trigger != "finder":
            emit_trace("action_session", "sync_time", f"button={safe_field(trigger, 'no_button')}")
            if not await write_current_time_direct(connection, args):
                emit_state("action_failed")
                emit_trace("action_session", "failed")
                return False

        emit_state("session_complete")
        emit_trace("action_session", "complete", f"button={safe_field(trigger, 'no_button')}")
        return True
    finally:
        client = getattr(connection, "client", None)
        if client is not None and getattr(client, "is_connected", False):
            await disconnect_watch(connection)
        else:
            emit("disconnect")
            emit_state("disconnected")


async def run_connection_trigger_session(args: argparse.Namespace, model: CasioModelAdapter) -> bool:
    connection_api = await connect_watch(args, model)
    if connection_api is None:
        emit_state("waiting")
        log("no compatible Casio watch connected", debug=args.debug)
        return False

    connection, api = connection_api
    debouncer = TriggerDebouncer(debounce_seconds=max(args.debounce_ms, 0) / 1000.0)
    try:
        trigger = await read_pressed_trigger(api, args)
        if trigger is not None and debouncer.should_emit(trigger):
            emit("press", trigger)

        await maybe_sync_time(api, args)
    finally:
        await disconnect_watch(connection)

    return True


async def run_poll_session(args: argparse.Namespace, model: CasioModelAdapter) -> bool:
    connection_api = await connect_watch(args, model)
    if connection_api is None:
        emit_state("waiting")
        log("no compatible Casio watch connected", debug=args.debug)
        return False

    connection, api = connection_api
    debouncer = TriggerDebouncer(debounce_seconds=max(args.debounce_ms, 0) / 1000.0)
    next_keepalive = time.monotonic() + max(args.keepalive_interval, 1.0)

    try:
        while True:
            client = getattr(connection, "client", None)
            if client is None or not getattr(client, "is_connected", False):
                break

            trigger = await read_pressed_trigger(api, args)
            if trigger is not None and debouncer.should_emit(trigger):
                emit("press", trigger)

            now = time.monotonic()
            if now >= next_keepalive:
                emit_state("connected")
                next_keepalive = now + max(args.keepalive_interval, 1.0)

            await asyncio.sleep(max(args.poll_interval, 0.25))
    finally:
        client = getattr(connection, "client", None)
        if client is not None and getattr(client, "is_connected", False):
            log("poll session ended while client is still connected; disconnecting", debug=args.debug)
            await disconnect_watch(connection)
        else:
            emit("disconnect")
            emit_state("disconnected")

    return True
