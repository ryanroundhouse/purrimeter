# Multiplayer design

Status: design interview in progress. Only the requirements below are confirmed; implementation decisions remain open.

## Confirmed requirements

- Launch into a main menu offering Single player and Multiplayer.
- Single player retains the existing gameplay.
- Add an Escape menu with Export and Import, moving those actions from their current location. Returning to the main menu requires confirmation.
- Multiplayer opens a list of open games and provides a Create game action.
- Creating a game requires a game name and allows an optional password.
- Each listed game shows its name, a lock icon when password-protected, and a Join game action. Joining a protected game requires the correct password.
- A connected multiplayer game shows two playing fields: the local player's on the left and the other player's on the right, including deployed towers and moving enemies.
- Each player progresses through levels and rebirths independently.
- Provide chat between the two players.
- The owner can host the server components on their VPS.

## Decision tree

The first interview round establishes these independent branches:

- Relationship between players: observation and chat, or gameplay interaction.
- Progress ownership: existing gardens across modes, separate multiplayer progress, or per-game progress.
- Audience and access: the existing family audience, invited friends, or public discovery.
- Game lifetime: play while alone, departures, and availability for another player.
- Pause behavior: Escape, focus loss, and independence between playing fields.
- Escape behavior: how the new menu interacts with existing placement cancellation and inspection dismissal.

Answers will determine follow-up questions about persistence, identity, reconnection, room access, synchronization, layout, chat, and deployment. Unanswered recommendations are not decisions.
