class_name Frenzy
extends RefCounted

const LIMIT := 12.0
const KEYS := ["visited", "frustration", "frenzied", "frenzy_target"]

static func initialize(e: Dictionary) -> void:
	e.visited=[int(e.cell)]; e.frustration=0.0; e.frenzied=false; e.frenzy_target=-1

static func arrive(e: Dictionary, destination: int) -> void:
	if not e.has("visited"): initialize(e)
	if destination in e.visited:
		e.frustration=minf(LIMIT,e.frustration+Routes.step_length(e.cell,destination))
		if e.frustration>=LIMIT: e.frenzied=true
	else: e.visited.append(destination)

static func valid(e: Dictionary, occupied: Dictionary, progress: PackedFloat64Array = PackedFloat64Array(), terrain: Dictionary = {}) -> bool:
	var present := 0
	for key in KEYS:
		if e.has(key): present+=1
	if present==0: return true # Older saves start tracking at the restored cell.
	if present!=KEYS.size(): return false
	if not e.visited is Array or e.visited.is_empty() or e.visited.size()>256: return false
	var seen := {}
	for cell in e.visited:
		if not PowerupSave.number(cell,0,255,true) or seen.has(int(cell)): return false
		if terrain.has(int(cell)): return false
		seen[int(cell)]=true
	if not seen.has(int(e.cell)): return false
	if not PowerupSave.number(e.frustration,0,LIMIT) or not e.frenzied is bool: return false
	if e.frenzied!=(e.frustration>=LIMIT): return false
	if not PowerupSave.number(e.frenzy_target,-1,255,true): return false
	var target := int(e.frenzy_target)
	if target>=0:
		if terrain.has(target): return false
		if not e.frenzied or e.next>=0: return false
		if target not in Routes.neighbors(int(e.cell),occupied): return false
		if not advancing(int(e.cell),target,progress): return false
	if e.frenzied and e.next>=0 and not advancing(int(e.cell),int(e.next),progress): return false
	return true

static func advancing(from: int, to: int, progress: PackedFloat64Array) -> bool:
	return progress[to]<progress[from]-0.000001 if not progress.is_empty() else Routes.exit_distance_squared(to)<Routes.exit_distance_squared(from)

static func restore(e: Dictionary) -> void:
	if not e.has("visited"): initialize(e)
	else:
		for i in range(e.visited.size()): e.visited[i]=int(e.visited[i])
		e.frenzy_target=int(e.frenzy_target)
