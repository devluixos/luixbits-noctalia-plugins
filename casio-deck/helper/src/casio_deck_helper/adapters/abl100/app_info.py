from __future__ import annotations

APP_INFO_LEGACY_PYTHON = "223488F4E5D5AFC829E06D02"
APP_INFO_SMART_SYNC = "229300000000000000000000"
APP_INFO_BLANK = "22FFFFFFFFFFFFFFFFFFFF00"


def app_info_response(profile: str) -> str:
    if profile == "smart-sync":
        return APP_INFO_SMART_SYNC
    if profile == "legacy-python":
        return APP_INFO_LEGACY_PYTHON
    return ""


def app_info_needs_write(current: str, profile: str) -> bool:
    if profile == "keep":
        return False
    if current == "":
        return False
    if current == APP_INFO_BLANK:
        return True
    if profile == "smart-sync":
        return current != APP_INFO_SMART_SYNC
    return False
