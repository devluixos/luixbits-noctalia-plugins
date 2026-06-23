from __future__ import annotations

import argparse
import asyncio
import sys
import traceback
from collections.abc import Awaitable, Callable
from typing import Any

from ...protocol import await_library, emit_state, emit_trace, log, safe_field


async def run_probe_sequence(
    api: Any,
    args: argparse.Namespace,
    probes: list[tuple[str, Callable[[], Awaitable[Any]]]],
) -> None:
    emit_state("phone_probe")
    timeout = min(max(args.app_init_timeout, 1.0), 5.0)

    for label, call in probes:
        emit_trace("phone_probe", label, "request")
        try:
            result = await asyncio.wait_for(
                await_library(call()),
                timeout=timeout,
            )
            emit_trace("phone_probe", label, "ok", safe_field(result, "empty"))
        except TimeoutError:
            emit_trace("phone_probe", label, "timeout")
        except Exception as exc:
            emit_trace("phone_probe", label, "failed", str(exc))
            log(f"phone-like probe {label} failed: {exc}", debug=args.debug)
            if args.debug:
                traceback.print_exc(file=sys.stderr)


async def smart_sync_post_init_probe(api: Any, args: argparse.Namespace, trigger: str | None) -> None:
    """Mirror the Smart Sync post-initialization path closely for ABL lower-left."""
    normalized = trigger or ""
    if normalized != "lower_left":
        emit_trace("phone_probe", "skipped", f"button={safe_field(normalized, 'no_button')}")
        return

    probes: list[tuple[str, Callable[[], Awaitable[Any]]]] = [
        ("timer", lambda: api.get_timer()),
        ("watch_condition", lambda: api.get_watch_condition()),
    ]
    await run_probe_sequence(api, args, probes)
