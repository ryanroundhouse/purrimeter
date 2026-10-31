# Public multiplayer server

Deployed on 2026-10-31 from game/server commit `23e43a5`.

| Item | Value |
| --- | --- |
| Client endpoint | `wss://purrimeter.graham.pub/ws` |
| Health check | `https://purrimeter.graham.pub/healthz` |
| VPS | `claw-s-1vcpu-2gb-tor1-01`, `146.190.246.30` |
| SSH | `~/bin/ssh-do.sh claw-s-1vcpu-2gb-tor1-01` (user `ryan`) |
| DNS | Cloudflare DNS-only A record, automatic TTL |
| Process | `purrimeter.service`, dedicated `purrimeter` system user |
| Executable | `/opt/purrimeter/current/purrimeter-relay` |
| Current release | `/opt/purrimeter/releases/23e43a5` |
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
