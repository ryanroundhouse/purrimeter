# Garden obstacles

Status: confirmed and implemented in the shared Godot game.

## Agreed rules

- Rocks and streams block tower placement and movement by all enemies, including frenzied enemies.
- Obstacles cannot be attacked or destroyed.
- Cats can attack across rocks and streams; existing range and targeting rules remain.
- Each New Garden receives a randomly generated obstacle layout. Terrain alone must leave a route from entrance to exit.
- The layout belongs to the garden and stays fixed through levels, defeat, rebirth, saving and reopening.
- Existing gardens retain their obstacle-free layout. Obstacles are generated only for a New Garden.
- Rocks occupy small clusters of one to four tiles. Each new layout has one winding, one-tile-wide stream with both ends inside the playing field. Enemies walk around the stream; there are no bridges in this version.
- Obstacles follow the same corner-clearance rules as towers, including mixed obstacle–tower corners. Enemies cannot squeeze diagonally between them.
- Every non-obstacle tile must connect to the exit when towers are ignored. Generated layouts cannot leave isolated patches of ground.
- Aim for 15–20% of the 256 tiles occupied by rocks and water together. The entrance, exit, and their immediate approaches remain free of terrain.
- Frenzied enemies may move physically farther from the exit to detour around terrain. Every step must reduce the remaining shortest terrain-only route distance, ignoring towers. They continue destroying obstructing towers and retain attack commitment. See [the routing decision](adr/0017-frenzy-progress-around-permanent-terrain.md).
- Terrain matches the existing pixel-art garden: mossy gray rocks and blue streams with grassy banks, clear occupied-tile boundaries, and subtle flowing water highlights.
- Provide visual variety among rock formations and between gardens. Each connected formation uses one consistent style; the single connected stream varies in style between gardens.
- Same-kind neighbors touching at either an edge or a corner share a style. Edge neighbors join seamlessly; diagonal neighbors meet at their corner without filling adjacent empty tiles. Rock cluster size refers to the resulting connected formation, so touching clusters cannot silently form an oversized rock formation.
- Rock–stream boundaries use a rocky shoreline in place of the grassy bank. Both materials remain distinct, with compatible colors and connected edges.
- Invalid recruitment uses the existing invalid-placement highlight and a terrain-specific reason: “Rocks block recruitment” or “Streams block recruitment.” The selected cat stays ready to place elsewhere.
- Outside recruitment, selecting an obstacle shows a short explanation without an inspector or action buttons.

## Implementation scope

`GardenTerrain` owns generated and saved cells, styles, connectivity checks, and cached terrain-only distances. Placement, open and breach routes, frenzy, save validation, and remote garden views use that same permanent layer. Version-5 saves require explicit terrain; versions 2–4 restore empty terrain. New gardens use `Session.fresh()`; plain sessions remain empty until explicitly generated or restored.

Actual terrain cells and visual styles persist, so future generation changes cannot alter existing gardens. Remote garden views, compact previews, and the mobile overview display terrain. Pointer, keyboard, and touch recruitment use the same placement errors.

A frenzied enemy whose shortest terrain-only step is diagonal can breach a side cat that blocks clearance while continuing to reduce terrain-only distance, without cutting corners. This case has explicit regression coverage.

`game/tests/terrain.gd` checks 150 seeded layouts, connectivity and coverage, rock formation sizes, narrow unbranched streams, placement, breach routes, frenzy detours, lifecycle retention, legacy saves, invalid-data rejection, and terrain/style save and remote-view round trips. `game/tests/terrain_ui.gd` checks recruitment feedback, selection, water-only animation, joined edges, diagonal contacts, shorelines, and New Garden generation. Server and multiplayer suites cover terrain bounds and relay preservation.

Native desktop and Android-layout captures are in `build/terrain-review/`. These are local renderer checks, not physical Android or iOS device tests. See [artwork provenance](terrain-artwork.md) for the generated source material and connection renderer.
