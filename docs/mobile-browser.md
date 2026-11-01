# Mobile browser play

All three interview rounds were accepted on 2026-10-31. The consolidated design is ready for final confirmation before implementation. These decisions describe the intended browser version, not capabilities already shipped.

## Accepted scope

- Make Purrimeter playable through purrimeter.graham.pub.
- Include the full game: single player, multiplayer, chat, achievements, and cat skins, with the same rules and progression as desktop and an interface adapted for touch.
- Require iPhone Safari and Android Chrome support. Support tablet and desktop browser play through the same browser version.
- Make portrait the primary phone experience and support landscape. Keep the playing field prominent and place secondary controls in panels.
- Autosave locally in the browser and support compatible Export/Import with desktop saves. Automatic cross-device synchronization and accounts are outside the initial scope.

## Accepted interaction and delivery decisions

- Touch recruitment uses cat selection, a tile tap to preview, and explicit placement confirmation. Support pinch zoom and panning for precision. Inspection takes one tap.
- Save and pause the local garden when the browser page becomes hidden. Returning requires explicit Resume. Other players' gardens continue independently.
- On phones, display one garden at a time. Player tabs switch to read-only views of other gardens; the local garden keeps its running or paused state. Put chat in a drawer with an unread indicator.
- Add a prominent Play in browser button to the homepage, opening `/play/`. Retain desktop downloads on the homepage.
- Initially require connectivity to load the game. Once loaded, single player should tolerate losing connectivity. Offline reopening and home-screen installation are outside the initial promise.
- Publish macOS, Windows, and browser play together under one game release identity, supporting cross-platform multiplayer. Existing multiplayer visits can continue on an older release; creating or joining a new multiplayer game requires the server's designated release. Browser updates use save and reload rather than the native updater.

See [ADR 0012](adr/0012-browser-shares-game-release.md) for the release decision.

## Accepted implementation direction

Extend the existing Godot project, sharing its simulation, save format, and artwork with the native versions. Add responsive layouts and browser-specific storage, file transfer, and update handling. Begin with a single-threaded Web export and verify it on phones before extensive interface work. See [ADR 0013](adr/0013-extend-shared-godot-game-to-browser.md).

## Combat and reconnect behavior

- Placement previews, inspection, powerups, and chat preserve the local garden's running or paused state. Keep Pause accessible. Opening Menu pauses combat.
- Confirming a placement rechecks affordability and tile availability. An invalid placement spends nothing and explains why it cannot proceed.
- After a multiplayer interruption exceeds the existing reconnect reservation, keep the garden paused and offer Rejoin or Continue offline. Explain if rejoining fails because the game ended or filled. Never silently enter a different multiplayer game.
- Existing reconnect reservations and release-admission rules remain applicable; a rejoin after reservation expiry is a new admission.

## Saves and concurrent tabs

- When persistent saving is unavailable, require an explicit Continue without autosave choice before allowing play. Keep a persistent warning and accessible Export.
- Do not report a successful save before persistence completes. Browser suspension or termination can interrupt pending work; the implementation must verify storage behavior rather than assume a file write reached persistent browser storage.
- Retain desktop import rules: validate before replacing the garden and preserve earned achievements. Use browser-compatible file selection and export rather than native filesystem dialogs.
- Permit one active game tab per browser profile. A second tab explains that another is active and offers takeover. Taking over saves and pauses the first where possible, and prevents the first from subsequently overwriting progress.
- Local browser saves and manual transfer remain the initial continuity model; there is no automatic cross-device synchronization.

## Launch acceptance

- Target phones from roughly 2022 onward, testing current and previous major iOS Safari versions and current Android Chrome at release time. Verify actual iPhone and Android hardware; browser emulation alone does not establish readiness.
- Support readable controls at a viewport width of 360 CSS pixels. Verify both orientations and orientation changes without lost state.
- Target 30 FPS during representative crowded boss levels, including three-player multiplayer. Define and record the tested devices, versions, and gameplay scenarios during implementation so performance claims are reproducible.
- Verify local saving and return after tab termination, phone interruptions, audio startup and return, and import/export on both phone platforms.
- Exercise touch placement, zoom/pan, inspection, and management controls, including an invalid placement at confirmation time.
- Verify cross-platform multiplayer, switching viewed gardens, chat, reconnect expiry, and release admission/reload behavior.
- Verify persistent-storage failure and competing-tab takeover without silent progress replacement.
- Verify homepage entry, browser loading, and continued single-player play after connectivity loss. Verify tablet and desktop browser layouts as part of the shared browser version.

## Existing constraints

The current Godot project exports only macOS and Windows builds. Its playing field has 16 by 16 tiles, and its interface uses desktop-sized fixed layouts. Multiplayer currently places other gardens and chat beside the local garden. The accepted touch and phone layouts require corresponding implementation work.

Desktop combat currently continues when the window loses focus. The browser pause-on-hidden policy deliberately differs. Native save dialogs and the native updater also need browser-specific behavior.

The glossary's game release definition now includes browser play, reflecting the accepted design. Browser builds and three-platform publication have not yet been implemented.

Official [Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) supports a single-threaded Web export using the project's existing Compatibility renderer. It also identifies mobile/Safari limitations, suspended background processing, and browser storage restrictions. A real export and device checks are required to establish this game's performance and reliability. [FileDialog](https://docs.godotengine.org/en/stable/classes/class_filedialog.html#class-filedialog-property-access) cannot access the host filesystem on Web; browser import/export needs an adapted path.

## Design status and remaining evidence

The product decisions raised in the interview are settled. Final confirmation of this consolidated design is pending; no browser implementation or deployment has been performed as part of the interview.

Implementation must establish export feasibility, device performance, audio behavior, durable browser saves, file transfer usability, and release loading behavior. If that evidence requires changing an accepted decision, bring the specific trade-off back to the user.
