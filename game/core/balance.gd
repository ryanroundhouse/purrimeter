class_name Balance
extends RefCounted
const ANTI_AIR := 3
const MOTH := 4
const CATS = [
	{"name":"Scout", "role":"BOLT · Air + ground", "price":50.0, "hp":160.0, "damage":14.0, "interval":0.48, "range":3.4, "color":Color("ffc46b")},
	{"name":"Gunner", "role":"CANNON · Ground splash", "price":80.0, "hp":260.0, "damage":36.0, "interval":1.65, "range":3.0, "color":Color("fb8875")},
	{"name":"Sage", "role":"FROST · Slows air + ground", "price":70.0, "hp":180.0, "damage":5.0, "interval":0.85, "range":2.8, "color":Color("78cfff")},
	{"name":"Ranger", "role":"ANTI-AIR · Flying enemies only", "price":90.0, "hp":200.0, "damage":26.0, "interval":0.6, "range":4.2, "color":Color("71dfc5")}
]
const FOES = [
	{"name":"Grunt", "weight":38.0, "speed":1.25, "dps":12.0},
	{"name":"Runner", "weight":27.0, "speed":2.1, "dps":8.0},
	{"name":"Brute", "weight":150.0, "speed":0.78, "dps":22.0},
	{"name":"Breaker", "weight":80.0, "speed":1.05, "dps":48.0},
	{"name":"Moth", "weight":38.0, "speed":1.25, "dps":0.0}
]
const BOSSES = [
	{"name":"THE THORN CRAWLER", "subtitle":"Armored caterpillar", "speed":0.55, "dps":68.0, "color":Color("a3d85e")},
	{"name":"THE VIOLET FANG", "subtitle":"Venomous cobra", "speed":1.15, "dps":48.0, "color":Color("c395f7")},
	{"name":"THE CRIMSON WIDOW", "subtitle":"Garden spider", "speed":0.85, "dps":85.0, "color":Color("f57487")},
	{"name":"THE IRON MAW", "subtitle":"Nightmare hound", "speed":0.70, "dps":120.0, "color":Color("adc5e7")}
]
const TIERS = ["Recruit", "Scout", "Veteran", "Elite", "Royal", "Mythic"]
const TITLES = ["A squeak in the grass", "Quick paws", "Rat race", "Heavy footsteps", "The demolition crew", "Double trouble", "Hammer time", "The long march", "Purple tide", "Midnight raid", "Steel and squeaks", "Green lightning", "Heavy machinery", "The sandwich", "A very bad picnic", "Rumble in the garden", "Breach party", "No rest for whiskers", "Nine lives", "The last meow"]
const GROUPS = [
	[[0,8]], [[0,5],[1,5]], [[1,8],[0,6]], [[0,8],[2,3]], [[0,6],[3,4],[1,4]],
	[[1,8],[2,4],[0,6]], [[3,6],[0,12]], [[2,7],[1,10]], [[0,24],[3,4]], [[1,12],[3,7],[2,5]],
	[[2,8],[0,18]], [[1,28],[3,5]], [[3,12],[2,8]], [[1,12],[2,10],[1,12]], [[0,22],[3,10],[2,6]],
	[[2,15],[1,16]], [[3,18],[1,16]], [[0,24],[1,20],[2,8]], [[2,14],[3,16],[1,16]], [[0,20],[3,14],[2,18],[1,24]]
]

static func health_power(level: int) -> float:
	return log(304.0)/log(10.0) + (level-1)*log(2.0)/log(10.0)

static func bounty(level: int) -> Amount:
	return Amount.from_power(log(64.0)/log(10.0) + (level-1)*log(1.5)/log(10.0))

static func flying(e: Dictionary) -> bool:
	return e.kind==MOTH and e.boss<0

static func can_target(kind: int, e: Dictionary) -> bool:
	return flying(e) if kind==ANTI_AIR else (not flying(e) if kind==1 else true)

static func valid_flight(e: Dictionary) -> bool:
	if not e.get("frenzied",false) is bool: return false
	return e.boss==-1 and e.cell>=Routes.ENTRANCE and e.cell<=Routes.EXIT and (e.next==-1 or (e.cell<Routes.EXIT and e.next==e.cell+1)) and not e.get("frenzied",false) and e.get("frustration",0)==0 and e.get("frenzy_target",-1)==-1 and e.attack==0 and e.get("burn_left",0)==0

static func plan(level: int, garden_level: int = 1) -> Array:
	var result: Array = []
	var pattern: Array = GROUPS[(level-1)%20].duplicate(true)
	# Later cycles vary the order while preserving a bounded enemy count.
	if ((level-1)/20)%2 == 1: pattern.reverse()
	for group in pattern:
		for i in range(group[1]): result.append({"kind":group[0], "boss":-1})
	# Two mixed waves out of three, beginning with wave one. Replace evenly
	# spaced ground units; health and bounty remain fixed wave-wide budgets.
	if garden_level>=2 and level%3!=2:
		var count := maxi(1,roundi(result.size()*(0.15+0.05*(garden_level-2))))
		for i in range(count): result[(i+1)*result.size()/(count+1)]={"kind":MOTH,"boss":-1}
	if level%10 == 0:
		result.insert(result.size()/2, {"kind":2, "boss":((level/10)-1)%4})
	return result

static func preview(level: int, garden_level: int = 1) -> String:
	var parts: Array[String] = []
	var counts := {}
	for entry in plan(level,garden_level):
		if entry.boss<0: counts[entry.kind]=int(counts.get(entry.kind,0))+1
	for kind in counts: parts.append("%d %s%s" % [counts[kind],FOES[kind].name," (air)" if kind==MOTH else ""])
	return " · ".join(parts)

static func title(level: int) -> String:
	return BOSSES[((level/10)-1)%4].name if level%10 == 0 else TITLES[(level-1)%20]
