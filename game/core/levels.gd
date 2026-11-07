class_name GardenLevels
extends RefCounted
## Level selection and compatibility rules; Session.level remains the saved wave number.
const COUNT := 5
const NAMES := ["Open Meadow","Stone Garden","Winding Brook","Twin Streams","Wildwater"]
const TERRAIN := [
	{"streams":0,"min_tiles":10,"max_tiles":14,"summary":"Sparse rocks · open ground"},
	{"streams":0,"min_tiles":28,"max_tiles":34,"summary":"Many rocks · no streams"},
	{"streams":1,"min_tiles":39,"max_tiles":45,"summary":"1 stream · scattered rocks"},
	{"streams":2,"min_tiles":46,"max_tiles":52,"summary":"2 streams · rocky banks"},
	{"streams":3,"min_tiles":56,"max_tiles":62,"summary":"3 streams · dense terrain"},
]

static func level_name(selected: int) -> String:
	return NAMES[clampi(selected,1,COUNT)-1]

static func terrain_profile(selected: int) -> Dictionary:
	return TERRAIN[clampi(selected,1,COUNT)-1]

static func wave_limit(selected: int) -> int:
	return selected*10 if selected<COUNT else 0

static func title(selected: int) -> String:
	return "Level %d · %s" % [selected,level_name(selected)]

static func legacy_unlock(best_wave: int) -> int:
	return clampi(best_wave/10+1,1,COUNT)

static func valid(data: Dictionary, unlocked: int) -> bool:
	if not PowerupSave.number(data.get("garden_level"),1,COUNT,true): return false
	if not data.get("completed") is bool or not data.get("legacy_endless") is bool: return false
	var selected := int(data.garden_level)
	if data.legacy_endless and selected!=COUNT: return false
	if selected>unlocked and not data.legacy_endless: return false
	var limit := wave_limit(selected)
	if limit==0: return not data.completed
	if data.level>limit or data.best>limit or data.run_best>limit: return false
	if data.completed:
		return data.level==limit and data.best==limit and data.run_best==limit and not data.active and data.auto_start_remaining==0 and data.pending_draft.is_empty()
	return data.best<limit
