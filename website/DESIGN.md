---
name: Purrimeter website
description: The Garden Guard’s desktop download website.
colors:
  ink: "#131c26"
  panel: "#202e3a"
  cream: "#f4edd7"
  muted: "#b0c3bd"
  mint: "#89dfb5"
  gold: "#ffc46b"
  garden: "#284b3b"
  line: "#42564f"
  mint-hover: "#a2ebc7"
typography:
  display:
    fontFamily: '"Pixelify Sans", sans-serif'
    fontSize: "clamp(48px, 5.2vw, 76px)"
    fontWeight: 600
    lineHeight: 0.98
    letterSpacing: "-0.025em"
  headline:
    fontFamily: '"Pixelify Sans", sans-serif'
    fontSize: "44px"
    fontWeight: 500
    lineHeight: 1.05
  title:
    fontFamily: '"Pixelify Sans", sans-serif'
    fontSize: "32px"
    fontWeight: 600
    lineHeight: 1.05
  body:
    fontFamily: '"Avenir Next", "Segoe UI", sans-serif'
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: '"Avenir Next", "Segoe UI", sans-serif'
    fontSize: "17px"
    fontWeight: 650
    lineHeight: 1.4
rounded:
  control: "5px"
spacing:
  small: "12px"
  medium: "24px"
  large: "32px"
  columns: "56px"
components:
  download:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.cream}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "14px 18px"
  download-hover:
    backgroundColor: "{colors.garden}"
    textColor: "{colors.cream}"
  download-recommended:
    backgroundColor: "{colors.mint}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "14px 18px"
  download-recommended-hover:
    backgroundColor: "{colors.mint-hover}"
    textColor: "{colors.ink}"
---

# Design System: Purrimeter website

## Overview

**Creative North Star: "An invitation into the actual garden"**

An invitation into the actual garden: navy surfaces, cream text, mint emphasis, and the existing pixel artwork carry the website’s identity. Pixel lettering gives headings their game voice; plain text keeps downloads and installation instructions readable.

This system applies only to the website. It inherits Purrimeter’s established identity and records the shipped surface, without changing the desktop game’s design.

**Key Characteristics:**
- Existing game imagery, shown without decorative cropping.
- Pixel display type paired with readable interface text.
- Flat surfaces, restrained corners, and clear keyboard focus.

## Colors

The dark garden palette uses warm cream for reading and mint for emphasis.

### Primary
- **Mint:** recommended downloads, headline emphasis, links and hover feedback; also the broad feature-section ground.
- **Mint hover:** brighter feedback on the recommended download.

### Secondary
- **Gold:** keyboard focus and the gameplay caption’s short descriptive line.
- **Garden green:** ordinary download hover fill.

### Neutral
- **Ink:** page background and text on mint.
- **Panel:** ordinary download surface.
- **Cream:** primary reading text.
- **Muted sage:** supporting text and ordinary download borders.
- **Garden line:** section separators and screenshot borders.

## Typography

**Display Font:** Pixelify Sans, with sans-serif fallback; served locally with its license.
**Body Font:** Avenir Next, Segoe UI, sans-serif.

Pixel headings connect the page to the game. Plain body text supports longer reading and platform instructions. The observed hierarchy is role-based, not a mathematical scale.

- **Display:** hero title; fluid desktop size from the frontmatter. At mobile widths it uses `clamp(48px, 12vw, 72px)`.
- **Headline:** installation heading; reduces to 38px on mobile.
- **Title:** feature headings; reduces to 28px at the middle breakpoint and 27px on mobile.
- **Body:** ordinary prose; the introduction uses 19px/1.5 (18px mobile). Supporting hero prose is limited to 45ch.
- **Label:** download action; supporting detail uses 12px and the recommendation uses 11px. Navigation is 14px (12px mobile).

**The Readable Instructions Rule.** Use pixel lettering for display roles; use the body face for actions, metadata, and instructions.

## Layout

The centered wrapper caps at 1280px, with 48px side gutters. At 1000px and below, gutters become 32px; at 760px and below, 20px. Desktop hero and installation use two columns in a .83:1.17 ratio with a 56px gap. The hero becomes equal columns with a 32px gap at the middle breakpoint; both sections stack at the mobile breakpoint. Downloads precede the image in source and visual order.

Feature content uses three columns on desktop. On mobile each feature becomes a two-column title/text row, then a single column at 420px. The footer stacks on mobile. Repeated spacing steps are recorded above; section padding remains contextual, with generous desktop spacing and shorter mobile spacing.

## Elevation & Depth

Depth comes from dark tonal surfaces, mint contrast, and single-pixel dividing lines. No box or text shadows are used.

**The Flat Garden Rule.** Separate surfaces with color and thin borders; the website has no shadow vocabulary.

## Shapes

Download surfaces and gameplay framing have gently rounded corners using the control radius. Sections remain rectangular. The cat icon preserves pixel rendering; the gameplay image retains its original aspect ratio. Interface arrows use simple inline SVG paths with a consistent two-pixel stroke.

## Components

### Downloads

Stacked, full-width links with separate action and metadata lines. Ordinary links use panel fill and a muted border; hover uses garden fill and a mint border. The recommended platform uses mint fill and ink text, with a visible recommendation line. Background and border transitions last 160ms with ease-out; reduced motion removes them. Detection changes emphasis only; both links work without JavaScript.

### Navigation

A compact icon/wordmark lockup sits opposite plain text links. Hover uses mint. At the mobile breakpoint, the game-section link is hidden and installation help remains available.

### Gameplay image

An uncropped, bordered image links to the full-size capture. The wrapping caption separates a gold descriptive line from muted viewing metadata and wraps when necessary.

### Installation disclosure

Native details/summary elements use single-pixel separators and generous vertical hit areas. The chevron rotates when open; summary hover turns mint. Body text is muted, with cream emphasis and mint links.

### Focus and anchors

Links and summaries receive a gold three-pixel outline with a six-pixel offset on keyboard focus. The skip link appears on focus. Anchor scrolling is smooth unless reduced motion is requested.

## Do's and Don'ts

### Voice

Lead with what players do and the choices that make the game interesting. Let the cats and garden supply the humour; use complete, natural sentences for explanations. Avoid paired slogans, repeated sentence fragments, small/big contrasts, and possessive sequences such as “Your garden. Your patrol.” Headings should name the section’s subject, screenshot captions should identify the scene, and installation help should be direct. Do not force line breaks to make copy look like a tagline.

### Do:
- Do preserve the existing cat icon, game artwork, and pixel display voice.
- Do keep screenshot proportions intact and retain full-size access.
- Do provide visible focus and honor reduced-motion preferences.
- Do keep both platform downloads available when highlighting a recommendation.

### Don't:
- Don’t use pixel lettering for installation instructions or download metadata.
- Don’t add floating shadows to the flat website surfaces.
- Don’t use a platform recommendation to hide the other download.


Source of truth: `style.css`, `index.html`, and `download.js`. Direction: `../docs/website.md`. Asset provenance: `../docs/website-assets.md`. This website boundary does not define the desktop game system.
