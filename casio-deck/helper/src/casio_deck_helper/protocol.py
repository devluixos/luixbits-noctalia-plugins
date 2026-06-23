from __future__ import annotations

import contextlib
from datetime import datetime
import os
from pathlib import Path
import sys
from typing import Any, Awaitable, TypeVar

T = TypeVar("T")

_log_file: Path | None = None


def configure_file_logging(path: str) -> None:
    global _log_file

    target = (path or "").strip()
    if target == "":
        _log_file = None
        return

    _log_file = Path(os.path.expanduser(target))
    _log_file.parent.mkdir(parents=True, exist_ok=True)


def _write_file_log(kind: str, message: str) -> None:
    if _log_file is None:
        return

    timestamp = datetime.now().isoformat(timespec="seconds")
    with _log_file.open("a", encoding="utf-8") as handle:
        handle.write(f"{timestamp} {kind} {message}\n")


def emit(*parts: object) -> None:
    """Emit one normalized helper protocol line on stdout."""
    line = " ".join(str(part) for part in parts)
    _write_file_log("OUT", line)
    print(line, flush=True)


def emit_state(state: str) -> None:
    emit("state", state)


def emit_trace(*parts: object) -> None:
    emit("trace", *parts)


def log(message: str, *, debug: bool = False) -> None:
    _write_file_log("DBG" if debug else "LOG", message)
    if debug:
        print(message, file=sys.stderr, flush=True)


async def await_library(awaitable: Awaitable[T]) -> T:
    """Keep third-party debug prints off the stdout protocol stream."""
    with contextlib.redirect_stdout(sys.stderr):
        return await awaitable


def safe_field(value: Any, fallback: str = "unknown") -> str:
    text = str(value or "").strip()
    return text if text else fallback
