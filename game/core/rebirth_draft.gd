class_name RebirthDraft
extends RefCounted
## Authored next-rank rewards. Eligibility is garden-wide; weights use run depth.
const FALLBACK := "lasting_fortune"
# id, name, band, cap, first best, best step, first rebirth, rebirth step, description
const ITEMS := [
	["mixed","Mixed Patrol",0,3,5,5,1,1,"Cats attack faster within 2 tiles of a different cat role. Multiple neighbors do not multiply the benefit."],
	["supply","Supply Cache",0,3,5,5,1,1,"Successful clears award extra coins based on that level's base bounty."],
	["salvage","Salvage Crew",0,3,5,5,1,1,"Destroyed cats refund part of their actual recruitment and tier investment. Selling grants no extra refund."],
	["guard","Frost Guard",0,3,5,5,1,1,"Chilled enemies deal less damage to cats. Total damage reduction is capped at 60%."],
	["spotter","Spotter Bolts",1,3,10,5,2,2,"Scout primary hits mark an enemy for 3 seconds. A Gunner's direct hit consumes the mark for bonus damage."],
	["front","Cold Front",1,3,10,5,2,2,"Sage attacks also slow nearby enemies within 1.5 tiles. Extra targets receive no freeze counters."],
	["cinder","Cinder Relay",1,3,10,5,2,2,"A burning enemy's death transfers its remaining burn to one neighbor. Transferred burns cannot relay again."],
	["steady","Steady Aim",1,3,10,5,2,2,"Scouts retain Focus Fire buildup when their target dies. Switching away from a living target still resets it."],
	["treasure","Treasure Trail",1,3,15,5,3,2,"Consecutive clears build extra base-bounty rewards, capped at five clears. Defeat or rebirth resets the streak."],
	["thermal","Thermal Shock",2,3,20,5,4,2,"A direct Gunner hit deals bonus damage to an enemy already burning and chilled. Both statuses remain."],
	["lives","Nine Lives",2,1,20,0,4,0,"Once per level attempt, save one cat from destruction and restore 35% health. One charge shared by your patrol."],
	["triad","Triad Strike",2,3,30,5,5,2,"Primary hits from all three roles within 3 seconds trigger bonus damage. Each enemy has a 3-second recovery."],
]
const BANDS := ["Basic","Advanced","Keystone"]
const DRAFT_REQUIRES := {"treasure":["supply"],"triad":["spotter","front"]}
const POWER_REQUIRES := {"cinder":"embers","thermal":"embers","steady":"focus"}

static func definition(id: String) -> Dictionary:
	if id==FALLBACK: return {"id":id,"name":"Lasting Fortune","band":0,"cap":0,"description":"No normal improvements are eligible. Add 10 percentage points to your permanent enemy coin bonus."}
	for row in ITEMS:
		if row[0]==id: return {"id":id,"name":row[1],"band":row[2],"cap":row[3],"best":row[4],"best_step":row[5],"rebirths":row[6],"rebirth_step":row[7],"description":row[8]}
	return {}

static func eligible(g, id: String) -> bool:
	var d := definition(id)
	if d.is_empty() or id==FALLBACK: return false
	var rank: int = g.draft_rank(id)
	if rank>=d.cap or g.best<d.best+d.best_step*rank or g.rebirths<d.rebirths+d.rebirth_step*rank: return false
	for prerequisite in DRAFT_REQUIRES.get(id,[]):
		if g.draft_rank(prerequisite)<1: return false
	return not POWER_REQUIRES.has(id) or g.powerup_rank(POWER_REQUIRES[id])>=1

static func pool(g) -> Array[String]:
	var result: Array[String] = []
	for row in ITEMS:
		if eligible(g,row[0]): result.append(row[0])
	return result

static func weights(depth: int) -> Array:
	if depth>=30: return [1.0,3.0,2.0]
	if depth>=20: return [1.0,2.0,1.0]
	if depth>=10: return [1.0,1.0,0.5]
	return [1.0,0.5,0.2]

static func draw(g, depth: int) -> Array:
	var remaining := pool(g)
	if remaining.is_empty(): return [FALLBACK]
	var result := []
	var bands := weights(depth)
	while result.size()<3 and not remaining.is_empty():
		var total := 0.0
		for id in remaining: total+=bands[definition(id).band]
		g.draft_seed=(g.draft_seed*48271)%2147483647
		var pick: float = float(g.draft_seed)/2147483647.0*total
		var chosen: String = remaining.back()
		for id in remaining:
			pick-=bands[definition(id).band]
			if pick<0: chosen=id; break
		result.append(chosen); remaining.erase(chosen)
	return result

static func requirements(g, id: String) -> String:
	if id==FALLBACK: return "Available only when no normal improvement is eligible."
	var d := definition(id)
	var rank: int = g.draft_rank(id)
	if rank>=d.cap: return "Complete · all ranks owned"
	var parts: Array[String] = ["Clear level %d · best %d"%[d.best+d.best_step*rank,g.best],"Rebirths %d / %d"%[g.rebirths,d.rebirths+d.rebirth_step*rank]]
	for prerequisite in DRAFT_REQUIRES.get(id,[]): parts.append("%s rank %d / 1"%[definition(prerequisite).name,g.draft_rank(prerequisite)])
	if POWER_REQUIRES.has(id):
		var power: String = POWER_REQUIRES[id]
		parts.append("%s rank %d / 1"%[Powerups.definition(power).name,g.powerup_rank(power)])
	return "\n".join(parts)

static func effect(id: String, rank: int) -> String:
	if rank==0: return "Not owned"
	match id:
		"mixed": return "+%d%% attack speed near another role"%(rank*8)
		"supply": return "+%d%% base level bounty per clear"%(rank*25)
		"salvage": return "%d%% investment returned on destruction"%(rank*15)
		"guard": return "%d%% less damage from chilled enemies"%(rank*10)
		"spotter": return "+%d%% direct Gunner damage to a marked foe"%(rank*25)
		"front": return "Slow %d additional nearby enemies"%rank
		"cinder": return "Transfer burn at %d%% strength within 2 tiles"%(40+rank*20)
		"steady": return "Retain up to %d Focus Fire stacks"%mini(5,rank*2)
		"treasure": return "+%d%% base bounty per streak clear, up to +%d%%"%[rank*5,rank*25]
		"thermal": return "+%d%% direct damage to burning, chilled foes"%(rank*35)
		"lives": return "Save one cat per attempt at 35% health"
		"triad": return "%d%% triggering hit damage as a combo burst"%(rank*50)
		FALLBACK: return "+%d percentage points of coin bonus"%(rank*10)
	return ""
