#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$godot_bin" --headless --path game --editor --import --quit
"$godot_bin" --headless --path game --script res://tests/run.gd
"$godot_bin" --headless --path game --script res://tests/levels.gd
"$godot_bin" --headless --path game --script res://tests/levels_ui.gd -- --multiplayer-test --mobile-test
"$godot_bin" --headless --path game --script res://tests/reset_progress.gd -- --multiplayer-test --mobile-test
"$godot_bin" --headless --path game --script res://tests/level_health.gd
"$godot_bin" --headless --path game --script res://tests/frenzy.gd
"$godot_bin" --headless --path game --script res://tests/terrain.gd
"$godot_bin" --headless --path game --script res://tests/terrain_ui.gd -- --multiplayer-test
"$godot_bin" --headless --path game --script res://tests/powerups.gd
"$godot_bin" --headless --path game --script res://tests/rebirth_draft.gd
"$godot_bin" --headless --path game --script res://tests/draft_ui.gd -- --multiplayer-test --mobile-test
"$godot_bin" --headless --path game --script res://tests/achievements.gd
"$godot_bin" --headless --path game --script res://tests/achievement_ui.gd -- --multiplayer-test
"$godot_bin" --headless --path game --script res://tests/cat_skins.gd
"$godot_bin" --headless --path game --script res://tests/skin_ui.gd -- --multiplayer-test
"$godot_bin" --headless --path game --script res://tests/campaign.gd
"$godot_bin" --headless --audio-driver Dummy --path game --script res://tests/music.gd -- --music-test
"$godot_bin" --headless --path game -- --smoke-test
"$godot_bin" --headless --path game --script res://tests/window_transition.gd -- --multiplayer-test

"$godot_bin" --headless --path game --script res://tests/mobile.gd -- --multiplayer-test --mobile-test

if [ "${PURRIMETER_NATIVE_UI_TESTS:-0}" = 1 ]; then
  "$godot_bin" --path game --script res://tests/android_controls.gd -- --multiplayer-test --android-ui-test
  "$godot_bin" --path game --script res://tests/android_menus.gd -- --multiplayer-test --android-ui-test
fi
