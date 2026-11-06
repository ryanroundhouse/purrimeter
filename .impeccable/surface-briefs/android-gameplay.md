# Android gameplay controls

Mode: Operate. On 2026-11-05 the user selected prototype B and requested implementation in Android. Preserve game rules, artwork, macOS UI and existing browser UI.

## Direction contract

THESIS: let the field occupy the Android gameplay viewport; float only frequently used controls over it.
OWN-WORLD: existing forest tiles and pixel cats; forest green controls (#18382a), dark green panels (#152e23), cream text, gold recruitment, mint selection, pink health. Opaque surfaces and readable 48dp targets.
STORY: recruit from a compact palette, preview and confirm a tile, inspect in a bounded panel, keep Pause accessible, pan/pinch the enlarged board and use Fit/Focus or the overview to navigate.
FIRST VIEWPORT: zoom to viewport width, crop vertically without distorting the square grid. Status top left; Pause/Resume/Start, speed, Auto, Menu top right. Fit and Powerups lower left, gold Recruit lower right, overview below top-right controls. Context panels preserve the field and combat state.
FORM: user-selected prototype B, preserved on branch prototype/android-controls, commit 1a0419e. No concept-seed: user selection is the design authority. Production code is native Godot; browser prototype code is not shipped.
FINISH: verify phone/tablet layouts, purchase validation, gesture/control separation, Back, pause while panels are open, read-only multiplayer, Android density and safe area; capture native evidence, obtain finish review, and document the implemented design.
