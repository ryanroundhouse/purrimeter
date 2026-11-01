# Mobile browser play

All three interview rounds and the consolidated design were confirmed on 2026-10-31. Implementation was authorized with “make it so.” The acceptance criteria below remain the reference for implementation and verification.

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

The shared Godot project exports macOS, Windows, and single-threaded browser builds. The 16 by 16 playing field and simulation are shared. Native builds keep their desktop layout; browser play uses the touch layout on touch-capable or small viewports, including tablet landscape.

Desktop combat currently continues when the window loses focus. The browser pause-on-hidden policy deliberately differs. Browser file selection/downloads replace native dialogs. Browser updates save to IndexedDB and reload the existing page.

The glossary's game release definition includes browser play. Release building and publication require matching macOS, Windows, and browser archives under one signed identity.

Official [Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) supports a single-threaded Web export using the project's existing Compatibility renderer. It also identifies mobile/Safari limitations, suspended background processing, and browser storage restrictions. A real export and device checks are required to establish this game's performance and reliability. [FileDialog](https://docs.godotengine.org/en/stable/classes/class_filedialog.html#class-filedialog-property-access) cannot access the host filesystem on Web; browser import/export needs an adapted path.

## Design status and remaining evidence

The product decisions raised in the interview are settled and implementation is authorized. See the verification record below for implemented behavior and remaining device checks.

Implementation must establish export feasibility, device performance, audio behavior, durable browser saves, file transfer usability, and release loading behavior. If that evidence requires changing an accepted decision, bring the specific trade-off back to the user.

## Implementation and verification — 2026-10-31

Release prepared: `4.0.0-1793499581`. Browser rendering and input use the same Godot project and simulation. The browser adapter owns IndexedDB persistence, confirms writes on transaction completion, and fences every write against the active tab identity. Web Locks and a broadcast channel coordinate takeover; the transaction fence also rejects a suspended stale writer. Browser settings and garden snapshots are separate entries in the same origin's database.

Checks completed:

- Full Godot regression suite, including existing combat, progression, saves, achievements, skins, audio, and native window-transition tests.
- Sixteen targeted mobile checks covering preview/confirmation, occupied-tile revalidation, zoomed selection, pause/return behavior, compact keyboard actions, orientation, remote views, unread chat, chat bounds, and narrow achievement/skin dialogs.
- Go race tests and the existing three-native-client multiplayer integration suite.
- Chromium with synthesized touch input: actual recruitment and persistence, two-finger zoom/pan, 360-pixel portrait and landscape rendering, reload, takeover and stale-write rejection, invalid and valid imports, export without persistent storage, browser chat through the real relay, and three-player room rendering with two lightweight relay peers. An earlier three-browser run also verified joining and field delivery; the repeatable suite uses lightweight peers to keep software-rendering memory bounded.
- Production-package browser check with immutable runtime URLs, precompressed assets, the deployed content-security policy, and the homepage Play link. This caught and corrected the policy for Godot-generated blob image URLs.
- Fourteen website platform-detection checks; native/browser archive identity, signature, checksums, and ZIP validation.

Commands: `scripts/test.sh`, `scripts/test_multiplayer.sh`, `scripts/build_web.sh`, `PLAYWRIGHT_MODULE=<installed-playwright-module> node scripts/test_browser.cjs`. After preparing a signed publication, use the same Playwright setting with `node scripts/test_browser_release.cjs`. Browser gameplay tests expect a development Web export; the publication check uses the signed prepared archive.

Physical iPhone and Android tests are still outstanding. Only simulated Apple devices were available; Chromium viewport/touch checks are not Safari or physical-device evidence. The 30 FPS target on representative phones, mobile Safari audio/keyboard behavior, long background suspension, and OS-driven storage eviction remain manual acceptance checks. Tests also report some Godot object/resource cleanup warnings at process exit; no behavioral assertions or script-compilation checks failed in the passing runs.


## Publication

Published at `https://purrimeter.graham.pub/play/` on 2026-10-31 (Toronto), website release `20261101T022553Z-098a18ac04fa`, game release `4.0.0-1793499581`. The live Chromium smoke test verified game loading under the actual nginx policy, recruitment, persistent saving across reload, same-origin WebSocket admission, creation of a temporary password-protected multiplayer game, the signed current-release designation, and all three downloadable archives. The test left its temporary game afterward. Relay health stayed `ok`; publication reloaded nginx without restarting the relay.

## Wave controls while recruiting

The initial mobile layout replaced Start/Resume and Auto with Confirm/Cancel whenever a cat was selected. Recruitment intentionally stays selected after a purchase, so this hid wave controls even after spending all starting coins. Wave controls now have a permanent row, with placement confirmation below it. Small portrait viewports reserve space for both rows without moving the field when selection changes.

The rendered regression test `game/tests/mobile_wave_controls.gd` reproduced six failures before the fix and passes afterward. It spends all 200 starting coins on four Scouts, leaves recruitment selected, starts combat, pauses, and resumes through the visible controls at 844×450, 390×844, and 360×640. It also checks viewport bounds and separation of wave/placement controls. Run with `.tools/Godot.app/Contents/MacOS/Godot --path game --audio-driver Dummy --script res://tests/mobile_wave_controls.gd -- --multiplayer-test --mobile-test`; it requires a rendering display rather than headless mode. The browser suite also checks actual touch wave start while recruitment is selected.

Published as game `4.0.1-1793500601`, website `20261101T023728Z-98c9d5a878df`. The live Chromium check purchased four Scouts, started the wave while recruitment remained selected, and verified persistence across reload, landscape rendering, matching immutable assets and signed release metadata, healthy relay status, and no browser runtime/CSP errors. Evidence: `build/wave-live-test.log`, `build/wave-live-ready.png`, and `build/wave-live-landscape.png`.
