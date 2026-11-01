# Progression and rebirth rework

The [Rebirth Draft](rebirth-draft.md) supersedes the automatic coin-bonus reward and rebirth confirmation described below. Possession retention, healing, level-five qualification, and manual restart remain in force.
Status: confirmed by the user and implemented in the shared Godot game.

The permanent-powerup expansion in `powerups.md` extends this progression with 30 powers, per-rank milestones, and compatible Godot save migration.

## Confirmed changes

- Each tower has six tiers: its purchased base form plus five upgrades. Every tier has distinct, more powerful-looking equipment, animation, and attack effects while preserving the cat's identity.
- Each successive enemy level has twice the total enemy health budget of the preceding level. Movement speed and tower-attack damage are balanced separately.
- Remove lives: the first enemy reaching the exit immediately loses the current attempt.
- Losing returns the player to the previous level while retaining current coins and surviving towers, including damage and upgrades. No checkpoint rollback. Clear remaining enemies and pause for preparation; level one remains level one on defeat.
- Rebirth unlocks after clearing level five and is available during combat and between levels. It returns progression to level one, ready to start manually, keeping coins, placed towers, upgrades, and previous coin bonuses. Surviving towers are fully repaired; destroyed and sold towers remain gone. Remaining enemies disappear; the unfinished level contributes no rebirth bonus. See `rebirth-and-pause-menu.md` for the updated interaction rules.
- Each rebirth adds 10 percentage points of permanent coin bonus per highest level cleared since the previous rebirth. Bonuses add: two level-five rebirths produce +100% total, or 2× rewards. Rebirth resets the run's cleared-level record; level five must be cleared again to qualify.
- Progression is endless. Preserve the first 20 enemy compositions, then cycle variations under the increasing health budget, with current level and personal best shown. Boss levels modify the regular compositions as agreed in the next round.
- Every tenth level features a huge, scary boss, cycling caterpillar → snake → spider → dog. Each has distinct animations, speed, durability, and tower damage. The boss receives 60% of the level's health budget; escorts share 40%. Bosses use ordinary one-cell routing even though their artwork spans multiple tiles. A boss health bar is prominent; an escaping boss causes defeat.
- The normal total coin bounty grows by 1.5× per level, before the rebirth bonus. Replayed levels continue paying coins.
- Unlimited Patrol Training purchases increase all cats' damage and maximum health by 25% per purchase, with each purchase costing 1.5× the previous one. Training survives defeat and rebirth; it does not introduce additional visual tiers.
- At level one, if no towers survive and the balance is below 50 coins, top it up to 50. Otherwise defeat retains its economic consequences. Once level five has been cleared this run, rebirth stays available during and between attempts even after falling backward.
- Visual evolution stays within existing roles: Tuxedo Scout progresses from bolts through glowing bolts to energy shots; Chunky from a small cannon through armored artillery to huge explosive shells; Siamese from ice sparks through crystal shards to frost blasts. Each of six tiers has distinct animated artwork and effects; visuals do not implicitly add combat abilities.
- Shared Godot 4.7.2 project exports a universal native macOS app and a Windows 10/11 x86-64 executable with its resource pack. Windows delivery is a portable ZIP.
- Start from scratch: the legacy save was deleted at the user's explicit request; no migration. New saves can be exported/imported manually across platforms.
- Remaining numerical values delegated to implementation/testing. Training starts at 100 coins, compounds damage and maximum health by 1.25×, and preserves health percentage. Fractional coin amounts are retained; large amounts use logarithmic representation and compact labels.

## Implementation decisions

- Tower damage doubles per tier; maximum health multiplies by 1.65. Range grows by 0.3 tiles and firing interval divides by 1 + 0.12 per upgrade count.
- Upgrade cost is base purchase price × 1.2 × 1.8^(current tier − 1). Repair costs 40% of purchase/upgrade investment times missing health. Selling returns 70% of investment times remaining health. Fractional currency is retained.
- Initial level health budget is 304 and bounty is 64. Subsequent budgets are 304 × 2^(level−1) and 64 × 1.5^(level−1). Normal enemies divide their budget by archetype health weight; boss levels allocate 60% to the boss and 40% to escorts.
- Enemy movement speeds retain their archetype roles. Attack damage scales separately by 1 + 0.04 × (level−1).
- No physical coin-clicking requirement: killing an enemy credits the boosted bounty immediately.
- Level identifies the current challenge or the next challenge ready to start. Clearing it advances the number; defeat decrements it with a floor of one.
- Existing unrelated repository files remain untouched. Original Swift source is retained in legacy/macos for reference.
