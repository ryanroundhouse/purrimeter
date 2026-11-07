# Artwork and audio

All new raster art was generated with the built-in imagegen tool. Final runtime assets live in `game/assets/`: `tuxedo.png`, `chunky.png`, `siamese.png`, `bosses.png`, and `icon.png`. Each cat sheet contains six tiers with four animation poses; the boss sheet contains four bosses with four poses. Original PNG alpha is retained. Measured source rectangles in `sprite_bounds.gd` correct uneven generated spacing without modifying the artwork.

## Terrain

Connected rock and stream materials use built-in imagegen artwork with runtime edge/corner joining and subtle water highlights. See [terrain artwork and exact prompt](terrain-artwork.md).

## Current cat identities

The basic Bolt unit is **Tuxedo Scout**, a black-and-white tuxedo cat. The Cannon unit is an orange tabby and retains the name **Chunky Gunner**. The six upgrade tiers, four poses, equipment, combat roles and numeric save identities are preserved. The Scout uses `game/assets/tuxedo.png`; the Gunner uses `game/assets/chunky.png`. Both were edited with the built-in imagegen tool, preserving generated alpha. Source rectangles are remeasured for the edited artwork.

### Tuxedo Scout edit prompt

Use case: precise-object-edit. Edit target: the provided Purrimeter Scout sprite atlas. Change ONLY the cat's coat from orange tabby to a black-and-white TUXEDO CAT in ALL 24 sprites, every upgrade tier and animation pose. Black head, ears, back and tail; a distinct white muzzle and small white facial blaze, white chest bib, white paws wherever exposed. Preserve green eyes, pink inner ears, green scarf/capes, crossbows, armor, crowns, ALL six equipment tiers, every pose, the crisp outlined pixel-art style and facing direction. Keep the source 1024x1536 canvas and EXACT 4 columns x 6 rows, with original sprite positions, sizes and silhouettes as closely as possible. Each row is one upgrade tier; each column is an animation frame. No missing sprites. Output a production-ready sprite sheet with a GENUINELY TRANSPARENT alpha background, including all gaps between body/equipment. Remove all colored backdrop or glow behind the characters; no floor, shadow, text, labels, grid lines, added props or detached effects. White markings must remain opaque white; black fur must remain visible through charcoal highlights, not transparent.

### Chunky Gunner edit prompt

Use case: precise-object-edit. Edit target: the provided Purrimeter Chunky Gunner sprite atlas. Change ONLY the cat's coat from gray British shorthair to an ORANGE TABBY CAT in ALL 24 sprites, every upgrade tier and animation pose. Warm orange fur with clearly visible darker orange/brown tabby stripes on forehead, cheeks, body and tail, light cream muzzle. Keep the chunky body shape and grumpy expression. Preserve yellow eyes, red scarf/capes, ALL cannons and wheels, goggles, armor and crowns, ALL six equipment tiers, every pose, the crisp outlined pixel-art style and facing direction. Keep the source 1024x1536 canvas and EXACT 4 columns x 6 rows, with original sprite positions, sizes and silhouettes as closely as possible. Each row is one upgrade tier; each column is an animation frame. No missing sprites. Output a production-ready sprite sheet with a GENUINELY TRANSPARENT alpha background, including all gaps between body/equipment. Remove all colored backdrop or glow behind characters; no floor, shadow, text, labels, grid lines, added props or detached effects. Do not recolor the cannon, equipment or clothing.

### Siamese Sage black-cat edit

The Frost unit retains the name **Siamese Sage** and now has solid black fur across all six tiers and four poses. Its blue eyes, outfits and icy staffs are preserved. The replacement uses the existing `game/assets/siamese.png` path and numeric save identity. It was edited with the built-in imagegen tool, preserving generated alpha; source rectangles were remeasured for all 24 sprites.

Use case: precise-object-edit. Edit target: the provided Purrimeter Siamese Sage sprite atlas. Change ONLY the cat's coat to an ALL-BLACK CAT in ALL 24 sprites, every upgrade tier and animation pose. Solid jet-black fur on the entire head, muzzle, ears, torso, legs, paws and tail; subtle dark charcoal highlights for readable volume, no cream, white, brown, Siamese points or tabby markings anywhere on fur. Preserve bright blue eyes and pink inner ears. Preserve blue scarf, hats, blue-white robes, white garment trim, capes, armor, gold fittings, crowns and ALL icy crystal staffs, all six equipment tiers and all four distinct poses per row. Clothing's white areas stay white. Preserve the crisp outlined pixel-art style, facing direction, scale and silhouettes as closely as possible. Keep the source 1024x1536 canvas and EXACT 4 columns x 6 rows with original sprite positions. Each row is one upgrade tier; each column an animation frame. Keep sprites separated with transparent gaps; no missing sprites or clipped equipment. Output a production-ready PNG sprite sheet with a GENUINELY TRANSPARENT alpha background including all gaps between body/equipment. Remove all colored backdrop/glow behind characters; no floor, shadow, text, labels, grid lines, added props or detached effects. Black fur must remain opaque and readable, not transparent.

The original generation prompts below are retained as provenance; the three edit prompts above supersede their cat coat descriptions.


The original Grunt, Runner, Brute and Breaker animation frames remain in `characters.png`. Attack effects are rendered in the game, varying shape, color, size and complexity by cat type and tier. Six visual tiers remain distinct from unlimited Patrol Training.

## Achievement skins

The [cat skins design](cat-skins.md) adds four achievement-unlocked appearances per cat alongside the existing default. Twelve built-in imagegen sheets in `game/assets/skins/` cover all six tiers and four poses, changing fur patterns and coordinated equipment colors. Exact initial generation prompts are recorded in [cat-skin-prompts.json](cat-skin-prompts.json), and final spacing refinements for the four Sage sheets are recorded in [cat-skin-refinement-prompts.json](cat-skin-refinement-prompts.json). The final generated PNGs retain their alpha unchanged; measured source rectangles and cached polygon outlines isolate neighboring sprite parts at runtime without modifying the images. Locked skins appear as solid silhouettes in the local collection until earned, while other players' equipped skins remain visible in multiplayer.

## tabby

Use case: stylized-concept. Production transparent PNG sprite atlas for a SNES-style 2D tower defence game, Purrimeter. Crisp pixel art, dark outlines, limited rich colors, square pixels, three-quarter top-down view facing right. No words, labels, borders, background, ground shadows, or detached particles. EXACT 4 columns by 6 rows on a 1024x1536 canvas; every cell 256x256. Each sprite must fit wholly within the CENTRAL 180x180 of its cell, with 38px transparent margins on every side. Same anchor and scale within each row. Do not cross cell borders. Each ROW is one upgrade tier, each COLUMN a distinct animation pose: 1 idle, 2 anticipation, 3 attack/recoil, 4 recovery. Keep body size consistent, equipment increasingly ornate. Transparent background genuinely alpha. Orange tabby cat with green scarf and ranged crossbow. Rows tiers: 1 simple leather scout and wooden crossbow; 2 green leather hood and reinforced bow; 3 bronze helmet, steel crossbow; 4 silver knight armor and blue-energy crossbow; 5 royal gold armor, small green cape, luminous gold crossbow; 6 mythic white-gold armor, emerald crown, magnificent emerald-energy bow. Clearly six different escalating forms, cat ears and face readable, all equipment within sprite cell.

## chunky

Use case: stylized-concept. Production transparent PNG sprite atlas for a SNES-style 2D tower defence game, Purrimeter. Crisp pixel art, dark outlines, limited rich colors, square pixels, three-quarter top-down view facing right. No words, labels, borders, background, ground shadows, or detached particles. EXACT 4 columns by 6 rows on a 1024x1536 canvas; every cell 256x256. Each sprite must fit wholly within the CENTRAL 180x180 of its cell, with 38px transparent margins on every side. Same anchor and scale within each row. Do not cross cell borders. Each ROW is one upgrade tier, each COLUMN a distinct animation pose: 1 idle, 2 anticipation, 3 attack/recoil, 4 recovery. Keep body size consistent, equipment increasingly ornate. Transparent background genuinely alpha. Chunky gray British shorthair cat with red bandana, operating a small cannon. Rows tiers: 1 plain brass stubby cannon; 2 copper reinforced cannon and leather goggles; 3 iron armor and steel cannon; 4 crimson armor and large black-gold artillery cannon; 5 royal scarlet cape, gold helmet and ornate gold cannon; 6 mythic dark-red plate armor and obsidian cannon with glowing molten orange bore. Each cat and cannon wholly in cell. Six distinctly different escalating forms. No cannonballs outside character bounds.

## siamese

Use case: stylized-concept. Production transparent PNG sprite atlas for a SNES-style 2D tower defence game, Purrimeter. Crisp pixel art, dark outlines, limited rich colors, square pixels, three-quarter top-down view facing right. No words, labels, borders, background, ground shadows, or detached particles. EXACT 4 columns by 6 rows on a 1024x1536 canvas; every cell 256x256. Each sprite must fit wholly within the CENTRAL 180x180 of its cell, with 38px transparent margins on every side. Same anchor and scale within each row. Do not cross cell borders. Each ROW is one upgrade tier, each COLUMN a distinct animation pose: 1 idle, 2 anticipation, 3 attack/recoil, 4 recovery. Keep body size consistent, equipment increasingly ornate. Transparent background genuinely alpha. Cream Siamese cat, dark face ears paws, blue scarf and icy staff. Rows tiers: 1 simple blue scarf and small crystal wand; 2 blue apprentice hat and sapphire staff; 3 blue-white robes and three-prong ice staff; 4 silver armor, blue cape, huge icy crystal staff; 5 royal white-sapphire robes, crystal crown and ornate staff; 6 mythic luminous blue-white wizard armor with antler-like ice crown and magnificent cyan crystal staff. All six clearly different, no ice effects outside central cell margin. Keep face readable.

## bosses

Use case: stylized-concept. Production transparent PNG boss sprite sheet for SNES 16-bit pixel art game Purrimeter. EXACT 4 columns x 4 rows, square 1024x1024 canvas. Cells exactly 256px. Every sprite wholly inside central 184x184 square of cell with at least 36px fully transparent gutters. No text, no labels, no grid lines, no backgrounds, no shadows or detached particles. Detailed crisp square pixels, thick dark outlines, vivid moody palette, view from three-quarter overhead facing right. Each row four animation frames of same boss, consistent size and center: neutral, anticipation, attack, recovery.
ROW1 gigantic poisonous armored caterpillar, emerald segmented body, violet spines, glowing amber eyes, sharp mandibles, forebody rears for attack.
ROW2 terrifying purple-black cobra, turquoise markings, orange eyes, massive flared hood, curled snake body and long fangs, striking pose.
ROW3 huge crimson and charcoal spider, eight articulated legs, red glowing eyes and jagged mandibles, lunging pose.
ROW4 monstrous dark blue-gray bulldog, massive jaws, spiked iron collar, scar over one eye, red eyes, snarling and lunging frames.
Scary fantasy garden bosses, no gore. Each row clearly distinct. All poses fit within cell bounds with generous transparent gutters.

## icon

Use case: stylized-concept. Create a square desktop game app icon for Purrimeter, a SNES-style cat tower defence game. A bold orange tabby cat face with emerald eyes, little green ranger scarf and a small gold shield, centered on a dark midnight teal rounded-square tile with a fine gold border. Authentic crisp 16-bit pixel art, strong readable silhouette at 32px, limited palette, no text or lettering, no gradient, no extra elements. 1024x1024 PNG.

## Transparency refinement

The three cat sheets were refined with: “Remove ALL of the colored brown/blue/gray background behind these 24 pixel-art cat sprites. Output a genuinely TRANSPARENT alpha PNG, no solid or gradient background anywhere. Preserve all 24 characters, their colors, pixels, outfits, weapons, 4-column 6-row layout, canvas dimensions, and exact sprite positions unchanged. Remove only background, including gaps between limbs and equipment. Do NOT redraw characters. Do NOT add shadows. Every non-character pixel must be fully transparent.” Alpha-channel inspection and native rendering confirmed transparency.

## Audio

The original 64-second chiptune loop and twelve synthesized effects are retained. New synthesized boss and rebirth cues are bundled. Shot sound pitch evolves with tower tier; effects are rate-limited and pooled to prevent excessive overlap. All audio is original synthesis, with no externally licensed samples.

Boss levels use five additional original chiptune scores: Midnight March, Bramble Chase, Moonlit Mischief, Thornwall Stomp, and Garden Guardians. Each is a 32-bar loop at 144–168 BPM with distinct melodies, harmony, bass, and percussion. Reproduce them with `python3 scripts/make_boss_music.py`; it writes `game/assets/boss_music_1.wav` through `boss_music_5.wav`, matching the garden track's RMS loudness. The runtime loops the scores and crossfades over half a second. See [Boss music](boss-music.md) for the confirmed playback design.

## Powerup icons

The 30 geometric line icons in `game/assets/powerups/*.svg` were authored for this game. They share a 32×32 viewbox and 1.8-unit rounded strokes; the sidebar tints them by powerup family. These vector symbols are independent of the existing pixel-art cat sprites.

Achievement fanfare uses an original geometric medal drawn in the game UI and an original 0.95-second chiptune generated by `scripts/make_achievement_audio.py`. The achievement menu reuses the established powerup SVG icons. No external samples or new generated raster artwork are used.
