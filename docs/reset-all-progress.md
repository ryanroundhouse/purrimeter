# Reset all progress

Status: design confirmed by the user and implemented in `codex/reset-all-progress`.

## Confirmed decisions

- Add **Reset all progress** as a distinct action from New Garden.
- Clear the current garden and all player-wide progression: earned level unlocks, achievements, achievement progress, and earned cat skins. Return to level one.
- Keep player preferences; this is not a factory reset.
- Offer the action in the main menu only, separate from ordinary play actions. Do not add it to the pause menu or Connection settings.
- Show one explicit confirmation listing the lost progress, with Cancel selected by default and a **Reset all progress** action. Do not require typing a phrase, exporting a backup, or creating an automatic backup or undo.
- Preserve Auto-start next wave as a preference, but leave the fresh garden waiting for a manual first Start.
- Keep existing save imports compatible: deliberately importing an old export can restore erased achievements, skins, and level unlocks.
- Implement in a separate worktree.

- Stay on the main menu after success, with a fresh paused level-one garden: 200 coins, no cats, default skins, and only level one unlocked. The first wave requires manual Start.
- Preserve multiplayer identity, sound, connection settings, chat notifications, route visibility, speed, and Auto-start preference.
- In browser session-only mode, reset the current session while retaining the existing unsaved-progress warning.
- Cancelling changes nothing. If the reset cannot be committed, retain the existing progress and explain the failure.

## Existing behavior relevant to the design

- New Garden retains player-wide achievements, cat skins, and level unlocks.
- Native saves keep a separate achievement record; browser saves include it in the garden save.
- Exported saves include player-wide progression. Import merges achievements and level unlocks into local progress.
- Preferences include sound, player name, server address, and chat notifications. Multiplayer credentials are stored separately from progression.
- Auto-start next wave is saved with the garden and defaults off.
- Opening the main menu disconnects multiplayer, so this action cannot reset progress while remaining in a room.
- A new player starts at level one, wave one, with 200 coins, no cats, default skins, and only level one unlocked.
- Browser play can run in session-only mode when persistent saving is unavailable.

See [the glossary](../CONTEXT.md) and [five-level progression](five-level-progression.md).

## Persistence and failure handling

- Native reset first atomically writes a fresh-state recovery record, then replaces the garden and achievement files. The record contains no previous progress and is removed after both files are replaced. If interrupted after commitment, startup reads the fresh record and skips stale achievements; subsequent writes finish recovery before saving further progress.
- A failure before that commit point leaves both the live garden and saved progression unchanged. Failure to finalize a committed reset leaves its fresh state durable and retries completion on later saves.
- Browser reset uses the existing IndexedDB owner check and serial write queue. Autosaves cannot submit a stale garden during reset. The candidate becomes the live garden only after the transaction succeeds, or after the player has explicitly accepted session-only play.
- Reset does not delete preferences, multiplayer credentials, or external exports. Existing native-update recovery behavior remains separate from gameplay reset.
- Pending drafts, victory state, inspected entities, and queued achievement/skin celebrations are cleared with the old garden.

## Verification

- `game/tests/reset_progress.gd`: cancellation, default Cancel focus, fresh state, retained preferences, pending-draft removal, skin/fanfare reset, old import compatibility, native reload and injected failures before commitment and at both finalization boundaries.
- The same UI test covers desktop, responsive browser layouts, and native mobile controls, including 640×320 landscape and 390×844 portrait. It checks touch targets, confirmation bounds, and visibility of the complete loss warning.
- `scripts/test_reset_browser.cjs`: actual browser confirmation/cancellation, durable reset and reload, retained preferences, old export import, storage failure, live-state retention, session-only reset, queued autosaves, and stale-tab fencing. Run after `scripts/build_web.sh` and the Godot reset test, which generates a synthetic fixture. Set `PLAYWRIGHT_MODULE` if Playwright is installed outside the repository.
- All save tests and captures use generated fixtures and isolated paths/profiles, never the player's save.
- Android is additionally checked in the API 35 ARM64 emulator using a separately identified debug application and synthetic progress. Cancellation, both durable progress files, retained preferences, and app restart were verified. Host layout checks are not physical-device Android/iOS verification.

### Final verification record

Verified on 2026-11-07:

- `PURRIMETER_NATIVE_UI_TESTS=1 ./scripts/test.sh` passes, including gameplay, persistence, responsive controls, Android gameplay controls, and main/pause menu regressions.
- `scripts/test_reset_browser.cjs` passes against the final browser export, including deliberately failed storage and competing-tab cases.
- Android API 35 ARM64 emulator: 844×390 logical phone layout (1688×780 pixels at 320dpi), 640×320 at 160dpi, and 1280×800 at 160dpi with 130% system text. Actual touch/keyboard cancellation, reset, both persisted records, preserved preferences, and application restart were checked in `com.roundhouselabsinc.purrimeter.resettest` with synthetic data.
- Emulator captures use immersive mode without a display cutout. Physical-device/iOS, cutout-specific layouts, and the inherited shared dialog's fixed font sizing remain outside this verification. The new native menu entry and result messages use the existing system-scaled typography.
- Reset results now appear above play actions, so failure and session-only messages remain visible even when the menu scrolls. Responsive keyboard focus scrolls the selected action into view.

Final visual/interaction review disposition: **ship** for this existing-system extension. No material fixes remain in the reviewed desktop, responsive, browser, and Android emulator scope. Documentation review required no additional system or token changes.
