# Build and deploy everything

Accepted design, implemented by `scripts/deploy_all.sh` and the Python modules in `scripts/deployment/`.

## Usage

Commit the intended changes first; the command rejects tracked modifications and untracked files. It builds a frozen archive of that commit, so later edits cannot leak into the release. It does not fetch or pull a branch.

```sh
./scripts/deploy_all.sh 4.0.2 --preview
./scripts/deploy_all.sh 4.0.2
./scripts/deploy_all.sh 4.0.2 --play-track internal   # first Play upload or a cautious release
./scripts/deploy_all.sh 4.0.2 --skip-play             # Play outage; rerun without the flag later
```

Choose an explicit version newer than production. The command builds, tests, signs, uploads to Google Play, uploads to the VM and activates without another prompt. The Android bundle goes to Play first because Play cannot be rolled back; a Play rejection stops the release before anything public changes. Google's review then publishes the Android build hours or days later; see [android.md](android.md). “Latest” here means the selected committed source; the glossary's **current game release** still means the server-designated admission release.

Rerun the same command after an interruption: completed preparation is reused byte-for-byte, and a verified deployment only rechecks production and retries cleanup. Do not delete or modify `build/deployments/<version>-<commit>/` when retrying. A failure before preparation completes may rebuild, because none of its artifacts have been uploaded yet. A different source commit requires a newer version.

The target is the existing `ryan@146.190.246.30` VM for `purrimeter.graham.pub`. Preview reads production metadata/configuration through SSH and lists eligible remote cleanup; it does not build, upload, delete or restart anything. A relay restart can only be determined exactly once a prepared binary is available.

## Prerequisites

Run on macOS with Python 3.11+, Git, Node, Go, `rg`, `zip`, `lipo`, `codesign`, `ditto`, JDK 17 (`jarsigner`) and the Android SDK. Install Godot/templates using `scripts/setup_godot.sh`, which now includes the Android templates. Go may come from `.tools/go/bin/go`, `GO_BIN`, or PATH. `GODOT` can select the matching Godot 4.7.2 executable.

Install the browser test dependency once:

```sh
npm install --prefix .tools/deploy playwright@1.63.0
.tools/deploy/node_modules/.bin/playwright install chromium
```

Alternatively set `PLAYWRIGHT_MODULE` to an existing Playwright module with its matching Chromium installed. The script resolves it before entering the isolated build workspace.

The Android upload keystore, its properties file and the Play service account JSON must exist with owner-only permissions in `~/.config/purrimeter/` ([android.md](android.md)); `--skip-play` waives only the service account. The official owner-only release key must already exist at `~/.config/purrimeter/release-signing.key`, or the path in `PURRIMETER_RELEASE_KEY`. Preflight checks that its public key matches the repository; it never generates or uploads a key. The VM requires noninteractive SSH/passwordless sudo, Python 3.11 with tar extraction filters, and its existing nginx/systemd setup. The script updates Purrimeter's release configuration and nginx snippet, not operating-system packages or unrelated services.

## Build, activation and recovery

The local workflow runs gameplay tests, Go race tests and three-client multiplayer integration; builds signed macOS, Windows and browser packages with bundled updaters and the signed Android App Bundle; builds both Linux relay architectures and the self-hosting archive; validates website packaging; and runs the production browser packaging test. All four game platforms share one signed release identity; the manifest's `android` entry records the Play URL and bundle digest rather than a hosted file. The website includes the self-hosting server download and its checksum.

The complete upload and build log, the Android bundle, and the Play edit record are stored under `build/deployments/<version>-<commit>/`. A rerun never uploads the bundle twice. Git provenance is recorded in the publication manifest; Go VCS stamping is disabled so an unrelated repository commit alone does not change the relay binary and interrupt players.

The VM holds one deployment lock through upload, activation, verification and cleanup, also acquiring the existing relay and website locks. It validates the upload and files, conditionally restarts the relay, validates/reloads nginx, and switches the website pointer. Only a changed binary/configuration or a mismatch with the running executable requires a relay restart. Maintenance restarts end active multiplayer games; gardens remain local. Website and client changes alone do not restart multiplayer.

Public verification checks health, release metadata, current and immutable download hashes, browser entry point, and the running relay binary. A failed relay upgrade restores its preceding binary/configuration. Once the website pointer has switched, failures leave that game designation in place: retry the exact artifacts, or publish a newer corrective release. Native clients cannot automatically downgrade, so switching the designation backwards could block updated players from joining.

Local and remote state distinguish preparation, publication and verified completion. If the connection ends after publication, rerunning is safe. Cleanup failure after verification returns a nonzero exit status and reports **Deployment succeeded; cleanup failed**. This does not roll production back. The server deployment records live under `/var/www/purrimeter/deployments/`; successful transactions remove their temporary upload and extracted staging tree immediately.

## Cleanup

Cleanup retains the active deployment, two preceding successful deployments, everything published within seven days, and the game packages and direct recovery targets those retained records reference. Older installations without deployment records conservatively retain the newest three releases of each kind, active symlinks, recent artifacts, and website/backup dependencies. More than three directories may therefore remain.

Pruning covers website releases, relay releases, immutable game packages, configuration backups, and this script's deployment history/staging on the VM. Local pruning covers only this script's `build/deployments/` history. It does not sweep unrelated `build/`, `dist/`, `/tmp`, persistent identity state, signing keys, or server configuration. Unknown directory names and symlinks are excluded from deletion.

Eligible remote artifacts are removed before upload if needed for space and after successful verification. The script estimates upload, extracted staging, website and immutable copies plus a 256 MiB margin; it fails if space remains insufficient without weakening retention. Local managed history is pruned before preparation and after completion. An in-progress transaction is protected by the lock and its deployment record; abandoned history can expire after seven days.

Finite retention means sufficiently old pending native downloads may need a fresh update check, and unfinished browser loads may need a reload. Immutable means retained bytes never change, not that their URLs exist forever.

The retention trade-off is recorded in [ADR 0015](adr/0015-bound-historical-release-retention.md).

## Validation

```sh
python3 -m unittest discover -s scripts/deployment -p 'test_*.py' -v
node --test website/tests/download.test.cjs
```

Deployment fixtures exercise real temporary files, symlinks, archives and locks with simulated services/HTTP, including failures and retries. They do not deploy to production. Browser/native release checks run automatically for each actual deployment; Windows runtime installation still requires a Windows machine.

Existing constraints and rationale: [update operations](game-update-operations.md), [server-designated release admission](adr/0009-server-designated-release-admission.md), and [shared browser/native releases](adr/0012-browser-shares-game-release.md).
