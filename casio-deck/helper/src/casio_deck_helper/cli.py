from __future__ import annotations

import argparse
import asyncio
import time

from .model_types import CasioModelAdapter
from .models import cli_model_choices, emit_model_lines, get_model
from .protocol import configure_file_logging, emit, emit_state, log
from .runtime import get_runtime

VERSION = "0.1.0"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Experimental Casio Bluetooth helper for Casio Deck."
    )
    parser.add_argument("--model", default="abl100we", choices=cli_model_choices())
    parser.add_argument("--address", default="", help="Optional BLE address to connect to.")
    parser.add_argument("--scan-only", action="store_true", help="Only scan and print candidate devices.")
    parser.add_argument(
        "--setup-pairing",
        action="store_true",
        help=(
            "Run one explicit watch setup flow: optional BlueZ repair, BLE pair/connect, "
            "Casio app-info handshake, report pairing status, then exit."
        ),
    )
    parser.add_argument("--once", action="store_true", help="Run one watch connection session and exit.")
    parser.add_argument("--loop", action="store_true", help="Keep the helper alive and wait for repeated watch connections.")
    parser.add_argument(
        "--listener",
        action="store_true",
        help=(
            "App-like background mode for Noctalia: use action sessions, keep "
            "the helper alive, and wait for repeated watch-initiated connections."
        ),
    )
    parser.add_argument(
        "--max-attempts",
        type=int,
        default=0,
        help="Stop after this many connection sessions when --loop is used. 0 means unlimited.",
    )
    parser.add_argument(
        "--session-mode",
        choices=("action", "timeserver", "fixed", "raw-probe", "connection-trigger", "poll"),
        default="action",
        help=(
            "action follows the app-style ABL flow: connect, init, emit trigger, disconnect; "
            "timeserver follows the proven GShockTimeServer flow: connect, init, set time, disconnect; "
            "fixed completes the Casio app-session handshake and tries to keep BLE open; "
            "raw-probe pairs/connects with Bleak and subscribes to notifications; "
            "connection-trigger reads the connect initiator once; poll keeps "
            "the gshock-api connection open for research."
        ),
    )
    parser.add_argument(
        "--pair",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Try BLE pairing/bonding before connecting. Use --no-pair to skip.",
    )
    parser.add_argument(
        "--repair-pairing",
        action="store_true",
        help="Remove the saved BlueZ watch record first, then scan by name and pair again.",
    )
    parser.add_argument(
        "--disconnect-after-press",
        action="store_true",
        help="Diagnostic alias for --session-mode connection-trigger.",
    )
    parser.add_argument(
        "--sync-time-on-connect",
        action="store_true",
        help="Set current time after the Casio app session is initialized.",
    )
    parser.add_argument(
        "--app-info-profile",
        choices=("smart-sync", "legacy-python", "keep"),
        default="smart-sync",
        help=(
            "App-info scratchpad behavior. smart-sync writes the newer 0x93 "
            "marker used by GShockAPI/SmartSync; legacy-python writes the older "
            "Python gshock-api marker only when the watch is blank; keep never "
            "changes app-info."
        ),
    )
    parser.add_argument(
        "--app-init-timeout",
        type=float,
        default=12.0,
        help="Seconds to wait for the Casio app-info handshake.",
    )
    parser.add_argument(
        "--time-offset",
        type=int,
        default=0,
        help="Seconds added when --sync-time-on-connect sets the watch time.",
    )
    parser.add_argument("--debug", action="store_true", help="Print detailed diagnostics to stderr.")
    parser.add_argument(
        "--log-file",
        default="~/.cache/casio-deck/helper.log",
        help="Append helper protocol/debug logs to this file. Use an empty value to disable.",
    )
    parser.add_argument("--scan-timeout", type=float, default=10.0, help="Seconds for --scan-only.")
    parser.add_argument(
        "--connect-timeout",
        type=float,
        default=12.0,
        help="Seconds to wait for an individual BLE connect attempt.",
    )
    parser.add_argument("--poll-interval", type=float, default=2.0, help="Seconds between button polls while connected.")
    parser.add_argument("--debounce-ms", type=int, default=500, help="Ignore duplicate trigger changes inside this window.")
    parser.add_argument(
        "--keepalive-interval",
        type=float,
        default=30.0,
        help="Seconds between helper connected-state heartbeat lines.",
    )
    parser.add_argument(
        "--reconnect-delay",
        type=float,
        default=10.0,
        help="Seconds to wait after a session before scanning/connecting again in --loop mode.",
    )
    parser.add_argument(
        "--button-timeout",
        type=float,
        default=10.0,
        help="Seconds to wait for gshock-api pressed-button decoding.",
    )
    return parser.parse_args(argv)


def selected_model(args: argparse.Namespace) -> CasioModelAdapter:
    return get_model(args.model)


async def run(args: argparse.Namespace) -> int:
    model = selected_model(args)
    runtime = get_runtime(model)
    args.model_adapter = model
    if args.listener:
        args.session_mode = "action"
        args.loop = True
        args.once = False
    if args.disconnect_after_press:
        args.session_mode = "connection-trigger"

    emit("ready", "casio-deck-helper", VERSION, model.id)
    emit_model_lines(emit, model)
    emit_state("waiting")

    if args.scan_only:
        return await runtime.scan_only(args)

    if args.setup_pairing:
        return await runtime.setup_pairing(args)

    loop = args.loop and not args.once
    attempts = 0
    while True:
        attempts += 1
        await runtime.run_connected_session(args)
        if not loop or (args.max_attempts > 0 and attempts >= args.max_attempts):
            emit_state("stopped")
            return 0
        emit_state("reconnecting")
        await asyncio.sleep(max(args.reconnect_delay, 0.0))


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    configure_file_logging(args.log_file)
    started = time.strftime("%Y-%m-%d %H:%M:%S")
    log(f"helper started at {started}", debug=args.debug)
    try:
        return asyncio.run(run(args))
    except KeyboardInterrupt:
        emit("disconnect")
        emit_state("disconnected")
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
