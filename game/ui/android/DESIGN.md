---
name: Purrimeter Android
description: Native Android floating garden controls, from the selected prototype B.
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
typography:
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
  pill: "24px"
  status: "26px"
  large-pill: "28px"
spacing:
  detail-gap: "6px"
  control-gap: "8px"
  inset: "12px"
  app-inline: "16px"
components:
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

This document captures the native Android implementation, including its app theme. It does not replace the desktop, browser or [website design system](../../../website/DESIGN.md). The selected direction is recorded in the [Android gameplay brief](../../../.impeccable/surface-briefs/android-gameplay.md); the name above describes that direction rather than introducing a new identity.

**Key Characteristics:**
- Existing pixel cats and garden artwork remain the visual identity.
- Rounded, opaque controls float over an undistorted square field.
- Compact contextual panels preserve access to the wave controls.
- Density-scaled touch targets and Android text preferences govern readability.

## Colors

Forest neutrals support warm action emphasis and cool tactical information.

### Primary
- **Gold:** Recruit, Start, enabled purchase confirmation, active Auto, prices and keyboard focus on drawn controls. Use ink lettering on gold fills.

### Secondary
- **Mint:** health and effect details, native-control focus outlines and text cursors.
- **Pink:** wave health, enemy markers, unaffordable recruitment prices and Sell emphasis.

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

**The Opaque Controls Rule.** Keep actionable surfaces opaque so their contrast does not depend on the field beneath them.

## Typography

**Interface Font:** Godot's `ThemeDB.fallback_font`, also inherited by native themed controls. No Android-specific display font is loaded. The website's Pixelify Sans pairing is outside this scope.

The frontmatter records nominal logical sizes, before Android system text scaling. Panel titles use the title role; inspection summaries and floating labels use body/label; powerup details, costs and panel actions use detail; status secondary lines use metadata. Recruitment names use 16, refund notes 13, and the app theme defaults to 16. The auto-start countdown uses 72.

`GamePlatform.ui_font_size()` converts each nominal size through Android `TypedValue.applyDimension(COMPLEX_UNIT_SP)` and divides by the window density scale. This preserves the platform's nonlinear scaling. Sizes are cached and refreshed with the app's platform settings refresh. Do not replace this with a fixed multiplier. The `px` units above describe Godot logical coordinates, not physical screen pixels.

**The Native Text Rule.** Route custom-drawn labels and explicit native-control sizes through `GamePlatform` so Android text preferences reach both rendering paths.

## Layout

Android plays in landscape. The field occupies the view; its square board scales uniformly. Focus initially makes the square board as wide as the viewport, cropping it vertically. Fit centers the complete square; pinch/pan and the tappable overview navigate the enlarged field.

Window density is `clamp(screen_dpi / 160, 1, 4)`. Layout uses the display-safe area transformed into local coordinates, inset by 12 logical units. Touch controls are at least 48 units in each actionable dimension; large bottom pills are 56 high. These are intended as density-scaled dp targets.

Status sits top left; Start/Pause/Resume, speed, Auto and Menu sit top right with 8-unit gaps. The wave action is at least 120 wide and expands to fit scaled “Resume”. Fit and Powerups sit lower left; Recruit sits lower right. Context panels start 64 below the safe top, leaving the wave controls accessible. Their width is the smaller of 332 and 49% of safe width. Inspection height is bounded by 236, Powerups by 420, and Patrol by 280, within available safe height. Panel details scroll while footer actions remain outside the scroll area.

At safe heights below 324, recruitment becomes a horizontal row across the safe width; otherwise it is a 212-by-196 palette near Recruit. Each recruit row is 56 high. The overview is 80 square when safe height is at least 330, otherwise 56 square. It appears only while zoomed, without a panel or recruitment palette open. These are safe-height thresholds, not device or CSS viewport breakpoints.

## Elevation & Depth

The Android overlay uses flat, opaque tonal layers. There are no added drop shadows, blur or glass effects. The field remains visible around the bounded panels; color and overlap establish foreground priority. Interface state changes are immediate. Brief notices remain for three seconds; this is a visibility duration, not a fade animation. Existing game and portrait animation remain active according to the game state.

## Shapes

Floating controls are capsules with a radius equal to half their height. Native panel buttons and fields use the control radius. Context panels and the recruitment palette use the panel radius; the placement strip, recruit rows and overview each have the smaller contextual radius recorded above. The square grid and pixel artwork retain their own geometry.

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

### Status and overview

The status capsule separates level and gold coin balance from ready, read-only or reconnecting text. During combat it adds a pink four-unit health bar and a numeric health percentage. The overview depicts tower colors, pink enemies and a cream camera frame; tapping it recenters the field. It is navigation, not a second independently interactive game board.

## Do's and Don'ts

### Do:
- Do preserve the existing pixel cats, garden tiles and square board proportions.
- Do keep wave controls accessible while contextual panels or placement are active.
- Do use display-safe bounds, density scaling and native Android text scaling together.
- Do keep purchase validation and read-only restrictions authoritative in the game session.
- Do distinguish custom-drawn pill states from native-control theme states.

### Don't:
- Don't stretch the board to fit landscape dimensions.
- Don't add translucent control surfaces or floating shadows to this system.
- Don't replace the compact Android panels with the desktop sidebar.
- Don't apply this Android layout or typography contract to the website or other game platforms.

Source of truth: [`android_game.gd`](../android_game.gd), [`main.gd`](../main.gd), [`app.gd`](../app.gd) and [`platform.gd`](../../core/platform.gd). The sidecar's HTML/CSS previews are portable illustrations of native Godot controls; production uses Godot drawing and nodes. Its generated tonal ramps are preview metadata, not additional shipped palette tokens.
