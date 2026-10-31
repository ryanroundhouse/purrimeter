# Permanent powerups

Status: confirmed by the user, implemented, and verified in the shared Godot game.

## Confirmed decisions

- Replace the idle sidebar guidance and separate Patrol Training row with an icon browser and selected-powerup details. Clicking an icon highlights it and shows its description, current effect, next-rank benefit, and price below.
- Provide approximately 30 varied powerups, including numerical bonuses and combat behaviors. Purchased effects work together automatically; there are no equipment slots or manually activated abilities.
- Mix one-time purchases and capped repeatable powerups. Patrol Training has no rank cap and is discoverable from enemy challenge level one, starting with zero purchases.
- Each additional rank has its own prerequisite, separate from its coin price. Having enough coins alone does not guarantee consecutive rank purchases.
- Rank prerequisites use lifetime milestones and can be satisfied ahead of time. A player who already satisfies several successive prerequisites may buy those ranks consecutively if they can afford them. Fresh progress after a purchase is required only when explicitly stated.
- Patrol Training's first purchase has no progress gate. Subsequent ranks require increasing lifetime enemy-kill milestones, allowing a player to earn more training by replaying challenges even when unable to clear a harder challenge. Other powerups can require cleared levels, rebirths, cat achievements, or other powerup ranks.
- Coins pay for powerups as well as towers, tower upgrades, and repairs.
- Purchases persist through defeat, rebirth, closing and reopening the game, and save transfer. New Garden resets them. Existing Patrol Training purchases must be preserved.
- Undiscovered icons are completely hidden. Discovery is permanent and can depend on historical achievements such as highest level cleared, rebirths, powerup ranks, or cat milestones. Losing a prerequisite cat or rebirthing does not hide an already discovered icon.
- Available and Owned tabs let players browse purchases and inspect their collection. Available contains discovered powerups with purchases remaining, including those whose next rank is locked. Owned contains every purchased powerup, including completed ones. Repeatable owned powerups appear in both until completed.
- A discovered powerup whose next prerequisite is unmet stays visible with a lock badge. Its details explain the prerequisite and progress, such as "Clear level 15 — best: 12". Purchasing is disabled until the player meets both its prerequisite and coin price.
- Selecting a placed cat temporarily replaces the powerup browser with existing cat controls. Back to powerups returns to the previously selected powerup.
- Prices, rank caps, milestone spacing, effect strengths, and interaction tuning are delegated to implementation and testing. Limit overlapping freezing and stunning so bosses cannot be permanently immobilized.

## Confirmed roster

These 30 powerups and their effect directions are approved. Numerical tuning and detailed interaction rules are delegated as described above.

| Group | Powerup | Effect |
| --- | --- | --- |
| Patrol | Patrol Training | Existing unlimited damage and maximum-health growth. |
| Patrol | Quick Paws | Faster attacks, capped. |
| Patrol | Keen Eyes | Longer attack range, capped. |
| Patrol | Lucky Claws | Chance of critical hits, capped. |
| Patrol | Heavy Claws | Stronger critical hits, capped. |
| Economy | Bounty Lessons | Increase enemy coin rewards, capped. |
| Economy | Boss Purse | Extra rewards from boss kills, capped. |
| Economy | Thrifty Recruiting | Reduce new-cat prices, capped. |
| Economy | Efficient Equipment | Reduce tower-tier upgrade prices, capped. |
| Economy | Repair Kit | Reduce paid repair prices, capped. |
| Durability | Reinforced Beds | Additional maximum health, capped. |
| Durability | Thick Fur | Reduce incoming damage, capped. |
| Durability | Catnap | Restore some health after a cleared challenge, capped. |
| Durability | First Aid | Slowly regenerate damaged cats during combat, capped. |
| Durability | Last Stand | Temporary faster attacks below a health threshold, one-time unlock. |
| Bolt | Needle Bolts | Shots also hit enemies behind their primary target, capped. |
| Bolt | Static Whiskers | Hits can arc to a nearby enemy, capped. |
| Bolt | Focus Fire | Consecutive hits on the same enemy build a capped damage bonus. |
| Bolt | Giant Hunter | Extra damage against bosses, capped. |
| Bolt | Finishing Touch | Extra damage against enemies below a health threshold, capped. |
| Cannon | Wider Blast | Larger splash radius, capped. |
| Cannon | Hot Embers | Explosions apply damage over time, capped. |
| Cannon | Concussion | Explosions can briefly stun enemies, capped. |
| Cannon | Aftershock | A delayed secondary blast, one-time unlock. |
| Cannon | Siege Shells | Extra damage against enemies currently attacking cats, capped. |
| Frost | Deep Chill | Stronger slowing, capped. |
| Frost | Lingering Cold | Longer slow duration, capped. |
| Frost | Ice Lock | Repeated hits can briefly freeze a target, capped. |
| Frost | Brittle Ice | Chilled enemies take extra damage from other cats, capped. |
| Frost | Winter Gift | Defeated chilled enemies spread a slow to nearby enemies, one-time unlock. |

## Confirmed migration policy

Existing saves record lifetime enemy kills, highest challenge cleared, rebirth count, training purchases, and surviving cats' kinds and tiers. They do not record sold or destroyed cats' historical achievements.

Preserve the complete garden and every existing Patrol Training rank, even when a new prerequisite would not have permitted that rank. Use saved lifetime counters and surviving cats to credit discoveries and initialize cat milestones. Begin tracking other unrecorded achievements from migration onward; do not invent prior history. All future purchases obey their next-rank prerequisites. Consequently, an existing high-training garden with relatively few kills may need to catch up on kills before purchasing more training, but loses none of its purchased strength.


## Direction contract

**Thesis:** Make permanent growth inspectable in the existing sidebar: select an icon, understand the next rank, then purchase when eligible.

**Own-world:** Inherit the garden game's ink background, cream text, mint selection, gold currency, 6px controls, existing typeface, and pixel cat artwork. New geometric line icons use a consistent stroke, with color identifying their powerup family.

**Story:** Undiscovered powerups are absent. Available holds discovered unfinished powers; Owned shows the collection. A locked next rank explains its milestone and progress. Cat inspection temporarily replaces this panel.

**First viewport:** Preserve recruitment above and rebirth/wave controls below. The replacement area contains tabs and pagination, eight selectable icons per page, then title/rank, effect description, current/next benefits, prerequisite progress, and a purchase button at the lower right.

**Form:** Local extension of the established desktop game; code-led, no concept tournament or approved comp. Signature interaction is persistent icon selection revealing the rank's benefit and milestone. Seed: none (local extension).

**Finish:** Verify fresh, owned, locked, completed, final-page, long-content, and cat-inspection states at standard and minimum desktop sizes; review rendered results and document the extension. No new shipping raster artwork.


## Initial balance

Effects are described in the confirmed roster and in-game details. Non-training percentage bonuses add across ranks within one powerup; separate damage/reward factors multiply. Discounts are capped at 25% for recruitment/tier upgrades and 50% for repairs. Training retains its existing 25% compounded damage/health growth.

For the table below, rank n costs the starting price multiplied by the price growth to the power n − 1. A milestone's threshold is its first value plus the rank step multiplied by n − 1. Training instead requires 4 × n × (n − 1) lifetime kills. Cat powers additionally require the named cat's historical tier to reach min(6, 1 + floor((n − 1) / 2)); Heavy Claws requires Lucky Claws rank one.

| Powerup | Rank cap | First price | Price growth | Milestone | First value | Rank step |
| --- | --- | --- | --- | --- | --- | --- |
| Patrol Training | Unlimited | 100 | ×1.5 | kills | 0 | Formula above |
| Quick Paws | 5 | 140 | ×2.4 | best | 2 | 4 |
| Keen Eyes | 5 | 180 | ×2.5 | best | 3 | 5 |
| Lucky Claws | 5 | 260 | ×2.6 | kills | 60 | 150 |
| Heavy Claws | 5 | 400 | ×2.6 | best | 6 | 5 |
| Bounty Lessons | 5 | 160 | ×2.8 | best | 2 | 5 |
| Boss Purse | 5 | 1800 | ×3.0 | best | 10 | 10 |
| Thrifty Recruiting | 5 | 200 | ×2.5 | kills | 30 | 120 |
| Efficient Equipment | 5 | 300 | ×2.8 | best | 4 | 5 |
| Repair Kit | 5 | 180 | ×2.4 | kills | 40 | 100 |
| Reinforced Beds | 5 | 180 | ×2.5 | best | 3 | 4 |
| Thick Fur | 5 | 300 | ×2.8 | best | 5 | 5 |
| Catnap | 5 | 320 | ×2.6 | best | 4 | 4 |
| First Aid | 5 | 700 | ×3.0 | rebirths | 1 | 1 |
| Last Stand | 1 | 900 | ×1.0 | best | 8 | 0 |
| Needle Bolts | 3 | 350 | ×3.2 | best | 4 | 6 |
| Static Whiskers | 3 | 600 | ×3.3 | best | 7 | 7 |
| Focus Fire | 5 | 400 | ×2.7 | best | 5 | 5 |
| Giant Hunter | 5 | 1500 | ×3.0 | best | 9 | 8 |
| Finishing Touch | 5 | 800 | ×2.8 | best | 8 | 6 |
| Wider Blast | 5 | 350 | ×2.8 | best | 4 | 5 |
| Hot Embers | 5 | 500 | ×2.9 | best | 6 | 5 |
| Concussion | 3 | 900 | ×3.2 | best | 8 | 7 |
| Aftershock | 1 | 4500 | ×1.0 | best | 14 | 0 |
| Siege Shells | 5 | 650 | ×2.8 | best | 7 | 6 |
| Deep Chill | 5 | 300 | ×2.7 | best | 3 | 5 |
| Lingering Cold | 5 | 350 | ×2.7 | best | 4 | 5 |
| Ice Lock | 3 | 1000 | ×3.2 | best | 9 | 7 |
| Brittle Ice | 5 | 850 | ×2.9 | best | 8 | 6 |
| Winter Gift | 1 | 5000 | ×1.0 | best | 15 | 0 |

Burns retain the strongest active damage rate and last three seconds. Piercing and chain hits cannot trigger themselves recursively. Cannon echoes do not trigger burns, stuns, or additional echoes. Freeze and stun share a recovery window: bosses are controlled for at most 0.3 seconds, followed by three seconds of immunity; ordinary enemies receive 0.8 seconds of immunity after control ends. Killing a chilled enemy can spread slow, but never duplicates rewards.

Version-3 saves include ranks, discoveries, historical cat tiers, the combat random stream, active burns/control/focus state, and delayed echoes. Loading is paused and validation completes before replacing the current garden. The 30 authored SVG icons share the existing game's palette and geometry; no generated raster assets were added.

### UI implementation evidence

The native sidebar retains recruitment above and rebirth/wave controls below. Available/Owned tabs and previous/next buttons browse eight icons per page. Selection reveals name, rank, description, current/next effects, milestone progress, and a lower-right purchase control; lock and completion badges supplement color. Cat inspection provides Back to powerups. The controls participate in the existing Tab/Shift+Tab and Enter navigation.

The implementation retains the fallback typeface, ink background (`#131c26`), panel fill (`#202e3a`), cream text (`#f4edd7`), mint selection (`#89dfb5`), gold currency/milestones (`#ffc46b`), and existing pixel artwork. Buttons retain 6px corners; icon tiles use 5px corners. The 30 SVGs share a 32×32 canvas and 1.8px rounded strokes, tinted by family: mint Patrol, gold Economy/Bolt, pink Durability, coral Cannon, and blue Frost.

Source inspection covered `game/ui/main.gd`, the SVG icons, and the window settings. Visual review covered `.impeccable/review/` captures `fresh`, `powerups`, and `powerups-owned` at 1152×810, plus `powerups-locked`, `powerups-last`, `powerups-empty`, `injured`, `winter`, `aftershock`, and `help-dialog` at the minimum 960×675. These show fresh/owned, locked, final-page, empty, completed, long-description, cat-inspection, and corrected help layouts fitting their panels. This records implementation and visual evidence; it adds no test-run claims.
