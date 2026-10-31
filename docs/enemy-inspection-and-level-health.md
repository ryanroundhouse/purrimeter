# Enemy inspection and level health

Confirmed and implemented on 2026-10-31.

## Confirmed requirements

- Enemies can be selected for inspection without changing cat targeting or combat behavior.
- Enemy inspection shows the enemy's name, animated preview, current and maximum health, and health bar.
- Inspection also shows tactical details: speed, attack damage, and active effects.
- Enemies use the same sidebar inspector space as towers. Only one unit can be selected at a time, and a highlight follows the selected enemy as it moves. The inspector includes **Back to powerups**.
- When the selected enemy dies or the attempt ends, selection clears and the sidebar returns to powerups. No other enemy is automatically selected.
- Clicking an occupied tower tile selects the tower first. Otherwise, outside recruitment mode, clicking an enemy selects the frontmost enemy under the pointer. Recruitment retains its existing placement behavior.
- Keyboard inspection uses the focused tile with the same tower-first priority.
- Both tower and enemy inspector previews animate, including during tactical pause. Battlefield animation remains frozen during tactical pause.
- A bar labeled **Level health** shows the combined remaining health of the entire level's wave, including enemies that have not yet arrived and any boss.
- Level health starts full and drains as damage is dealt. Each enemy contributes its actual remaining health, rather than an equal share per enemy or a count of enemies killed.
- The level health bar replaces the thin arrival-progress bar. Existing field and arrival counts remain above it, and the health bar is accompanied by a remaining percentage, such as **Level health · 72%**.
- Show level health only during an active attempt, including while paused. Between attempts, retain the existing next-level preview or countdown instead of displaying a refilled health bar.

## Confirmed acceptance scenarios

- A wave has 1,000 total maximum HP. Its first enemies, worth 100 HP, die before the others arrive. Level health is 900/1,000; later arrivals do not increase it.
- A selected enemy remains subject to the existing automatic cat targeting rules.
- A boss contributes its share of the level's health, so killing low-health escorts does not misleadingly imply that most of the challenge is complete.
- Selecting an enemy replaces tower inspection or the powerup browser; its highlight follows that individual as it moves.
- Killing the selected enemy returns to powerups without selecting a different enemy. Victory and defeat also clear enemy selection.
- A click on a cat's occupied tile selects the cat even if boss artwork overlaps it. Away from occupied tower tiles, overlapping enemies are selected in front-to-back visual order.
- Recruitment mode continues to place cats rather than selecting enemies. Keyboard inspection respects tower priority on the focused tile.
- Tactical pause freezes battlefield animation and health changes while both kinds of inspector preview remain animated.
- The active level shows field/arrival counts plus the remaining-health bar and percentage. Victory or defeat returns that area to its existing preview/countdown presentation.

## Previous behavior informing the design

- The thin bar below the field/arrival counts tracked arrivals.
- Tower inspection occupied the sidebar in place of the powerup browser. Its portrait was static, although cats animated on the field.
- Boss artwork extends beyond its logical cell and can overlap other units.
- One enemy escaping immediately ends the attempt in defeat. Successful completion immediately advances the level. Both outcomes clear the active wave.
- Enemies do not currently heal, split, or summon other enemies.

## Verification

- `game/tests/level_health.gd` covers whole-wave health, damage, overkill, later arrivals, save restoration, pause, boss weighting, unequal enemy health, success, defeat, and levels through 1,000,000,000.
- Scene smoke checks cover pointer and keyboard inspection, overlapping enemies and cats, moving enemies near tile boundaries, recruitment priority, pause, returning to powerups, Escape, death, victory, defeat, and New Garden.
- Native previews cover regular enemies with all active effects, bosses, and scientific-notation health values at the minimum window size. Reproduce with `--preview <path> --preview-state enemy|enemy-boss|enemy-effects|enemy-long`.
