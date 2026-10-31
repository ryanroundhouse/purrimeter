# Tower Defence

A game in which the player builds towers to defeat enemies crossing a square playing field.

## Language

**Playing field**:
The square area through which enemies travel and on which towers occupy space.

**Multiplayer game**:
A shared game for two players, each with their own playing field and independent level and rebirth progression, where both can watch one another play and chat.

**Entrance**:
The point where enemies enter the playing field.

**Exit**:
The destination enemies attempt to reach.

**Enemy**:
A hostile unit attempting to reach the exit, attacking obstructing towers if no open route exists or if it is in frenzy.

**Wave**:
An ordered sequence of enemies entering the playing field, with specified types and quantities.

**Level**:
A numbered enemy challenge consisting of a wave, with progression advancing on success or moving backward on defeat.
_Avoid_: Tower level (use tower tier)

**Level health**:
The combined remaining health of every enemy in a level's wave, including the full health of enemies that have not yet arrived. It starts at the wave's total maximum health and falls as enemies take damage.

**Auto-start next level**:
A player-controlled option for starting the next level automatically after successfully clearing the current level.

**Tower tier**:
A tower's upgrade rank, from its purchased base form through five progressively stronger forms.

**Rebirth**:
A voluntary return to level one that retains the player's coins and surviving towers and adds a permanent coin-reward bonus.

**Run**:
The progression between rebirths, including retries after defeat.

**Coin bonus**:
The permanent percentage increase to enemy coin rewards accumulated through rebirths.

**Patrol Training**:
A permanent improvement to every cat's damage and durability, purchased independently of individual tower tiers.

**Powerup**:
A purchased improvement that remains active through defeat, rebirth, and returning to a saved garden, until a New Garden replaces it. Powerups work together automatically and may be bought once or strengthened through additional purchases.
_Avoid_: Upgrade (reserved for tower tiers)

**Powerup rank**:
The number of improvements purchased for a powerup. Each next rank has its own prerequisite in addition to its coin price.
_Avoid_: Powerup level (level identifies an enemy challenge)

**Powerup discovery**:
The permanent revealing of a powerup after its initial prerequisite is met. Discovery survives rebirth, defeat, and loss of the cat that helped earn it.

**Rank prerequisite**:
A milestone required to purchase a particular powerup rank, separate from its coin price. Lifetime progress can satisfy the prerequisites for several future ranks in advance.

**Boss**:
A huge, threatening enemy featured in every tenth level.

**Boss level**:
Every tenth level, whose wave includes a boss and regular enemies.

**Boss music**:
The music accompanying an entire active boss level, including the regular enemies before the boss arrives and any remaining after it dies.

**Tower**:
A player-owned structure that occupies space on the playing field and can be purchased, upgraded, sold, or attacked by enemies.

**Coins**:
The currency awarded for killing enemies and spent on buying, upgrading, and repairing towers and purchasing powerup ranks.

**Open route**:
A path from an enemy to the exit that neither crosses a tower's occupied square nor cuts across a tower's corner. Towers that meet at a corner leave no opening between them.

**Breach route**:
A path to the exit that requires destroying one or more towers, available to enemies with no open route and to enemies in frenzy.

**Frenzy**:
An individual enemy's lasting response to accumulated frustration, advancing toward the exit and destroying obstructing towers even when an open route exists. Frenzy lasts until death or escape and does not increase combat strength or remove vulnerability to slowing and stunning.

**Frustration**:
An enemy's accumulated repeated travel over previously visited ground. Frustration does not fade and eventually triggers frenzy; time spent slowed, stunned, paused, or attacking does not itself add frustration.

**Defeat**:
The immediate failure of an attempt when an enemy reaches the exit. Progression moves back one level while coins and surviving damaged towers remain.

**Tactical pause**:
A pause in combat and any next-level countdown during which the player can still build, upgrade, and sell towers.

**Tuxedo Scout (Bolt)**:
A black-and-white tuxedo cat tower specializing in fast single-target attacks.

**Chunky Gunner (Cannon)**:
An orange tabby cat tower specializing in slow cannon attacks that damage enemies around the target.

**Siamese Sage (Frost)**:
A tower specializing in slowing enemies while dealing low damage.

**Grunt**:
The baseline enemy type.

**Runner**:
A fast enemy with low health.

**Brute**:
A slow enemy with high health.

**Breaker**:
An enemy specializing in damage against blocking towers.

**Upgrade**:
A purchased increase in a tower's tier, improving its combat role, durability, appearance, and attack effects.

**Repair**:
A purchased restoration of a damaged tower's health.
