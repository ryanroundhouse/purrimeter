# Diagonal enemy movement

Design confirmed through the movement interview and implemented in the shared Godot simulation.

## Confirmed rules

- Enemies can move horizontally, vertically, and diagonally.
- Towers block their entire occupied square. A diagonal step requires an empty destination and both adjacent side squares to be clear of towers, so enemies cannot cut across even a single tower's corner. Towers that meet at a corner form a wall.
- Enemies maintain the same physical speed in every direction. A diagonal step covers √2 times the distance and takes √2 times as long as an orthogonal step.
- These movement and clearance rules apply to every enemy type, including bosses. Large boss artwork does not change the logical movement footprint.
- Preserve open-route priority outside frenzy: enemies take the shortest open route whenever one exists, measuring length by physical distance. Outside frenzy, only fully blocked enemies consider breaching, based on estimated travel plus tower destruction time as recorded in `docs/adr/0001-open-routes-before-breaching.md`. [Frenzy](frenzy.md) is the explicit exception; it preserves these diagonal clearance rules and also reserves clearance during committed attacks.
- A wall of corner-touching towers can be breached by destroying a blocking tower. Enemies cannot cross an occupied square or a blocked corner before the obstruction is destroyed.
- During a diagonal crossing, both required side squares reject tower placement until the enemy reaches its destination. Departure and destination squares remain reserved as before.
- When no open route exists, an enemy may attack a diagonally adjacent destination tower if both side squares are clear. Damage is unchanged. The enemy stays in its current square until the tower is destroyed before entering the destination.

## Integration

- Route length, movement duration, and remaining-time targeting account for the longer diagonal distance.
- Breach estimates use current tower occupancy for corner clearance and recalculate after a tower is destroyed. They do not assume a side tower has disappeared before it is actually destroyed.
- Route previews use the same rules as enemy movement.
- Saves retain diagonal progress and resume paused. Import rejects a crossing with a tower in either required side square before changing the live game. Existing cardinal crossings remain valid.
- `PRODUCT.md` reflects these rules. `docs/game-design.md` remains historical documentation.
