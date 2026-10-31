# Verification — Purrimeter 2

Validated locally on Apple Silicon macOS with Godot 4.7.2.

## Shared game

The complete `./scripts/test.sh` suite passes: 163 behavioral checks, 67 frenzy checks, 78 powerup checks, the earned-resource campaign, 42 music checks, and the headless scene smoke test. The native scene smoke test also passes with rendering enabled. The earlier diagonal frenzy fixture and help-copy-fit failures are resolved.

- **163 behavioral checks**: eight-direction shortest routes, single-corner clearance, corner-touching walls, constant diagonal speed and arrival estimates for every enemy and boss with and without slow, diagonal attacks and destruction, crossing reservations and release, and mid-diagonal save restoration and obstruction rejection. Auto-start checks cover default-off behavior, real-time countdowns at 2× speed, pause, toggles, manual starts, building during countdowns, defeat/rebirth exceptions, legacy and invalid saves, and countdown restores across boss transitions and replayed lower levels. Existing checks cover six-tier upgrades, costs, health-preserving upgrades/training, repairs and resale, open-route priority, weighted breaches, immediate one-escape defeat, retained resources, emergency recovery, additive rebirth rewards and requalification, four-boss rotation, exact health and bounty budgets including levels 100 and 2,000, splash, slowing, shared tower destruction, pause, save validation, fractional/large amounts, and actual save-file replacement/restore.
- **Earned-resource campaign**: an automated patrol uses the normal economy, clears level 5, rebirths for +50%, and then beats the level-10 boss. No injected coins or damage bonuses. It reaches level 11 after 15 attempts.
- **Scene smoke checks**: recruit input, upgrade/pause/speed/route/start/sell actions, cat and boss textures, and music/effect resources.

## Boss music

- **42 dedicated checks pass** through the actual scene wiring: five distinct looping assets, selection by level, manual and automatic boss starts, surviving escorts after boss death, clear/defeat/countdown transitions, retries, actual save import, New Garden, rebirth, crossfade duration and interruption, regular-track position retention, boss-loop wraparound, focus/mute interaction, and combat-speed independence.
- Reproduce with `.tools/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path game --script res://tests/music.gd -- --music-test`. This test does not load the player's save or preferences; its temporary save is removed afterward.
- The five original generated WAVs have distinct audio content, 45.7–53.3-second durations, RMS amplitude matched to the garden track (0.089), peaks below 0.51, and loop-boundary sample jumps below 0.003. This is signal-level validation, not a subjective listening review.
- Rebuilt both distribution ZIPs and the original `build/Purrimeter.app` handoff. Mac signing and ZIP integrity checks pass. Both exported resource packs pass the same 42 music checks using the local Godot runtime with the external test script. The music tests report ObjectDB/resource cleanup warnings at exit, including in the final full-suite run. This does not verify the Windows executable on Windows or replace a subjective listening review.

## Permanent powerups

- **78 new checks** cover the 30-powerup catalog, hidden discovery, per-rank milestone gates, eligibility earned in advance, all finite rank caps, permanence through defeat/rebirth, surviving-cat achievement credit, version-2 migration preserving training, version-3 round trips, and atomic rejection of malformed imports.
- Effects checks cover stat and price changes, healing, critical hits, piercing geometry, chain target limits, focus resets, boss/finishing/chilled bonuses, blast radius, burning over time, one-shot delayed echoes, slow strength/duration, boss control recovery, reward multiplication, and death-triggered slow without duplicate rewards. A mid-combat save restores burning, control, and pending echoes consistently.
- Scene smoke checks exercise keyboard purchases, locked-rank rejection despite sufficient coins, pointer icon selection, inspector return preserving selection, pagination, Available/Owned membership, completed inspection, empty collections, and bounds for every description and rank label.
- Native captures at 1152×810 and 960×675 cover fresh, populated, owned, locked, final-page, completed, insufficient-coins, empty, and selected-cat states. The finish review accepted the browser; its sole finding (help overflow after concurrent frenzy instructions) was fixed and scored resolved. The final help panel fits at the minimum size.
- Reproduce with `--preview <path> --preview-state powerups|powerups-owned|powerups-locked|powerups-last|powerups-empty`; optionally select a discovered icon with `--preview-powerup <id>`. Fixtures never read or modify the player's garden.
- Prices and rank gates are initial balance, documented in `docs/powerups.md`; long-term balance across all combinations has not had a human playthrough. No Windows machine or VM was used for runtime verification.

## UI refinement

- **Enemy inspection and level health (2026-10-31):** the full suite passes with 30 added health checks covering unspawned enemies, unequal enemy health, overkill, restoration, pause, boss weighting, attempt outcomes, and levels through 1,000,000,000. Sixteen added scene checks exercise pointer and keyboard selection, overlap priority, interpolated positions and tile boundaries, recruitment, inspector controls, pause, and selection cleanup. After final layout refinements, the native scene smoke test passes. Inspected regular-enemy effects and scientific-notation health at 960×675 and boss inspection at 1152×810; the scoped finish review returned `ship` with no material findings. Both distribution ZIPs and `build/Purrimeter.app` were rebuilt; signing, archive integrity, and smoke tests of the Mac app and Windows resource pack pass. The Windows resource pack was checked using Godot on macOS, not the Windows executable on Windows. Some Godot runs still report the previously observed resource/ObjectDB cleanup warnings at exit.

- **Enemy frenzy:** 67 dedicated regression checks cover the alternating-opening exploit (including continued edits after frenzy), an unchanged winding maze, all enemy and boss thresholds, diagonal revisit distance, independent histories, pause/stun/slow, committed attacks, diagonal reservations, forward-only routing, targeting estimates, JSON restoration, legacy defaults, and atomic rejection of malformed state. Inspected the native `--preview-state frenzy` render: increasing red tint, sweat on normal enemies and bosses, already-red boss artwork, and simultaneous slow effects. Tests and previews use synthetic state and do not touch player saves.

- Auto-start next level uses a keyboard- and pointer-accessible checkbox labeled Auto to the right of Start/Wave in progress/Resume. A centered 3–2–1 shrinks and fades once per real second, freezes when paused, and leaves the map clickable. Native smoke tests cover toggling, map clicks during the countdown, countdown Resume, and manual Start. Inspected native previews of full-size and fading numbers at 1152×810 and the minimum 960×675 window size. Reproduce with preview states `countdown`, `countdown-two`, `countdown-one`, `countdown-faded`, `countdown-paused`, or `auto-start-off`.
- Larger secondary text, higher-contrast disabled labels, clearer recruitment selection and affordability, a selected-cat portrait with health and actions, and a permanent-powerup browser above progression controls.
- Paused combat exposes an enabled Resume level action. Pause state and boss health sit above the garden, leaving its tiles unobscured.
- Tab / Shift+Tab traverse enabled controls and the garden. Enter activates controls; arrow keys move the garden cursor, and Enter recruits or inspects. Native dialogs block these gameplay inputs.
- The scene smoke checks cover the original controls plus rendered targets, focus traversal, keyboard recruitment and inspection, repair clicks, paused-combat resume, viewport bounds, and modal input blocking.
- Inspected native renders of fresh, recruitment, low-coin, injured-cat, rebirth-ready, active, and large-number states at window sizes from 960×675 through 1440×900. The game keeps its aspect ratio when resized, preserving the square playing field.
- Preview states are reproducible with `--preview <path> --preview-state fresh|recruit|low-coins|injured|rebirth|running|long`. They use synthetic state without loading or saving a player's patrol.
- Keyboard navigation is implemented in the custom-drawn UI; this is not a claim of screen-reader support. Windows input/rendering still needs a real Windows check as described below.

### In-game panels

- Rebirth uses a compact, themed confirmation with the additional and resulting coin bonuses, retained possessions, healing, and restart requirements. Its buttons say Cancel and Rebirth patrol; Cancel receives initial keyboard focus.
- How to play groups the rules beside a keyboard-control reference and has one Got it action. Both panels dim the garden, wrap text, and fit without scrolling at the minimum 960×675 window size. The reusable panel also styles New Garden and save-replacement confirmations.
- Native smoke coverage verifies help dismissal, content bounds, Tab / Shift+Tab navigation, Escape cancellation, preserved state on Cancel, and one-time rebirth confirmation. A subsequent help panel cannot invoke a stale confirmation callback.
- Reproduce the native previews with `--preview <path> --preview-state help-dialog|rebirth-dialog`. These use synthetic state and never load a player's save.

## Native rendering and packages

- Rendered the actual Mac game scene and an artwork gallery. Inspected all six forms of each cat and all four bosses.
- Rendered every attack-effect tier. Explicit alpha-derived sprite bounds eliminate neighboring-row bleed. Source PNGs remain unchanged.
- Native-window control checks pass after accounting for the application's intended focus-loss auto-pause.
- Tuxedo Scout and the orange-tabby Chunky Gunner each retain 24 transparent frames (six tiers × four poses). Remeasured alpha bounds and inspected the rendered upgrade gallery and gameplay view after the coat edits. Unit kind IDs are unchanged, so existing patrol saves use the new appearances automatically.
- The export script builds a universal Intel/Apple Silicon Mac app and Windows x86-64 GUI executable/resource pack. Mac signing is verified locally. ZIP integrity is checked.
- The Windows resource pack is loaded with Godot on the Mac to exercise the exported scene and bundled assets. The Windows executable is verified as PE32+ x86-64.

## Limits

The Windows executable has not been run on a physical Windows computer or Windows VM in this environment. Its resource pack and shared gameplay are tested, but Windows driver/input integration still needs a real-device check. Audio resources load and prepare; no subjective listening review was performed. Balance beyond the first rebirth and boss has automated budget checks, not a human playthrough. Currency/stat arithmetic uses floating-point log space, retaining fractional payouts with finite precision.

The earlier Swift prototype's sandboxed preview crash is historical: that attempt aborted during macOS application registration before game code. Native Godot checks run outside the restricted agent sandbox. The old save was explicitly deleted and is not migrated.
