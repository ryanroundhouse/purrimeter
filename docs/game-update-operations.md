# Publishing and operating game updates

## Release identity and trust

`game/network/build.cfg` defaults to `development`. An explicit release build temporarily embeds a shared version, unique release ID and increasing sequence into macOS, Windows, and browser builds, then restores the source development configuration. macOS/Windows package metadata is also updated for the release. Wire protocol version 1 remains separate.

`server/internal/releases` verifies Ed25519 signatures over the exact payload bytes. The official public key is committed in `public.key` and compiled into the relay and native updater. The dedicated private key lives at `~/.config/purrimeter/release-signing.key` with owner-only permissions, outside the repository, and is never uploaded to the game server. `PURRIMETER_RELEASE_KEY` can select another protected location containing the same key. Back up this key securely; losing it requires a new trust bootstrap/manual installation. Do not generate a replacement key as part of an ordinary release.

Signed metadata identifies the macOS, Windows and browser package URLs, sizes and SHA-256 hashes, plus an `android` entry with the Google Play listing URL, the uploaded bundle's digest, size and version code. Production publication requires all four complete packages; the relay and native updater validate the three hosted ones and ignore the Android entry. The updater checks signatures, transport, sizes, hashes, safe archive paths and the macOS app signature before replacement. This release signing does not provide Apple notarization or Windows publisher certification.

## Build and publish

Use `./scripts/deploy_all.sh MAJOR.MINOR.PATCH` for the complete production workflow: build and test all components, publish, verify, and clean up. Run with `--preview` for a read-only preflight. See [deployment workflow](deployment-workflow.md) for prerequisites, retention and retry behavior. The lower-level commands below remain available for targeted operations.

```sh
./scripts/test.sh
./scripts/test_multiplayer.sh
./scripts/build_release.py 3.0.1
./scripts/build_server.sh
./scripts/publish_website.sh --prepare-only
./scripts/publish_website.sh
```

Release building requires the configured Godot tools, Go and macOS `lipo`/`codesign`. The native updater is universal on macOS and x64 on Windows. Ordinary `scripts/build.sh` produces development builds and does not publish. The website packager rejects archives that differ from the signed game manifest or disagree on embedded release identity.

The website activation retains packages at `/var/www/purrimeter/game-releases/<release-id>/` before switching `/var/www/purrimeter/current`. Immutable package URLs remain available across later releases; the existing `/downloads/` links still offer the current archives. Website-only publication preserves the game release ID. The relay reads `/var/www/purrimeter/current/game-release.json`, and `/updates` serves its last verified designation with no caching. Routine client publication never restarts the relay.

For relay changes, explicitly run `scripts/deploy_server.sh`. This builds the server, retains the previous binary, installs the release-file systemd configuration, restarts the relay, verifies local and public metadata, and restores the previous service configuration on failure. This maintenance restart ends existing multiplayer visits while their gardens remain local.

A server may pin an older official manifest, but newer clients cannot automatically downgrade. Prefer correcting a bad release with a newer forward release; rolling the website designation backward can temporarily block already-updated players from new multiplayer visits.

## Installation and recovery

The game invokes the bundled native updater asynchronously. Downloads live under the Purrimeter user-data directory in `updates/`; partial downloads are never installed. On “Restart and play,” the helper prepares a sibling staging directory and checks the replacement before the game saves and exits. A copied helper outside the installation waits for the old process to exit, backs up `save.json`, `settings.cfg`, `multiplayer.cfg`, and `achievements.json`, replaces the managed application files, and launches the new game.

Windows replaces only `Purrimeter.exe`, `Purrimeter.pck`, and `PurrimeterUpdater.exe`, leaving unrelated files alone. macOS replaces the app bundle. The development editor cannot be replaced. An unwritable installation exposes the verified archive and manual instructions instead.

The new game acknowledges startup after its menu and saved garden load. Failure to launch, early exit, unreadable garden, or failure to acknowledge within 60 seconds restores the previous app and pre-update player data. Successful startup ends automatic rollback eligibility; later progress is never automatically restored from an older backup. Recovery/staging directories are retained beside the installation as `.purrimeter-update-*`; they can be removed after confirming the new game works. `updates/transaction.json` records the phase and backup locations; `updates/error.txt` records an installation failure. Do not remove a staging directory while an update is running.

An interrupted download can be retried. A machine shutdown or forced termination of the updater during file replacement may require manual recovery using the recorded backups; the current transactional rollback covers errors while the helper remains running, not crash-proof filesystem recovery.

## Verification boundaries

Automated coverage includes signature tampering, incomplete platform releases, unsafe URLs and archive paths, package integrity, healthy startup, failed-startup recovery of application and garden, exact release admission, live designation reload, stale lobby actions and reservation-expiry boundaries. The three-client Godot suite exercises opening and leaving updates while connected and retaining keyboard actions through state changes.

Windows helper and game exports are cross-compiled and package-checked on macOS. Windows runtime installation and Windows security prompts require a Windows machine; do not treat cross-compilation as runtime validation.

Legacy clients without a game release receive the existing terminal `hello` error code with the public download URL, so their older error handling retains the manual-upgrade instruction instead of overwriting it with a generic connection failure.

## Android updates

Android builds never download packages. The game reads the server designation like the browser does; when a newer release is required, Game updates offers **Update in Google Play**, which opens the listing. Google Play delivers the new bundle after its review, so Android players may be unable to join multiplayer for a while after each release ([ADR 0016](adr/0016-android-joins-the-game-release.md)). Server operators who pin an older manifest produce the same "server requires an older release" message as on desktop.

## Browser updates

The browser reads the selected server's release designation for admission. Save and reload always reloads the existing page; metadata never supplies an executable update URL. Reload proceeds only after the garden's IndexedDB transaction commits. If saving fails, the player can export first. The browser package shares the signed release identity with native builds, and its unpacked runtime is retained under immutable release URLs. Historical native-only manifests remain valid to permit existing servers and updaters to migrate.
