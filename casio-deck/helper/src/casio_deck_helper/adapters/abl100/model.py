from __future__ import annotations

from ...model_types import CasioModelAdapter

MODEL = CasioModelAdapter(
    id="casio_abl100we_3565",
    aliases=("abl100we", "abl100", "casio_abl100we", "casio_abl100we_3565", "module_3565"),
    display_name="Casio ABL-100WE-1A",
    module_number="3565",
    support="experimental",
    scan_keywords=("ABL", "ABL-100", "3565"),
    triggers=("lower_right", "finder", "lower_left"),
    capabilities=(
        "action_transaction",
        "ble_connection",
        "session_initiators",
        "finder",
    ),
)
