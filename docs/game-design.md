# Mini Tower Defence design

Status: historical version-one design. Superseded by [progression-rework.md](progression-rework.md) for the active Godot version.

## Confirmed foundations

- Standalone, windowed macOS app with crisp geometric graphics, distinct enemy silhouettes, and visible tower ranges.
- Square 16×16 grid. Each tower occupies one cell. Enemies move in four directions without diagonals.
- Enemies follow the shortest open route to the exit, even when breaking a tower would be faster.
- Only when no open route exists do enemies choose a route minimizing estimated travel time plus tower destruction time.
- Towers can be purchased, upgraded, and sold during combat. Tactical pause permits building.
- Waves start manually through a Next wave action.
- A game has 20 waves and starts with 20 lives. Every enemy reaching the exit removes one life. Reaching zero lives loses; surviving the final wave wins.
- Each wave specifies enemy types, quantities, and spawn order.
- Killing enemies awards coins.

## Confirmed board and combat

- Empty board with entrance midway down the left edge and exit opposite on the right. Both cells are unbuildable, as are cells occupied by enemies.
- Bolt towers fire fast single-target shots; Cannon towers fire slow splash attacks; Frost towers deal low damage and slow enemies.
- Towers automatically target the enemy closest to escaping.
- Grunts are baseline enemies; Runners are fast and fragile; Brutes are slow with high health; Breakers deal extra damage to towers. All use ground routes and can attack towers when blocked.
- Multiple enemies can attack a blocking tower together from beside it. Towers continue firing while under attack.
- Tower damage persists. Destroyed towers disappear without a refund.
- Enemies reconsider routes when towers are placed or removed. Breach estimates use the individual enemy's damage, without predicting assistance from other enemies.
- Towers have three levels, with upgrades improving their role and durability. Repair is a separate paid action restoring health.
- Selling returns 70% of purchase and upgrade spending, scaled by remaining health. Repair spending does not contribute to resale value.

## Confirmed economy and waves

- Starting coins: 200. Initial tower prices: Bolt 50, Cannon 80, Frost 70.
- Kill rewards vary by enemy type. There is no passive income.
- Twenty fixed, handcrafted waves, with a preview of the next wave's enemy order.
- Rewards should allow early waves to fund additional towers or upgrades; exact balance remains subject to playtesting.

## Final scope accepted

The complete design was confirmed for implementation, including the following:
- Enemies overlap and move smoothly between cell centers. Both cells of a crossing are reserved against construction. Routes change at cell centers.
- Shots cross towers; splash affects enemies only. Frost refreshes duration without stacking strength. Upgrading preserves health percentage.
- Target priority uses estimated remaining route time, including necessary breaches.
- Click-to-build and click-to-inspect controls, placement feedback, ranges, health, prices, optional route overlay, Space pause, Escape cancel, 1×/2× speed.
- Autosave and restore paused, pause on losing focus, New Game confirmation, Next Wave only after clearing the current wave.
- Numerical balance, wave compositions, and rounding delegated to implementation and testing.
- Deliver a native Swift macOS .app, source, and build instructions.
- Art direction supersedes initial geometric visuals: animated SNES-style pixel art for every tower and enemy. Cat-themed towers (Tabby/Bolt, British Shorthair/Cannon, Siamese/Frost), original music and sound effects.
