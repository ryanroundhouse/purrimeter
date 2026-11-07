class_name Achievements
extends RefCounted
## Player-wide recognition. Attempt evidence belongs to Session, not this book.
signal earned_now(id: String)
const ITEMS := [
 ["first","First Watch","Clear wave 1.","best",1,"First steps","training"],
 ["crew","The Whole Crew","Have Bolt, Cannon and Frost cats placed together.","crew",3,"First steps","quick"],
 ["upgrade","Sharper Claws","Purchase your first tower-tier upgrade.","upgrades",1,"First steps","equipment"],
 ["power","A Little Extra","Purchase your first powerup rank.","ranks",1,"First steps","lucky"],
 ["rebirth","Nine Lives Begin","Perform your first rebirth.","rebirths",1,"First steps","aid"],
 ["boss_level","Big Pest, Small Problem","Clear wave 10, including the boss and its escorts.","best",10,"First steps","purse"],
 ["kills100","Pest Patrol","Defeat 100 enemies across your gardens.","kills",100,"Lifetime","heavy"],
 ["kills5000","Garden Veteran","Defeat 5,000 enemies across your gardens.","kills",5000,"Lifetime","giant"],
 ["bosses","Big Game Hunter","Defeat 25 bosses across your gardens.","bosses",25,"Lifetime","siege"],
 ["recruits","Cat Person","Recruit 50 cats across your gardens.","recruits",50,"Lifetime","thrifty"],
 ["repairs","Tender Loving Care","Make 25 paid repairs that restore health.","repairs",25,"Lifetime","repair"],
 ["upgrades","Better Every Day","Purchase 100 tower-tier upgrades.","upgrades",100,"Lifetime","eyes"],
 ["rebirths","Back for More","Perform 10 rebirths.","rebirths",10,"Lifetime","catnap"],
 ["ranks","Power Collector","Purchase 25 powerup ranks across any powerups.","ranks",25,"Lifetime","bounty"],
 ["solo","Lone Guardian","Clear wave 5 or higher with exactly one cat present throughout the attempt.","solo",5,"Tactics","focus"],
 ["bolt","Bolt from the Blue","Clear wave 5 or higher using only Bolt cats throughout the attempt.","bolt",5,"Tactics","needle"],
 ["cannon","Cannon Fodder","Clear wave 5 or higher using only Cannon cats throughout the attempt.","cannon",5,"Tactics","blast"],
 ["basic","Back to Basics","Clear wave 10 or higher with every cat at base tier throughout the attempt.","basic",10,"Tactics","beds"],
 ["idle","Set and Forget","Clear wave 10 or higher without recruiting, selling, upgrading, repairing or buying powerups during the attempt.","idle",10,"Tactics","stand"],
 ["unhurt","Not a Scratch","Clear wave 10 or higher without any cat taking damage during the attempt.","unhurt",10,"Tactics","fur"],
 ["cold","Cold Reception","Defeat a boss while it is slowed by a Frost cat or its powerups.","cold",1,"Tactics","chill"],
 ["frenzy","Keep Your Cool","Defeat an enemy after it enters frenzy.","frenzy",1,"Tactics","concussion"],
 ["medic","Field Medic","During wave 5 or higher, pay to repair a damaged cat, then clear that attempt with that same cat still present.","medic",5,"Tactics","aid"],
 ["streak","On a Roll","Clear five consecutive waves numbered 10 or higher without defeat or rebirth.","streak",5,"Tactics","quick"],
 ["level25","Garden Sentinel","Clear wave 25.","best",25,"Mastery","embers"],
 ["level50","Legendary Guard","Clear wave 50.","best",50,"Mastery","aftershock"],
 ["dream","Dream Team","Have a tier-six Bolt, Cannon and Frost placed together.","dream",3,"Mastery","static"],
 ["toys","Full Toy Box","Own at least one rank of all 30 powerups in one garden.","toys",30,"Mastery","winter"],
 ["school","Finishing School","Reach maximum rank on five different capped powerups in one garden. Unlimited Patrol Training does not count.","school",5,"Mastery","lock"],
 ["gold","Seasoned Guardian","Complete 20 rebirths across your gardens.","rebirths",20,"Mastery","bounty"],
]
const CONDITIONS := ["solo","bolt","cannon","basic","idle","unhurt"]
var values: Dictionary = {}
var earned: Dictionary = {}
var pending: Array = []
var summary: Array = []
var skin_choices: Dictionary = {}
var seen_skins: Array = []
var unlocked_level := 1 # Player-wide access, independent of achievement wave records.

static func item(id: String) -> Array:
	for row in ITEMS:
		if row[0]==id: return row
	return []

static func valid_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=9e15 and floor(float(value))==float(value)

static func valid(data) -> bool:
	if not data is Dictionary or not PowerupSave.number(data.get("version"),1,2,true): return false
	if data.version==2 and not PowerupSave.number(data.get("unlocked_level"),1,GardenLevels.COUNT,true): return false
	if not CatSkins.valid_choices(data.get("skin_choices",{})) or not CatSkins.valid_seen(data.get("seen_skins",[])): return false
	if not data.get("values") is Dictionary or not data.get("earned") is Dictionary or not data.get("pending") is Array: return false
	var keys := ["bonus"] # Accept historical Golden Garden progress without removing earned rewards.
	for row in ITEMS:
		if row[3] not in keys: keys.append(row[3])
	for key in data.values:
		if key not in keys or not valid_number(data.values[key]): return false
	for id in data.earned:
		if item(str(id)).is_empty() or not data.earned[id] is bool or not data.earned[id]: return false
	var seen := {}
	for id in data.pending:
		if not id is String or not data.earned.has(id) or seen.has(id): return false
		seen[id]=true
	return true

static func valid_run(data) -> bool:
	if not data is Dictionary: return false
	for key in data:
		if key not in ["attempt","streak","last_clear"]: return false
	for key in ["streak","last_clear"]:
		if not valid_number(data.get(key,0)): return false
	var attempt = data.get("attempt",{})
	if not attempt is Dictionary: return false
	if attempt.is_empty(): return true
	if attempt.size()!=3 or not valid_number(attempt.get("level")) or attempt.level<1: return false
	if not attempt.get("failed") is Dictionary or not attempt.get("repaired") is Array: return false
	for key in attempt.failed:
		if key not in CONDITIONS or not attempt.failed[key] is String or attempt.failed[key].length()>120: return false
	if attempt.repaired.size()>254: return false
	for cell in attempt.repaired:
		if not valid_number(cell) or cell>255 or cell in [Routes.ENTRANCE,Routes.EXIT]: return false
	return true

func snapshot() -> Dictionary:
	return {"version":2,"unlocked_level":unlocked_level,"values":values.duplicate(),"earned":earned.duplicate(),"pending":pending.duplicate(),"skin_choices":skin_choices.duplicate(),"seen_skins":seen_skins.duplicate()}

static func saved_unlock(data: Dictionary) -> int:
	return int(data.unlocked_level) if data.version==2 else GardenLevels.legacy_unlock(int(data.values.get("best",0)))

func highest(key: String, value: float) -> void:
	values[key]=maxf(float(values.get(key,0)),minf(value,9e15))

func increment(key: String) -> void:
	highest(key,float(values.get(key,0))+1)

func award(id: String, retrospective: bool) -> void:
	if earned.has(id): return
	earned[id]=true; pending.append(id)
	if retrospective: summary.append(id)
	else: earned_now.emit(id)

func evaluate(retrospective: bool = false) -> void:
	for row in ITEMS:
		if values.get(row[3],0)>=row[4]: award(row[0],retrospective)

func merge(data: Dictionary, startup: bool = false) -> void:
	unlocked_level=maxi(unlocked_level,saved_unlock(data))
	for key in data.values: highest(key,data.values[key])
	for id in data.earned: award(id,true)
	if startup:
		# A local profile is authoritative about which celebrations were already seen.
		pending=data.pending.duplicate(); summary=pending.duplicate()
	evaluate(true)
	for key in data.get("skin_choices",{}):
		if not skin_choices.has(key): CatSkins.equip(self,int(key),data.skin_choices[key])
	# Seen notifications are local: an import must not suppress this device's reveal.
	if startup: seen_skins=data.get("seen_skins",[]).duplicate()

func acknowledge(ids: Array) -> void:
	for id in ids:
		pending.erase(id); summary.erase(id)
		var skin := CatSkins.reward(id)
		if not skin.is_empty() and skin not in seen_skins: seen_skins.append(skin)

func observe(g) -> void:
	highest("best",g.best); highest("bonus",floor(g.bonus_points))
	var kinds := {}; var mythics := {}; var owned := 0; var capped := 0
	for t in g.towers:
		kinds[t.kind]=true
		if t.tier==6: mythics[t.kind]=true
	for row in Powerups.ITEMS:
		if g.powerup_rank(row[0])>0: owned+=1
		if g.powerup_complete(row[0]): capped+=1
	highest("crew",kinds.size()); highest("dream",mythics.size())
	highest("toys",owned); highest("school",capped)

func credit_saved(g) -> void:
	# These are lower bounds proven by the save, not reconstructed history.
	highest("kills",g.kills); highest("rebirths",g.rebirths); highest("recruits",g.towers.size())
	var upgrades := 0; var ranks := 0
	for t in g.towers: upgrades+=t.tier-1
	var historical := 0
	for tier in g.cat_milestones: historical+=maxi(0,tier-1)
	highest("upgrades",maxi(upgrades,historical))
	for row in Powerups.ITEMS: ranks+=g.powerup_rank(row[0])
	highest("ranks",ranks); observe(g); evaluate(true)

func attempt(g) -> Dictionary:
	return g.achievement_run.get("attempt",{})

func fail_condition(g, key: String, reason: String) -> void:
	var a := attempt(g)
	if not a.is_empty() and not a.failed.has(key): a.failed[key]=reason

func check_squad(g) -> void:
	if g.towers.size()!=1: fail_condition(g,"solo","The patrol did not contain exactly one cat.")
	if g.towers.is_empty():
		fail_condition(g,"bolt","The patrol was empty."); fail_condition(g,"cannon","The patrol was empty.")
	for t in g.towers:
		if t.kind!=0: fail_condition(g,"bolt","A cat other than Bolt was present.")
		if t.kind!=1: fail_condition(g,"cannon","A cat other than Cannon was present.")
		if t.tier!=1: fail_condition(g,"basic","A cat above base tier was present.")

func record(g, event: String, detail: Dictionary = {}) -> void:
	match event:
		"start":
			g.achievement_run.attempt={"level":g.level,"failed":{},"repaired":[]}
			check_squad(g)
		"build", "upgrade", "repair", "sell", "powerup":
			var counter: String = {"build":"recruits","upgrade":"upgrades","repair":"repairs","powerup":"ranks"}.get(event,"")
			if not counter.is_empty(): increment(counter)
			fail_condition(g,"idle","A purchase, repair or sale was made during the attempt.")
			if event=="repair" and not attempt(g).is_empty() and detail.cell not in attempt(g).repaired: attempt(g).repaired.append(detail.cell)
			if event=="sell" and not attempt(g).is_empty(): attempt(g).repaired.erase(detail.cell)
			check_squad(g)
		"damage": fail_condition(g,"unhurt","A cat took damage during the attempt.")
		"destroyed":
			if not attempt(g).is_empty(): attempt(g).repaired.erase(detail.cell)
			check_squad(g)
		"kill":
			increment("kills")
			if detail.boss>=0:
				increment("bosses")
				if detail.slow>0: highest("cold",1)
			if detail.get("frenzied",false): highest("frenzy",1)
		"clear":
			highest("best",g.level)
			var a := attempt(g)
			if not a.is_empty() and int(a.level)==g.level:
				check_squad(g)
				for key in CONDITIONS:
					if not a.failed.has(key): highest(key,g.level)
				for cell in a.repaired:
					if not g.tower_at(int(cell)).is_empty(): highest("medic",g.level)
				var streak: int = int(g.achievement_run.get("streak",0))+1 if int(g.achievement_run.get("last_clear",0))==g.level-1 else 1
				g.achievement_run.streak=streak if g.level>=10 else 0
				g.achievement_run.last_clear=g.level
				highest("streak",g.achievement_run.streak)
			else:
				g.achievement_run.streak=0; g.achievement_run.last_clear=0
			g.achievement_run.attempt={}
		"defeat", "rebirth":
			g.achievement_run.clear()
			if event=="rebirth": increment("rebirths")
	observe(g); evaluate()

func progress_text(row: Array, g) -> String:
	var value: int = mini(int(values.get(row[3],0)),int(row[4]))
	if earned.has(row[0]): return "Earned · %d / %d%s" % [int(row[4]),int(row[4]),"%" if row[3]=="bonus" else ""]
	var result := "%d / %d%s" % [value,int(row[4]),"% coin bonus" if row[3]=="bonus" else ""]
	if row[3] in CONDITIONS or row[3]=="medic": result="Best qualifying wave: "+result
	elif row[3] in ["crew","dream","toys","school"]: result="Best in one garden: "+result
	elif row[3]=="best": result="Best wave cleared: "+result
	if row[3] in CONDITIONS:
		var a := attempt(g)
		if a.is_empty(): result+="\nStart a new attempt to try this challenge."
		elif a.failed.has(row[3]): result+="\nThis attempt: ineligible. "+str(a.failed[row[3]])
		elif g.level<row[4]: result+="\nThis attempt is below the required wave."
		else: result+="\nThis attempt: eligible. Clear the wave to earn it."
	if row[3]=="medic":
		var a := attempt(g)
		result+="\nRepair recorded this attempt: "+("yes" if not a.is_empty() and not a.repaired.is_empty() else "not yet")
	if row[3]=="streak": result+="\nCurrent streak: %d / 5" % int(g.achievement_run.get("streak",0))
	if row[3] in ["crew","dream"]:
		for kind in range(3):
			var present: bool = g.towers.any(func(t): return t.kind==kind and (row[3]=="crew" or t.tier==6))
			result+="\n%s: %s" % [Balance.CATS[kind].name,"present" if present else "needed"]
	return result
