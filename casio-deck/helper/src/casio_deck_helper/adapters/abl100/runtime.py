from __future__ import annotations

import argparse

from ...model_types import CasioModelAdapter
from .action_sessions import (
    run_action_session,
    run_connection_trigger_session,
    run_poll_session,
    run_timeserver_session,
)
from .device import scan_only
from .fixed_sessions import run_fixed_session, run_raw_probe_session
from .pairing_session import setup_pairing_session


async def run_connected_session(args: argparse.Namespace, model: CasioModelAdapter) -> bool:
    if args.session_mode == "action":
        return await run_action_session(args, model)
    if args.session_mode == "timeserver":
        return await run_timeserver_session(args, model)
    if args.session_mode == "fixed":
        return await run_fixed_session(args, model)
    if args.session_mode == "raw-probe":
        return await run_raw_probe_session(args, model)
    if args.session_mode == "poll":
        return await run_poll_session(args, model)
    return await run_connection_trigger_session(args, model)


class Abl100Adapter:
    def __init__(self, model: CasioModelAdapter):
        self.model = model

    async def scan_only(self, args: argparse.Namespace) -> int:
        args.model_adapter = self.model
        return await scan_only(args)

    async def setup_pairing(self, args: argparse.Namespace) -> int:
        args.model_adapter = self.model
        return await setup_pairing_session(args, self.model)

    async def run_connected_session(self, args: argparse.Namespace) -> bool:
        args.model_adapter = self.model
        return await run_connected_session(args, self.model)
