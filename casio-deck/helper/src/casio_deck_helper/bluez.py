from __future__ import annotations

import re
import subprocess

from .model_types import CasioModelAdapter


def bluez_device_info(address: str) -> dict[str, str]:
    if not address:
        return {}

    try:
        completed = subprocess.run(
            ["bluetoothctl", "info", address],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except Exception:
        return {}

    info: dict[str, str] = {}
    for line in completed.stdout.splitlines():
        key, separator, value = line.strip().partition(":")
        if separator:
            info[key.strip().lower()] = value.strip()
    return info


def is_bluez_paired(address: str) -> bool:
    info = bluez_device_info(address)
    return info.get("paired") == "yes" or info.get("bonded") == "yes"


def trust_bluez_device(address: str) -> None:
    if not address:
        return

    try:
        subprocess.run(
            ["bluetoothctl", "trust", address],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except Exception:
        return


def remove_bluez_device(address: str) -> bool:
    if not address:
        return False

    try:
        completed = subprocess.run(
            ["bluetoothctl", "remove", address],
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception:
        return False

    return completed.returncode == 0


def paired_model_address(model: CasioModelAdapter) -> str | None:
    try:
        completed = subprocess.run(
            ["bluetoothctl", "devices", "Paired"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except Exception:
        return None

    for line in completed.stdout.splitlines():
        match = re.match(r"Device\s+([0-9A-Fa-f:]{17})\s+(.+)$", line.strip())
        if match is None:
            continue

        address, name = match.groups()
        if model.matches_name(name):
            return address

    return None
