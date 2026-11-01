# Game updates and multiplayer version requirements

The user confirmed this design and authorized implementation and deployment. Implementation and operational instructions are described in [game-update-operations.md](game-update-operations.md).

## Confirmed requirements

- Check the game version with the server when the game launches.
- When the server hosts a newer game version, offer the player the option to download and play it.
- Multiplayer admission requires the current game release designated by the selected multiplayer server. The public server designates the latest officially published release; self-hosted servers control their own upgrade timing.
- Accepting an update downloads it inside the game, then offers “Restart and play” to install and relaunch while preserving the saved garden.
- Single player remains available when the player declines an update or the version check fails. Multiplayer requires server confirmation that the installed release is current, with a Retry option when verification fails.
- Publishing a new release does not end existing multiplayer sessions. Notify connected players about the update and require the current release for subsequent joins.
- Check for updates in the background without delaying the launch menu or single player. Multiplayer waits for verification. Provide a manual “Check for updates” action.
- Publish macOS and Windows builds together under one game release identity. A release becomes current only after both packages are ready. Website-only updates do not change that identity.
- A reconnect within the existing 60-second membership reservation continues the original session and may use its older release. Creating or joining another game requires the current release, including from an already-open game browser.
- Custom multiplayer servers may designate only official Purrimeter releases for this updater. Verify update packages against an official signing key; custom executable distribution is outside the initial scope.
- Do not offer built-in downgrades initially. If the installed release is newer than the selected server's current release, explain the mismatch, prevent new multiplayer admission, and retain single player.
- Unpublished development builds cannot join the public multiplayer service. Permit them only through an explicit development setting on a local/test server.
- Download and installation failures must preserve a usable existing installation, saves, and settings, with Retry available. If automatic replacement is impossible, offer the verified download and manual installation instructions. Starting a download does not quit the game.
- Use a dedicated official release-signing key kept outside the repository on the publishing machine. Require signed release metadata for public game releases. Retain the existing platform distribution approach; Apple notarization and Windows publisher certification are outside this change.
- Keep the previous application and a pre-update backup of saves and settings until the replacement passes its first startup check. If that startup fails, recover the previous installation and original data. After gameplay begins successfully, do not automatically roll back later progress.
- “Restart and play” saves the garden, leaves multiplayer if connected, applies the update, and returns to the main menu. The saved garden remains paused; the player chooses whether to resume single player or rejoin multiplayer.
- Routine client publication changes the required release without restarting the relay or ending active sessions. A necessary relay upgrade may disconnect players as a maintenance exception; preserve their gardens and explain that they need to reconnect.
- Existing clients without the updater require one manual download of the first updater-enabled release. Subsequent releases use the update mechanism.

## Verification scenarios

- Launch the current release: the menu and single player are immediately usable, and multiplayer becomes available after server verification.
- Launch an older release: offer the update, allow the player to decline and play single player, and enforce the current release on the server for new multiplayer admission.
- Fail the startup version check: preserve single player, explain why multiplayer is unavailable, and allow retrying the check.
- Publish a release during a multiplayer game: notify players and preserve their sessions, including reconnects within existing 60-second reservations. Reject outdated clients creating or joining another game, including clients already connected to the browser.
- Prepare only one platform, or change only website content: neither operation advances the current game release.
- Select a server requiring an older release: explain the mismatch without offering a downgrade, preserve single player, and prevent new multiplayer admission.
- Receive untrusted metadata or an invalid package: refuse installation and preserve the existing application and player data.
- Interrupt a download or encounter an installation failure: retain a usable installation and offer Retry; an unwritable installation also offers a verified package and manual instructions.
- Apply an update from single player or multiplayer: preserve the garden and settings, restart to the main menu, and retain the paused garden.
- Fail the replacement's first startup: recover the previous application and pre-update player data. A later failure after successful gameplay does not trigger automatic restoration of older progress.
- Attempt public admission with an unpublished development build: reject it; permit development builds only on explicitly configured local/test servers.
- Upgrade the relay when maintenance requires a restart: preserve local gardens and provide reconnect messaging; distinguish this interruption from routine client publication.

## Related decisions

- [Server-designated release admission](adr/0009-server-designated-release-admission.md)
- [Official update verification](adr/0010-verify-official-game-updates.md)
- [Project glossary](../CONTEXT.md)

## Existing context

The project distributes native macOS and Windows ZIP archives. Website/download publication and multiplayer relay deployment are independent operations. The website publication manifest describes the publication snapshot; its checkout metadata does not establish which source produced an existing client archive. See [website.md](website.md) and [deployment.md](deployment.md).
