from __future__ import annotations

import unittest
from datetime import datetime, timezone
from pathlib import Path

from casio_deck_helper.adapters.abl100.app_info import (
    APP_INFO_BLANK,
    APP_INFO_LEGACY_PYTHON,
    APP_INFO_SMART_SYNC,
    app_info_needs_write,
    app_info_response,
)
from casio_deck_helper.adapters.abl100.time_sync import current_time_command
from casio_deck_helper.adapters.abl100.triggers import button_to_trigger
from casio_deck_helper.cli import parse_args
from casio_deck_helper.debounce import TriggerDebouncer
from casio_deck_helper.models import ABL100WE, cli_model_choices, get_model, normalize_model_id


class Button:
    def __init__(self, name: str):
        self.name = name


def split_deck_list(value: str) -> tuple[str, ...]:
    return tuple(item.strip() for item in value.split(",") if item.strip())


def load_deck_model(model_id: str) -> dict[str, str]:
    model_path = Path(__file__).resolve().parents[2] / "data" / "models.deck"
    for line in model_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) < 3 or parts[0] != "model" or parts[1] != model_id:
            continue
        fields = {"id": parts[1]}
        for part in parts[2:]:
            key, _, value = part.partition("=")
            fields[key] = value
        return fields
    raise AssertionError(f"missing deck model: {model_id}")


class ModelRegistryTests(unittest.TestCase):
    def test_abl_aliases_normalize_to_stable_model_id(self) -> None:
        self.assertEqual(normalize_model_id("abl100we"), "casio_abl100we_3565")
        self.assertEqual(normalize_model_id("Casio ABL100WE"), "casio_abl100we_3565")
        self.assertEqual(get_model("module-3565").id, "casio_abl100we_3565")

    def test_cli_choices_include_aliases_and_model_id(self) -> None:
        choices = cli_model_choices()
        self.assertIn("abl100we", choices)
        self.assertIn("casio_abl100we_3565", choices)

    def test_abl_scan_filter_is_specific_enough(self) -> None:
        self.assertTrue(ABL100WE.matches_name("CASIO ABL-100WE"))
        self.assertTrue(ABL100WE.matches_name("Casio module 3565"))
        self.assertFalse(ABL100WE.matches_name("CASIO GBX-100"))
        self.assertFalse(ABL100WE.matches_name("CASIO WATCH"))

    def test_helper_model_matches_plugin_data(self) -> None:
        plugin_model = load_deck_model(ABL100WE.id)

        self.assertEqual(plugin_model["display_name"], ABL100WE.display_name)
        self.assertEqual(plugin_model["module"], ABL100WE.module_number)
        self.assertEqual(plugin_model["support"], ABL100WE.support)
        self.assertEqual(split_deck_list(plugin_model["triggers"]), ABL100WE.triggers)
        self.assertEqual(split_deck_list(plugin_model["capabilities"]), ABL100WE.capabilities)


class TriggerMappingTests(unittest.TestCase):
    def test_gshock_button_names_map_to_stable_triggers(self) -> None:
        self.assertEqual(button_to_trigger(Button("LOWER_LEFT")), "lower_left")
        self.assertEqual(button_to_trigger(Button("LOWER_RIGHT")), "lower_right")
        self.assertEqual(button_to_trigger(Button("FIND")), "finder")
        self.assertEqual(button_to_trigger(Button("FIND_PHONE")), "finder")
        self.assertEqual(button_to_trigger(Button("INVALID")), "unknown")

    def test_no_button_does_not_emit_a_trigger(self) -> None:
        self.assertEqual(button_to_trigger(Button("NO_BUTTON")), "")


class TimeCommandTests(unittest.TestCase):
    def test_current_time_command_uses_minimal_casio_time_packet(self) -> None:
        current = datetime(2026, 6, 23, 11, 48, 8, 710_937, tzinfo=timezone.utc)

        self.assertEqual(current_time_command(current), "09EA0706170B300802B501")


class AppInfoTests(unittest.TestCase):
    def test_smart_sync_profile_uses_newer_scratchpad_marker(self) -> None:
        self.assertEqual(app_info_response("smart-sync"), APP_INFO_SMART_SYNC)

    def test_smart_sync_profile_replaces_legacy_python_marker(self) -> None:
        self.assertTrue(app_info_needs_write(APP_INFO_LEGACY_PYTHON, "smart-sync"))
        self.assertFalse(app_info_needs_write(APP_INFO_SMART_SYNC, "smart-sync"))

    def test_legacy_profile_only_initializes_blank_watch(self) -> None:
        self.assertTrue(app_info_needs_write(APP_INFO_BLANK, "legacy-python"))
        self.assertFalse(app_info_needs_write(APP_INFO_LEGACY_PYTHON, "legacy-python"))

    def test_keep_profile_never_writes_app_info(self) -> None:
        self.assertFalse(app_info_needs_write(APP_INFO_BLANK, "keep"))
        self.assertEqual(app_info_response("keep"), "")


class DebounceTests(unittest.TestCase):
    def test_duplicate_trigger_is_suppressed_until_release(self) -> None:
        debouncer = TriggerDebouncer(debounce_seconds=0)

        self.assertTrue(debouncer.should_emit("lower_left"))
        self.assertFalse(debouncer.should_emit("lower_left"))
        self.assertFalse(debouncer.should_emit(""))
        self.assertTrue(debouncer.should_emit("lower_left"))


class CliTests(unittest.TestCase):
    def test_default_session_mode_targets_action_transaction(self) -> None:
        args = parse_args([])

        self.assertEqual(args.session_mode, "action")
        self.assertEqual(args.app_info_profile, "smart-sync")
        self.assertTrue(args.pair)
        self.assertFalse(args.loop)
        self.assertEqual(args.max_attempts, 0)

    def test_disconnect_after_press_keeps_legacy_diagnostic_path(self) -> None:
        args = parse_args(["--disconnect-after-press"])

        self.assertTrue(args.disconnect_after_press)

    def test_max_attempts_is_available_for_finite_ui_runs(self) -> None:
        args = parse_args(["--loop", "--max-attempts", "3"])

        self.assertTrue(args.loop)
        self.assertEqual(args.max_attempts, 3)

    def test_loop_has_reconnect_delay_to_avoid_watch_hammering(self) -> None:
        args = parse_args([])

        self.assertEqual(args.reconnect_delay, 10.0)

    def test_listener_flag_is_available_for_background_action_mode(self) -> None:
        args = parse_args(["--listener"])

        self.assertTrue(args.listener)
        self.assertFalse(args.loop)
        self.assertFalse(args.once)

    def test_repair_pairing_flag_is_opt_in(self) -> None:
        default_args = parse_args([])
        repair_args = parse_args(["--repair-pairing"])

        self.assertFalse(default_args.repair_pairing)
        self.assertTrue(repair_args.repair_pairing)

    def test_setup_pairing_flag_is_separate_from_action_sessions(self) -> None:
        args = parse_args(["--setup-pairing", "--repair-pairing"])

        self.assertTrue(args.setup_pairing)
        self.assertTrue(args.repair_pairing)
        self.assertEqual(args.session_mode, "action")


if __name__ == "__main__":
    unittest.main()
