# Auto-start next level

The [five-level progression](five-level-progression.md) supersedes the single endless challenge described here. In this document, historical “level” depth means **wave** depth; rebirth stays within the selected level, and finite victory stops Auto and rebirth.

Design confirmed through the user interview and implemented in the shared Godot game.

## Confirmed requirements

- Provide a player-controlled option to auto-start the next level.
- Show it as a checkbox labeled "Auto" to the right of Start, Wave in progress, or Resume on the same row.
- Disable the option by default.
- Trigger only after successfully clearing a level. Defeat, new gardens, and rebirth wait for a manual start.
- Start the next level after a three-second countdown. Show a large 3, 2, 1 centered on the playing field; each number shrinks and fades before the next number appears.
- Save the option with the garden so it survives reopening and Export/Import. New gardens and older saves default to disabled. Explicit saved choices are preserved.
- The countdown lasts three real seconds at both 1× and 2× combat speed.
- Pause freezes both countdown and animation, including menu and dialog pauses. Losing application focus or viewing another garden does not pause the countdown; music and gameplay effects are silent while unfocused. A pending countdown is saved with its remaining time; loading resumes paused until the player resumes.
- Switching the option off cancels a countdown. Switching it back on between successfully cleared levels starts a fresh three-second countdown. Enabling it during a level applies to the next successful clear; enabling it after defeat, rebirth, or in a new garden does not start a level.
- Countdown numbers do not intercept clicks. Building and upgrades remain available and do not reset the timer. Manual Start skips the countdown; rebirth cancels it.
- The same behavior applies to every successful clear, including level five and boss levels. Rebirth is available during the countdown and during combat once unlocked.
