from __future__ import annotations

import argparse
import asyncio
import sys
import traceback
from typing import Any

from ...debounce import TriggerDebouncer
from ...protocol import emit, emit_state, emit_trace, log
from .app_info import app_info_needs_write, app_info_response
from .triggers import read_pressed_trigger


async def complete_app_info_handshake(connection: Any, args: argparse.Namespace) -> bool:
    session = getattr(connection, "casio_deck_session", None)
    if not isinstance(session, dict):
        emit("error", "app-info handshake unavailable: missing helper session")
        emit_trace("init_step", "app_info_internal_error", "missing_session")
        return False

    loop = asyncio.get_running_loop()
    future: asyncio.Future[bytes] = loop.create_future()
    session["app_info_future"] = future

    try:
        await connection.request("22")
        data = await asyncio.wait_for(
            future,
            timeout=max(args.app_init_timeout, 1.0),
        )
        app_info = data.hex().upper()
        emit_trace("init_step", "app_info_challenge", app_info)
        response = app_info_response(args.app_info_profile)
        if app_info_needs_write(app_info, args.app_info_profile) and response != "":
            await connection.write(0x0E, response)
            emit_trace(
                "init_step",
                "app_info_response_sent",
                response,
                f"profile={args.app_info_profile}",
            )
        else:
            emit_trace(
                "init_step",
                "app_info_already_set",
                app_info,
                f"profile={args.app_info_profile}",
            )
        return True
    except TimeoutError:
        emit("error", "app-info handshake timed out; watch may still show connection/search mode")
        emit_trace("init_step", "app_info_timeout")
        return False
    except Exception as exc:
        emit("error", f"app-info handshake failed: {exc}")
        emit_trace("init_step", "app_info_failed", str(exc))
        log(f"app-info handshake failed: {exc}", debug=args.debug)
        if args.debug:
            traceback.print_exc(file=sys.stderr)
        return False
    finally:
        session["app_info_future"] = None


async def complete_app_session(connection: Any, api: Any, args: argparse.Namespace) -> tuple[str | None, bool]:
    debouncer = TriggerDebouncer(debounce_seconds=max(args.debounce_ms, 0) / 1000.0)

    emit_state("initializing")
    emit_trace("init_step", "app_info_request")
    if not await complete_app_info_handshake(connection, args):
        emit_state("app_handshake_failed")
        return None, False

    log("app-info handshake result: OK", debug=args.debug)
    emit_trace("init_step", "app_info_result", "OK")

    emit_trace("init_step", "button_pressed_request")
    trigger = await read_pressed_trigger(api, args)
    if trigger is not None:
        emit_trace("init_step", "button_pressed_result", trigger or "no_button")
        if trigger != "" and debouncer.should_emit(trigger):
            emit("press", trigger)
    else:
        emit_trace("init_step", "button_pressed_result", "timeout_or_error")

    emit_state("init_complete")
    return trigger, True
