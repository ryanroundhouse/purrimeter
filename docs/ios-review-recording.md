# App Review screen recording

Apple's Guideline 2.1 "Information Needed" response to the first submission (4.4.0, 2026-11-08) asks for a screen recording captured on a physical iPhone running the latest iOS. The simulator does not satisfy this. Record once per submission that Apple asks for it; attach it in App Store Connect under App Review Information → Attachment on the version page, then press Update Review / Resubmit.

## Capture

Install the submitted build through TestFlight on an iPhone on the latest iOS. Start recording with Control Centre → Screen Recording before launching the app. Two to three minutes is enough. Keep the device in landscape.

Without a device, the 4.4.0 reply used the iPhone 17 Pro simulator instead: `scripts/build_ios.py --simulator` stamped as the live release, taps driven by an XCUITest loop, a second player joining from the browser build, and `xcrun simctl io <udid> recordVideo` started right after launch so the file stays landscape (starting on the portrait home screen records sideways). Say so in the notes; do not claim a physical device.

## Shot list

1. Launch from the home screen; wait for the main menu.
2. Single player → Recruit → pick a cat → tap a tile → Confirm. Place two or three cats.
3. Start a wave. Tap a cat and an enemy to show inspection. Open Powerups briefly.
4. Menu: show Sound, Export/Import, New Garden, Help; return to the main menu.
5. Multiplayer → Join a game (or Create a game) on the official server.
6. Chat: send a message. Show Mute on another player's message, then Report on a message, including the confirmation. If no other player is present, create the game and join from a second device or the browser build at purrimeter.graham.pub/play/.
7. Return to the main menu and stop recording.

Trim nothing before the launch. The review notes in `store/ios/listing.json` state that the recording is attached, so do not resubmit without it.
