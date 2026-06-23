from __future__ import annotations

import argparse
import asyncio
import sys
import traceback
from typing import Any

from ...protocol import log


def button_to_trigger(button: Any) -> str:
    raw_name = getattr(button, "name", str(button))
    name = str(raw_name).upper()
    mapping = {
        "LOWER_LEFT": "lower_left",
        "LOWER_RIGHT": "lower_right",
        "FIND": "finder",
        "FIND_PHONE": "finder",
        "NO_BUTTON": "",
        "INVALID": "unknown",
    }
    return mapping.get(name, "unknown")


async def read_pressed_trigger(api: Any, args: argparse.Namespace) -> str | None:
    try:
        button = await asyncio.wait_for(
            api.get_pressed_button(),
            timeout=args.button_timeout,
        )
        trigger = button_to_trigger(button)
        log(f"raw pressed button: {button!r} -> {trigger or 'no_button'}", debug=args.debug)
        return trigger
    except TimeoutError:
        log("button poll timed out", debug=args.debug)
        return None
    except Exception as exc:
        log(f"could not decode pressed button: {exc}", debug=args.debug)
        if args.debug:
            traceback.print_exc(file=sys.stderr)
        return None
