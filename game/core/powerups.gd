class_name Powerups
extends RefCounted
## Stable save IDs, player-facing effects, and rank milestone schedules.
## max_rank == 0 denotes unlimited ranks. Cat milestones are historical tiers.
const ITEMS = [
	["training", "Patrol Training", "Patrol", 0, 100, 1.5, "kills", 0, 0, -1, "Every cat gains 25% damage and maximum health per rank, compounded."],
	["quick", "Quick Paws", "Patrol", 5, 140, 2.4, "best", 2, 4, -1, "Every cat attacks 8% faster per rank."],
	["eyes", "Keen Eyes", "Patrol", 5, 180, 2.5, "best", 3, 5, -1, "Every cat gains 0.15 tiles of attack range per rank."],
	["lucky", "Lucky Claws", "Patrol", 5, 260, 2.6, "kills", 60, 150, -1, "Attacks gain a 4% critical-hit chance per rank. Critical hits deal double damage."],
	["heavy", "Heavy Claws", "Patrol", 5, 400, 2.6, "best", 6, 5, -1, "Critical hits deal an extra 25% of normal damage per rank. Requires Lucky Claws."],
	["bounty", "Bounty Lessons", "Economy", 5, 160, 2.8, "best", 2, 5, -1, "Enemy coin rewards increase by 10% per rank, multiplying your permanent coin bonus."],
	["purse", "Boss Purse", "Economy", 5, 1800, 3.0, "best", 10, 10, -1, "Boss coin rewards increase by an additional 20% per rank."],
	["thrifty", "Thrifty Recruiting", "Economy", 5, 200, 2.5, "kills", 30, 120, -1, "Recruiting cats costs 5% less per rank."],
	["equipment", "Efficient Equipment", "Economy", 5, 300, 2.8, "best", 4, 5, -1, "Tower-tier upgrades cost 5% less per rank."],
	["repair", "Repair Kit", "Economy", 5, 180, 2.4, "kills", 40, 100, -1, "Paid repairs cost 10% less per rank."],
	["beds", "Reinforced Beds", "Durability", 5, 180, 2.5, "best", 3, 4, -1, "Every cat gains 15% additional maximum health per rank. Health percentage is preserved."],
	["fur", "Thick Fur", "Durability", 5, 300, 2.8, "best", 5, 5, -1, "Cats take 6% less damage per rank."],
	["catnap", "Catnap", "Durability", 5, 320, 2.6, "best", 4, 4, -1, "Clearing a level restores 5% of each surviving cat's maximum health per rank."],
	["aid", "First Aid", "Durability", 5, 700, 3.0, "rebirths", 1, 1, -1, "During combat, cats regenerate 0.2% of maximum health each second per rank."],
	["stand", "Last Stand", "Durability", 1, 900, 1.0, "best", 8, 0, -1, "Cats below 30% health attack 30% faster until their health recovers."],
	["needle", "Needle Bolts", "Bolt", 3, 350, 3.2, "best", 4, 6, 0, "Bolts pierce up to one extra enemy per rank behind their target, dealing 60% damage."],
	["static", "Static Whiskers", "Bolt", 3, 600, 3.3, "best", 7, 7, 0, "Bolts arc to up to one nearby enemy per rank, dealing 35% damage. Arcs do not chain again."],
	["focus", "Focus Fire", "Bolt", 5, 400, 2.7, "best", 5, 5, 0, "Each consecutive bolt on one target adds 4% damage per rank, up to five stacks."],
	["giant", "Giant Hunter", "Bolt", 5, 1500, 3.0, "best", 9, 8, 0, "Bolts deal 20% more damage to bosses per rank."],
	["finish", "Finishing Touch", "Bolt", 5, 800, 2.8, "best", 8, 6, 0, "Bolts deal 15% more damage per rank to enemies below 30% health."],
	["blast", "Wider Blast", "Cannon", 5, 350, 2.8, "best", 4, 5, 1, "Cannon explosions gain 0.15 tiles of splash radius per rank."],
	["embers", "Hot Embers", "Cannon", 5, 500, 2.9, "best", 6, 5, 1, "Explosions burn for 8% of their damage per second per rank for 3 seconds. Strongest burn wins."],
	["concussion", "Concussion", "Cannon", 3, 900, 3.2, "best", 8, 7, 1, "Explosions have a 10% chance per rank to stun for 0.45 seconds. Control has a recovery window."],
	["aftershock", "Aftershock", "Cannon", 1, 4500, 1.0, "best", 14, 0, 1, "Explosions echo after 0.45 seconds for 40% damage. Echoes cannot trigger more echoes or burns."],
	["siege", "Siege Shells", "Cannon", 5, 650, 2.8, "best", 7, 6, 1, "Shells deal 20% more damage per rank to enemies currently attacking a cat."],
	["chill", "Deep Chill", "Frost", 5, 300, 2.7, "best", 3, 5, 2, "Frost slows become 4 percentage points stronger per rank, up to 68% slowing."],
	["linger", "Lingering Cold", "Frost", 5, 350, 2.7, "best", 4, 5, 2, "Frost slows last 0.4 seconds longer per rank."],
	["lock", "Ice Lock", "Frost", 3, 1000, 3.2, "best", 9, 7, 2, "Every fourth frost hit freezes for 0.3 seconds per rank. Control has a recovery window."],
	["brittle", "Brittle Ice", "Frost", 5, 850, 2.9, "best", 8, 6, 2, "Chilled enemies take 8% more damage per rank from Bolt and Cannon cats."],
	["winter", "Winter Gift", "Frost", 1, 5000, 1.0, "best", 15, 0, 2, "Defeated chilled enemies spread a 1.2-second slow to foes within 1.5 tiles."]
]

static func definition(id: String) -> Dictionary:
	for row in ITEMS:
		if row[0]==id:
			return {"id":row[0],"name":row[1],"group":row[2],"cap":row[3],"price":row[4],"growth":row[5],"metric":row[6],"first":row[7],"stride":row[8],"cat":row[9],"description":row[10]}
	return {}

static func cost(id: String, owned: int) -> Amount:
	var d := definition(id)
	return Amount.from_power(log(float(d.price))/log(10.0)+owned*log(float(d.growth))/log(10.0))

static func requirements(id: String, next_rank: int) -> Array:
	var d := definition(id)
	if d.is_empty(): return []
	var threshold: float = d.first+float(next_rank-1)*d.stride
	if id=="training": threshold=4.0*next_rank*(next_rank-1)
	var result: Array = [{"metric":d.metric,"value":threshold}]
	if d.cat>=0: result.append({"metric":"cat%d"%d.cat,"value":mini(6,1+(next_rank-1)/2)})
	if id=="heavy": result.append({"metric":"lucky","value":1})
	return result

static func progress(g, metric: String) -> int:
	if metric.begins_with("cat"): return g.cat_milestones[int(metric.right(1))]
	if metric in ["kills","best","rebirths"]: return g.get(metric)
	return g.powerup_rank(metric)

static func eligible(g, id: String, next_rank: int) -> bool:
	for requirement in requirements(id,next_rank):
		if progress(g,requirement.metric)<requirement.value: return false
	return not definition(id).is_empty()

static func requirement_text(g, id: String, next_rank: int) -> String:
	var parts: Array[String] = []
	for requirement in requirements(id,next_rank):
		var metric: String = requirement.metric
		var needed: float = requirement.value
		if needed==0: continue
		var current := progress(g,metric)
		var label: String
		match metric:
			"kills": label="Lifetime kills %d / %d"%[current,int(needed)]
			"best": label="Clear level %d · best %d"%[needed,current]
			"rebirths": label="Rebirths %d / %d"%[current,needed]
			"lucky": label="Lucky Claws rank %d / %d"%[current,needed]
			_: label="%s tier %d / %d"%[["Bolt","Cannon","Frost"][int(metric.right(1))],current,needed]
		parts.append(label)
	return "  ·  ".join(parts) if not parts.is_empty() else "Available from level 1"

static func effect(id: String, rank: int) -> String:
	if rank==0: return "Not purchased"
	match id:
		"training":
			var multiplier := Amount.from_power(rank*log(1.25)/log(10.0))
			return "%s× damage & health"%("%.2f"%multiplier.numeric() if multiplier.power<3 else multiplier.label())
		"quick": return "+%d%% attack speed"%(rank*8)
		"eyes": return "+%.2f tiles range"%(rank*0.15)
		"lucky": return "%d%% critical chance"%(rank*4)
		"heavy": return "%.2f× critical damage"%(2.0+rank*0.25)
		"bounty": return "+%d%% enemy coins"%(rank*10)
		"purse": return "+%d%% boss coins"%(rank*20)
		"thrifty", "equipment": return "%d%% discount"%(rank*5)
		"repair": return "%d%% repair discount"%(rank*10)
		"beds": return "+%d%% maximum health"%(rank*15)
		"fur": return "%d%% less damage taken"%(rank*6)
		"catnap": return "%d%% healing after a clear"%(rank*5)
		"aid": return "%.1f%% health / second"%(rank*0.2)
		"stand": return "+30% speed below 30% health"
		"needle": return "%d extra piercing targets"%rank
		"static": return "%d arc targets"%rank
		"focus": return "+%d%% damage at five stacks"%(rank*20)
		"giant", "siege": return "+%d%% conditional damage"%(rank*20)
		"finish": return "+%d%% finishing damage"%(rank*15)
		"blast": return "%.2f tile blast radius"%(1.35+rank*0.15)
		"embers": return "%d%% damage / second for 3s"%(rank*8)
		"concussion": return "%d%% chance of 0.45s stun"%(rank*10)
		"aftershock": return "40% damage echo after 0.45s"
		"chill": return "%d%% slowing"%(48+rank*4)
		"linger": return "%.1fs slow duration"%(1.8+rank*0.4)
		"lock": return "%.1fs freeze every fourth hit"%(rank*0.3)
		"brittle": return "+%d%% damage to chilled foes"%(rank*8)
		"winter": return "Spread chill within 1.5 tiles"
	return ""
