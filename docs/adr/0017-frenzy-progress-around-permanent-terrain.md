---
status: accepted
---

# Measure frenzy progress around permanent terrain

Indestructible rocks and streams can require enemies to move physically farther from the exit, making the straight-line progress rule in [the original frenzy decision](0005-frenzy-breaks-rerouting-loops.md) capable of trapping them even when a route exists. Frenzied enemies will instead reduce their shortest remaining terrain-only route distance on every step, ignoring towers when measuring that progress while retaining tower destruction and attack commitment. A fixed measure determined by the garden's permanent terrain allows detours without letting construction and sales recreate rerouting loops; it avoids restricting every generated layout to straight-line-monotonic escape paths.

This replaces the straight-line progress constraint only. Implemented as part of [garden obstacles](../obstacles.md).
