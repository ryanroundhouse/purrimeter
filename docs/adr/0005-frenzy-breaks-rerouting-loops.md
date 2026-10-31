---
status: accepted
---

# Frenzy breaks repeated rerouting loops

Alternating maze openings can redirect an enemy indefinitely while an open route always exists, so an enemy that accumulates sufficient repeated travel will permanently enter frenzy and advance only toward the exit, destroying committed obstructions even when an open route exists. This deliberately limits [open-route priority](0001-open-routes-before-breaching.md) to enemies outside frenzy: repeated travel preserves legitimate long mazes better than a lifetime timer, while directional progress and attack commitment prevent changing openings or destruction estimates from recreating the exploit. Frenzy retains ordinary combat strength and vulnerabilities, preventing routing loops without imposing an escape deadline against repairs or crowd control; see the [design rules](../frenzy.md).
