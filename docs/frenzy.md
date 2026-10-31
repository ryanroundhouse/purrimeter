# Enemy frenzy

Status: confirmed and implemented in the shared Godot simulation.

## Agreed rules

- Detect repeated wasted travel caused by rerouting. A long, unchanged maze must not trigger frenzy merely because traversal takes a long time.
- Track the effect on each enemy separately. One affected enemy does not put the entire wave into frenzy.
- Frenzy allows an enemy to destroy towers obstructing its route toward the exit even when an open route exists. It does not divert to attack unrelated nearby towers.
- Frustration measures repeated travel over previously visited ground, accumulated without expiry. Each completed movement into a previously visited tile adds that step's physical length: 1 for an orthogonal step, √2 for a diagonal step. The starting tile counts as visited. First visits do not add frustration.
- Frenzy triggers at 12 tile-lengths of repeated travel, equally for all enemy types and bosses. This is an initial playtesting value. Several short reversals or one sufficiently long retrace can trigger it; the detector does not attempt to infer player intent.
- Route recalculations and edits to unrelated towers do not themselves add frustration. Time spent attacking, slowed, stunned, or paused does not itself add frustration. Distance actually retraced while slowed still counts normally.
- Frenzy lasts until death or escape. Saving and loading preserve both travel history and frenzy state.
- Every frenzied movement step must bring the enemy physically closer to the exit. Changing openings cannot lure it backward; normal enemies may still follow winding mazes.
- Once attacking an obstructing tower, a frenzied enemy remains committed until that tower is destroyed or sold, then advances through the opening. Newly attractive routes do not interrupt the attack.
- Frenzy preserves existing movement speed, attack damage, and susceptibility to slow and stun.
- Feedback is visual on the enemy: redness increases as frustration builds, then a strong red tint and animated sweat droplets persist during frenzy. Existing slow effects remain visible. This applies to ordinary enemies and bosses, including those whose artwork is already red.

## Existing behavior and design constraints

Previously, the simulation always preferred an open route and kept no travel history. Tower construction and sales invalidate routes; enemies finish a crossing before selecting their next step. Alternating openings could therefore repeatedly redirect the same enemy.

Frenzy is an intended exception to [open-route priority](adr/0001-open-routes-before-breaching.md), recorded in the [frenzy decision](adr/0005-frenzy-breaks-rerouting-loops.md). Simply allowing the current travel-plus-destruction route calculation during frenzy would still allow changing tower costs and openings to redirect enemies.

Detection distinguishes repeated travel from legitimate maze turns, Frost effects, stuns, and tactical pause. Movement still prevents crossing occupied squares or cutting tower corners. A committed attack reserves its destination and any diagonal clearance squares until the enemy completes its crossing, preventing a sold target from being immediately replaced or a new side tower from interrupting the attack. Save restoration and tower targeting account for frenzy and committed attacks; older saves initialize travel history at the restored enemy position.

Directional progress prevents movement loops; it does not impose a deadline for escape. Repair and regeneration can sustain a tower under attack, and combat effects can delay an enemy, consistent with preserving existing combat strength and vulnerabilities.

## Implementation verification

The dedicated frenzy regression suite and visual review cover:

- Alternating distant openings accumulates repeated travel and triggers frenzy for affected enemies only.
- An unchanged winding maze does not trigger frenzy; first visits, unrelated edits, and stationary delays do not increase frustration.
- Straight and diagonal revisits contribute their physical lengths, trigger at the threshold, and retain their history after pauses and forward travel.
- Frenzied movement always reduces physical distance to the exit, preserves occupied-square and corner-clearance restrictions, and cannot be redirected backward by building or selling.
- Obstruction attacks stay committed through unrelated edits and repairs; destruction or sale lets the enemy advance through the opening.
- Frenzy preserves normal enemy statistics, slow, stun, and boss control rules.
- Save/load retains history, frustration, frenzy, and any attack commitment; older saves without this history remain loadable using explicit defaults, and malformed new state is rejected.
- Tower targeting estimates account for the enemy's frenzy route and any committed attack.
- Visual review covers increasing redness, the transition to red with sweat, normal and boss sizes, already-red artwork, and simultaneous slow effects.
