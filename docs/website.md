# Purrimeter website

## Confirmed direction

- Serve a small public promotional website at `https://purrimeter.graham.pub`.
- Offer free desktop client downloads without an account requirement.
- Detect the visitor's operating system and offer the corresponding client download.
- Preserve the game's pixel-art identity. Include a real gameplay image, a short garden-defence pitch, three feature highlights, and a prominent download button.

## Existing constraints

The domain already serves the multiplayer relay. Preserve `/ws`, `/healthz`, HTTPS, and certificate renewal when adding the website. See [deployment.md](deployment.md).

Available client packages are universal macOS (Intel and Apple Silicon, macOS 11 or later) and Windows x64. There are no Linux or mobile builds. macOS builds currently use ad hoc signing and are not notarized; Windows builds are unsigned. No GitHub releases or automated public-release workflow currently exist.

Multiplayer supports up to three players with independent gardens and progression, plus chat. Marketing copy must reflect this rather than imply shared combat.

## Download and publication decisions

- Publish the current unsigned builds with a clear unsigned-build notice and concise platform-specific installation instructions. Signing and notarization are not prerequisites for this launch.
- Host the website and download archives on the existing server at `purrimeter.graham.pub`.
- Provide an explicit publish command for uploading tested client builds. Ordinary local builds do not change the publicly available downloads.
- Always show both macOS and Windows download links, highlighting the detected platform.
- On unsupported or unknown devices, show “Available for macOS and Windows” and retain both download links.
- Start downloads only after the visitor clicks a download link.

## Implementation scope

Build the static page using existing game artwork and a fresh gameplay image. Add client-side OS detection with working plain download links when JavaScript is unavailable. Include installation help, prepare an explicit publication workflow, and deploy the page and client archives to the existing HTTPS host while preserving multiplayer routes.

Verify the page at desktop and mobile sizes, platform selection and fallback behavior, public downloads, and continued multiplayer service availability. Record the deployed paths and publication instructions in the repository.

The design questions are settled. Implementation awaits the final confirmation of this shared understanding required by the requested design interview.
