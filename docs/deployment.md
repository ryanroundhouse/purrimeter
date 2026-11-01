# Public multiplayer server

For a complete coordinated update, use [`scripts/deploy_all.sh`](deployment-workflow.md). It builds and tests the committed source, updates every downloadable client plus the server archive, conditionally restarts the relay, verifies production, and cleans up expired releases. The targeted commands and historical deployments below remain useful operational context.

Updated on 2026-10-31 with signed game release `3.0.0-1793460493` and relay artifact `updates-48f6d4ef3ec1`. The initial relay deployment was commit `23e43a5`.

| Item | Value |
| --- | --- |
| Client endpoint | `wss://purrimeter.graham.pub/ws` |
| Health check | `https://purrimeter.graham.pub/healthz` |
| VPS | `claw-s-1vcpu-2gb-tor1-01`, `146.190.246.30` |
| SSH | `~/bin/ssh-do.sh claw-s-1vcpu-2gb-tor1-01` (user `ryan`) |
| DNS | Cloudflare DNS-only A record, automatic TTL |
| Process | `purrimeter.service`, dedicated `purrimeter` system user |
| Executable | `/opt/purrimeter/current/purrimeter-relay` |
| Current release | `/opt/purrimeter/releases/updates-48f6d4ef3ec1` |
| Game release endpoint | `https://purrimeter.graham.pub/updates` |
| Release policy file | `/var/www/purrimeter/current/game-release.json` |
| Release environment | `/etc/systemd/system/purrimeter.service.d/game-release.conf` |
| Relay listener | `127.0.0.1:18080` |
| Persistent identity key | `/var/lib/purrimeter/signing.key` |
| nginx virtual host | `/etc/nginx/sites-available/purrimeter.graham.pub` |
| TLS certificate | `/etc/letsencrypt/live/purrimeter.graham.pub/` |
| ACME webroot | `/var/www/purrimeter-acme` |

The VPS already hosts other applications through nginx and Certbot, so this deployment uses the native Go binary with systemd. Docker Compose remains an alternative for a separate host. Existing applications and firewall rules were retained.

The unit enables automatic startup and restart on failure, uses a read-only system filesystem with a writable state directory, and limits memory to 256 MiB (`GOMEMLIMIT=192MiB`). `TRUST_PROXY=true` is safe here because the relay only listens on loopback and nginx overwrites `X-Forwarded-For` with the connecting IP. Only HTTPS serves the relay; HTTP redirects to HTTPS except for ACME challenges.

On the VPS, inspect and manage the service with:

```sh
sudo systemctl status purrimeter
sudo journalctl -u purrimeter --since '1 hour ago'
curl --fail https://purrimeter.graham.pub/healthz
sudo systemctl restart purrimeter
```

Restarting the relay ends active multiplayer games. Players retain their local gardens. Preserve the signing key across upgrades so installation identities remain valid; back it up securely without placing it in source control.

For an update, run `scripts/build_server.sh` locally, upload the Linux amd64 binary into a new `/opt/purrimeter/releases/<commit>/` directory as `purrimeter-relay`, set its owner to root and mode to 0755, and repoint `/opt/purrimeter/current` to that release. Restart `purrimeter`, verify the public health endpoint, and run the public integration check below. To roll back, repoint the symlink to the previous release and restart. Keep the persistent state directory throughout.

Certbot's enabled timer renews the certificate automatically. The certificate's deploy hook reloads nginx after renewal. To check renewal manually:

```sh
sudo certbot renew --cert-name purrimeter.graham.pub --dry-run --no-random-sleep-on-renew
```

From the repository root, run the public multiplayer check with:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path game \
  --script res://tests/multiplayer.gd \
  --log-file "$PWD/build/multiplayer-production.log" -- \
  --multiplayer-test --server wss://purrimeter.graham.pub/ws
```

Require both a successful exit and `Multiplayer checks: 0 failure(s)` in the log. The test uses isolated gardens and identities and briefly creates a password-protected public test room.

## Website and client downloads

The public landing page shares `https://purrimeter.graham.pub` with the relay. It is static content served by nginx; the relay continues to own exactly `/ws` and `/healthz`.

Initial website release: `20261031T142649Z-86e1cd3e4d63`, published and verified on 2026-10-31. Its complete file manifest is served at `/release.json`. Both client downloads matched their local SHA-256 checksums after full public downloads; the public multiplayer integration check passed with zero failures. The relay retained PID `1521024` and its original start time throughout publication.

| Item | Value |
| --- | --- |
| Website source | `website/` |
| Publication command | `scripts/publish_website.sh` |
| Website releases | `/var/www/purrimeter/releases/<release-id>/` |
| Active website | `/var/www/purrimeter/current` (symlink) |
| Static nginx include | `/etc/nginx/snippets/purrimeter-website.conf` |
| Config backups | `/var/www/purrimeter/config-backups/<release-id>/` |
| Mac download | `/downloads/Purrimeter-macOS.zip` |
| Windows download | `/downloads/Purrimeter-Windows.zip` |
| Client checksums | `/downloads/SHA256SUMS.txt` |
| Publication manifest | `/release.json` |

Website files and stable download URLs use cache revalidation. Downloads support byte ranges through nginx. Archives are transferred unchanged; public checksums identify the exact downloadable bytes. Preparation and publication are documented in [website.md](website.md).

Publication retains old release directories. For a content rollback, read `previous-release.txt` in the matching config backup, create a temporary symlink to that release directory, and atomically rename it over `/var/www/purrimeter/current` with `mv -Tf`. No nginx reload or relay restart is needed for content-only rollback. Verify `/release.json`, `/healthz`, and both download links afterward. If nginx configuration also needs rollback, restore `site.conf` and, when present, `snippet.conf` from the same backup, run `nginx -t`, then reload nginx. The first deployment's backup has no prior website release and restores the original root 404 behavior.

Website and relay releases are independent. Do not repoint `/opt/purrimeter/current` or restart `purrimeter.service` when updating only the website or downloadable clients.

## Updater rollout (2026-10-31)

Published website snapshot `20261031T153202Z-f95876e8aa70`, containing signed game release `3.0.0-1793460493` for macOS and Windows. Immutable downloads and signed metadata are retained under `/var/www/purrimeter/game-releases/3.0.0-1793460493/`. The relay now serves `/updates` and reloads the current signed manifest without restarting for future client publications.

The one-time relay upgrade used `scripts/deploy_server.sh`, retaining the previous `releases/23e43a5` binary and preserving `/var/lib/purrimeter/signing.key`. Live verification confirmed signed metadata, successful current-client creation/joining, and rejection of legacy, development, older and newer mismatched releases. Both complete public downloads matched their signed sizes and SHA-256 hashes; the native Mac updater performed its own download verification.

Verification logs are local build artifacts: `build/update-live-verification.log`, `build/update-relay-deployment.log`, `build/update-publication.log`, and `build/update-windows-public-verification.log`. See [game-update-operations.md](game-update-operations.md) for release signing, future publication, self-hosting and recovery. Windows runtime installation remains untested on this Mac.


## Browser release — 2026-10-31

Website release `20261101T022553Z-098a18ac04fa` publishes game release `4.0.0-1793499581` for macOS, Windows, and browser play. `/play/` loads one immutable runtime from `/game-releases/4.0.0-1793499581/web/`; gzip-compressed runtime assets are enabled. The preceding website release is `/var/www/purrimeter/releases/20261031T172139Z-04e18e6d3fb6`.

Live checks passed for page loading, gameplay/save persistence, browser-origin WebSocket admission, a temporary password-protected multiplayer game, matching signed metadata, native/browser download sizes, and relay health. Activation reloaded nginx and preserved the running relay. Physical iPhone/Android acceptance remains outstanding as recorded in `mobile-browser.md`.

## Mobile wave-control patch — 2026-10-31

Website release `20261101T023728Z-98c9d5a878df` publishes synchronized game release `4.0.1-1793500601`. Start/Resume and Auto remain available while recruiting; Confirm/Cancel occupy their own row. Signed package checks, browser integration, and production packaging checks passed before activation. The preceding website release is `/var/www/purrimeter/releases/20261101T022553Z-098a18ac04fa`. Activation validated uploaded checksums, reloaded nginx, and returned healthy relay status without restarting it. Logs: `build/wave-release-build.log`, `build/wave-prepare.log`, and `build/wave-publication.log`.
