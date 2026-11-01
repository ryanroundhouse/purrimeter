class_name CatSkins
extends RefCounted
## Stable cosmetic identities. Achievement ownership is the only unlock authority.
const ITEMS := [
	["scout_default","Tuxedo Scout",0,"","tuxedo"],
	["scout_ginger","Ginger Scout",0,"first","skins/scout_ginger"],
	["scout_silver","Silver Scout",0,"bolt","skins/scout_silver"],
	["scout_calico","Calico Scout",0,"recruits","skins/scout_calico"],
	["scout_golden","Golden Scout",0,"level50","skins/scout_golden"],
	["gunner_default","Orange Tabby",1,"","chunky"],
	["gunner_smoky","Smoky Gunner",1,"upgrade","skins/gunner_smoky"],
	["gunner_tiger","Tiger Gunner",1,"cannon","skins/gunner_tiger"],
	["gunner_snow","Snow Gunner",1,"bosses","skins/gunner_snow"],
	["gunner_royal","Royal Gunner",1,"dream","skins/gunner_royal"],
	["sage_default","Black Sage",2,"","siamese"],
	["sage_classic","Classic Siamese",2,"power","skins/sage_classic"],
	["sage_silver","Silver Sage",2,"cold","skins/sage_silver"],
	["sage_lilac","Lilac Sage",2,"ranks","skins/sage_lilac"],
	["sage_aurora","Aurora Sage",2,"toys","skins/sage_aurora"],
]
const DEFAULTS := ["scout_default","gunner_default","sage_default"]

static func item(id: String) -> Array:
	for row in ITEMS:
		if row[0]==id: return row
	return []

static func for_kind(kind: int) -> Array:
	return ITEMS.filter(func(row): return row[2]==kind)

static func reward(achievement: String) -> String:
	if achievement.is_empty(): return ""
	for row in ITEMS:
		if row[3]==achievement: return row[0]
	return ""

static func unlocked(book, id: String) -> bool:
	var row := item(id)
	return not row.is_empty() and (row[3].is_empty() or book.earned.has(row[3]))

static func selected(book, kind: int) -> String:
	var id: String = book.skin_choices.get(str(kind),DEFAULTS[kind])
	return id if unlocked(book,id) and item(id)[2]==kind else DEFAULTS[kind]

static func equip(book, kind: int, id: String) -> bool:
	if kind<0 or kind>2 or not unlocked(book,id) or item(id)[2]!=kind: return false
	book.skin_choices[str(kind)]=id
	return true

static func valid_choices(data) -> bool:
	if not data is Dictionary or data.size()>3: return false
	for key in data:
		if key not in ["0","1","2"] or not data[key] is String: return false
		var row := item(data[key])
		if row.is_empty() or row[2]!=int(key): return false
	return true

static func valid_seen(data) -> bool:
	if not data is Array or data.size()>12: return false
	var seen := {}
	for id in data:
		if not id is String: return false
		var row := item(id)
		if row.is_empty() or row[3].is_empty() or seen.has(id): return false
		seen[id]=true
	return true

static func unseen_rewards(book) -> Array:
	var result := []
	for row in ITEMS:
		if not row[3].is_empty() and unlocked(book,row[0]) and row[0] not in book.seen_skins: result.append(row[0])
	return result
