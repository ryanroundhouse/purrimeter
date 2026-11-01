# Native update interface review

Disposition: **ship the local UI extension**. This records the existing desktop design and the reviewed updater states; it does not certify a published release or installation on Windows.

## Inherited design

The updater reuses `game/ui/app.gd`'s theme, title-page layout, labels, and buttons. Comparison with the incumbent code at `HEAD` and `build/multiplayer-settings.png` confirms the navy background (`#131c26`), tonal panel controls (`#202e3a`), cream text (`#f4edd7`), muted supporting text (`#b0c3bd`), mint emphasis (`#89dfb5`), and gold status text (`#ffc46b`). It retains the existing Godot interface type, 38-unit page heading, 18-unit default text, gently rounded controls, 48-unit minimum button height, and mint keyboard-focus outline. No artwork or visual identity was added.

`website/DESIGN.md` applies only to the website. Its Pixelify Sans pairing and website focus rules were not imported into the native game. Existing design files are preserved; this ordinary extension creates no root `DESIGN.md` or design sidecar.

## Evidence checked

- `build/update-available.png`: installed and server releases, gold update notice, mint “Download update,” and a persistent return action.
- `build/update-checking.png`: explicit checking status, continued single-player availability, and visible keyboard focus on “Back · keep playing.”
- `build/update-downloaded.png`: verified-ready status and “Restart and play,” with the save and multiplayer departure consequences stated before activation.
- `build/update-error.png`: wrapped failure text, Retry, package reveal, and readable manual replacement instructions; the return action remains available.
- `game/updates/updater.gd` and `game/ui/app.gd`: background checks, download progress, retries, update-state actions, state-change focus restoration, and return navigation.
- `build/update-multiplayer-final.log`: “updates clear remote controls while retaining multiplayer membership,” “update state changes retain a keyboard action,” and “returning from updates rebuilds remote gardens” all pass. The run reports `Multiplayer checks: 0 failure(s)`.

The four state captures are local previews using a development installation and illustrative server version 3.1.0. They establish layout and copy, not a live release download. No clipping or new visual drift was observed at the captured 1152×810 size. The test log also contains resource-leak diagnostics at exit; it is not a clean-shutdown certification.

## Existing documentation drift

The initial review found a stale “implementation has not started” introduction in `docs/game-updates.md`; the implementation documentation pass has since updated it. Unrelated product wording, including deployment ownership, was preserved. No design-system drift requiring repair was found in this extension.
