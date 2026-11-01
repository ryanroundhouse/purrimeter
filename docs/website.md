# Purrimeter website

## Confirmed direction

- Serve a small public promotional website at `https://purrimeter.graham.pub`.
- Offer Play in browser at `/play/` and free desktop downloads without an account requirement.
- Detect the visitor's operating system and offer the corresponding client download.
- Preserve the game's pixel-art identity. Include a real gameplay image, a short garden-defence pitch, three feature highlights, and a prominent download button.

## Existing constraints

The domain already serves the multiplayer relay. Preserve `/ws`, `/healthz`, HTTPS, and certificate renewal when adding the website. See [deployment.md](deployment.md).

Available client packages are universal macOS (Intel and Apple Silicon, macOS 11 or later) and Windows x64. Phone and tablet play uses the browser build; there is no native mobile app or Linux download. macOS builds currently use ad hoc signing and are not notarized; Windows builds are unsigned. Signed game releases now use the repository build/publication scripts; GitHub releases are not used.

Multiplayer supports up to three players with independent gardens and progression, plus chat. Marketing copy must reflect this rather than imply shared combat.

## Download and publication decisions

- Publish the current unsigned builds with a clear unsigned-build notice and concise platform-specific installation instructions. Signing and notarization are not prerequisites for this launch.
- Host the website and download archives on the existing server at `purrimeter.graham.pub`.
- Provide an explicit publish command for uploading tested client builds. Ordinary local builds do not change the publicly available downloads.
- Always show both macOS and Windows download links, highlighting the detected platform.
- Offer Play in browser on all devices; retain both native download links and detect their matching desktop OS as a convenience.
- Start downloads only after the visitor clicks a download link.

## Implementation scope

Build the static page using existing game artwork and a fresh gameplay image. Add client-side OS detection with working plain download links when JavaScript is unavailable. Include installation help, prepare an explicit publication workflow, and deploy the page and client archives to the existing HTTPS host while preserving multiplayer routes.

Verify the page at desktop and mobile sizes, platform selection and fallback behavior, public downloads, and continued multiplayer service availability. Record the deployed paths and publication instructions in the repository.

The user confirmed this scope and authorized implementation and deployment.

## Direction contract

**Mode:** Persuade. Visitors should understand the game and download their desktop client within seconds.

**THESIS:** A small invitation into the actual garden, with game imagery and direct downloads carrying the page.

**OWN-WORLD:** Inherit the game's navy, cream, mint, gold, and garden green. Pixel lettering carries the display voice; plain, readable text carries instructions. Use the existing cat icon and a fresh game capture.

**STORY:** Meet the cat patrol, see the game, choose a download, then follow short installation instructions. The three highlights explain maze building, persistent growth, and independent gardens with friends.

**FIRST VIEWPORT:** Compact wordmark/navigation above a two-column opening: a large pixel headline and both downloads on the left, an uncropped gameplay image on the right. Mobile stacks the download controls before the image. OS detection gives the matching download mint emphasis without hiding the alternative.

**FORM:** Code-led implementation of the layout confirmed during the interview, inside the established game identity; no concept roll needed for the specified scope.

**FINISH:** unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Preview and publish

The website is buildless HTML, CSS, and JavaScript. Python 3.11+ and Node.js 18+ prepare a publication; no npm dependencies are needed. The packager copies the page, stylesheet, script, public assets, matching native ZIPs, and the browser files extracted from the signed Web ZIP. Source, tests, deployment scripts, and design documents are not served.

First create a signed release with `scripts/build_release.py MAJOR.MINOR.PATCH` (see [update operations](game-update-operations.md)). To prepare a local preview using its matching `dist/game-release.json`, `dist/Purrimeter-macOS.zip`, `dist/Purrimeter-Windows.zip`, and `dist/Purrimeter-Web.zip`:

```sh
./scripts/publish_website.sh --prepare-only
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/website
```

Open `http://127.0.0.1:8765` for the homepage. For standalone browser development, run `scripts/build_web.sh` and serve `dist/` with a local HTTP server, opening `/web/`. The prepared production `/play/` page deliberately references immutable assets under `/game-releases/<id>/web/`; previewing that packaged page also requires mapping that URL to `build/website/play/`. Preparation runs OS-detection tests and validates ZIP integrity and required executables, then snapshots the page and packages into `build/website/`. It writes SHA-256 checksums and a release manifest with exact file hashes, preparation time, and the checkout commit/dirty status. That checkout information describes the publication, not a guarantee of which source commit produced pre-existing client ZIPs.

After building and testing any game changes using the existing game workflows, explicitly publish the reviewed page and tested ZIPs:

```sh
./scripts/publish_website.sh
```

Publication needs SSH access as `ryan@146.190.246.30` and passwordless sudo on the existing VPS. It uploads a snapshot to a temporary staging directory, verifies all hashes remotely, retains the previous website release, and atomically switches the public symlink. The initial deployment replaces only the existing root 404 handler with a static-site nginx include; `/ws`, `/healthz`, HTTP redirection, and ACME challenge handling remain intact. It tests nginx configuration before reload, checks the public release manifest and relay health, and restores the previous configuration/release if activation fails. It never restarts the relay.

Ordinary `scripts/build.sh` runs produce development builds and do not publish anything. Publication snapshots existing signed release archives without rebuilding them and refuses archives that differ from their signed game manifest. The ZIP checks verify packaging integrity; they do not replace gameplay tests or a Windows-device test.

See [deployment.md](deployment.md) for server paths and rollback, [website-assets.md](website-assets.md) for asset sources, and [../website/DESIGN.md](../website/DESIGN.md) for the website's visual system.

The website publication manifest `/release.json` remains separate from signed game metadata `/game-release.json`. The relay serves its verified current designation at `/updates`. Activation first retains immutable platform packages and signed metadata under `/game-releases/<game-release-id>/`, then switches the website pointer. All three platforms must match the signed game release before publication; updating website content alone does not change multiplayer admission.

## Browser publication

`/play/` is a no-store entry page. Its script, pack, and WebAssembly URLs all identify one immutable game release under `/game-releases/<id>/web/`. This prevents mixed files if publication happens during loading and preserves running older sessions. Browser storage uses the stable site origin, independent of those asset paths. Precompressed runtime files are served with nginx `gzip_static`; the browser route permits WebAssembly compilation and same-origin scripts without enabling arbitrary script sources. Publication also validates the signed Web archive and its embedded identity before activation.
