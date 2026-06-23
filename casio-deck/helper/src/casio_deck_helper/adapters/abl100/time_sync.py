from __future__ import annotations

import argparse
import asyncio
from datetime import datetime, timedelta
import sys
import traceback
from typing import Any

from ...protocol import emit, emit_state, emit_trace, log


async def write_current_time_direct(connection: Any, args: argparse.Namespace) -> bool:
    emit_state("syncing")
    emit_trace("sync_time_direct", "start")
    try:
        current = datetime.now().astimezone() + timedelta(seconds=args.time_offset)
        command = current_time_command(current)
        emit_trace("sync_time_direct", command)
        await connection.write(0x0E, command)
        await asyncio.sleep(0.5)
        emit_trace("sync_time_direct", "ok")
        return True
    except Exception as exc:
        emit("error", f"direct time sync failed: {exc}")
        emit_trace("sync_time_direct", "failed", str(exc))
        log(f"direct time sync failed: {exc}", debug=args.debug)
        if args.debug:
            traceback.print_exc(file=sys.stderr)
        return False


def current_time_command(current: datetime) -> str:
    year = current.year.to_bytes(2, byteorder="little")
    day_of_week = int(current.strftime("%w"))
    subsecond = (current.microsecond * 256 // 1_000_000) & 0xFF
    payload = bytes([
        0x09,
        year[0],
        year[1],
        current.month,
        current.day,
        current.hour,
        current.minute,
        current.second,
        day_of_week,
        subsecond,
        0x01,
    ])
    return payload.hex().upper()


async def maybe_sync_time(api: Any, args: argparse.Namespace, *, force: bool = False) -> bool:
    if not force and not args.sync_time_on_connect:
        return True

    emit_state("syncing")
    emit_trace("sync_time", "start")
    try:
        await api.set_time(offset=args.time_offset)
        emit_trace("sync_time", "ok")
        emit_state("init_complete")
        return True
    except Exception as exc:
        emit("error", f"time sync failed: {exc}")
        emit_trace("sync_time", "failed", str(exc))
        log(f"time sync failed: {exc}", debug=args.debug)
        if args.debug:
            traceback.print_exc(file=sys.stderr)
        return False
