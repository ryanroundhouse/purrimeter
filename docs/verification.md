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

## Multiplayer implementation (2026-10-31)

- The existing core, level-health, frenzy, powerup, campaign, music, and gameplay smoke suites pass with the new launch shell. Test/preview modes continue to avoid loading or replacing the player's save.
- `scripts/test_multiplayer.sh` runs the Go race detector and relay tests, then starts an isolated relay on an ephemeral localhost port and connects three Godot clients. Tests cover passwords, last-slot races, duplicate identities/names, owner transfer, reservations and expiry, kick enforcement, room-scoped chat without history replay, bounded/coalesced snapshots, protocol validation, and identity survival across a simulated server restart.
- The Godot integration suite verifies launch/Escape flow, real WebSocket admission, independent field progress, moving enemies and interpolation, chat focus/muting, read-only inspection, live Import/New Garden, failed-import preservation, stale-revision rejection, reconnect with preserved chat/views, and ownership transfer. The same integration flow was run with native macOS rendering.
- Native screenshots in `build/multiplayer-*.png` cover the main menu, pause menu, connection settings, password-protected game browser, two/three-player gameplay, and enlarged inspection. Three-player layout was also checked at the minimum multiplayer window size. Remote views reuse existing artwork and inspection logic without running remote combat or writing remote state to the local save.
- The default client endpoint is `wss://purrimeter.graham.pub/ws`, as supplied by the owner. `network/server.cfg` is explicitly included in both desktop exports. Public DNS and VPS deployment are complete; see below.
- `scripts/build_server.sh` cross-compiles Linux amd64/arm64 relay binaries and packages their source, Go dependency lock, Dockerfile, Caddy configuration, Compose configuration, and instructions. The Compose configuration parses successfully. After the owner started Docker, the production Dockerfile built successfully and the non-root, read-only relay ran in Linux containers with its signing-key volume. The full three-Godot-client integration suite passed through an isolated Caddy reverse proxy on loopback ports.
- A separate TLS WebSocket probe trusted only the isolated Caddy test CA, authenticated, and created a game over `wss://localhost:18443/ws`. After restarting the relay container, the same credentials authenticated as the same installation while the old game correctly expired. No CA was installed into the host trust store.
- Both desktop ZIPs pass archive integrity checks and the macOS app passes signature verification. The exported macOS app renders the new main menu and its connection settings show the configured public endpoint. Both macOS and Windows resource packs pass isolated launch/default-endpoint/pause-menu checks using Godot. The Windows executable itself has not run on Windows.

## Public deployment (2026-10-31)

- Deployed the Linux amd64 relay from commit `23e43a5` to the owner's claw VPS as an unprivileged systemd service. Its listener is restricted to `127.0.0.1:18080`; the signing-key directory and file have permissions 0700 and 0600 respectively. Service startup is enabled at boot.
- Created the Cloudflare DNS-only A record for `purrimeter.graham.pub` pointing to `146.190.246.30` using `flarectl`. Added a separate virtual host to the existing nginx installation. `nginx -t` passes; the proxy overwrites the forwarded client-IP header before sending requests to the trusted relay.
- Obtained a public Let's Encrypt certificate and configured automatic renewal with an nginx reload hook. Public DNS resolves to the VPS and `https://purrimeter.graham.pub/healthz` returns `ok` with normal certificate validation. The initial probe raced the nginx reload; subsequent local and external probes passed.
- A Certbot renewal dry run for this hostname passed using the deployed ACME webroot. Both `purrimeter.service` and `certbot.timer` are enabled.
- Ran the full Godot multiplayer integration suite with three clients against `wss://purrimeter.graham.pub/ws`: **0 failures**. This exercised password admission, remote movement, three-player layout, chat, Import/New Garden, reconnection, kicking, and ownership transfer over public TLS. Log: `build/multiplayer-production.log` (local ignored artifact). Godot reported two ObjectDB instances at shutdown; all checks completed and the test process exited successfully.

## Multiplayer resume fix

Multiplayer resume fix (2026-10-31): a native input reproduction failed when chat retained focus and the player clicked Resume. The text-entry guard had rejected mouse events before the field could release chat focus. Restricting that guard to keyboard events restores garden clicks while preserving shortcut suppression during typing. The public three-client native integration suite now covers chat-focused Resume, subsequent combat advancement, and Space after leaving chat, and passes with zero failures.

## Website launch (2026-10-31)

- Published the static promotional page and both existing client ZIPs at `https://purrimeter.graham.pub/`, release `20261031T142649Z-86e1cd3e4d63`.
- Fourteen OS-detection tests pass, including desktop Mac/Windows, client hints, iPad desktop mode, phones, Linux, ChromeOS, and unknown devices. Native Chrome on macOS highlighted the Mac download on both the local and public page. Both platforms remain ordinary download links when JavaScript is disabled.
- Inspected full-page Chrome captures at 1440px and 390px, including expanded installation disclosures, and a 320px layout with JavaScript disabled. Text and controls remained visible without clipping. Screenshots: `.impeccable/review/website/`. Independent visual review returned `ship` for the required desktop/mobile views. The optional automated Impeccable detector was unavailable because its engine was not installed; no automated detector pass is claimed.
- Checked local links, asset paths, section anchors, and text contrast. Every used text color pair measured at least 7.5:1. The public page loads its fonts and assets from the same host and uses no third-party scripts.
- Packaging validated ZIP checksums and required client files. Downloaded every public site asset and both complete ZIPs and matched their SHA-256 values to the prepared manifest. Downloads return HTTP 200 with attachment disposition and support HTTP 206 byte-range requests. Evidence: `build/website-verification.json`.
- `nginx -t` passes. The root page returns HTTP 200, and `/healthz` continues to return `ok`. The three-client public multiplayer suite completed with **0 failures**, recorded in `build/multiplayer-website-deployment.log`. The relay's PID and start time were unchanged; only nginx reloaded.
- These are the existing unsigned/ad hoc signed packages. No signing/notarization pipeline or native Windows testing was added by the website work.

## Remaining platform limits

Mac window transition (2026-10-31): the owner reported stale Create-page pixels with gameplay drawn in a small lower-left region; manually resizing the normal window corrected it. The exact framebuffer artifact was not reproduced locally. To remove the suspected trigger, mode changes now retain the native window size and change only the logical canvas, with one common minimum size of 1280×720. The native `tests/window_transition.gd` regression failed on the previous automatic resizing and passes after its removal, also checking that the Create page is freed and gameplay fills its logical viewport. Confirming the original visual symptom on the affected machine remains necessary.

The Windows executable has not been run on a physical Windows computer or Windows VM in this environment. Its resource pack and shared gameplay are tested, but Windows driver/input integration still needs a real-device check. Audio resources load and prepare; no subjective listening review was performed. Balance beyond the first rebirth and boss has automated budget checks, not a human playthrough. Currency/stat arithmetic uses floating-point log space, retaining fractional payouts with finite precision.

The earlier Swift prototype's sandboxed preview crash is historical: that attempt aborted during macOS application registration before game code. Native Godot checks run outside the restricted agent sandbox. The old save was explicitly deleted and is not migrated.

Mid-level rebirth, Escape controls, background play, and viewed-garden audio (2026-10-31): `scripts/test.sh` passes, including 168 core checks, 30 level-health checks, 67 frenzy checks, 78 powerup checks, campaign checks, 49 music/focus checks, scene smoke checks, and window transitions. `scripts/test_multiplayer.sh` passes the relay race suite and 63 integration checks; the native run passes 65 checks including mouse input after chat. Coverage includes mid-combat rebirth cleanup and manual restart, focus-loss countdown progression, menu toggles, remote boss music and tiered effects, duplicate-event suppression, viewer mute/focus handling, reconnect silence, and preserved running/manual-pause state while viewing. Inspected the Escape menu at normal and minimum window sizes and the expanded rebirth explanation; the native scene smoke check confirms the dialog fits without scrolling. Mac and Windows distributions and the Linux relay package were rebuilt. Both ZIPs pass integrity checks; the Mac app passes signature verification, and the exported Mac app and Windows resource pack pass isolated smoke checks. The Windows resource pack was tested through Godot on macOS; the Windows executable was not run on Windows. Existing Godot resource/ObjectDB cleanup warnings remain in some test exits. No live relay or website deployment was performed.

Gameplay label cleanup (2026-10-31): removed the field status dot/text, the escape reminder above the field, and the multiplayer layout explanation. Moved Continue offline from the multiplayer window to its Escape menu. Inspected isolated native single-player and multiplayer renders, including the updated menu. Both desktop packages were rebuilt; ZIP integrity and Mac signature checks pass.

## Game updater and release admission (2026-10-31)

- Full Godot gameplay suite passed (`build/update-game-tests.log`). The initial sandboxed run could not write the music test's temporary save; the unrestricted isolated-fixture run passed.
- Go race tests passed, covering signature tampering, package integrity/archive traversal, startup acceptance and recovery of both application and garden, release admission, live reload, stale browser create/join rejection and 60-second reconnect boundaries (`build/update-go-final.log`).
- Three-client Godot integration passed, including updates → multiplayer round-trip and keyboard focus, with zero failures (`build/update-multiplayer-final.log`). Existing Godot resource-leak diagnostics remain at test exit.
- Four update screen states were visually reviewed and approved. See [update-ui-review.md](update-ui-review.md).
- The exported Mac game passed isolated headless startup. Its actual signed archive staged through the native helper in a disposable installation, including app signature verification. Healthy and failed first-launch transactions are tested with isolated executable fixtures; this does not claim a full real-game upgrade cycle on both operating systems.
- The actual native updater downloaded and verified the public Mac package. A full public Windows download matched its signed size/hash. Windows game/helper binaries cross-compiled successfully, but installation on Windows has not been run.
- Live public relay verification passed: current signed release `3.0.0-1793460493` can create and join; legacy, development, older and newer mismatched releases are rejected.


## Achievements (3.1.0)

- All 30 achievements are exercised by 83 focused gameplay and persistence checks. Coverage includes real tower damage, restricted squads, repair/sale/replacement identity, uninterrupted clear streaks, boss-kill versus boss-level completion, migration, invalid-import atomicity, repeated-import idempotency, and player-wide profile persistence.
- Native achievement UI checks pass for the two menu entry points, three filters, all 30 detail layouts, Escape and pause restoration, layout refresh while open, New Garden persistence, banner queuing, hidden-banner timing, and summary presentation.
- The full gameplay, level-health, frenzy, powerup, campaign, music, smoke, and window-transition suites pass. Relay race tests, updater recovery (including achievement data), and three-client multiplayer integration pass.
- Inspected native renders at the standard window and a 1280×720 window: menu entry, pause entry, all/empty/earned collection, tactical details, live fanfare, and retrospective summary. Captures live in `build/achievement-review/` and `build/achievement-review-min/`.
- The signed macOS and Windows release packages build successfully. The exported macOS game passes its isolated native smoke test; Windows is cross-compiled and package-verified, without a Windows runtime test.

- Published game release `3.1.0-1793467239` through website release `20261031T172139Z-04e18e6d3fb6`. The live `/updates` designation exactly matches the signed local manifest; `/healthz` returns `ok`; downloaded macOS and Windows immutable packages match their signed byte counts and SHA-256 hashes. The multiplayer relay was not restarted.

## Achievement cat skins

Implemented fifteen appearances across Scout, Gunner, and Sage, with twelve achievement unlocks and all 288 new animation poses. `scripts/test.sh` and `scripts/test_multiplayer.sh` passed their behavioral checks, including actual relay transmission of selected skins without granting ownership. Final sprite-outline validation and native skin UI tests passed after the Sage artwork refinements. The existing music and multiplayer test teardown still emits resource-leak diagnostics; no behavioral assertion failed.

Native captures at the default and minimum window sizes are in `build/skin-review/` and `build/skin-review-min/`. Independent UI review returned `ship`, with no material fixes. Locked skins stay silhouetted, requirements fit, equipped status remains distinct from preview selection, and portraits exclude neighboring sprite fragments.

Local macOS and Windows packages were rebuilt with all twelve new atlases. macOS code-signature verification and the exported application's built-in smoke test passed. Windows was cross-built, not run on Windows. These local builds have not been published as a game release. See `docs/cat-skins.md` for implementation and prompt provenance.
