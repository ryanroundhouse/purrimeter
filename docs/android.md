# Android and Google Play

Purrimeter ships on Google Play as `com.roundhouselabsinc.purrimeter`, published by Roundhouse Labs Inc. The Android build is the same Godot project with the phone layouts already used in browsers, exported as a signed Android App Bundle and uploaded by the normal release command. Design rationale: [ADR 0016](adr/0016-android-joins-the-game-release.md).

## What differs on Android

- The responsive phone and tablet layouts, pinch/pan, and touch inspection come from the browser work; `GamePlatform` (`game/core/platform.gd`) treats web, Android and `--mobile-test` as one responsive family.
- The Android back button steps out of the innermost layer (panel, chat, pause menu, expanded field, placement) and never quits from the main menu. Backgrounding the app pauses combat and saves, like a hidden browser tab.
- The in-app updater only reads the server's release designation. When a newer release is required, Game updates offers **Update in Google Play** instead of downloading anything. Until Google publishes the new bundle, Android players keep single player and cannot join multiplayer.
- Export and Import use Godot's file dialog inside the app sandbox; moving a garden between an Android device and a desktop is not yet convenient and is a known limitation.
- Report sits beside Mute on every player's card and in the phone chat sheet. The relay stores reports (see [server/README.md](../server/README.md)); nothing else about chat is retained.

Architectures are arm64-v8a and x86_64; the minimum is Android 7 (API 24); the target SDK follows Godot's Gradle template (36 for Godot 4.7.2). Both orientations are allowed.

## One-time setup

### Signing and credentials on the publishing Mac

All files live in `~/.config/purrimeter/` with owner-only permissions; preflight refuses to run otherwise.

| File | Purpose |
| --- | --- |
| `android-upload.keystore` | PKCS#12 upload key (alias `upload`, RSA 2048, 10,000 days). Google holds the app signing key through Play App Signing. |
| `android-upload.properties` | `storeFile=…`, `keyAlias=upload`, `storePassword=…`; read by `scripts/build_android.sh`. |
| `play-service-account.json` | Google Cloud service account key with release access to the app. |

The keystore was generated on 2026-11-01 with `keytool -genkeypair -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000`. Back it up with the release-signing key; losing it means requesting an upload-key reset from Google. `PURRIMETER_ANDROID_UPLOAD_PROPERTIES` and `PURRIMETER_PLAY_SERVICE_ACCOUNT` can point at other locations.

Godot reads the JDK 17 and Android SDK paths only from its editor settings. `scripts/configure_godot_android.py` upserts them (Homebrew `openjdk@17`, `~/Library/Android/sdk`) and runs automatically before each export. `scripts/setup_godot.sh` downloads the Android templates; the Gradle build template is unpacked into the gitignored `game/android/` directory on demand.

### Play Console (manual, once)

1. In Play Console, **Create app**: name "Purrimeter — The Garden Guard", default language English (United States), Game, Free. Accept the declarations.
2. **Set up your app** checklist: privacy policy `https://purrimeter.graham.pub/privacy/`; app access "all functionality available without special access"; ads "No"; content rating questionnaire (answers below); target audience 13+; news app "No"; COVID "No"; data safety (answers below); government app "No"; financial features "None"; health "None". Store settings: category Strategy, email `ryan@roundhouselabsinc.com`, website `https://purrimeter.graham.pub/`.
3. **Play App Signing** is enabled by default for new apps; keep it. The first bundle upload registers the upload key.
4. **API access** (Settings → Developer account → API access): link or create a Google Cloud project, create a service account, grant it the **Release manager** role for this app (or "Admin (all permissions)" limited to the app). Download its JSON key to `~/.config/purrimeter/play-service-account.json` and `chmod 600` it. Enable the Google Play Android Developer API in that Cloud project. New service accounts can take up to 24 hours before the API accepts them.
5. First release: run `./scripts/deploy_all.sh X.Y.Z --play-track internal`. The upload creates the listing text and graphics from `store/android/`. Finish any remaining checklist items in the console, then promote or publish later releases with the default production track. Google's first review is manual and may take several days; the website flag stays on "Coming soon" until the listing is live.

### Content rating questionnaire (IARC)

Violence: cartoon or fantasy violence against fantasy creatures, no blood, no realistic depictions. Sexuality, language, controlled substances, gambling: none. User interaction: users can interact with each other (chat); no location sharing; no purchases. Expected rating: Everyone / PEGI 7 with "Users interact".

### Data safety form

- Data collected: **none** stored by the developer in the ordinary sense. Declare **Messages → Other in-app messages** as collected, optional, not shared, used for "App functionality" (safety reports only), with deletion after 90 days; and **App activity → Other user-generated content** (player name) as transmitted ephemerally, optional, not shared.
- Data shared with third parties: none. Encryption in transit: yes (WSS/HTTPS). Users can request deletion: via `ryan@roundhouselabsinc.com` (reports are the only stored data). No ads SDK, no analytics.
- Account creation: none. Security practices: data encrypted in transit; developer committed to the Play Families policy is not required (audience 13+).

## Releasing

`./scripts/deploy_all.sh MAJOR.MINOR.PATCH` builds and tests everything, exports `dist/android/Purrimeter.aab` with version code MAJOR×1,000,000 + MINOR×10,000 + PATCH×100, uploads it with the listing to Google Play, and only then runs the VM transaction. Options:

- `--play-track production|beta|alpha|internal` (default production, status completed).
- `--skip-play` builds and records the bundle without uploading; rerun without the flag to publish that exact bundle.
- `--preview` prints the Play plan with everything else.

A prepared release keeps its bundle at `build/deployments/<version>-<commit>/Purrimeter.aab`; the Play step records `play.version_code`, `play.edit` and `play.committed_at` in `state.json` and is skipped on reruns. If Play already holds the same version code with different bytes, the release stops: publish a newer version. The signed game manifest contains an `android` entry with the Play URL, bundle digest, size and version code; the relay and desktop updater ignore it.

Validation without network or credentials:

```sh
python3 -m unittest discover -s scripts/deployment -p 'test_*.py' -v
```

## Store listing content

`store/android/listing.json` holds the title, short and full descriptions, contact details and category; `release-notes.txt` is the "What's new" text with `{version}` substituted. Images under `store/android/images/`: `icon.png` (512), `feature.png` (1024×500), `phone/` (1080×1800 portrait plus one 1800×1080 landscape), `tablet7/` and `tablet10/` (1800×1120). Every upload replaces the listing wholesale, so the repository is the source of truth.

Regenerate images after visual changes; they are committed, not rebuilt per release:

```sh
./scripts/make_store_screenshots.sh   # windowed Godot, staged demonstration garden
node scripts/make_store_graphics.cjs  # icon, feature graphic, launcher icons
```

Screenshots use `--app-preview` with `--preview-scene` (garden, placement, inspect, powerups, multiplayer, chat, achievements) and `--preview-scale 2`; the multiplayer scenes fake a three-player room locally. The window cannot exceed the Mac display, which is why portrait captures are 1080×1800 rather than 1080×1920.

## Verification boundaries

Automated: Gradle export and `jarsigner` verification of the bundle on every release, relay report handling, Play API sequencing against a fake transport with real RSA signing, deployment idempotency, website badge behaviour, and the Godot mobile suite including Report and back handling. Not automated: installation on physical Android hardware, Play's own review, the Play Console checklist, and real-device performance; keep the manual checks from [mobile-browser.md](mobile-browser.md) for each release.
