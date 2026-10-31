# Purrimeter — The Garden Guard

An endless pixel-art cat tower defence game for native macOS and Windows, built from one Godot 4.7.2 project.

## Play the builds

- **Mac:** open `dist/macos/Purrimeter.app`. The original `build/Purrimeter.app` handoff is updated too.
- **Windows:** send `dist/Purrimeter-Windows.zip`. Extract the whole ZIP and run `Purrimeter.exe`, keeping `Purrimeter.pck` beside it. No Godot editor or installation is required.
- `dist/Purrimeter-macOS.zip` contains the universal Intel/Apple Silicon Mac app.

These are personal-use builds: Mac signing is ad hoc and Windows is unsigned. Public distribution signing/notarization is not configured.

## Controls

Click a cat card, then an empty tile to recruit. Click a placed cat to inspect, upgrade, repair or sell. **1 / 2 / 3** select cats, **Space** pauses, **Esc** cancels placement, and **N** starts the next attempt. Building, repairs and upgrades work while paused. Use the 1×/2× speed and Sound buttons as needed. Leaving the game window pauses combat and music.

Click an enemy or boss to inspect its animated portrait, name, current/max health, speed, tower damage, and active effects. A highlight follows the selected enemy; inspection does not change targeting. Cats take priority on occupied tiles, and recruitment mode keeps placing cats. **Esc** or **Back to powerups** closes inspection; death or the end of the attempt clears it automatically. Both cat and enemy inspector portraits animate while paused.

**Tab / Shift+Tab** move between controls and the garden, with a visible focus outline. **Enter** activates a focused control. On the garden, use **arrow keys** to choose a tile and **Enter** to recruit or inspect a cat or enemy. Selecting a cat with 1 / 2 / 3 moves keyboard focus to the garden. During paused combat, the main **Resume level** button continues the current attempt.

## Progression

- **Auto-start next level** is off by default. After each clear, a large 3–2–1 shrinks and fades in the center of the garden, then the next level starts. The countdown takes three real seconds at either combat speed. Space pauses it; N starts early. Use the **Auto** checkbox to the right of Start/Wave in progress. Your choice and any pending countdown are saved; loading resumes paused. Defeat, rebirth, and new gardens still wait for Start.
- Three cat types, each with a purchased form plus **five upgrades**: six animated forms and distinct attack effects.
- Enemies take the shortest open route; fully blocked enemies attack towers along the quickest estimated breach route.
- Repeated backtracking builds frustration. After 12 tile-lengths of revisits, that enemy enters permanent **frenzy**, moving toward the exit and destroying obstructing cats even when an open route exists. Increasing redness warns you; red with animated sweat means frenzy. Long unchanged mazes are unaffected. Slow, stun, and normal combat stats still apply; saves preserve the history.
- All enemies move diagonally at the same physical speed as straight movement. Towers block their whole square and prevent corner cutting, so corner-touching towers form a wall. Squares needed to clear a diagonal crossing temporarily reject construction. Blocked enemies can attack diagonally only when both side squares are clear, destroying the tower before entering its square.
- **One escape loses the attempt.** Return one level, keeping coins, upgrades, training and surviving cats—including damage. At level one, an empty patrol with fewer than 50 coins receives enough for one Tuxedo Scout.
- Total enemy health **doubles every level**. Total base coin bounty grows by **1.5×**. Progression continues beyond level 20.
- **Level health** beneath the field/arrival counts shows the entire wave's remaining health, including enemies still waiting to arrive and the boss. Damage drains the bar; arrivals do not refill it. The bar appears during active attempts, including tactical pause.
- A huge boss appears every tenth level: caterpillar, cobra, spider, then hound, cycling thereafter. Bosses use the same routing rules; their artwork is larger than their logical footprint.
- Boss levels play five original, more intense chiptune themes: levels 10–50 cycle through all five, then repeat. Music crossfades at the start and end of the whole level; the garden theme resumes afterward. Retries and saved boss levels restart their assigned theme.
- **30 permanent powerups** cover patrol stats, economy, durability, and unique Bolt/Cannon/Frost abilities. Click a discovered icon to inspect its current effect, next benefit, and prerequisite. **Available / Owned** switches between unfinished powerups and your collection. Hidden icons appear when their discovery milestones are earned; discoveries persist through rebirth and defeat. Each rank needs its own milestone and coin price. Completed powers remain in Owned. Select a placed cat for its controls; **Back to powerups** restores the browser.
- **Patrol Training** increases all cats' damage and maximum health by 25% per purchase, compounded, while preserving their health percentage. Initial cost: 100 coins; each purchase costs 1.5× the previous one. It has unlimited ranks: rank one is available immediately, and rank n requires 4 × n × (n − 1) lifetime kills. Replayed levels count.
- **Rebirth** unlocks after clearing level 5 and can be used between attempts. Return to level 1, retain coins, surviving cats, tiers, training and existing bonuses, and fully heal cats.
- Each rebirth adds **10 percentage points per highest level cleared that run** to permanent coin rewards. Two level-five rebirths give +100% total, or 2× normal rewards. Clear level 5 again to qualify after each rebirth.

## Saves

Autosave runs every four seconds, after changes, when losing focus and on exit. Loads resume paused. **Export / Import** transfers a JSON save between computers. New Garden resets all progression after confirmation.

- Mac: `~/Library/Application Support/Purrimeter/save.json`
- Windows: `%APPDATA%/Purrimeter/save.json`

The original Swift game's save was deleted as requested. Existing Godot version-2 gardens migrate automatically, preserving every training rank and crediting recorded lifetime milestones and surviving cats. Version-3 saves also preserve powerups, discoveries, and active combat effects. No migration from the original Swift format is performed. Game tests and screenshot previews do not modify the player's save.

## Build on macOS

```sh
./scripts/setup_godot.sh  # downloads official pinned Godot and export templates
./scripts/test.sh
./scripts/build.sh       # creates BOTH Mac and Windows packages
```

No paid engine, Windows computer, Apple developer account or Windows compiler is needed to export these personal-use packages from the Mac. Set `GODOT` to an alternate Godot 4.7.2 executable if desired. Export templates are kept in `.tools/templates`, outside the shipped game. The repo must remain together so the relative template paths in `game/export_presets.cfg` resolve.

To develop interactively, open `game/project.godot` in Godot 4.7.2. After installing matching export templates, presets can also be adapted to the local Godot installation on Windows or Linux.

Native GUI checks should run from a normal desktop session outside an agent sandbox:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path game -- --smoke-test
.tools/Godot.app/Contents/MacOS/Godot --path game -- --preview "$PWD/build/preview.png"
.tools/Godot.app/Contents/MacOS/Godot --path game -- --preview "$PWD/build/gallery.png" --gallery
```

## Source map

- `game/core/session.gd`: simulation, economy, progression and save validation.
- `game/core/powerups.gd`, `powerup_combat.gd`, `powerup_save.gd`: the 30-powerup catalog, milestone rules, combat effects, and save migration.
- `game/core/routes.gd`: shortest open paths and weighted breaches.
- `game/core/frenzy.gd`: repeated-travel tracking and frenzy save validation.
- `game/core/amount.gd`: fractional currency and overflow-resistant large amounts.
- `game/core/balance.gd`: cat/enemy stats, boss rotation and wave compositions.
- `game/ui/`: window interface, sprite animation, attack effects and audio.
- `game/tests/`: behavior, campaign, and artwork inspection tools.
- `game/assets/`: runtime artwork and audio. See `docs/artwork.md` for generation prompts.
- `legacy/macos/`: superseded Swift prototype, preserved for reference.

Godot and third-party license notices accompany each distribution. See `docs/verification.md` for what was tested and its limits.
