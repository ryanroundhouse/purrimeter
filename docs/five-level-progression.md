# Five-level progression

Status: design confirmed by the user in both interview rounds; implemented in the shared Godot game. Verification is recorded below.

## Requested structure

| Level | Name | Waves | Unlock requirement |
| --- | --- | --- | --- |
| 1 | Open Meadow | 10 | Available initially |
| 2 | Stone Garden | 20 | Beat level 1 |
| 3 | Winding Brook | 30 | Beat level 2 |
| 4 | Twin Streams | 40 | Beat level 3 |
| 5 | Wildwater | Endless | Beat level 4 |

New Garden shows all five named levels with terrain icons, wave counts, obstacle summaries, and locked requirements, and permits selection of any unlocked level. Unlocks are player-wide and survive New Garden.

## Confirmed decisions

- A **level** contains multiple **waves**. Existing wave-depth rules retain their numerical meaning under the terminology change. Use Wave health, Auto-start next wave, and Boss wave in player-facing language.
- Clearing a finite level's final wave shows victory and unlocks the next level. Starting that next level or replaying an earlier level creates a fresh garden; cats, coins, and other garden possessions do not carry over.
- All levels share wave health and bounty progression, with no additional level-specific difficulty multiplier. The [anti-air design](anti-air.md) introduces Moths into selected waves in levels two through five while retaining those budgets; level one stays ground-only. Later levels require deeper progression. Each level now has a distinct name and obstacle profile, as requested in the follow-up: sparse rocks, many rocks, one stream, two streams, then three streams. See [terrain profiles](obstacles.md#level-identities).
- Rebirth remains available after clearing wave five and returns to wave one within the selected level, retaining its current rewards and possessions. It does not beat the level or unlock another.
- Defeat keeps the existing one-wave setback, stopping at wave one, and retains coins and surviving damaged cats. Prior defeats and rebirths do not disqualify eventual victory.
- Bosses remain every tenth wave. Existing achievement, powerup, and draft requirements refer to wave depth; requirements beyond wave 40 are endless-mode goals.
- Existing saves keep their current garden in endless mode as a legacy exception. Recorded highest cleared wave grants unlocks at thresholds 10, 20, 30, and 40 for levels two through five respectively; this does not imply that all legacy players may create a new endless garden.

## Completion and transfers

- A completed garden is terminal: combat and Auto stop, and rebirth is no longer available. It remains viewable, saveable, and exportable, including after reopening or importing it. The victory screen offers View garden, Choose level, and Next level. Starting another garden always requires replacement confirmation.
- Save imports combine source and destination unlocks and never relock earned levels. Legacy credit uses the greater of the garden's highest cleared wave and the player's achievement history; the current or next attempted wave is not evidence of a clear.
- A legacy endless garden retains its exception through reloads, rebirths, and transfers. Replacing that garden ends its exception. New-format wave records alone do not grant level unlocks; a finite level must actually be completed.
- New Garden first shows all five levels, then asks for confirmation after an unlocked level is selected. Cancelling either step keeps the original garden paused. First-time players start in level one.
- Players in one multiplayer room may choose different levels and earn victories and unlocks independently. Starting another garden preserves room membership and chat. Spectators see the selected level, wave, and completion state.

## Persistence and compatibility

- Garden saves use version 6, carrying the selected level, completion state, and legacy endless exception. The historical `level` field continues to represent a wave so combat, balance, and migration retain their established meaning.
- The player-wide achievement record uses version 2 and additionally stores the highest unlocked level. Sequential unlocks form a contiguous range; imports preserve the higher unlocked level rather than adding counters.
- Version 1 achievement records and version 2–5 garden saves migrate without deleting earned possessions or ongoing combat. Validation finishes before replacing live state.
- Completed gardens retain their final wave number and cleared-wave records, with no active enemies, pending draft, or Auto countdown. Resuming, purchasing, recruiting, defeating, and rebirthing cannot reopen a completed challenge.

## Verification

- `game/tests/levels.gd` exercises all four victory thresholds, sequential access, fresh replacement, endless continuation, rebirth/defeat boundaries, save and draft transfers, legacy thresholds, unlock merging, atomic invalid-save rejection, and spectator representation.
- `game/tests/levels_ui.gd` exercises locked choices, cancellation, replacement confirmation, automatic victory, Next level, and desktop/portrait/landscape bounds and touch targets. Captures use isolated gardens rather than the player's save.
- Existing simulation tests that exercise deep waves explicitly select endless mode. Multiplayer tests exercise import and replacement while retaining membership and chat.
- Verified on 2026-11-07: `scripts/test.sh` passes, including the gameplay campaign and existing simulation/UI regressions; `scripts/test_multiplayer.sh` passes, including Go race tests and three local Godot clients. The final-wave boss/escort and protocol validation cases pass as well.
- Native Godot captures and layout checks pass at 1280×900, 390×844, and 844×390 with desktop/browser and native mobile control variants. The existing native Android control and menu suites pass. The portrait victory panel was enlarged after visual review to show its entire explanation; the reviewer confirmed that fix. These are desktop-hosted layout tests, not physical Android/iOS device verification.

## Existing behavior relevant to the decisions

- A single saved garden is shared between single player and multiplayer.
- New Garden resets garden possessions and progression; achievements and cat skins survive.
- One enemy escaping loses the attempt, moves progression back one wave, and retains coins and surviving damaged cats.
- Rebirth becomes available after five cleared waves, resets to the first wave, and retains possessions while granting a draft reward.
- Enemy health doubles and base coin bounty grows by 1.5 times per wave. Bosses appear every tenth wave.

These facts explain the starting point. The confirmed decisions above take precedence for the proposed design.

## Related decisions

- [Separate permanent level unlocks from garden progression](adr/0018-player-wide-level-unlocks.md).
- [Preserve legacy endless gardens](adr/0019-preserve-legacy-endless-gardens.md).
