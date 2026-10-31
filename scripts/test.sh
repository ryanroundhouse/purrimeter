#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$godot_bin" --headless --path game --editor --import --quit
"$godot_bin" --headless --path game --script res://tests/run.gd
"$godot_bin" --headless --path game --script res://tests/level_health.gd
"$godot_bin" --headless --path game --script res://tests/frenzy.gd
"$godot_bin" --headless --path game --script res://tests/powerups.gd
"$godot_bin" --headless --path game --script res://tests/campaign.gd
"$godot_bin" --headless --audio-driver Dummy --path game --script res://tests/music.gd -- --music-test
"$godot_bin" --headless --path game -- --smoke-test
"$godot_bin" --headless --path game --script res://tests/window_transition.gd -- --multiplayer-test
