# Purrimeter — The Garden Guard

<!-- impeccable:product-schema 1 -->

## Platform

Native macOS and Windows plus browser play on phones, tablets, and desktop, built from one Godot project.

Preserve desktop game conventions in native builds. Mobile play uses landscape with compact touch controls and a pinch-to-zoom playing field. Android locks to sensor landscape; mobile browsers show a rotate-device prompt in portrait and offer an orientation lock where supported. See `docs/mobile-browser.md` for the confirmed scope and acceptance criteria.

Android gameplay uses the floating-control direction selected from prototype B on 2026-11-05. The square field initially fills the landscape viewport width, with vertical cropping and pinch/pan, a tappable overview, and Fit/Focus. Forest-green controls and gold recruitment float over the field. A collapsible recruitment palette and bounded inspection/Powerups panels replace the broad sidebar. Pause remains accessible while panels are open; Start/Resume remains accessible during placement. Android uses density-scaled 48dp targets and display-safe insets. This selection does not change macOS or browser layout conventions. The three exploratory variants remain on `prototype/android-controls` at `1a0419e`.

Android main and pause menus use sample A (Garden sidebar), selected on 2026-11-05. The main menu places the title and animated cats beside a forest action panel. The pause menu keeps the field visible behind a right-side panel, with pinned Resume/close actions and a scrollable two-column action list. Existing confirmations and progression remain authoritative.

## Users

The original players are the owner on macOS and their son on Windows. The game now also supports public multiplayer discovery on an owner-hosted server, with up to three independent gardeners watching one another play and chatting.

Players build a defensive patrol of cats, shape enemy routes, and improve their patrol through repeated attempts and persistent progression.

## Product Purpose

Provide a standalone cat tower defence game with four finite levels and an unlockable endless fifth level that the family can play on their respective computers. Success means readable tactical decisions, understandable progression, reliable preservation of earned progress, and the same gameplay across native and browser platforms.

## Positioning

The defining combination is cat-themed maze building, enemies that breach towers when blocked or driven into frenzy by repeated backtracking, and persistent growth through six tower tiers, unlimited Patrol Training, and permanent rebirth draft rewards. These are product mechanisms, not claims of market uniqueness.

## Operating Context

- One Godot 4.7.2 project produces a universal macOS app and a portable Windows x86-64 executable/resource pack. Players do not need the Godot editor.
- Play uses a mouse and keyboard in a resizable desktop window. Click a cat card and a tile to recruit; click an existing cat to inspect, upgrade, repair, or sell. Shortcuts include 1/2/3 for cat selection, Space for pause, Esc to cancel placement, and N to start an attempt.
- Click an enemy or boss to inspect its animated portrait, health, speed, tower damage, and effects in the shared sidebar. Inspection does not change targeting. One selected enemy is highlighted while moving; death or attempt completion clears it. Cats take click priority on occupied tiles, and recruitment retains placement behavior. Inspector portraits for cats and enemies animate during tactical pause. See `docs/enemy-inspection-and-level-health.md`.
- During active attempts, **Wave health** below the field/arrival counts shows the remaining health of the whole wave, including unspawned enemies and bosses. Its bar and percentage drain with damage and disappear between attempts, leaving the existing preview/countdown.
- Tactical pause permits building, repairs, and upgrades. Combat and Auto countdowns keep running when the game loses focus; music and gameplay effects are silent until focus returns. Combat supports 1×/2× speed; Route and Sound toggles are in the Escape menu.
- Autosaves preserve progress; loading resumes paused. JSON Export/Import transfers saves between computers. Starting a New Garden requires confirmation. **Reset all progress**, available only on the main menu, confirms clearing the garden, level unlocks, achievements and earned skins while keeping preferences and multiplayer identity. It stays on the main menu with a fresh paused level-one garden. There is no undo or automatic backup; old exports can restore their progress. See `docs/reset-all-progress.md`.
- Launch into a Single player / Multiplayer menu. Escape cancels placement or inspection first, then opens a pause menu with Export/Import and a confirmed return to the main menu. Both modes use the same personal garden; importing or starting a New Garden during multiplayer preserves membership and chat.
- Check for game updates in the background at launch, with a manual check in the menu. Single player remains available while checking, after declining an update, or after a failure. New multiplayer admission requires the selected server to confirm the installed release is current; failed checks offer Retry. A server requiring an older release explains the mismatch without offering a downgrade.
- Updates download inside the game without quitting. “Restart and play” saves the garden and settings, leaves multiplayer, installs the verified update, and returns to the main menu with the garden paused. Failures preserve a usable installation and player data, with Retry and a verified download plus manual installation instructions when automatic replacement is unavailable. Retain the previous application and pre-update data until the replacement passes its first startup check; later gameplay must not be rolled back automatically.
- A game release includes macOS, Windows, and browser packages and becomes current only when all three are ready; website-only changes do not advance it. Accept only officially signed releases, including on custom servers. Existing multiplayer sessions and reconnects within their 60-second reservation may continue on the previous release; subsequent creates and joins require the current release. Unpublished development builds require explicit local/test-server permission. Existing clients without the updater need one manual download. See `docs/game-updates.md`.
- Multiplayer shows the local field on the left and one or two remote fields on the right. Remote fields support read-only inspection. View switches music and gameplay effects to the selected garden while preserving the local garden’s running or paused state; closing View restores local audio. Levels, rebirths, pause and speed are independent. Game names and optional passwords are set at creation; the browser lists games with free places. Shared chat, local muting, owner kicks, ownership transfer, and 60-second reconnect reservations are included. See `docs/multiplayer.md`.
- The default relay endpoint is `wss://purrimeter.graham.pub/ws`, overridable in Connection settings. The server package targets a Linux VPS. DNS and live deployment remain the owner's setup work; local implementation does not publish the service.
- Auto-start next wave defaults off and is saved with the garden. Successful clears show a central shrinking, fading 3–2–1 countdown lasting three real seconds at either combat speed. Pause freezes it, manual Start skips it, and switching it off or rebirthing cancels it. Loading restores a pending countdown paused. Defeat, rebirth, and new gardens wait for a manual start. See `docs/auto-start-next-level.md`.
- Distribution is currently for personal use: macOS signing is ad hoc and Windows is unsigned. Public release signing and notarization are not configured.

Browser play uses local IndexedDB saves and compatible manual transfers, without accounts or cloud synchronization. Hidden pages pause the local garden and require explicit resume. Phone multiplayer shows one garden at a time with player tabs and a chat drawer. Browser builds share the native release identity and update by saving and reloading the same page. First loading requires internet; offline reopening and installation are outside the initial scope.

## Capabilities and Constraints

- Five selectable levels contain 10, 20, 30, 40, and unlimited waves. Beating a finite level permanently unlocks the next. New Garden selects an unlocked level and confirms replacing the current garden; each challenge starts fresh. Finite victory stops combat, Auto, and rebirth, with View garden, Choose level, and Next level actions. Unlocks survive replacement and merge on save import. Legacy gardens remain endless with access credited from recorded wave depth. See `docs/five-level-progression.md`.

- Preserve the square 16×16 playing field and one-cell towers. New gardens contain permanent rock clusters and zero to three winding streams, with increasing density across Open Meadow, Stone Garden, Winding Brook, Twin Streams, and Wildwater. Terrain prevents recruitment and movement, allows shots across it, and stays fixed through defeat, rebirth, saves, and multiplayer. Existing gardens retain their saved terrain, including obstacle-free legacy gardens. Connected terrain shares a consistent pixel-art style, including diagonal contacts and rocky shorelines. See `docs/obstacles.md`. All enemies move in eight directions at constant physical speed; diagonal movement and attacks require both adjacent side squares to be clear of towers and terrain. Corner-touching towers form a wall, and side squares stay reserved during diagonal crossings. Outside frenzy, enemies take the shortest open route whenever one exists and consider breaches only when fully blocked. After 12 tile-lengths of repeated travel, an enemy permanently enters frenzy, reduces its remaining terrain-only route distance to the exit, and commits to destroying obstructions regardless of open detours. Redness builds with frustration; red with animated sweat identifies frenzy. Combat stats and control effects remain unchanged. See `docs/diagonal-movement.md` and `docs/frenzy.md`.
- Preserve three cat roles: Scout (Bolt) for fast single-target attacks, Gunner (Cannon) for splash damage, and Sage (Frost) for slowing enemies. Each has a purchased form plus five upgrades, with six distinct animated forms and attack effects. Visual tower tiers do not implicitly add combat abilities; purchased powerups explicitly add piercing, chain hits, burns, freezes, and other abilities within those roles.
- One enemy escaping immediately loses the attempt. Defeat moves back one wave, with a floor of wave one, while retaining coins, training, upgrades, and surviving cats including their damage. It does not restore a checkpoint.
- Levels contain 10, 20, 30, and 40 waves, followed by an unlockable endless fifth level. Total enemy health doubles per wave; total base coin bounty grows by 1.5×. Every tenth wave features a boss, cycling caterpillar, cobra, spider, and hound. Large boss artwork retains a one-cell logical routing footprint.
- Thirty permanent powerups cover patrol stats, economy, durability, and role-specific combat abilities. All purchased effects work automatically together. Powerups are hidden until discovered; discovery and ranks survive defeat, rebirth, and saving. Each rank has its own lifetime milestone and coin price. The sidebar has Available/Owned tabs, selected-icon details, and a return path from cat inspection. See `docs/powerups.md`.
- Thirty achievements cover introductory milestones, cumulative activity, tactical challenges, and mastery. Main and Escape menus expose requirements and progress with All / In Progress / Earned filters. Brief queued banners and chimes celebrate unlocks when the local garden is visible. Achievements and lifetime counters persist through New Garden, single player, multiplayer, and save transfers; imports merge earned badges and maximum counters rather than adding overlapping totals. Tactical restrictions last for the whole attempt and survive save/resume. See `docs/achievements.md`.
- Each cat type has five cosmetic skins: its original appearance and four permanent achievement unlocks. Cat Skins in the main and Escape menus shows silhouettes for locked skins, exact requirements and progress, and animated previews of all six tiers once unlocked. Equip one skin per type across existing and future cats; multiplayer viewers see the owner's selections. Earned achievements grant skins retroactively. Selections survive New Garden and save transfers, with local selections taking precedence on import. See `docs/cat-skins.md`.
- Patrol Training is unlimited and increases all cats' damage and maximum health by 25% per purchase, preserving health percentage. Its cost starts at 100 coins and grows by 1.5× per purchase. Training does not add visual tiers. Rank one is available from wave one; subsequent ranks require increasing lifetime kills, so replaying challenges always provides a path to further growth.
- Rebirth is available during combat and between attempts after clearing wave five in the current run. It returns to wave one, retains coins, surviving cats, tiers, training, and existing bonuses, and heals surviving cats. Rebirth replaces new automatic coin bonuses with a saved choice of one permanent draft improvement. Three unique eligible offers are weighted by current-run depth; smaller pools show fewer offers and an empty pool offers a +10 percentage-point income fallback. Existing bonuses remain. Draft ranks and prerequisites belong to the garden, reset with New Garden, and appear in a separate Draft Collection. Eligibility must be earned again after rebirth. See `docs/rebirth-draft.md`.
- At wave one, an empty patrol with fewer than 50 coins receives enough for one Scout. Other defeat consequences remain intact.
- Save import must validate data before replacing progress. Preview and test runs must not modify the player's save. The legacy Swift save is not migrated.
- Use `CONTEXT.md` for domain terminology: a level contains multiple waves, a tower tier is an upgrade rank, and a run is progression through waves between rebirths.
- Detailed confirmed progression rules and delegated numerical balance decisions live in `docs/progression-rework.md`; routing and persistence decisions live in `docs/adr/`.

## Brand Commitments

Preserve the name Purrimeter — The Garden Guard, the cat identities, garden-defence theme, and existing animated SNES-style pixel artwork. The existing chiptune music and synthesized effects are part of the game. This initialization confirms the current identity; it does not authorize a rebrand or replacement artwork.

## Evidence on Hand

- `README.md`: player controls, progression, saves, build instructions, and source map.
- `CONTEXT.md`: shared domain vocabulary.
- `docs/progression-rework.md`: confirmed current gameplay and implementation decisions. `docs/game-design.md` is historical and must not override the active progression rules.
- `docs/adr/`: open-route priority, shared desktop implementation, and retained-state endless progression decisions.
- `game/core/` and `game/ui/`: active simulation and desktop interface. `legacy/macos/` is the superseded Swift prototype.
- `game/network/`, `server/`, and `docs/multiplayer.md`: the public relay protocol, identity and room rules, live field views, chat, and deployment instructions.
- `game/updates/`, `docs/game-updates.md`, and `docs/update-ui-review.md`: agreed update behavior, the native update interface, and its local visual and interaction verification.
- `game/assets/` and `docs/artwork.md`: existing cat/enemy/boss sprites, icon, original synthesized audio, and artwork provenance.
- `game/tests/` and `docs/verification.md`: behavior, campaign, scene, artwork, and package checks. The verification record reports macOS testing; the Windows executable has not been tested on a Windows machine or VM. Do not claim otherwise without new evidence.
- Human balance testing beyond the first rebirth and boss remains limited. No public-market validation or commercial positioning is established.

## Product Principles

1. Make tactical state understandable: routes, placement, range, damage, costs, and available actions should help the player decide what to do next.
2. Preserve earned progress and make destructive actions explicit. Defeat has consequences without silently rolling back possessions.
3. Keep gameplay and saves consistent across macOS, Windows, and browser play through the shared implementation.
4. Preserve the cats' distinct combat roles and identities as their visible power grows.
5. Support deliberate play through tactical pause, explicit confirmations, and clear progression feedback.

## Open Decisions

No additional player-specific accessibility needs, age-specific requirements, or difficulty changes were established. Do not infer an age or ability level from the family relationship. Public multiplayer is confirmed; public-release signing and notarization remain outside the configured distribution workflow.
