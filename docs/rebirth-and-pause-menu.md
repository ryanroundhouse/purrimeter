# Mid-level rebirth and Escape menu

Status: design confirmed through the user interview; implemented in the shared Godot game.

## Confirmed decisions

- Keep Rebirth in the sidebar, showing the available coin bonus. Enable it during combat once level five has been cleared in the current run, including after defeats move progression backward.
- Mid-level rebirth retains coins already earned, removes remaining enemies, fully heals surviving cats, and returns to level one. Retain the existing tower upgrades, powerups, discoveries, lifetime best, and accumulated coin bonus.
- Award 10 percentage points of additional coin bonus per highest level cleared this run. An unfinished level contributes no additional rebirth bonus: rebirthing during level nine after clearing eight adds 80 percentage points.
- Reset the run's cleared-level record and require clearing level five again to qualify. Cancel any auto-start countdown; level one waits for manual Start even when Auto is enabled.
- Put Route on/off and Sound on/off directly in the Escape menu, without a Settings submenu. Remove their HUD buttons and the duplicate New Garden HUD button; retain the existing New Garden menu action.
- Put Continue offline in the multiplayer Escape menu and remove it from the main gameplay window.
- Remove the field status labels and the multiplayer layout explanation from the gameplay window.
- Keep confirmation dialogs for Rebirth and New Garden. Cancelling either leaves combat paused.
- Losing application focus must not pause an otherwise running game. Existing explicit pauses, menus, and confirmation dialogs still pause combat; focus changes must not resume them.
- Silence music and game sound effects while the application is unfocused. Restore audio on return only if Sound is enabled; gameplay and Auto countdowns continue while unfocused unless otherwise paused.
- Clicking View on another player's multiplayer garden replaces local music and gameplay effects with that garden's music and effects, including its boss theme. Only the selected garden is audible; small previews remain silent.
- The viewer's Sound setting and focus state control playback. Closing View restores local audio. Chat mute and chat notification preferences remain separate.
- Viewing another garden preserves the local garden's running or paused state. Closing View does not change that state either.

These decisions supersede the earlier between-level rebirth restriction, focus-loss pause, and local pause during enlarged remote inspection.

## Multiplayer audio behavior

- Remote music follows the selected garden's current regular or boss theme; exact playback positions are not synchronized.
- Relay updates carry a bounded half-second history of numbered sound events. Receivers validate the names, tiers, and ordering, and discard already-consumed events. Older clients without sound events remain compatible and still provide theme selection.
- Entering View, regaining focus, unmuting, or reconnecting establishes a fresh event baseline without replaying buffered effects. A temporarily disconnected viewed garden is silent; a departing player closes View.
- Events are captured independently of the source player's sound preference, application focus, and currently viewed garden.
- Explicit menu/dialog/manual pauses and multiplayer connection-loss pauses are preserved. Closing the application or suspending the computer does not introduce offline progression.
