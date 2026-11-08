# iOS and the App Store

Purrimeter uses the same Godot project and native mobile controls on Android, iPhone, and iPad. Its Apple identity is `com.roundhouselabsinc.purrimeter`, team `CC36J3BH7X` (Roundhouse Labs Inc.), App Store ID `6831635489`. [App Store Connect](https://appstoreconnect.apple.com/apps/6831635489/distribution) · [Public listing](https://apps.apple.com/app/id6831635489).

The iOS app requires iOS 16+, supports iPhone and iPad in landscape, applies the device's screen scale and safe area, and pauses/saves when backgrounded. Game updates reads the same server designation as Android and opens the App Store. It never runs the desktop updater. The existing Android-specific font scaling remains Android-only; iOS uses the shared base font sizes. Export/import currently uses the in-app sandbox file dialog, as on Android.

## Release workflow

```sh
./scripts/deploy_all.sh 4.3.0 --preview
./scripts/deploy_all.sh 4.3.0
```

Every normal release builds all five platforms under one signed identity. The iOS step exports an Xcode project, archives it, exports an App Store IPA, verifies its bundle/version, provisioning profile and code signature, and freezes its SHA-256 with the deployment. The mobile entries in the signed release manifest point to their stores; IPAs and AABs are never hosted as website downloads.

Google Play and App Store publication run before the VM transaction. Apple publication uploads the frozen IPA, waits for processing, uploads repository listing text and screenshots, selects that exact build, and submits it for review with automatic release after approval. Apple still reviews each version; submission does not mean the app is public. As agreed for Android, multiplayer requires the server-designated release, so mobile players may have to wait for store approval while single player remains available. Apple permits only one submission in review at a time; another pending submission stops a new release rather than cancelling it.

- `--skip-app-store`: build and record the signed IPA but skip Apple publication. Rerun the same commit/version without this flag to submit it.
- `--skip-ios`: omit the iOS build and publication when signing is unavailable. Preserve this flag on retries; adding iOS requires a newer release.
- `--skip-listing`: skip listing changes for both stores, while still uploading and submitting builds. Required first-launch metadata must already be complete.
- `--skip-play`: unchanged; it does not skip Apple.

Artifacts and checkpoints live in `build/deployments/<version>-<commit>/`. The frozen `store/` directory, not the current checkout, supplies both listings on retries. `state.json` records Apple's upload intent, digest, processing/build ID, listing checkpoint and submission receipt. A lost response is reconciled against Apple's version and selected build. Apple does not expose the uploaded IPA's digest: a pre-existing build without this local upload receipt is rejected instead of assumed identical. If an upload's outcome is unknown and the build has not appeared, inspect App Store Connect before any retry; never rebuild different bytes under that version. After confirming Apple rejected the upload before accepting a build, a maintainer may remove only the `upload_started_at` checkpoint to retry the same frozen IPA.

Both Apple's marketing version and build number use `MAJOR.MINOR.PATCH`. Existing release rules require a new version for different source. Apple approval cannot be rolled back together with a failed VM deployment; resume the same prepared release.

## One-time Apple setup

The App ID and listing shell were created on 2026-11-06. The account's free-app agreement is active. Browser login and Xcode signing are separate from unattended API access.

1. In Users and Access → Integrations → App Store Connect API, request API access for the organisation if unavailable. Accept any required Apple agreement as the account owner.
2. Create a team API key with the App Manager role for publishing. Team keys cover all apps in the account; keep the key owner-only and never commit it. A key's permissions may need additional provisioning access for unattended signing; this Mac can also use its existing signed-in Xcode account.
3. Save the downloaded key and an owner-only JSON configuration under `~/.config/purrimeter/`:

```json
{
  "key_id": "APPLE_KEY_ID",
  "issuer_id": "APPLE_ISSUER_ID",
  "key_file": "/Users/rg/.config/purrimeter/AuthKey_APPLE_KEY_ID.p8",
  "review_phone": "APPLE_REVIEW_CONTACT_NUMBER"
}
```

Name the JSON file `app-store.json`, and set permissions to `600` on both files. `PURRIMETER_APP_STORE_CREDENTIALS` can override its location. The review phone stays in this private file and is submitted only as Apple's review contact, not public listing text. Existing Xcode accounts supply signing when no API configuration is present for a standalone build.

4. Install fastlane for the active Ruby (`gem install fastlane` from RubyGems). The adapter uses fastlane's documented App Store Connect API and Transporter support. No Apple account password is stored by this project. Preflight checks that Ruby can load `fastlane`, `deliver`, and `spaceship`.
5. Finish the first-listing declarations in App Store Connect: free price, availability, Games / Strategy category, content rights, age-rating questionnaire, app privacy, and review contact. No sign-in, ads, purchases, tracking or analytics are present. Fantasy/cartoon combat has no blood; multiplayer includes messaging and user-generated names. The Android audience is 13+; use an appropriate age override if Apple's calculated rating is lower.
6. Privacy: ordinary multiplayer state is ephemeral. Reports retain chat messages, chosen names and installation identities for 90 days, for safety/app functionality. Disclose the stored messages/content and identifiers; do not declare “no data collected.” No tracking or third-party advertising. Privacy URL: `https://purrimeter.graham.pub/privacy/index.html`. Check Apple's current questionnaire against `website/privacy/index.html`.
7. Confirm moderation meets Apple's user-generated-content requirements before the first submission. Current shared functionality is session mute, reporting and host kick; a filtering method and durable user blocking need review against Apple's guideline 1.2. Do not claim these safeguards exist in the questionnaire or review notes if they have not been implemented.

App Store metadata is in `store/ios/listing.json`, release notes in `store/ios/release-notes.txt`, and real simulator captures in `store/ios/screenshots/en-US/`. The first version omits What's New, which Apple does not request for a first release.

## Build and capture locally

```sh
./scripts/setup_godot.sh
python3 scripts/build_ios.py
```

Output: `dist/ios/Purrimeter.ipa`; Xcode and Godot logs are in `build/ios-*.log`. The build uses automatic development signing for the archive and App Store distribution signing during export. No signing secrets or generated Xcode project are committed.

The official Godot 4.7.2 iOS template incorrectly declares an arm64 simulator slice containing only x86_64 objects. To test natively on Apple Silicon, compile the matching engine once:

```sh
./scripts/setup_ios_simulator.sh
python3 scripts/build_ios.py --simulator
xcrun simctl list devices available
python3 scripts/make_ios_screenshots.py --iphone IPHONE_UDID --ipad IPAD_UDID
```

Use a 6.5/6.7/6.9-inch iPhone and a 13-inch iPad Pro. Captures come from the native iOS app's rendered viewport, using the isolated preview garden; no player save is used. The simulator library is local tooling only. Distribution IPAs always use the official device template. Simulator projects live in `build/ios-simulator-project`, separately from the signed distribution artifacts in `dist/ios`.

## Website availability

The iOS website entry remains “Coming soon” until Apple publishes the listing. Run `python3 scripts/ios_status.py`; exit 0 means Apple's Canadian public lookup contains this app, exit 1 means not public yet. Once confirmed, set `data-store-status="live"` on `#download-ios` and publish the next release. The stored URL becomes clickable and is recommended on iPhone/iPad, including iPad desktop-mode Safari. No background polling job is installed by this script.

## Validation

```sh
python3 -m unittest discover -s scripts/deployment -p 'test_*.py'
node --test website/tests/download.test.cjs
./scripts/test.sh
```

Store API tests use a fake service and real immutable files. They cover changed bytes, foreign builds, in-flight reviews, interrupted uploads, failed processing, and lost submission responses. A successful simulator test does not establish physical-device performance. The first live API upload and Apple review are separate verification steps.

References: [Godot iOS export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html), [Godot simulator template issue](https://github.com/godotengine/godot/issues/122379), [fastlane deliver](https://docs.fastlane.tools/actions/deliver/), [fastlane API authentication](https://docs.fastlane.tools/app-store-connect-api/), [Apple user-generated-content guideline](https://developer.apple.com/app-store/review/guidelines/#user-generated-content).

See [App Review screen recording](ios-review-recording.md) for the physical-device recording Apple requests under Guideline 2.1.
