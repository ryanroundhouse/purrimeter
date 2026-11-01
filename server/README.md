# Purrimeter multiplayer server

A Go relay for public games of up to three players. It handles admission, chat, moderation and live field updates. Each desktop client runs and saves its own garden. Game membership is temporary; restarting the relay clears games without deleting anyone's progress.

## Deploy on a Linux VPS with Docker Compose

1. Point `purrimeter.graham.pub` at your VPS. Allow inbound TCP ports 80 and 443. Use a supported Linux installation with Docker Engine and the Compose plugin.
2. Copy this directory (or extract `Purrimeter-Server.tar.gz`) to the VPS. Create a `.env` file beside `compose.yaml` containing your real hostname:

   ```dotenv
   GAME_HOST=purrimeter.graham.pub
   ```

3. Start the service:

   ```sh
   docker compose up -d --build
   docker compose logs --tail=50
   curl https://purrimeter.graham.pub/healthz
   ```

4. The game's default address is `wss://purrimeter.graham.pub/ws`. Choose a name in **Connection settings**, then open Multiplayer. All players must use the same server; the address can be overridden there.

Caddy obtains and renews the TLS certificate. The relay is reachable only through the private Compose network; its port is not published to the VPS. Keep the `relay_data`, `caddy_data`, and `caddy_config` volumes. In particular, the signing key in `relay_data` preserves installation identities across restarts. Do not use `docker compose down -v` unless you intend to discard those credentials and certificates.

Update by replacing the source and running `docker compose up -d --build` again. Active games end during a relay restart; clients pause and retain their saved gardens. Inspect operational logs with `docker compose logs --tail=100`. Logs do not contain chat, passwords, tokens, or field payloads.

## Existing reverse proxy or no Docker

The release includes `purrimeter-relay-linux-amd64` and `purrimeter-relay-linux-arm64`. Run the appropriate binary as a dedicated unprivileged service user under your existing process supervisor:

```sh
LISTEN_ADDR=127.0.0.1:8080 \
SIGNING_KEY_FILE=/var/lib/purrimeter/signing.key \
./purrimeter-relay-linux-amd64
```

The key directory must be writable by that user. The service creates a random key on its first start. Put an HTTPS reverse proxy in front of it that supports WebSocket upgrades and long-lived connections. For Caddy on the same host:

```caddyfile
purrimeter.graham.pub {
    reverse_proxy 127.0.0.1:8080
}
```

`TRUST_PROXY=true` makes the relay apply its per-IP limits using the proxy's `X-Forwarded-For` header. Enable it only when the relay cannot be reached directly and the proxy sanitizes that header. The supplied Compose setup meets that condition. Native Godot clients need no browser-origin configuration. Browser clients are not part of this release; cross-origin browser connections are rejected unless their origins are explicitly allowed with space-separated `ALLOWED_ORIGINS`.

## Local development and checks

Use Go 1.24 or newer and the project's pinned Godot toolchain. From the repository root:

```sh
./scripts/test_multiplayer.sh
./scripts/build_server.sh
```

The scripts use `.tools/go/bin/go` when present, otherwise Go on `PATH`; `GO_BIN` and `GODOT` can override them. The integration script starts an isolated relay on an ephemeral localhost port and exercises three Godot clients without touching the player's garden. Socket tests need an environment that permits binding local ports.

For manual play:

```sh
cd server
go run .
```

Set the client address to `ws://127.0.0.1:8080/ws`. Unencrypted connections are accepted by the client only for loopback development; public connections require `wss://` with a valid certificate.

The owner supplied `purrimeter.graham.pub` as the public hostname. That default is recorded in `game/network/server.cfg` and included in the desktop exports. Changing the bundled default requires rebuilding with `./scripts/build.sh`; players can override it without rebuilding. The public server is deployed; see the [VPS operations notes](../docs/deployment.md).

## Protocol and operational limits

- One version-1 JSON WebSocket connection per installation. The server issues an authenticated installation token stored outside garden exports. Losing the signing key requires players to use **Reset identity for this server**. An identity is not a registered account, and reinstalling/resetting can bypass a per-game kick.
- Client sends `hello`, then `list`, `create`, `join`, `resume`, `leave`, `kick`, `chat`, `state`, and `ping` as needed. The server assigns sender identity and enforces room permissions. Version mismatches and failed admission have actionable errors.
- Up to three reserved/connected places per game. A dropped connection reserves its place and ownership for 60 seconds. Intentional departure frees it; an offline departure can only notify the server after connectivity returns, so its old reservation may remain until expiry.
- Rooms with free places are listed; full rooms are hidden. Maximum 200 rooms and 600 connections. Per-IP admission allows 30 concurrent connections and a burst of 20 attempts, replenishing at one per second. Unused IP-limit entries expire after five minutes and the table is capped at 4,096 entries.
- Names: 24 characters per player, 40 per game. Passwords: at most 64 characters. Chat: 400 characters, a burst of five messages then one per second. Control characters are rejected. Clients retain at most 200 messages in memory for the current visit; new arrivals receive no chat history.
- A connection sends at most 30 messages per second with a burst of 60. Create/join attempts permit a burst of five, replenishing at one every two seconds. Visible fields are sent around 10 times per second and capped by the relay at 12 per second with a burst of 20.
- Messages are limited to 512 KiB. Visible state validates counters, artwork indices, positions, health, arrays, and numeric bounds. Clients validate it again before creating a separate read-only view. No remote update can replace the local saved garden.
- Outgoing control queues are bounded to 64 messages. Pending field updates are coalesced per sender; writes time out after five seconds. Clients with no received messages for 25 seconds reconnect, and the server drops silent connections after 35 seconds. Clients send a heartbeat every ten seconds.
- TLS protects admission and gameplay traffic in transit. Password verifiers stay only in memory. The relay does not validate whether personal progress was earned legitimately.

The service intentionally runs as one process. Multiple replicas would require shared room membership and routing; do not place independent replicas behind round-robin balancing. The Compose memory/CPU limits are protective defaults, not a measured capacity claim. Load-test against your VPS and bandwidth budget before raising limits or inviting a large audience.

## Game release admission

Production startup requires `GAME_RELEASE_FILE` pointing to an official signed game-release manifest. Download one from `https://purrimeter.graham.pub/game-release.json`; to pin a retained release, use `/game-releases/<release-id>/release.json`. The public verification key is compiled into the server; its release-signing private key is not needed for hosting. Docker Compose mounts `./releases:/releases:ro` and expects `releases/current.json`.

The relay serves this metadata at `/updates` and reloads it each second without restarting. Replace the manifest atomically; invalid replacements retain the last valid designation. Proxy `/updates` alongside `/ws` and `/healthz` when using a separate reverse proxy. Clients use the selected `/ws` endpoint's sibling `/updates` URL.

The `hello` message now includes a game `release` identity, separate from wire protocol `version: 1`. Current-release checks also run on create/join. Existing visits may continue and reconnect within their original 60-second reservation using the same release. New production connections without a published release are rejected. A local/test service may explicitly set `ALLOW_DEVELOPMENT_BUILDS=true` to accept the `development` identity; never enable that on the public service.
