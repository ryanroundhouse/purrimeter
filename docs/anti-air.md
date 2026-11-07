# Anti-air cats and flying enemies

Status: both design rounds confirmed; shared understanding and implementation authorized. Implemented in the shared Godot game.

## Confirmed decisions

- Beating level one permanently unlocks a new anti-air cat. Existing players who have already unlocked level two receive access automatically, and the cat remains available when replaying level one or replacing a garden.
- Anti-air uses long-range single-target shots with higher damage than Bolt to compensate for its restricted targets and flyers' shorter route.
- Cannon attacks ground enemies only; anti-air attacks flying enemies only. Bolt and Frost attack both.
- These restrictions cover secondary effects as well as primary shots: Cannon splash, aftershocks, burns, and spreading burns cannot damage air. Bolt piercing/chaining and Frost spreading effects may cross between air and ground.
- One distinct flying enemy species appears from level two's first wave, mixed into selected waves throughout levels two through five. Flyers replace some ground enemies, starting around 15% and rising toward 30% in later levels. Bosses remain grounded; level one has no flyers.
- Flyers travel straight from the entrance to the exit over towers and obstacles. They never attack towers or enter frenzy, and players may build beneath them. Slowing and freezing work normally. A flying enemy reaching the exit causes the same defeat as a ground enemy escaping.

## Ranger and Moth

- **Ranger (Anti-air)** is a calico archer with teal clothing and a recurved bow. Its six tiers progress from leather to mythic white-gold armor, with four poses per tier and a distinct arrow trail. It has one default skin; there are no additional achievement skins in this change.
- Initial Ranger stats: 90 coins, 200 health, 26 damage every 0.6 seconds, and 4.2 tiles of range. Its tier growth follows the existing cats. Numerical tuning was delegated to implementation and testing.
- **Moth** has lavender wings, an ivory body, four flight poses, hovering motion, and a ground shadow. Its speed and health weighting match Grunt: 1.25 tiles per second and weight 38. It has no tower damage.
- All towers retain shortest-time-to-escape target priority among eligible enemies. Moths use their direct flight time rather than a ground route estimate.
- Mixed waves occur on wave numbers whose remainder after division by three is one or zero. They replace evenly spaced regular enemies: approximately 15%, 20%, 25%, and 30% for levels two through five respectively, rounded to the nearest enemy with at least one Moth. Total enemy count, total wave health, total bounty, and every-tenth-wave boss cadence remain unchanged.
- Recruitment shows a fourth slot and explains its level-one unlock. Keyboard shortcut 4 selects Ranger. Pre-wave summaries identify incoming air, and enemy inspection describes flight. Native mobile and browser layouts retain their established controls.

## Improvements and rewards

- Ranger receives all ordinary all-cat benefits, including training, speed, range, critical hits, discounts, healing, and Mixed Patrol. Existing role-specific effects stay with their roles; no new powerup catalog is added.
- Brittle Ice boosts all non-Frost cats against chilled enemies, including Ranger.
- Triad Strike accepts primary hits from any three distinct roles within its existing time window and cooldown. Bolt + Frost + Ranger can trigger it in air; Bolt + Cannon + Frost still trigger it on the ground. Secondary hits do not create combo marks.
- Whole Crew and Dream Team still require the original three named roles. Existing achievement rewards and the 30-powerup Full Toy Box requirement retain their meanings.

## Saved gardens and multiplayer

- Save version 7 records the active wave's roster profile. Versions 2–6 reconstruct their original ground-only wave until that attempt ends, including its remaining unspawned enemies. Re-saving a migrated active wave preserves that profile.
- The next started wave, including a retry or rebirth, uses the selected level's new roster. Existing legacy endless gardens whose player has not unlocked level two retain ground-only waves until that unlock is earned.
- Player unlocks and cosmetic ownership still merge through the existing progression record. Invalid flight positions or states are rejected before replacing live progress.
- Spectator messages carry the active roster profile and a separate read-only view of level unlocks. The client and relay accept flyers crossing terrain and towers while preserving ground-enemy restrictions. Watching another garden grants no local unlocks or cosmetics.
- See [preserve active wave rosters](adr/0020-preserve-active-wave-rosters.md).

## Verification

- `game/tests/air.gd` covers unlocks, level-one replay, rosters across all five levels and sixty waves, conserved health/reward budgets, targeting, secondary damage, Frost control, air Triad persistence, flight over terrain and towers, placement beneath flyers, escape, atomic invalid-save rejection, migration, spectators, and original-role achievements.
- `game/tests/air_ui.gd` covers locked/unlocked recruitment, all four controls, keyboard/action selection, touch target bounds, enemy inspection above terrain, Ranger cosmetics, and measured art for all 24 poses. Native captures cover desktop, phone, and Android landscape layouts; these are desktop-hosted UI checks, not physical-device certification.
- `game/tests/air_campaign.gd` exercises the first ten waves of levels two through five with earned coins, upgrades, training, and a rebirth. These scripted playthroughs are a baseline balance check; deeper human playtesting remains useful.
- `server/air_test.go` covers relay validation for Ranger towers/shots, Moths crossing terrain, and invalid flying states.
- The complete gameplay/UI regression suite and local multiplayer suite pass. Sprite PNGs retain their generated alpha; `scripts/measure_air_art.gd` reproduces their runtime bounds without changing pixels.

Artwork and exact built-in imagegen prompts: [anti-air artwork](anti-air-artwork.md).

Related: [glossary](../CONTEXT.md), [five-level progression](five-level-progression.md), and [Rebirth Draft](rebirth-draft.md).
