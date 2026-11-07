# Purrimeter — The Garden Guard

A cat tower defence game with four finite levels and an endless fifth level, in which the player builds towers to defeat enemies crossing a square playing field.

## Language

**Playing field**:
The square area through which enemies travel and on which towers occupy space.

**Obstacle**:
A rock or stream that blocks ground enemy movement and tower placement on the playing field, but does not block flying enemies or attacks across it. Obstacles cannot be attacked or destroyed and remain fixed for the life of a garden.

**Rock**:
A solid obstacle occupying a small cluster of one to four tiles.

**Stream**:
A winding, one-tile-wide water obstacle with both ends inside the playing field, allowing enemies to walk around it.

**Multiplayer game**:
A shared game for up to three players, each controlling their own playing field and progressing independently while watching one another play and chatting. Players do not affect one another's combat, rewards, or progression.

**Garden**:
A player's persistent playing field and progression within one selected level, carried between single player and multiplayer games.

**Game release**:
A published version of Purrimeter available together for macOS, Windows, browser play, Android, and iOS under one release identity. Mobile packages are submitted to Google Play and the App Store as part of the release and become installable after their respective stores approve and publish them.

**Current game release**:
The game release designated by a multiplayer server as required for new multiplayer admissions. Players already in a multiplayer game may continue when the server designates a newer release.
_Avoid_: Latest version (without identifying the multiplayer server)

**New Garden**:
A fresh garden at a selected unlocked level that replaces the player's current garden, resetting coins, cats, powerups, discoveries, best wave, rebirth bonuses, and draft improvements. Level unlocks, achievements, and cat skins belong to the player and survive this replacement.

**Reset all progress**:
A fresh start at level one that clears the current garden, earned level unlocks, achievements and their progress, and earned cat skins while retaining the player's preferences.

**Game owner**:
The player responsible for moderating a multiplayer game, initially its creator. Ownership passes to the longest-connected remaining player when the owner leaves.

**Game chat**:
Messages shared among the players in a multiplayer game. Each player sees messages received during their current visit and can mute or report other players.

**Report**:
A player's complaint about another player's chat, sent to the multiplayer server with that player's recent messages. Reporting also mutes the reported player for the reporter and does not notify or remove anyone.

**Viewed garden**:
Another player's garden enlarged for read-only inspection, whose music and gameplay effects replace the viewer's local garden audio. Viewing preserves the local garden's running or paused state.

**Entrance**:
The point where enemies enter the playing field.

**Exit**:
The destination enemies attempt to reach.

**Enemy**:
A hostile unit attempting to reach the exit, traveling either on the ground or through the air.

**Ground enemy**:
An enemy that follows routes around obstacles and towers, attacking obstructing towers if no open route exists or if it is in frenzy.

**Flying enemy**:
An enemy that flies straight from the entrance to the exit, ignoring obstacles and towers without attacking them or entering frenzy. Flying enemies can be slowed or frozen and do not prevent tower placement beneath them.

**Anti-air tower**:
A cat tower specializing in long-range single-target attacks against flying enemies. Beating level one permanently unlocks it for every garden, including replays of level one.

**Wave**:
An ordered sequence of enemies entering the playing field, with specified types and quantities. Waves are numbered within the garden's selected level.

**Level**:
A selectable challenge containing 10, 20, 30, or 40 waves for levels one through four, or unlimited waves for level five. Clearing a finite level's final wave beats that level and unlocks the next.
_Avoid_: Tower level (use tower tier)

**Level unlock**:
A player's permanent permission to start a garden at a particular level, normally earned by beating the preceding level. Level one is available from the beginning, and earned unlocks survive New Garden.

**Level terrain profile**:
The kinds and amount of permanent obstacles that identify a level: Open Meadow has sparse rocks, Stone Garden has many rocks, and Winding Brook, Twin Streams, and Wildwater have one, two, and three streams respectively. A new garden varies its layout within the selected profile; an existing garden keeps its terrain.

**Endless mode**:
Level five, whose waves continue without a final wave or level victory.

**Level victory**:
The completion of a finite level by clearing its final wave, permanently unlocking the next level. The completed garden remains available to view or export but has no further combat or rebirths.

**Wave health**:
The combined remaining health of every enemy in a wave, including the full health of enemies that have not yet arrived. It starts at the wave's total maximum health and falls as enemies take damage.
_Avoid_: Level health

**Auto-start next wave**:
A player-controlled option for starting the next wave automatically after successfully clearing the current wave.
_Avoid_: Auto-start next level

**Tower tier**:
A tower's upgrade rank, from its purchased base form through five progressively stronger forms.

**Rebirth**:
A voluntary return to wave one within the selected level that retains coins and surviving towers, fully heals those towers, and awards a Rebirth Draft. It becomes available after clearing wave five in the current run and does not itself beat or unlock a level.

**Run**:
The progression through waves within a garden between rebirths, including retries after defeat.

**Rebirth Draft**:
A choice of one permanent draft improvement from randomly offered eligible improvements, earned through rebirth.

**Draft improvement**:
A permanent rebirth reward belonging to a collection separate from coin-bought powerups. It remains owned across rebirths within a garden and is removed by New Garden.

**Draft rank**:
An owned step of a draft improvement, earned one at a time through draft choices. Each next rank can have its own requirements, up to that improvement's maximum rank.

**Draft strength band**:
An improvement's Basic, Advanced, or Keystone classification, used to favor stronger eligible offers after deeper runs.

**Pending draft**:
A committed rebirth's revealed offers awaiting the player's choice. The same offers remain pending when the player leaves and returns, and play resumes only after choosing a reward.

**Draft Collection**:
The garden's catalog of draft improvements, showing owned ranks and requirements for unowned improvements.

**Coin bonus**:
The permanent percentage increase to enemy coin rewards.

**Patrol Training**:
A permanent improvement to every cat's damage and durability, purchased independently of individual tower tiers.

**Powerup**:
A purchased improvement that remains active through defeat, rebirth, and returning to a saved garden, until a New Garden replaces it. Powerups work together automatically and may be bought once or strengthened through additional purchases.
_Avoid_: Upgrade (reserved for tower tiers)

**Powerup rank**:
The number of improvements purchased for a powerup. Each next rank has its own prerequisite in addition to its coin price.
_Avoid_: Powerup level (level identifies a selectable challenge)

**Powerup discovery**:
The permanent revealing of a powerup after its initial prerequisite is met. Discovery survives rebirth, defeat, and loss of the cat that helped earn it.

**Rank prerequisite**:
A milestone required to purchase a particular powerup rank, separate from its coin price. Lifetime progress can satisfy the prerequisites for several future ranks in advance.

**Boss**:
A huge, threatening enemy featured in every tenth wave.

**Boss wave**:
Every tenth wave, which includes a boss and regular enemies.
_Avoid_: Boss level

**Boss music**:
The music accompanying an entire active boss wave, including the regular enemies before the boss arrives and any remaining after it dies.

**Tower**:
A player-owned structure that occupies space on the playing field and can be purchased, upgraded, sold, or attacked by enemies.

**Coins**:
The currency awarded for killing enemies and spent on buying, upgrading, and repairing towers and purchasing powerup ranks.

**Open route**:
A path from a ground enemy to the exit that neither crosses a tower or obstacle nor cuts across its corner. Towers and obstacles that meet at a corner leave no opening between them.

**Breach route**:
A path to the exit that avoids obstacles and requires destroying one or more towers, available to enemies with no open route and to enemies in frenzy.

**Frenzy**:
An individual ground enemy's lasting response to accumulated frustration, advancing toward the exit and destroying obstructing towers even when an open route exists. Frenzy lasts until death or escape and does not increase combat strength or remove vulnerability to slowing and stunning.

**Frustration**:
An enemy's accumulated repeated travel over previously visited ground. Frustration does not fade and eventually triggers frenzy; time spent slowed, stunned, paused, or attacking does not itself add frustration.

**Defeat**:
The immediate failure of an attempt when an enemy reaches the exit. Progression moves back one wave within the selected level, stopping at wave one, while coins and surviving damaged towers remain.

**Tactical pause**:
A pause in combat and any next-wave countdown during which the player can still build, upgrade, and sell towers.

**Scout (Bolt)**:
A cat tower specializing in fast single-target attacks against ground and flying enemies, with a tuxedo coat as its default skin.

**Gunner (Cannon)**:
A cat tower specializing in slow cannon attacks that damage ground enemies around the target, with an orange-tabby coat as its default skin. It cannot damage flying enemies.

**Sage (Frost)**:
A cat tower specializing in slowing ground and flying enemies while dealing low damage, with a solid-black coat as its default skin.

**Ranger (Anti-air)**:
A calico cat tower specializing in long-range single-target bow attacks against flying enemies, permanently unlocked by beating level one.

**Moth**:
A flying enemy with lavender wings that travels directly from the entrance to the exit without attacking cats.

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

**Achievement**:
A player-wide accomplishment earned by meeting a defined gameplay milestone or challenge, retained through defeat, rebirth, and New Garden. Achievements can unlock cat skins without granting gameplay advantages.

**Cat skin**:
A cosmetic appearance for a cat type, available by default or permanently unlocked through an achievement. Each type has one player-selected skin shared by all of that player's cats of that type, without changing their combat abilities or tower tiers.

**Achievement progress**:
The player's recorded advancement toward an achievement's requirements, shared across single player and multiplayer.

**Achievement fanfare**:
The on-screen celebration shown when the player earns an achievement.
