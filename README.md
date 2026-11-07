# Purrimeter — The Garden Guard

A five-level pixel-art cat tower defence game for browsers, Android, iOS, native macOS and Windows, built from one Godot 4.7.2 project.

Play in your browser at **[purrimeter.graham.pub/play/](https://purrimeter.graham.pub/play/)**, download the game at **[purrimeter.graham.pub](https://purrimeter.graham.pub/)**, or install it from Google Play once the listing is published (see [docs/android.md](docs/android.md)). The page highlights the download for your operating system and includes installation help for the unsigned builds. Website source is in `website/`; preview and publication instructions are in [docs/website.md](docs/website.md).

The launch menu offers **Single player** and **Multiplayer**. Both use your same saved garden. Multiplayer supports public, optionally password-protected games for up to three players, with live remote fields, independent progression, and shared chat.

## Game updates

The game checks the selected server in the background at launch. Open **Check for updates** on the main menu or **Game updates** in the pause menu to download a verified official release, then choose **Restart and play**. Your garden and settings are preserved. Single player remains available offline or if you decline an update; joining multiplayer requires the server’s current game release.

Existing multiplayer visits can continue after a release is published, including their 60-second reconnect reservations. Existing builds without an updater need one manual download of version 3.0.0. See [update operations](docs/game-update-operations.md) for signing, publication, recovery, and self-hosting.

## Multiplayer

Choose a player name in **Connection settings**, then open Multiplayer to create or join a game. The default server is `wss://purrimeter.graham.pub/ws` and is live. The address can be changed in settings.

Your garden stays on the left. One other field fills the right-hand field area; with three players, the other two share it vertically. **View** enlarges a field for read-only cat, enemy, and powerup inspection and switches music and gameplay effects to that garden. Your own garden keeps its running or paused state while viewing. Closing View restores your audio; small previews stay silent. Each player controls their own waves, rebirths, pause, and speed. Opening a menu pauses only your combat.

Press **T** to focus chat, **Enter** to send, and **Esc** to leave the text box. **Mute** hides one player's messages; **Report** sends that player's recent messages to the server operator and mutes them for you. Chat notification sound is separately switchable. The owner can kick a player; ownership transfers when they leave. Dropped connections reserve a place for 60 seconds and reconnect automatically, leaving your garden paused. **Continue offline** in the Escape menu keeps your personal game going without the other players.

Server hosting instructions are in [server/README.md](server/README.md). The self-hosting release is `dist/Purrimeter-Server.tar.gz`, including Linux amd64/arm64 binaries and Docker Compose/Caddy configuration. No VPS changes or DNS updates are performed by the build scripts.

## Play the builds

- **Mac:** open `dist/macos/Purrimeter.app`. The original `build/Purrimeter.app` handoff is updated too.
- **Windows:** send `dist/Purrimeter-Windows.zip`. Extract the whole ZIP and run `Purrimeter.exe`, keeping `Purrimeter.pck` beside it. No Godot editor or installation is required.
- `dist/Purrimeter-macOS.zip` contains the universal Intel/Apple Silicon Mac app.

These downloadable builds use ad hoc signing on Mac and are unsigned on Windows. Public distribution signing/notarization is not configured; the website includes the relevant installation notes.

## Android

The Android app (`com.roundhouselabsinc.purrimeter`) is the same game with the phone layouts, published to Google Play by `scripts/deploy_all.sh` as part of every release. Updates arrive through Play; Game updates opens the listing when the server requires a newer release. The back button steps out of panels and menus, and backgrounding the app pauses and saves. Store listing text and images live in `store/android/`.

Android gameplay uses a full-screen, zoomable field with floating forest-green controls. **Recruit** opens the four cat roles; select one, tap a tile, then **Confirm**. **Fit / Focus** switches between the whole garden and the enlarged view; pinch, drag, or tap the overview to navigate. Start/Resume, speed, Auto and Menu stay at the top. Inspection and Powerups use compact panels with actions kept visible; the Powerups filter also opens **Patrol & rebirth** for Rebirth and Draft Collection. Android Back closes the innermost panel or placement first. macOS and browser layouts retain their existing controls.

## iOS

The iPhone and iPad app shares Android's floating controls and sidebar menus, with iOS screen scaling and safe areas. It builds as a signed App Store IPA and joins every `deploy_all.sh` release. Apple uploads, repository listing updates, and review submission use checkpointed retries. See [docs/ios.md](docs/ios.md) for Apple setup, screenshots, first-release status, and the `--skip-app-store` escape hatch. The website shows Coming soon until Apple publishes the first version.

## Browser and phone play

Phone play uses portrait or landscape layouts. Select a cat, tap a tile to preview it, then Confirm; pinch to zoom, drag to pan, and Fit to see the whole garden. Tap cats or enemies to inspect them. Powerups open in a scrollable panel. Pause remains available while building, and Menu pauses combat. In phone multiplayer, player tabs switch gardens and Chat opens the conversation and moderation controls.

Browser progress autosaves locally in this browser profile. Export/Import transfers the same garden files as desktop. Clearing site data also clears the browser garden, so export a backup before doing so. Only one tab owns autosaving at a time; Play in this tab takes over safely. Storage failures pause play and offer Export or an explicit Continue without autosave choice.

Switching apps or hiding the page pauses your garden; returning requires Resume. Single player continues if connectivity drops after loading. Reloading requires internet; installable/offline reopening is not part of this version. Browser updates save before reloading the same page. See [mobile design and verification](docs/mobile-browser.md) for test coverage and outstanding physical-device checks.

## Controls

Click a cat card, then an empty tile to recruit. Click a placed cat to inspect, upgrade, repair or sell. **1 / 2 / 3 / 4** select cats, **Space** pauses, **Esc** cancels placement, and **N** starts the next attempt. Building, repairs and upgrades work while paused. Use the 1×/2× speed button as needed. Leaving the game window keeps combat and Auto countdowns running, while music and gameplay effects become silent until you return.

With no placement or inspection active, **Esc** opens the pause menu; the visible **Menu** button opens it directly. The menu contains Route on/off, Sound on/off, Export, Import, New Garden, help, and a confirmed return to the main menu. Closing it keeps combat paused; **Resume** continues it. Export, Import, and New Garden also work during multiplayer, preserving your membership and chat.

Click an enemy or boss to inspect its animated portrait, name, current/max health, speed, tower damage, and active effects. A highlight follows the selected enemy; inspection does not change targeting. Cats take priority on occupied tiles, and recruitment mode keeps placing cats. **Esc** or **Back to powerups** closes inspection; death or the end of the attempt clears it automatically. Both cat and enemy inspector portraits animate while paused.

**Tab / Shift+Tab** move between controls and the garden, with a visible focus outline. **Enter** activates a focused control. On the garden, use **arrow keys** to choose a tile and **Enter** to recruit or inspect a cat or enemy. Selecting a cat with 1 / 2 / 3 / 4 moves keyboard focus to the garden. During paused combat, the main **Resume wave** button continues the current attempt.

## Progression

Choose from **five levels: 10, 20, 30, 40 waves, then endless**. Beat each finite level to unlock the next. **New Garden** shows every level and lets you choose any unlocked one, then confirms replacing your garden. Each starts at wave one with fresh terrain, coins, cats, and garden progression. Level unlocks, achievements, and cat skins remain yours.

Clearing the final wave ends that garden’s challenge and opens a victory screen with **View garden**, **Choose level**, and **Next level**. Auto and rebirth stop at victory; the completed garden remains available to view, save, and export. Players in a multiplayer room may play different levels independently. See [the complete progression rules](docs/five-level-progression.md).

- **Auto-start next wave** is off by default. After each clear, a large 3–2–1 shrinks and fades in the center of the garden, then the next wave starts. The countdown takes three real seconds at either combat speed. Space pauses it; N starts early. Use the **Auto** checkbox to the right of Start/Wave in progress. Your choice and any pending countdown are saved; loading resumes paused. Defeat, rebirth, and new gardens still wait for Start.
- Four cat types, each with a purchased form plus **five upgrades**: six animated forms and distinct attack effects. **Ranger (Anti-air)** unlocks permanently after beating level 1, including for existing players who unlocked level 2. Ranger attacks air only, Gunner (Cannon) attacks ground only, and Scout (Bolt) and Sage (Frost) attack both.
- New gardens contain level-specific terrain: sparse rocks in Open Meadow, more rocks in Stone Garden, then one, two, or three streams in Winding Brook, Twin Streams, and Wildwater. They block recruitment and ground-enemy movement, cannot be destroyed, and allow cats to shoot across them. Terrain and connected visual styles persist through defeat, rebirth, saves, and multiplayer. Existing gardens keep their original empty terrain. See [obstacle rules](docs/obstacles.md).
- Ground enemies take the shortest open route; fully blocked enemies attack towers along the quickest estimated breach route.
- Repeated backtracking builds frustration. After 12 tile-lengths of revisits, that enemy enters permanent **frenzy**, moving toward the exit and destroying obstructing cats even when an open route exists. Increasing redness warns you; red with animated sweat means frenzy. Long unchanged mazes are unaffected. Slow, stun, and normal combat stats still apply; saves preserve the history.
- Ground enemies move diagonally at the same physical speed as straight movement. Towers block their whole square and prevent corner cutting, so corner-touching towers form a wall. Squares needed to clear a diagonal crossing temporarily reject construction. Blocked enemies can attack diagonally only when both side squares are clear, destroying the tower before entering its square.
- **Moths** join selected waves in levels 2–5. They fly straight from IN to OUT over cats and terrain, never attack towers or enter frenzy, and can be slowed or frozen. You may build beneath them. Incoming-air previews identify the threat. See [air defense and saved-wave compatibility](docs/anti-air.md).
- **One escape loses the attempt.** Return one wave, keeping coins, upgrades, training and surviving cats—including damage. At wave one, an empty patrol with fewer than 50 coins receives enough for one Scout.
- Total enemy health **doubles every wave**. Total base coin bounty grows by **1.5×**. Wave strength follows the same curve in every level; endless has no final wave.
- **Wave health** beneath the field/arrival counts shows the entire wave's remaining health, including enemies still waiting to arrive and the boss. Damage drains the bar; arrivals do not refill it. The bar appears during active attempts, including tactical pause.
- A huge boss appears every tenth wave: caterpillar, cobra, spider, then hound, cycling thereafter. Bosses use the same routing rules; their artwork is larger than their logical footprint.
- Boss waves play five original, more intense chiptune themes: waves 10–50 cycle through all five, then repeat. Music crossfades at the start and end of the whole wave; the garden theme resumes afterward. Retries and saved boss waves restart their assigned theme.
- **30 permanent powerups** cover patrol stats, economy, durability, and unique Bolt/Cannon/Frost abilities. Click a discovered icon to inspect its current effect, next benefit, and prerequisite. **Available / Owned** switches between unfinished powerups and your collection. Hidden icons appear when their discovery milestones are earned; discoveries persist through rebirth and defeat. Each rank needs its own milestone and coin price. Completed powers remain in Owned. Select a placed cat for its controls; **Back to powerups** restores the browser.
- **Patrol Training** increases all cats' damage and maximum health by 25% per purchase, compounded, while preserving their health percentage. Initial cost: 100 coins; each purchase costs 1.5× the previous one. It has unlimited ranks: rank one is available immediately, and rank n requires 4 × n × (n − 1) lifetime kills. Replayed waves count.
- **Rebirth** unlocks after clearing wave 5 and can be used during combat or between attempts. Return to wave 1, retain coins, surviving cats, tiers, training and existing bonuses, and fully heal cats. Remaining enemies disappear; only cleared waves count toward draft quality. Wave one waits for a manual Start, even with Auto enabled.
- **Rebirth Draft** replaces automatic coin bonuses: confirm rebirth, then choose one permanent improvement from up to three eligible offers. The 12-improvement collection has capped ranks, prerequisites, and stronger-offer odds after deeper runs. Offers survive reopening without rerolls. Existing coin bonuses stay; if no normal improvement is eligible, the sole fallback adds 10 percentage points. **Draft Collection** shows every reward and requirement (inside Powerups on phones). Clear wave 5 again to qualify. New Garden resets the draft collection. See [the complete rules](docs/rebirth-draft.md).

## Achievements

Earn **30 achievements** through milestones, lifetime progress, tactical challenges, and mastery goals. Open **Achievements** from the main menu or Escape menu to browse All / In Progress / Earned and inspect exact requirements. New unlocks celebrate with a brief banner and chime. Achievements grant recognition, persist through New Garden, and travel with exported saves; imports keep earned badges and the higher counter values without adding overlapping totals. Existing saves receive credit for recorded accomplishments.

Open **Cat Skins** from the main or Escape menu to choose among **five skins for each original cat** and Ranger’s default calico appearance. Ranger’s skin unlocks with the cat after level 1. Four skins per original type unlock through achievements; locked looks stay silhouetted while their requirements and progress remain visible. Preview unlocked skins across all six tiers, then Equip to change all existing and future cats of that type. Skins are cosmetic, permanent, retroactive for earned achievements, and visible to other gardeners. Save transfers include selections, preserving the destination device's existing choices.

## Saves

Autosave runs every four seconds, after changes, when losing focus and on exit. Loads resume paused. **Export / Import** transfers a JSON save between computers. New Garden resets garden progression after level selection and confirmation, while keeping permanent level unlocks, achievements, and cat skins.

**Reset all progress** is available only on the main menu. After confirmation, it clears your garden, level unlocks, achievements and earned skins, then leaves a fresh level-one garden ready with 200 coins. Preferences and multiplayer identity stay; Auto keeps its setting, but the first wave waits for Start. There is no undo or automatic backup. Export first if you want to keep a copy; importing an old export can restore its progress.

- Mac: `~/Library/Application Support/Purrimeter/save.json`
- Windows: `%APPDATA%/Purrimeter/save.json`

The original Swift game's save was deleted as requested. Existing Godot version-2 gardens migrate automatically, preserving every training rank and crediting recorded lifetime milestones and surviving cats. Version-3 saves also preserve powerups, discoveries, and active combat effects. No migration from the original Swift format is performed. Game tests and screenshot previews do not modify the player's save.

Older Godot gardens continue in endless mode with their existing possessions and wave intact. Recorded highest cleared wave (including achievement history) grants new-garden access at 10/20/30/40 for levels 2/3/4/5. Continuing a legacy endless garden does not grant permission to create another until unlocked. Save transfers preserve the higher unlocked level from either device.

## Build on macOS

To build, test, sign, and deploy the complete committed project to the production VM, including the website, native/browser clients, server, and self-hosting download:

```sh
./scripts/deploy_all.sh 4.0.2 --preview
./scripts/deploy_all.sh 4.0.2
```

Choose a version newer than production and commit changes first. The command includes verification, resumable uploads, conditional relay restarts, and retention-based cleanup. See [the deployment workflow](docs/deployment-workflow.md) for prerequisites and recovery.

```sh
./scripts/setup_godot.sh  # downloads official pinned Godot and export templates
./scripts/test.sh
./scripts/build.sh       # creates macOS, Windows and browser packages
./scripts/build_web.sh   # browser-only local export to dist/web
./scripts/test_multiplayer.sh # Go race tests + three isolated Godot clients
./scripts/build_server.sh     # Linux binaries + Docker deployment archive
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
- `game/core/levels.gd`: the five level lengths, selection labels, legacy unlock credit, and progression validation.
- `game/core/achievements.gd`: the 30-achievement catalog, lifetime progress, challenge evidence, and migration.
- `game/ui/achievements_panel.gd`, `achievement_fanfare.gd`: collection menu and queued celebrations.
- `game/core/powerups.gd`, `powerup_combat.gd`, `powerup_save.gd`: the 30-powerup catalog, milestone rules, combat effects, and save migration.
- `game/core/routes.gd`: shortest open paths and weighted breaches.
- `game/core/terrain.gd`, `game/ui/terrain_art.gd`: persistent obstacle generation, validation, and connected pixel-art terrain.
- `game/core/frenzy.gd`: repeated-travel tracking and frenzy save validation.
- `game/core/amount.gd`: fractional currency and overflow-resistant large amounts.
- `game/core/balance.gd`: cat/enemy stats, boss rotation and wave compositions.
- `game/ui/`: window interface, sprite animation, attack effects and audio.
- `game/ui/app.gd`: launch menu, game browser, pause menu, remote views, and chat.
- `game/network/`: WebSocket client, separate installation settings, default endpoint, and validated visible field representation.
- `server/`: Go relay, protocol/lifecycle tests, and VPS deployment configuration.
- `game/tests/`: behavior, campaign, and artwork inspection tools.
- `game/assets/`: runtime artwork and audio. See `docs/artwork.md` for generation prompts.
- `legacy/macos/`: superseded Swift prototype, preserved for reference.

Godot and third-party license notices accompany each distribution. See `docs/verification.md` for what was tested and its limits.
