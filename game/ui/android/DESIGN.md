---
name: Purrimeter Android
description: Native Android floating garden controls (B) and Garden sidebar menus (A).
colors:
  surface: "#18382a"
  panel: "#152e23"
  hud: "#162b22"
  ink: "#131c26"
  cream: "#f4edd7"
  muted: "#b0c3bd"
  mint: "#89dfb5"
  gold: "#ffc46b"
  pink: "#fa7897"
  line: "#3d514e"
  selected: "#395b3e"
  pressed: "#39584b"
  text-selection: "#416957"
  menu-grass-light: "#30483c"
  menu-grass-dark: "#2d4439"
  menu-grass-detail: "#48634a"
typography:
  menu-display:
    fontFamily: "Godot ThemeDB.fallback_font (FontVariation embolden 1.0)"
    fontSize: "48px"
  menu-heading:
    fontFamily: "Godot ThemeDB.fallback_font"
    fontSize: "22px"
  menu-note:
    fontFamily: "Godot ThemeDB.fallback_font"
    fontSize: "13px"
  title:
    fontFamily: "Godot ThemeDB.fallback_font"
    fontSize: "18px"
  body:
    fontFamily: "Godot ThemeDB.fallback_font"
    fontSize: "15px"
  detail:
    fontFamily: "Godot ThemeDB.fallback_font"
    fontSize: "14px"
  label:
    fontFamily: "Godot ThemeDB.fallback_font"
    fontSize: "15px"
  metadata:
    fontFamily: "Godot ThemeDB.fallback_font"
    fontSize: "12px"
rounded:
  overview: "8px"
  recruit-row: "10px"
  control: "12px"
  placement: "14px"
  panel: "16px"
  menu-panel: "20px"
  pill: "24px"
  status: "26px"
  large-pill: "28px"
spacing:
  detail-gap: "6px"
  control-gap: "8px"
  inset: "12px"
  app-inline: "16px"
components:
  menu-panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.cream}"
    rounded: "{rounded.menu-panel}"
    padding: "16px"
  menu-action:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.cream}"
    typography: "{typography.detail}"
    rounded: "{rounded.control}"
    padding: "6px 10px"
  menu-action-primary:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "6px 10px"
  menu-action-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.cream}"
    typography: "{typography.detail}"
    rounded: "{rounded.control}"
    padding: "6px 10px"
  pill:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.cream}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    height: "48px"
  pill-primary:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    height: "48px"
  recruit:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.large-pill}"
    width: "132px"
    height: "56px"
  panel-button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.cream}"
    typography: "{typography.detail}"
    rounded: "{rounded.control}"
    padding: "6px 8px"
  panel-button-primary:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.ink}"
    typography: "{typography.detail}"
    rounded: "{rounded.control}"
    padding: "6px 8px"
  context-panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.cream}"
    rounded: "{rounded.panel}"
    padding: "12px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.cream}"
    rounded: "{rounded.control}"
    padding: "12px 16px"
  status:
    backgroundColor: "{colors.hud}"
    textColor: "{colors.cream}"
    rounded: "{rounded.status}"
    height: "52px"
---

# Design System: Purrimeter Android

## Overview

**Creative North Star: "The garden under your fingertips"**

The selected prototype B puts the existing pixel garden behind a small set of forest-green controls. Cream labels, gold recruitment and mint tactical information keep the familiar cats and combat state readable. Opaque surfaces provide separation from the animated field.

The selected A Garden sidebar extends this family to the main and in-game menus: existing animated cats and the title accompany a bounded forest action panel; a gold action gives entry or return to the garden priority. Menu surfaces share the gameplay palette without changing B’s field controls.

This document captures the native Android implementation, including its app theme. It does not replace the desktop, browser or [website design system](../../../website/DESIGN.md). The selected direction is recorded in the [Android gameplay brief](../../../.impeccable/surface-briefs/android-gameplay.md); the [Android menu brief](../../../.impeccable/surface-briefs/android-menus.md) records the selected A direction. The name above describes the shared family rather than introducing a new identity.

**Key Characteristics:**
- Existing pixel cats and garden artwork remain the visual identity.
- Rounded, opaque controls float over an undistorted square field.
- Compact contextual panels preserve access to the wave controls.
- Menu sidebars prioritize one gold action and keep secondary navigation in a bounded scroll region.
- Density-scaled touch targets and Android text preferences govern readability.

## Colors

Forest neutrals support warm action emphasis and cool tactical information.

### Primary
- **Gold:** Recruit, Start, enabled purchase confirmation, Single player, Resume, active Auto, enabled menu switches, prices and keyboard focus on drawn controls. Use ink lettering on gold fills.

### Secondary
- **Mint:** health and effect details, native-control focus outlines and text cursors.
- **Pink:** wave health, enemy markers, unaffordable recruitment prices and Sell/New garden emphasis.

### Neutral
- **Forest surface:** floating controls and native app controls.
- **Deep forest panel:** contextual sheets, recruitment palette and placement confirmation.
- **Forest HUD:** the compact status capsule.
- **Ink:** field fallback and lettering on gold.
- **Cream:** primary labels and the overview camera outline.
- **Muted sage:** supporting or unavailable information.
- **Garden line:** health-track fill.
- **Selected forest:** the selected recruitment row.
- **Pressed forest:** pressed native app controls.
- **Text selection:** selected text in native fields.
- **Menu grass:** alternating light/dark forest tiles with sparse detail marks behind the title and cats. This decorative menu field does not stage or mutate a saved garden.

**The Opaque Controls Rule.** Keep actionable surfaces opaque so their contrast does not depend on the field beneath them.

## Typography

**Interface Font:** Godot's `ThemeDB.fallback_font`, also inherited by native themed controls. No Android-specific display font is loaded. The website's Pixelify Sans pairing is outside this scope.

The frontmatter records nominal logical sizes, before Android system text scaling. Panel titles use the title role; inspection summaries and floating labels use body/label; powerup details, costs and panel actions use detail; status secondary lines use metadata. Recruitment names use 16, refund notes 13, and the app theme defaults to 16. The auto-start countdown uses 72.

`GamePlatform.ui_font_size()` converts each nominal size through Android `TypedValue.applyDimension(COMPLEX_UNIT_SP)` and divides by the window density scale. This preserves the platform's nonlinear scaling. Sizes are cached and refreshed with the app's platform settings refresh. Do not replace this with a fixed multiplier. The `px` units above describe Godot logical coordinates, not physical screen pixels.

Menu primary actions use label, secondary actions use detail, pause headings use menu-heading, and the real-save progression line uses menu-note. Supporting multiplayer and update text uses metadata. The drawn main title uses menu-display through a `FontVariation` with `variation_embolden = 1.0`, capped at `int(hero.width / 7.3)` after system scaling. Its subtitle uses title, capped at `int(hero.width / 10)`. These fit caps apply only to the drawn hero text. Native action text keeps Android scaling and a full-caption tooltip.

**The Native Text Rule.** Route custom-drawn labels and explicit native-control sizes through `GamePlatform` so Android text preferences reach both rendering paths.

## Layout

Android plays in landscape. The field occupies the view; its square board scales uniformly. Focus initially makes the square board as wide as the viewport, cropping it vertically. Fit centers the complete square; pinch/pan and the tappable overview navigate the enlarged field.

Window density is `clamp(screen_dpi / 160, 1, 4)`. Layout uses the display-safe area transformed into local coordinates, inset by 12 logical units. Touch controls are at least 48 units in each actionable dimension; large bottom pills are 56 high. These are intended as density-scaled dp targets.

Status sits top left; Start/Pause/Resume, speed, Auto and Menu sit top right with 8-unit gaps. The wave action is at least 120 wide and expands to fit scaled “Resume”. Fit and Powerups sit lower left; Recruit sits lower right. Context panels start 64 below the safe top, leaving the wave controls accessible. Their width is the smaller of 332 and 49% of safe width. Inspection height is bounded by 236, Powerups by 420, and Patrol by 280, within available safe height. Panel details scroll while footer actions remain outside the scroll area.

At safe heights below 324, recruitment becomes a horizontal row across the safe width; otherwise it is a 212-by-196 palette near Recruit. Each recruit row is 56 high. The overview is 80 square when safe height is at least 330, otherwise 56 square. It appears only while zoomed, without a panel or recruitment palette open. These are safe-height thresholds, not device or CSS viewport breakpoints.

### Menu sidebars

Both menus use the same display-safe bounds inset by 12. The panel is right-aligned and vertically centered. Width is `min(min(510, max(340, safe_width * 0.46)), safe_width * 0.62)`; height is bounded by safe height and 440 for main or 560 for pause. Inner padding is 16, with 8-unit stack and grid gaps. The hero occupies the remaining left region with a 16-unit gutter. All measurements are logical units. The computed width and height also set `panel.custom_maximum_size`, keeping the native container bounded.

Secondary actions use two columns, falling back to one only when panel width is below 460 and the scaled 14-unit font exceeds 16. Main-menu connection and update utilities always occupy full-width rows. The main panel scrolls vertically as a whole. Pause keeps its heading/close, gold Resume, and bottom “Close menu · stay paused” outside the secondary-action scroller; horizontal scrolling is disabled and focus follows into view. Preserve at least 48-by-48 targets and scrolling when short landscapes or larger text need more room. Menu buttons use `MOUSE_FILTER_PASS` so touch gestures reach their parent scroller. After initial layout, resize events or changed safe bounds/scaled font trigger layout; animation redraws do not reset container sizing each frame, preserving native scrolling.

## Elevation & Depth

The Android overlay uses flat, opaque tonal layers. There are no added drop shadows, blur or glass effects. The field remains visible around the bounded panels; color and overlap establish foreground priority. Interface state changes are immediate. Brief notices remain for three seconds; this is a visibility duration, not a fade animation. Existing game and portrait animation remain active according to the game state.

The pause menu adds a full-viewport `Color(0.05, 0.12, 0.09, 0.23)` scrim over the actual paused field. It is backdrop dimming; the menu panel remains opaque. Main-menu cat portraits cycle four frames at three frames per second using the saved skin choices and existing art. Menu control state changes have no added motion.

## Shapes

Floating controls are capsules with a radius equal to half their height. Native panel buttons and fields use the control radius. Context panels and the recruitment palette use the panel radius; the placement strip, recruit rows and overview each have the smaller contextual radius recorded above. The menu sidebar uses its own menu-panel radius. Primary menu actions use the pill radius; secondary and quiet actions use the control radius. The square grid and pixel artwork retain their own geometry.

Drawn-control keyboard focus is a gold two-unit rectangular outline expanded two units beyond the control. Native themed focus is a mint two-unit rounded border. Preserve these separate rendering paths when extending either family.

## Components

### Floating controls

Compact capsules keep frequent actions on the field. Icons are 20 square; icon-only controls center them. Default pills are forest with cream text; lit enabled pills are gold with ink text. Disabled pills retain forest fill with muted text. Drawn pills have no hover-color or press-animation treatment. Start/Pause/Resume stays accessible during placement and while a contextual panel is open.

### Recruitment and placement

The gold Recruit capsule opens three rows containing an existing animated cat, role name and current cost. Selection uses the selected-forest fill; unaffordable cost text is pink. Choosing a cat collapses the palette. A separate placement strip explains the tile's validation state and offers a gold Confirm action plus a 48-square Cancel action. Only a valid, affordable preview enables confirmation. The pending tile receives a gold outline; the session remains authoritative for purchases.

### Context panels and actions

Forest panels use 12-unit inner padding, 8-unit layout gaps and 6-unit detail gaps. The header contains the title or mode selector and a 48-square close control. Inspection keeps its animated portrait, tactical details, Upgrade and Repair; Sell occupies the header and uses pink text. Powerups uses native selectors for Available/Owned/Patrol and the current powerup, followed by details and an external Buy footer. Native selectors retain their Godot control behavior; they are not a custom chip grid.

Panel buttons are at least 48 square and use 14-base text, 8-unit horizontal and 6-unit vertical padding. Hover lightens the resting fill by 8%; pressed fill matches resting fill. Enabled Upgrade and Buy use gold; other actions use forest. Native mint focus remains inherited. Disabled native button text comes from the app theme's muted color darkened by 15%.

### App controls and fields

The shared app theme switches to forest controls and gold primary actions on Android. It gives controls the control radius, 16-unit horizontal and 12-unit vertical padding. Ordinary hover lightens forest by 10%; primary hover lightens gold by 12%. Ordinary pressed fill uses pressed forest. Fields use cream text, muted placeholders, a mint caret and the text-selection fill; focus uses the native mint border. Inputs and app buttons have a 48-unit minimum height.

### Garden menu navigation

Menu action buttons use at least 48-by-48 targets, 10-unit horizontal and 6-unit vertical padding. Primary actions use gold with ink labels and icons, 15-base type, and an 8% lightened hover fill; their pressed fill remains gold. Secondary actions use forest with cream labels/icons and 14-base type; hover inherits the app theme’s 10% lightening and pressed uses pressed forest. Quiet utilities use a transparent resting fill over the opaque panel, then forest on hover/press. All use a two-unit mint focus border at their own radius. Disabled text remains the inherited muted color darkened by 15%. Menu actions use 20-unit icons and an 8-unit icon/text gap; the line icons are generated from 24-unit SVG paths with 1.8-unit round strokes. Play and Close reuse existing control artwork.

Single player is the main menu’s primary action. Its supporting line shows the current garden’s selected level and wave progress. Multiplayer follows with its short live-fields/chat explanation, then Achievements/Cat Skins, connection settings and updates. The title and three existing pixel cats occupy the left region; nearest-neighbor rendering preserves their edges.

The pause sidebar prioritizes Resume. Route and Sound show both current-state text and a right-aligned 32-by-20 switch icon: a 30-by-18 rounded track with a six-unit-radius knob. Enabled uses gold track/ink knob; disabled uses garden-line track/muted knob. The grid then exposes Achievements, Cat Skins, Export/Import garden, How to play, Updates, New garden and Main menu. New garden uses pink resting text/icon emphasis on a forest action, rather than a filled danger treatment. Multiplayer adds its other-gardeners note and Continue offline below the grid.

**The Deliberate Resume Rule.** Opening the menu pauses local play. Resume closes the menu and explicitly resumes; both close controls dismiss it while keeping the garden paused. Nested panels retain the existing app navigation and confirmation paths. Main menu saves and pauses after confirmation, and New garden retains its destructive-action confirmation. No visual menu state bypasses these behaviors.

### Status and overview

The status capsule separates selected level, wave, and gold coin balance from ready, completed, read-only or reconnecting text. During combat it adds a pink four-unit health bar and a numeric health percentage. The overview depicts tower colors, pink enemies and a cream camera frame; tapping it recenters the field. It is navigation, not a second independently interactive game board.

## Do's and Don'ts

### Do:
- Do preserve the existing pixel cats, garden tiles and square board proportions.
- Do keep wave controls accessible while contextual panels or placement are active.
- Do use display-safe bounds, density scaling and native Android text scaling together.
- Do keep purchase validation and read-only restrictions authoritative in the game session.
- Do distinguish custom-drawn pill states from native-control theme states.
- Do preserve the gold primary menu action, visible pause close controls and scrollable secondary actions.
- Do show actual save progression and preserve explicit resume and destructive-action confirmation.

### Don't:
- Don't stretch the board to fit landscape dimensions.
- Don't add translucent control surfaces or floating shadows to this system; quiet menu actions sit on an opaque panel, and the pause scrim is only a backdrop.
- Don't replace the compact B gameplay panels with the desktop sidebar; A menu sidebars are a separate navigation surface.
- Don't apply this Android layout or typography contract to the website or other game platforms.

Source of truth: [`android_menus.gd`](../android_menus.gd), [`android_game.gd`](../android_game.gd), [`main.gd`](../main.gd), [`app.gd`](../app.gd) and [`platform.gd`](../../core/platform.gd). The sidecar's HTML/CSS previews are portable illustrations of native Godot controls; production uses Godot drawing and nodes. Its generated tonal ramps are preview metadata, not additional shipped palette tokens.
