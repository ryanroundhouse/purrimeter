# Multiplayer design

Status: implemented following three interview rounds and delegated technical/interface decisions, and deployed at `wss://purrimeter.graham.pub/ws`. Local regression, relay, and public three-client integration verification are recorded in `docs/verification.md`. See `docs/deployment.md` for VPS operations.

## Confirmed requirements

- Launch into a main menu offering Single player and Multiplayer.
- Single player retains the existing gameplay.
- Add an Escape menu with Export and Import, moving those actions from their current location. Returning to the main menu requires confirmation.
- Multiplayer opens a list of open games and provides a Create game action.
- Creating a game requires a game name and allows an optional password.
- Each listed game shows its name, a lock icon when password-protected, and a Join game action. Joining a protected game requires the correct password.
- A multiplayer game supports up to three players. The local player's field is on the left. Other players share the field area on the right: one remote field uses that area, while two remote fields are smaller and share it. Fields show deployed towers and moving enemies.
- Each player progresses through levels and rebirths independently.
- Provide chat between the players in the game.
- The owner can host the server components on their VPS.

## Confirmed interview decisions

- **Relationship:** independent gameplay with live observation and chat. Players control only their own field; there are no gifts, shared rewards, attacks against other players, or combat assistance.
- **Progress ownership:** use the same personal garden across single player and multiplayer. Joining does not reset or fork progress, and progress earned in either mode carries into the other.
- **Audience:** a public service. Players can discover and join available games, with passwords restricting individual games where configured.
- **Game lifetime:** the creator can play immediately while waiting. Any remaining player can continue when someone leaves, including when the creator leaves, and another player can join. Remove a game when everyone intentionally leaves. If everyone disconnects temporarily, keep it until its last reservation expires.
- **Pause and speed:** each player independently controls pause and 1×/2× speed. Opening the Escape menu pauses only that player's combat; remote fields and chat continue updating. Losing application focus preserves running combat and Auto countdowns while silencing music and gameplay effects.
- **Escape priority:** cancel placement or close inspection before opening the Escape menu on a subsequent press. Add a visible Menu button that opens it directly.
- **Identity:** a remembered display name and automatically generated identity on each installation, without registration. Identity is separate from exported gardens and is not replaced by Import or New Garden. Names need not be unique; disambiguate duplicates within a game with short visible suffixes. Display names can be changed from the main menu before joining. Permit only one active multiplayer connection per installation identity.
- **Trust and simulation:** accept personal gardens including edited saves. Each computer runs its own simulation; the server manages multiplayer games and chat and relays visible gameplay. Validate incoming messages without promising legitimate progression or anti-cheat enforcement.
- **Connection loss:** pause local combat when disconnection is detected, preserve progress locally, and attempt automatic reconnection. Reserve the player's place for 60 seconds and show their frozen remote field marked Reconnecting. Offer Continue offline in the Escape menu. An intentional departure frees the place immediately. A successful reconnect leaves combat paused until explicitly resumed. After reservation expiry, free the place and require joining again. Server restarts clear games and reservations, while locally saved progress remains available.
- **Moderation:** the game owner can kick players and prevent their identified installation from rejoining that game, including through reconnection. Hold ownership during a temporary disconnect reservation; transfer it to the longest-connected remaining player when the owner intentionally leaves or their reservation expires. Installation-based restrictions can be bypassed by reinstalling; they are basic moderation, not durable account bans.
- **Chat:** one shared chat for everyone in the game, without private messages. New arrivals see only messages sent after joining; history lasts only for the current visit. Players can mute one another's messages.
- **Garden replacement:** Export, Import, and New Garden are all allowed while connected to multiplayer. Confirm before replacing progress and validate imports before changing anything; a failed import leaves the current garden untouched. Replace the field for everyone watching and start the replacement paused. Preserve game membership, name, chat, identity, and ownership.
- **Remote fields:** stack two remote fields vertically in the right-side area, keeping the local field's size stable as players join or leave. Show name, level, rebirth count, and pause status. Support read-only cat/enemy/powerup inspection and an enlarged view of a selected remote field, with a return to the normal layout.
- **Audio:** the local garden produces music and gameplay effects in the normal layout. View switches exclusively to the selected garden's music and effects, controlled by the viewer's Sound preference and application focus; closing View restores local audio. Small previews remain silent. Chat notification sound is separately switchable. See `rebirth-and-pause-menu.md` for event and reconnection behavior.
- **Browser:** list only games with available places, displaying occupancy (for example 1/3 or 2/3), name, lock status, and Join. Reservations count toward capacity. Game name and password are fixed at creation for that game's lifetime.
- **Input and resuming:** typing in chat does not pause combat and suppresses gameplay shortcuts. Enter sends; Escape leaves the text box. Closing the Escape menu leaves combat paused, with an explicit Resume action. Opening or closing an enlarged remote field preserves the local garden's running or paused state.
- **Server discovery and delivery:** ship `wss://purrimeter.graham.pub/ws` as the default public-server address, with a settings override. The owner supplied this hostname during implementation and subsequently authorized deployment to their claw VPS and creation of its Cloudflare DNS record. Deliver a server package and VPS setup instructions.
- **Delegation:** the implementer selects server technology, deployment packaging, synchronization, layout, text limits, and connection/message rate limits, documents those choices, and tests them against the agreed behavior.

## Selected implementation approach

- **Server:** a single Go service using the standard HTTP server and `github.com/coder/websocket`. It owns membership, capacity reservations, owner permissions, password admission, installation authentication, chat routing, and bounded field-state relaying.
- **Transport:** secure WebSockets (`wss://`) with versioned JSON messages, connected through Godot's `WebSocketPeer`. Continue polling independently of local combat pause. Plain WebSockets are limited to explicit local development.
- **Hosting:** provide Docker Compose with the Go service and Caddy for TLS termination and certificate renewal, plus configuration for using an existing reverse proxy. Production setup needs a hostname and suitable VPS configuration. Persist TLS material and server signing secrets; game state, reservations, and per-game restrictions are in memory. No game database or cloud saves are required by this design.
- **Identity:** authenticate server-issued installation credentials, stored separately from the garden. Do not treat a client-provided display name or claimed player ID as proof of identity. Bind membership, kicks, and reconnects to authenticated identity.
- **Replication:** publish a dedicated visible-state representation, initially targeting 10 updates per second, and interpolate remote movement. Include pause/speed, inspectable progression and powerups, towers, enemies, and attack effects. Remote fields are read-only views and do not run independent combat simulations. Measure bandwidth and visual smoothness before fixing final update limits.
- **Replacement:** increase a garden revision on Import/New Garden; apply a complete replacement view and clear stale interpolation, selections, and effects. A failed import publishes no replacement.
- **Backpressure:** bound message sizes, queues, room/connection counts, chat, and join attempts. Coalesce unsent field states rather than building a backlog. Reject malformed fields, non-finite numbers, unknown protocol versions, and unauthorized control messages. The server sets sender identity and permits field publication only for that sender's current membership.
- **Presentation:** keep local controls with the local field; place remote fields in the right-side region and chat below them. One remote field fills the available field region; two stack vertically. Provide an empty waiting state while alone. Adapt multiplayer layout separately from the existing single-player layout, preserving remote-field square proportions.

The WebSocket/TCP trade-off is occasional delayed remote viewing under packet loss. Local combat and local saves remain independent of that delay. A Go relay adds another implementation language, but keeps engine simulation and assets out of the hosted service. See [the server technology ADR](adr/0008-go-websocket-relay.md).

## Verification required during implementation

- Preserve existing gameplay and save validation through the current regression suite.
- Exercise public discovery, correct/incorrect passwords, simultaneous joins for the final place, full-game hiding, duplicate identity rejection, kicking, and ownership transfer.
- Exercise reconnect within and beyond the grace period, all-player disconnection, Continue offline, and server restart without losing local progress or replaying chat to new arrivals.
- Verify three independent clients with different levels, speeds, pauses, rebirths, and live garden replacements; malformed imports must change nothing.
- Verify chat input does not trigger gameplay, menus do not stop networking, and remote interaction never mutates another player's garden.
- Visually inspect two/three-player layouts, remote interpolation, inspection, enlargement, and chat at supported window sizes. Check that only local combat drives audio.
- Test bounded behavior under oversized/malformed messages and slow connections; validate TLS deployment instructions with a local test setup where possible.

## Interview outcome

Round one settled independent gameplay, shared progression, public access, ordinary departures, pause/speed, and Escape priority, and expanded capacity to three. Round two settled identity, client simulation, reconnect grace, moderation, chat, remote viewing, and audio, with live Import/New Garden explicitly retained. Round three settled the remaining behavioral edge cases and delegated routine implementation choices. No behavioral question remains pending. The owner subsequently supplied purrimeter.graham.pub as the production hostname and authorized the completed VPS deployment.
