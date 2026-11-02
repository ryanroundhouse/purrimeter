# Website asset provenance

- `website/assets/gameplay.png`: unedited capture of this repository's game, produced with `.tools/Godot.app/Contents/MacOS/Godot --path game -- --preview "$PWD/build/website-gameplay.png"` on 2026-10-31. Uses the isolated demonstration garden, not a player's save. Copied directly from the capture.
- `website/assets/icon.png`: unmodified copy of `game/assets/icon.png`. Existing Purrimeter artwork; see [artwork.md](artwork.md) for the original asset provenance.
- `website/assets/PixelifySans.ttf`: Pixelify Sans variable font, downloaded from the [Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/pixelifysans), with its SIL Open Font License retained as `PixelifySans-OFL.txt`. Served locally; no third-party font requests.
- Interface arrows and the Google Play triangle: authored inline SVG geometry, using one consistent two-pixel stroke. Google's official badge artwork is deliberately not embedded.
- `store/android/images/`: Play listing graphics. Screenshots are unedited captures of this repository's game via `scripts/make_store_screenshots.sh` (staged demonstration garden and a locally faked three-player room, 2026-11-01). `icon.png`, `feature.png` and `game/assets/android/*` are composed by `scripts/make_store_graphics.cjs` from `game/assets/icon.png`, `website/assets/gameplay.png` and Pixelify Sans.

Installation guidance was checked against [Apple's downloaded-app guide](https://support.apple.com/en-us/102445) and [Microsoft's SmartScreen documentation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation) on 2026-10-31. Neither source is a claim that the app is signed, notarized, or independently security-reviewed.
