# Achievements

Status: all interview recommendations accepted by the user; implemented in the shared desktop game.

## Requested experience

- Provide 30 varied achievements earned through gameplay milestones and challenges.
- Provide a menu screen showing achievements and progress toward them.
- Celebrate newly earned achievements with an on-screen fanfare.

## Accepted roster

The mix is six introductory milestones, eight cumulative milestones, ten tactical challenges, and six mastery challenges. All are achievable solo, with no daily streaks or multiplayer requirements.

A clear means successfully completing the entire level, including any boss and escorts. Tactical restrictions apply from starting the attempt until its successful clear; a condition broken during that attempt cannot be restored by selling a cat or undoing a purchase. Existing powerups, training, and rebirth bonuses are allowed. Permanent progression deliberately makes these challenges easier later.

| # | Achievement | Requirement | Progress shown |
| --- | --- | --- | --- |
| 1 | First Watch | Clear level 1. | Best level cleared / 1. |
| 2 | The Whole Crew | Have Bolt, Cannon, and Frost cats placed together. | Checklist of the three types currently placed. |
| 3 | Sharper Claws | Purchase your first tower-tier upgrade. | Upgrades purchased / 1. |
| 4 | A Little Extra | Purchase your first powerup rank. | Powerup ranks purchased / 1. |
| 5 | Nine Lives Begin | Perform your first rebirth. | Rebirths / 1. |
| 6 | Big Pest, Small Problem | Clear your first boss level, level 10. | Best level cleared / 10. |
| 7 | Pest Patrol | Defeat 100 enemies. | Enemies defeated / 100. |
| 8 | Garden Veteran | Defeat 5,000 enemies. | Enemies defeated / 5,000. |
| 9 | Big Game Hunter | Defeat 25 bosses. | Bosses defeated / 25. |
| 10 | Cat Person | Recruit 50 cats. | Cats recruited / 50. |
| 11 | Tender Loving Care | Make 25 paid repairs that restore health. | Qualifying repairs / 25. |
| 12 | Better Every Day | Purchase 100 tower-tier upgrades. | Upgrades purchased / 100. |
| 13 | Back for More | Perform 10 rebirths. | Rebirths / 10. |
| 14 | Power Collector | Purchase 25 powerup ranks across any powerups. | Total ranks purchased / 25. |
| 15 | Lone Guardian | Clear a level numbered 5 or higher with exactly one cat present throughout the attempt. | Best qualifying level / 5; current attempt eligibility. |
| 16 | Bolt from the Blue | Clear a level numbered 5 or higher using only Bolt cats throughout the attempt. | Best qualifying level / 5; current attempt eligibility. |
| 17 | Cannon Fodder | Clear a level numbered 5 or higher using only Cannon cats throughout the attempt. | Best qualifying level / 5; current attempt eligibility. |
| 18 | Back to Basics | Clear a level numbered 10 or higher with every cat at base tier throughout the attempt. | Best qualifying level / 10; current attempt eligibility. |
| 19 | Set and Forget | Clear a level numbered 10 or higher without recruiting, selling, upgrading, repairing, or buying a powerup during the attempt. | Best qualifying level / 10; current attempt eligibility. |
| 20 | Not a Scratch | Clear a level numbered 10 or higher without any cat taking damage during the attempt. | Best qualifying level / 10; current attempt eligibility. |
| 21 | Cold Reception | Defeat a boss while it is affected by a slow from a Frost cat or its powerups. | Earned / not yet earned. |
| 22 | Keep Your Cool | Defeat an enemy after it enters frenzy. | Earned / not yet earned. |
| 23 | Field Medic | During an active level numbered 5 or higher, pay to repair a damaged cat, then clear that attempt with the repaired cat still present. | Repair performed, repaired cat survives, level cleared. |
| 24 | On a Roll | Clear five consecutive levels numbered 10 or higher without defeat or rebirth. | Current qualifying streak / 5; best streak / 5. |
| 25 | Garden Sentinel | Clear level 25. | Best level cleared / 25. |
| 26 | Legendary Guard | Clear level 50. | Best level cleared / 50. |
| 27 | Dream Team | Have a tier-six Bolt, tier-six Cannon, and tier-six Frost placed together. | Checklist of the three types currently at tier six. |
| 28 | Full Toy Box | Own at least one rank of each of the 30 powerups. | Distinct powerups owned / 30. |
| 29 | Finishing School | Reach maximum rank on five different capped powerups. Patrol Training has no maximum and does not count. | Capped powerups completed / 5. |
| 30 | Seasoned Guardian | Complete 20 rebirths across your gardens. | Rebirths / 20. |

Progress displays follow the table above. Counters should display at most the goal in completion summaries while retaining underlying progress where useful. Tactical eligibility must explain the condition that failed; it must not imply that part of a failed attempt carries into a retry. The roster does not require a final victory, multiple maps, difficulty modes, or cooperative combat, none of which exists in the current game.

## Confirmed decisions

1. **Ownership and reset:** A player-wide collection on this device is shared between single player and multiplayer and survives defeat, rebirth, and New Garden.
2. **Rewards:** Achievements can unlock cosmetic cat skins, with no currency or combat rewards. The original recognition-only decision is revised by the implemented [cat skins design](cat-skins.md).
3. **Challenge mix:** The 6 introductory / 8 cumulative / 10 tactical / 6 mastery split above, with no daily streaks or multiplayer requirements.
4. **Visibility:** All 30 are visible with exact requirements and meaningful progress.
5. **Fanfare:** A brief animated banner and sound without pausing or blocking controls, queuing simultaneous unlocks.

## Confirmed follow-up decisions

6. **Save transfer:** Include achievements in garden exports. Import retains the union of earned achievements and the higher value for each cumulative counter, never adding potentially overlapping totals. Repeated imports cannot increase progress. Independent play on separate devices is not fully aggregated by this policy.
7. **Existing players:** Credit only facts proven by existing saves, starting missing historical counters and tactical tracking from migration onward. Retrospective unlocks appear in one summary instead of individual fanfares; the same summary approach applies to imported unlocks.
8. **Challenge tools and continuity:** Allow training, powerups, rebirth bonuses, and tactical pause. Save/resume preserves the entire attempt's eligibility, including failed conditions. Defeat, rebirth, or abandonment ends that attempt; New Garden also resets active streaks. Earned achievements remain earned.
9. **Collection boundaries:** Require powerup collections and simultaneous squads within one garden. Preserve best collection progress for display after New Garden, but do not combine partial collections from separate gardens. Explicit cumulative goals accumulate new play across gardens.
10. **Menu:** Entry from both main and Escape menus, All / In Progress / Earned filters, an earned-out-of-30 total, and selectable details with exact requirements and progress. Opening pauses the local garden; closing restores its prior pause state.
11. **Fanfare scheduling:** Use approximately four-second banners, shown only when the local garden is visible and focused. Defer while in menus, unfocused, or inspecting a remote garden; honor Sound off. Queue simultaneous unlocks once each, save earned badges immediately, and summarize any unseen unlocks from a previous session on return. Visual styling and animation details are delegated to match the game.

## Existing domain constraints

The game has endless numbered levels. A single escaping enemy causes defeat, so a successful clear already implies no escapes. Bosses occur every tenth level; defeating a boss and clearing its level are distinct events. Rebirth retains surviving cats, coins, training, and powerups. Multiplayer players have independent combat and progression.

Existing saves retain some progression facts, including lifetime enemy kills, best level cleared, rebirth count and bonus, powerup ownership/discovery, and historical highest cat tiers. Those facts do not prove historical tactical challenges, boss-kill totals, repair totals, or past simultaneous squad composition. Migration must not invent missing history.

The player-wide ownership boundary is recorded in [ADR 0011](adr/0011-player-wide-achievements.md).


## Implementation and presentation

The catalog and recognition rules live in `game/core/achievements.gd`. Session events track purchases, kills, repairs, squad changes, damage, clears, defeats, and rebirths. Per-attempt evidence and streaks travel with the garden; a separate `achievements.json` retains the player collection across New Garden. Exports include the collection, imports validate it before replacing the garden, and merges use the greater counter rather than adding potentially overlapping totals. Legacy saves receive only provable credit; their unfinished attempts have no historical tactical eligibility.

Newly earned badges are written immediately to the player record. Pending celebrations are durable; seen celebrations are acknowledged, and unseen celebrations from prior sessions or imported history are summarized. The native updater backs up and restores the achievement record along with the garden when startup recovery is needed.

The menu extends the existing ink, cream, mint, and gold desktop interface. An earned total and three filters lead into a scrolling grouped list and selected achievement details with a progress bar. Collection details distinguish the best progress in one garden from the current squad; tactical details explain failed eligibility. Native controls support keyboard focus and Escape, and opening/closing preserves local pause state. Other players' progression never grants achievements.

The non-blocking fanfare uses an authored geometric medal, a short entrance and fade, and a new original synthesized chiptune. It runs for four real seconds, respects sound and focus preferences, and defers while the local garden is hidden or a menu/dialog is open. Several unlocks queue individually; retrospective unlocks use one summary.

## Verification

Dedicated gameplay tests exercise all 30 achievements, threshold events, failed-condition persistence, same-tile cat replacement, streak resets, legacy credit, atomic rejection of invalid imports, repeat-import idempotency, and profile persistence. Native UI tests cover filters, pause restoration, Escape, every detail layout, New Garden, sequential fanfares, hidden-banner timing, and retrospective summaries. Rendered menu, empty, earned, challenge, fanfare, and summary states are recorded under `build/achievement-review/`.

Released as **3.1.0** (`3.1.0-1793467239`) at https://purrimeter.graham.pub/ on 2026-10-31. Live release metadata, relay health, and both public package hashes were verified after publication.

The Rebirth Draft update preserves the internal `gold` achievement identity and all previously earned Golden Garden rewards. Its new Seasoned Guardian requirement credits saved rebirth history; legacy bonus progress remains readable without granting the renamed achievement solely from income.
