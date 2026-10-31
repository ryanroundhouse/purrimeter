# Character atlas

Generated with the built-in image generation tool; transparent PNG preserved without raster editing. The generated sheet has uneven gutters; explicit source rectangles in the renderer isolate all 28 poses, using nearest-neighbor interpolation without altering the PNG.

Rows: Tabby Scout (Bolt), Chunky Gunner (Cannon), Siamese Sage (Frost), purple rat (Grunt), green rat (Runner), armored boar (Brute), raccoon bandit (Breaker). Columns are four animation poses; the third is used for attacks and all four for walking.

## Generation prompt

Use case: stylized-concept. Asset type: production sprite atlas for a native macOS tower defence game called Purrimeter.
Create ONE transparent PNG sprite sheet with EXACTLY 4 columns and 7 rows of equally sized square cells (canvas aspect 4:7). NO text, NO borders, NO background. Every sprite centered within its cell, same baseline, fits within middle 80% of cell. Crisp authentic SNES 16-bit pixel art, visible square pixels, limited rich palette, dark outlines, no blur. Three-quarter top-down game view, characters face right. Each row is four successive looping animation frames of the SAME character: idle/step A, rising/step B, attack/step C, settling/step D. Consistent proportions between frames.
Row 1: orange tabby cat archer, green scarf, tiny crossbow (Bolt tower), ears and tail animate, firing pose in frame 3.
Row 2: chunky gray British shorthair cat with red bandana beside brass round cannon (Cannon tower), recoil in frame 3.
Row 3: cream Siamese wizard cat with dark ears and paws, blue scarf, icy crystal staff (Frost tower), magical gesture frame 3.
Row 4: small purple rat with pink nose (Grunt), 4 frame walk cycle.
Row 5: skinny green rat with yellow scarf (Runner), 4 frame running cycle.
Row 6: large stocky brown armored boar (Brute), 4 frame lumbering walk.
Row 7: red raccoon bandit with hammer (Breaker), 4 frame walk/hammer swing cycle.
Strict 4 by 7 evenly spaced grid; no extra sprites, no labels, transparent gutters. All 28 sprites separate, no overlapping cells.
