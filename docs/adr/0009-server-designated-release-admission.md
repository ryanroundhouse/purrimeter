# Let each multiplayer server designate its current game release

Players can select a self-hosted multiplayer server, so each server designates the current game release required for new multiplayer admissions rather than all servers following a global release switch. Existing multiplayer sessions may continue after that designation changes, and single player remains available when updates are declined or version verification fails. This gives self-hosted servers control over upgrade timing and avoids interrupting active play, at the cost of temporarily allowing existing players on older releases and requiring players to match the selected server before joining again.

A reconnect within the existing 60-second membership reservation continues the original session; creating or joining another game requires the current release. The initial updater supports only official signed Purrimeter releases and does not offer downgrades, so a server designation controls admission without granting that server authority to supply arbitrary game executables.

Routine client publication must change the designation without restarting the relay. Necessary relay maintenance remains an explicit exception that may end sessions while preserving each player's local garden and explaining the need to reconnect.
