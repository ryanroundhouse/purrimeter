class_name Balance
extends RefCounted
const CATS = [
	{"name":"Tuxedo Scout", "role":"BOLT · Fast single target", "price":50.0, "hp":160.0, "damage":14.0, "interval":0.48, "range":3.4, "color":Color("ffc46b")},
	{"name":"Chunky Gunner", "role":"CANNON · Explosive splash", "price":80.0, "hp":260.0, "damage":36.0, "interval":1.65, "range":3.0, "color":Color("fb8875")},
	{"name":"Siamese Sage", "role":"FROST · Slows the swarm", "price":70.0, "hp":180.0, "damage":5.0, "interval":0.85, "range":2.8, "color":Color("78cfff")}
]
const FOES = [
	{"name":"Grunt", "weight":38.0, "speed":1.25, "dps":12.0},
	{"name":"Runner", "weight":27.0, "speed":2.1, "dps":8.0},
	{"name":"Brute", "weight":150.0, "speed":0.78, "dps":22.0},
	{"name":"Breaker", "weight":80.0, "speed":1.05, "dps":48.0}
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

static func plan(level: int) -> Array:
	var result: Array = []
	var pattern: Array = GROUPS[(level-1)%20].duplicate(true)
	# Later cycles vary the order while preserving a bounded enemy count.
	if ((level-1)/20)%2 == 1: pattern.reverse()
	for group in pattern:
		for i in range(group[1]): result.append({"kind":group[0], "boss":-1})
	if level%10 == 0:
		result.insert(result.size()/2, {"kind":2, "boss":((level/10)-1)%4})
	return result

static func preview(level: int) -> String:
	var parts: Array[String] = []
	var pattern: Array = GROUPS[(level-1)%20].duplicate(true)
	if ((level-1)/20)%2 == 1: pattern.reverse()
	for group in pattern: parts.append("%d %s" % [group[1], FOES[group[0]].name])
	return " → ".join(parts)

static func title(level: int) -> String:
	return BOSSES[((level/10)-1)%4].name if level%10 == 0 else TITLES[(level-1)%20]
