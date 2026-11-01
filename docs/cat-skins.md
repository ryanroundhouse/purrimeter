# Cat skins

Status: implemented in the shared desktop game; local verification and package checks are recorded below.

## Confirmed decisions

1. Each of the three cat types has five total skins: its current appearance, available immediately, and four achievement unlocks. This means twelve additional skins.
2. Skins change fur patterns and coordinated equipment colors while preserving silhouettes, weapons, all six tower-tier appearances, and four animation poses per tier. Skins do not change combat.
3. Use the twelve existing achievements mapped below. Each unlock requires one achievement, with no coin cost. No new achievements are needed.
4. Already-earned achievements unlock their associated skins retroactively. Unlocks and selected skins belong to the player and survive defeat, rebirth, and New Garden.
5. The player selects one skin per cat type. Selection immediately updates every existing cat of that type, future purchases, and gameplay previews.
6. A dedicated Cat Skins option appears in the main and Escape menus. It shows each cat's appearances, selection, exact unlock requirements, and progress. Opening pauses the local garden; closing restores the prior pause state, following Achievements.
7. Multiplayer viewers see the garden owner's selected skins.
8. Use Scout, Gunner, and Sage consistently as cat display names, retaining Bolt, Cannon, and Frost as combat-role identifiers. Show the skin name separately.
9. Unlocking never automatically equips a skin. Include the skin name and thumbnail in its achievement fanfare; retroactive unlocks appear in one summary. Follow existing fanfare scheduling, sound, and pause behavior.
10. Exports include selected skins. Merge achievements according to the existing policy, granting skins earned on either device. Keep this device's saved selection for each cat; adopt its imported selection only when this device has no saved preference for that cat.

## Accepted roster

The three current appearances are available immediately. Each row below adds one unlockable skin.

| Cat | Skin | Appearance | Achievement | Exact requirement |
| --- | --- | --- | --- | --- |
| Scout | Ginger Scout | Orange tabby, forest-green equipment | First Watch | Clear level 1. |
| Scout | Silver Scout | Silver tabby, navy equipment | Bolt from the Blue | Clear level 5 or higher using only Bolt cats throughout the attempt. |
| Scout | Calico Scout | Calico coat, plum equipment | Cat Person | Recruit 50 cats across gardens. |
| Scout | Golden Scout | Golden coat, ivory-and-gold equipment | Legendary Guard | Clear level 50. |
| Gunner | Smoky Gunner | Gray coat, burgundy equipment | Sharper Claws | Purchase a tower-tier upgrade. |
| Gunner | Tiger Gunner | Brown tabby, copper equipment | Cannon Fodder | Clear level 5 or higher using only Cannon cats throughout the attempt. |
| Gunner | Snow Gunner | White coat, steel-blue equipment | Big Game Hunter | Defeat 25 bosses across gardens. |
| Gunner | Royal Gunner | Black coat, crimson-and-gold equipment | Dream Team | Have a tier-six Bolt, tier-six Cannon, and tier-six Frost placed together. |
| Sage | Classic Siamese | Cream coat with dark points, blue equipment | A Little Extra | Purchase a powerup rank. |
| Sage | Silver Sage | Silver coat, deep-blue equipment | Cold Reception | Defeat a boss while slowed by a Frost cat or its powerups. |
| Sage | Lilac Sage | Gray-lilac coat, violet equipment | Power Collector | Purchase 25 powerup ranks across any powerups. |
| Sage | Aurora Sage | White coat, teal-and-purple equipment | Full Toy Box | Own at least one rank of all 30 powerups in one garden. |

## Menu and discovery

- Three cat tabs, each containing five skin cards, lead to an animated selected preview with a tower-tier selector.
- Unlocked skins can be previewed across all six tiers. An explicit Equip button applies the previewed skin immediately. Browsing alone never changes the equipped skin.
- Locked skins display solid silhouettes in cards and previews. Do not reveal fur, colors, equipment details, or the full artwork through hover, animation, or tier selection. Names, associated achievements, exact requirements, and progress remain visible.
- Locked skins cannot be equipped. Distinguish locked, unlocked, and equipped states clearly.
- Seeing another player's equipped skin is allowed even when it is locked locally. This neither unlocks the skin nor reveals its full artwork in the local collection.
- The default skin remains available for selection at any time.

## Artwork constraints

The defaults are the tuxedo Scout, orange-tabby Gunner, and solid-black Sage. Display names are now Scout, Gunner, and Sage; skin names identify their appearances separately. See [Artwork and audio](artwork.md) for source prompts and edits.

Each complete skin requires six tiers with four poses each. Twelve additional skins therefore require 288 sprite poses. Preserve transparent backgrounds, readable tier progression, and the existing pixel-art style.

## Design completion

No open product decisions remain from the interview. Both rounds were accepted, with the locked-preview correction incorporated above.

## Implementation

`game/core/cat_skins.gd` defines the fifteen stable skin identities and their achievement requirements. Choices and acknowledged skin announcements are optional fields in the existing player-wide achievement record, so older saves remain valid and existing updater backup/recovery covers them. Unlocks derive from earned achievements. Imports keep local choices, adopt valid imported choices only where no local preference exists, and reject malformed identities before replacing the garden. Unearned selections cannot bypass unlocks.

The shared renderer uses the selected skin for placed cats, placement previews, recruitment cards, inspection portraits, and main-menu cats. New atlases retain their original generated alpha. Measured bounds and cached alpha-outline geometry isolate each animation pose, preventing adjacent sprite tips from appearing in irregular sheet layouts. `scripts/measure_skin_bounds.gd` reproduces the source bounds without modifying images.

Live field messages carry bounded, validated skin IDs, independent of achievement ownership. Older messages without skin data use the defaults. The Cat Skins dialog preserves pause/input state and uses native focusable controls; browsing never equips. It extends the existing Patrol dialog with the same ink panels, cream text, mint focus and progress accents, gold reward labels, and rounded frame used by Achievements. Achievement banners include skin rewards, while imported and historical rewards use summaries.

## Verification

- `game/tests/cat_skins.gd`: all unlocks, per-type choices, persistence, legacy saves, import precedence/idempotency/atomic rejection, combat neutrality, rebirth, spectator ownership boundaries, retrospective announcements, and all 288 new sprite outlines.
- `game/tests/skin_ui.gd`: menu entry points, silhouettes, all tier previews, explicit equip, pause restoration, New Garden, all skin details, and fanfare scheduling/acknowledgement.
- `game/tests/multiplayer.gd`: equipped skins cross the local relay without transferring ownership.
- Native menu and gameplay captures live under `build/skin-review/` and `build/skin-review-min/`.

Generated assets are in `game/assets/skins/`. Exact built-in imagegen prompts and generation provenance are recorded in [cat-skin-prompts.json](cat-skin-prompts.json); final spacing refinements for the four Sage sheets are recorded in [cat-skin-refinement-prompts.json](cat-skin-refinement-prompts.json). The final generated PNGs retain their alpha unchanged; frame isolation happens at runtime. Local desktop builds do not publish a release; Windows runtime verification requires a Windows machine.

The existing player-wide achievement boundary is explained in [ADR 0011](adr/0011-player-wide-achievements.md). This feature extends achievement rewards to cosmetics without granting gameplay advantages.
