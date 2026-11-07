# Purrimeter — The Garden Guard

An endless cat tower defence game in which the player builds towers to defeat enemies crossing a square playing field.

## Language

**Playing field**:
The square area through which enemies travel and on which towers occupy space.

**Multiplayer game**:
A shared game for up to three players, each controlling their own playing field and progressing independently while watching one another play and chatting. Players do not affect one another's combat, rewards, or progression.

**Garden**:
A player's persistent playing field and progression, carried between single player and multiplayer games.

**Game release**:
A published version of Purrimeter available together for macOS, Windows, browser play, Android, and iOS under one release identity. Mobile packages are submitted to Google Play and the App Store as part of the release and become installable after their respective stores approve and publish them.

**Current game release**:
The game release designated by a multiplayer server as required for new multiplayer admissions. Players already in a multiplayer game may continue when the server designates a newer release.
_Avoid_: Latest version (without identifying the multiplayer server)

**New Garden**:
A fresh garden that replaces the player's current garden, resetting coins, cats, powerups, discoveries, best level, rebirth bonuses, and draft improvements.

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
A voluntary return to level one that retains coins and surviving towers, fully heals those towers, and awards a Rebirth Draft. It becomes available after clearing level five in the current run.

**Run**:
The progression between rebirths, including retries after defeat.

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

**Scout (Bolt)**:
A cat tower specializing in fast single-target attacks, with a tuxedo coat as its default skin.

**Gunner (Cannon)**:
A cat tower specializing in slow cannon attacks that damage enemies around the target, with an orange-tabby coat as its default skin.

**Sage (Frost)**:
A cat tower specializing in slowing enemies while dealing low damage, with a solid-black coat as its default skin.

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
