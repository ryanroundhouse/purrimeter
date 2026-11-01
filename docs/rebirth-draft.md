# Rebirth Draft

Status: confirmed design implemented in the shared Godot game. Initial numerical tuning and automated progression checks are recorded below; extended human balance testing remains ongoing.

## Requested direction

- Each rebirth offers three randomly selected eligible permanent improvements; the player chooses one.
- Eligibility can depend on highest cleared progress, rebirth count, ownership, stack caps, and prerequisite draft or powerup ranks. Achievement requirements are excluded from the initial release.
- Chosen improvements are saved and retained across future rebirths.
- Unchosen improvements remain eligible for future offers, subject to their requirements.
- The draft replaces future automatic rebirth coin bonuses.

## Confirmed foundations

- Draft improvements form a separate collection, emphasizing distinctive combat changes and synergies. Existing coin-bought powerups remain the ordinary numerical-growth system.
- Future rebirths award a chosen improvement instead of an automatic coin bonus. The draft pool includes economy improvements. Existing earned bonuses are preserved; progression balance remains to be validated.
- Deeper runs improve the odds of stronger eligible offers, while players stuck at a challenge can still earn a draft after clearing level five.
- Draft ownership survives defeat, rebirth, and saving/loading, but resets with New Garden.
- Progress eligibility uses the highest level cleared across runs in the current garden, rather than the highest level entered or the current run's record. Rebirth does not revoke these level qualifications.
- Achievement requirements are deferred from the initial system.

## Implementation scope

The design interview is complete and shared understanding is confirmed. The roster, prerequisite policy, selection rules, persistence behavior, migration policy, and presentation direction below are approved. Numerical tuning and detailed interaction limits were delegated to implementation and balance testing.

## Confirmed draft rules

- Rebirth remains available after clearing level five in the current run. Greater current-run depth increases the chance of stronger eligible improvements; garden-best cleared progress determines lasting level qualification. A normal draft still offers three improvements and awards one.
- Confirmation precedes revelation. Confirming commits the rebirth and durably saves its offers; the game remains paused until a choice is made. Closing and reopening restores the same pending draft. No cancellation or free reroll is available after revelation. Save the chosen reward immediately.
- If fewer than three eligible improvements remain, show those unique options. If none remain, offer a sole repeatable coin-income improvement as an explicit uncapped fallback.
- Existing saves retain earned coin bonuses, possessions, rebirth counts, and highest-cleared-level progress. Stop granting automatic bonuses; the next rebirth awards the first draft. No retroactive draft picks are granted.
- Initial improvements have no penalties or mutually exclusive branches. Owned effects combine automatically. Prerequisites and stack caps structure progression, and existing boss crowd-control safeguards remain in force.
- Replace Golden Garden's +1,000% rebirth coin-bonus requirement with 20 completed rebirths, crediting existing rebirth history. Preserve already-earned achievement rewards and revise its player-facing name and description.
- A separate Draft Collection view shows owned ranks, unowned improvements, and requirements. Coin-bought powerups remain in their existing browser.

## Confirmed selection and choice rules

Each eligible improvement's next rank receives its strength band's weight. Draw three distinct improvements without replacement, or all eligible improvements if fewer than three remain. Weights are relative, not fixed probabilities; the eligible pool determines actual probabilities. There are no guaranteed bands, free rerolls, or hidden pity mechanics in the initial release.

| Highest level cleared this run | Basic | Advanced | Keystone |
| --- | ---: | ---: | ---: |
| 5–9 | 1 | 0.5 | 0.2 |
| 10–19 | 1 | 1 | 0.5 |
| 20–29 | 1 | 2 | 1 |
| 30+ | 1 | 3 | 2 |

- These odds improve deeper-run offers but do not guarantee that deep runs outperform short runs per minute. With three or fewer eligible improvements, all are offered and weights have no effect. Finishing weaker improvements can leave only stronger eligible improvements even at low run depth. This follows from lasting eligibility and unique offers; balance testing must account for it.
- Count the newly committed rebirth for eligibility: an improvement requiring three rebirths may appear in the third rebirth's draft. Use retained garden-best cleared progress and capture current-run depth before resetting it.
- Successive ranks are one collection entry, not separate improvements. Only the next rank may appear, each rank may have its own requirements, and a pick grants exactly one rank. Other improvements may require a specific owned draft rank.
- When no normal improvement is eligible, the sole fallback grants 10 percentage points of permanent coin bonus, additive with preserved legacy bonus. For example, +100% becomes +110%, changing the bonus factor from 2× to 2.1×. This also applies when uncollected normal improvements remain locked.
- Selecting an offer previews it; a separate Choose improvement button commits the selection. Show the effect, current-to-next rank, and resulting benefit. Show all three cards together where space permits, support keyboard and touch, and use neither a timer nor a default selection.
- Exact damage percentages, cooldowns, stack caps, and unlock thresholds are delegated to implementation and balance testing. Start with the weights above and record final tuning here. Preserve the agreed limits: no penalties, no mutually exclusive branches, no recursive effect chains, and no bypassing boss freeze/stun protections.

## Confirmed initial roster

| Band | Improvement | Effect direction |
| --- | --- | --- |
| Basic | Mixed Patrol | Cats attack faster near a cat of a different role; neighboring benefits do not multiply. |
| Basic | Supply Cache | Successful level clears grant extra coins based on that level's base bounty. |
| Basic | Salvage Crew | Destroyed cats refund part of their actual purchase and tier investment; no additional sale refund. |
| Basic | Frost Guard | Chilled enemies deal less damage to cats, subject to a combined mitigation cap. |
| Advanced | Spotter Bolts | Primary Scout hits mark an enemy for a subsequent Gunner hit to exploit for bonus damage. |
| Advanced | Cold Front | Sage attacks also slow a few nearby enemies without spreading freeze counters. |
| Advanced | Cinder Relay | A burning enemy's death transfers its remaining burn to one nearby enemy; transferred burns cannot relay again. |
| Advanced | Steady Aim | Scouts retain some Focus Fire buildup when their target dies, within the existing buildup cap. |
| Advanced | Treasure Trail | Consecutive successful clears build a capped extra clear reward; defeat and rebirth reset the streak. |
| Keystone | Thermal Shock | A direct Gunner hit causes a bounded bonus burst against a target already burning and chilled, preserving both statuses. |
| Keystone | Nine Lives | Once per level attempt, prevent one cat's destruction and restore some health; one shared charge for the garden. |
| Keystone | Triad Strike | Primary hits from all three cat roles within a short window trigger a bonus burst, subject to a cooldown. |

Eligibility may require owned coin-bought powerup ranks as well as owned draft ranks. Cinder Relay and Thermal Shock require Hot Embers; Steady Aim requires Focus Fire. Treasure Trail requires Supply Cache; Triad Strike requires Spotter Bolts and Cold Front. Exact ranks and progress thresholds remain delegated. Do not require qualifying cats to be currently placed: the player may recruit the relevant roles later, and selling or losing a cat must not revoke qualification.

All added bursts use ordinary damage scaling and the existing single-payment kill path. Secondary effects do not generate new combo marks or recursively trigger further bursts; transferred burns cannot propagate a chain. Temporary marks, streaks, and charges must survive save/load consistently and follow the declared attempt or run boundary.

## Verification required during implementation

- Check level-five qualification, mid-level rebirth, retained possessions and healing, captured run depth, and eligibility using the newly incremented rebirth count.
- Check unique weighted offers, next-rank requirements, maximum ranks, cross-collection prerequisites, and pools with zero, one, two, or three eligible improvements. Unchosen improvements must remain available for later drafts.
- Check that confirmation commits one rebirth, reopening restores the same pending offers, and committing a choice grants exactly one rank. Exercise interrupted saves and save transfer without losing or duplicating rewards.
- Check legacy-save preservation, the absence of retroactive picks and new automatic bonuses, additive fallback income, and preservation of earned achievement rewards when the requirement changes.
- Check that draft ownership survives defeat and rebirth but resets with New Garden. Verify saved temporary combat state, declared streak and charge resets, capped mitigation, nonrecursive effects, and boss crowd-control limits.
- Review draft and collection views with keyboard and touch, including narrow layouts, rank previews, locked requirements, completed improvements, and the sole fallback option.
- Compare short-run farming and deeper-run progression in fresh and migrated gardens, including partially collected and exhausted pools. Confirm that income still supports sustained progression and record final tuning.

## Initial numerical tuning

All ordinary improvements have three ranks except Nine Lives, which has one. Requirements are cumulative: for next rank n, add the listed level and rebirth increments n − 1 times to the first-rank thresholds. Every prerequisite below requires rank one. Current cat placement never gates a reward.

| Improvement | First cleared level / increment | First rebirth / increment | Additional prerequisite | Effect per owned rank |
| --- | --- | --- | --- | --- |
| Mixed Patrol | 5 / +5 | 1 / +1 | None | +8% attack speed within 2 tiles of any different role; one benefit regardless of neighbor count. |
| Supply Cache | 5 / +5 | 1 / +1 | None | +25% of base level bounty after each clear. |
| Salvage Crew | 5 / +5 | 1 / +1 | None | Refund 15% of actual recruitment and tier investment on destruction; no extra sale refund. |
| Frost Guard | 5 / +5 | 1 / +1 | None | 10 percentage points less incoming damage from chilled enemies; combines additively with Thick Fur, capped at 60% total reduction. |
| Spotter Bolts | 10 / +5 | 2 / +2 | None | +25% direct Gunner damage when consuming a Scout mark; marks last 3 seconds. |
| Cold Front | 10 / +5 | 2 / +2 | None | Slow one extra enemy per rank within 1.5 tiles, nearest first. Uses normal slow duration, with no extra freeze counters. |
| Cinder Relay | 10 / +5 | 2 / +2 | Hot Embers | Transfer remaining burn to one nearest enemy within 2 tiles at 60% / 80% / 100% strength. Strongest burn wins; transferred burns cannot relay again. |
| Steady Aim | 10 / +5 | 2 / +2 | Focus Fire | Retain up to 2 / 4 / 5 Focus Fire stacks after the target dies. |
| Treasure Trail | 15 / +5 | 3 / +2 | Supply Cache | Extra base-bounty reward of 5% × owned rank × consecutive clears, capped at five clears. |
| Thermal Shock | 20 / +5 | 4 / +2 | Hot Embers | +35% direct Gunner hit damage per rank if the enemy was burning before the hit and is chilled. |
| Nine Lives | 20 / none | 4 / none | None | Prevent one destruction per attempt and restore 35% health. One shared charge; refreshes on Start. |
| Triad Strike | 30 / +5 | 5 / +2 | Spotter Bolts and Cold Front | Bonus damage of 50% × owned rank of the triggering primary hit after all three roles hit within 3 seconds. Enemy then has 3 seconds of combo recovery. |

Supply Cache and Treasure Trail use base level bounty and add together; neither multiplies legacy income, Bounty Lessons, or Boss Purse. Normal enemy kill rewards retain those existing factors. Lasting Fortune is the uncapped fallback and adds 10 percentage points to the legacy-compatible permanent coin bonus each time it is chosen.

Only primary attacks make combo marks or trigger direct-hit synergies. Bonus damage never invokes another attack. Direct burns can replace transferred burns under the existing strongest-burn rule. Attempt start clears carried Focus Fire buildup; defeat and rebirth reset the treasure streak. Saved combat state includes marks, combo recovery, burn-transfer provenance, carried focus, streak, and the shared rescue charge.

## Persistence and integration

Version-4 snapshots store draft ranks, an independent random stream, pending offers with their committed rebirth number and run depth, and temporary effect state. Version-2 and version-3 imports retain existing progression and receive no retroactive choices. Invalid new fields or pending offers are rejected before the live garden changes.

The UI stages rebirth and selection on a separate session, writes that snapshot, and only then publishes it to the live garden. A failed write leaves the original state and choice intact. Native saves flush before atomic rename; browser commits wait for IndexedDB transaction completion. In the browser's explicitly chosen Continue without autosave mode, drafts remain fixed in memory and are labeled session-only; manual export is required to preserve them. Ordinary play and purchases cannot bypass a pending draft, even if pause is toggled.

Spectator field messages include validated draft ownership for accurate stats and collection inspection; they do not expose pending choices. Achievement `gold` keeps its identity and earned rewards, with the player-facing name Seasoned Guardian and the requirement of 20 completed player-wide rebirths.

## Interface direction and verification

Mode: Operate. This is an extension of the existing game, using its ink panels, cream copy, mint choices, gold economy/Keystone accents, fallback typeface, and rounded controls. No new artwork or visual identity is introduced.

The task is a deliberate lasting choice: confirm rebirth before revelation, inspect the offered effects and current-to-next ranks, then explicitly choose. Three cards sit side by side on wide views; narrow phones stack them in a full-height scrolling panel with a persistent choice button. Keyboard focus never selects a reward by itself. The separate Draft Collection exposes ownership, completion, and every future requirement. Desktop places its entry beside Rebirth; phones expose it inside Powerups. Seed: none (local extension; context launcher unavailable).

Verification covers isolated native fixtures, portable JSON and disk transactions, weighted sampling, all twelve effects, legacy achievements, malformed imports, and desktop/phone/landscape interface states. The full native regression suite passes, including the campaign reaching level 10 after rebirth. With identical eligible pools and 1,000 seeded three-offer draws, the initial weights produced 279 Keystone offers at run depth 5 versus 728 at depth 30. This demonstrates improved offer quality, not superior rewards per minute; short-run farming remains possible as explicitly agreed. Extended progression pacing still benefits from human playtesting.

The new core suite passes 64 checks, including completion of a partially saved three-role combo with identical damage. Chromium touch tests verify durable offers before selection, unchanged offers after Escape and reload, exactly one selected rank, preservation of legacy bonuses, and recovery from an injected IndexedDB write failure without granting a reward. The existing browser suite also passes touch recruitment, wave start, rotation, takeover fencing, import/export, unavailable-storage play, multiplayer, and chat. These are automated/emulated checks, not certification on physical iPhone or Android hardware.

Reproduce with `scripts/test.sh` and `scripts/test_multiplayer.sh`. For the targeted browser test, run the Godot `tests/rebirth_draft.gd` script with `-- --browser-fixture`, build with `scripts/build_web.sh`, then run `PLAYWRIGHT_MODULE=<installed-playwright-module> node scripts/test_draft_browser.cjs`. Rendered UI fixtures use `tests/draft_ui.gd -- --multiplayer-test --mobile-test --draft-captures` and write isolated captures under `/tmp/td-draft-*.png`. Local evidence is copied to `build/rebirth-draft/`.

The [earlier rebirth and pause menu](rebirth-and-pause-menu.md) and [permanent powerup](powerups.md) documents retain the historical progression decisions. This document supersedes their automatic rebirth coin-reward rule.
