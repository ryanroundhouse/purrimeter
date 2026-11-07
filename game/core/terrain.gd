class_name GardenTerrain
extends RefCounted
## Permanent garden geometry. Saved cells/styles, never regenerated on restore.
const ROCK := 0
const STREAM := 1
const STYLES := 3
var cells: Dictionary = {}
var _distance := PackedFloat64Array()

func blockers() -> Dictionary:
	var result := {}
	for cell in cells: result[cell]=-1.0
	return result

func distances() -> PackedFloat64Array:
	if _distance.is_empty(): _distance=Routes.field(blockers()).distance
	return _distance

func snapshot() -> Array:
	var result := []
	var ordered := cells.keys(); ordered.sort()
	for cell in ordered: result.append({"cell":cell,"kind":cells[cell].kind,"style":cells[cell].style})
	return result

func description(cell: int, recruiting: bool = false) -> String:
	if not cells.has(cell): return ""
	var name: String = "Rocks" if cells[cell].kind==ROCK else "Streams"
	return name+" block recruitment." if recruiting else name+" block movement and recruitment. They cannot be destroyed."

static func adjacent(cell: int, diagonal: bool = false) -> Array[int]:
	var result: Array[int] = []
	for dy in range(-1,2):
		for dx in range(-1,2):
			if (dx==0 and dy==0) or (not diagonal and dx!=0 and dy!=0): continue
			var x := cell%16+dx; var y := cell/16+dy
			if x>=0 and x<16 and y>=0 and y<16: result.append(y*16+x)
	return result

static func gate_approach(cell: int) -> bool:
	return cell/16 in [7,8,9] and cell%16 in [0,1,14,15]

static func connected(occupied: Dictionary) -> bool:
	if occupied.has(Routes.ENTRANCE) or occupied.has(Routes.EXIT): return false
	# Cardinal reachability is equivalent to eight-way reachability without corner cutting.
	var seen := {Routes.EXIT:true}; var queue: Array[int] = [Routes.EXIT]; var index := 0
	while index<queue.size():
		for n in adjacent(queue[index]):
			if not occupied.has(n) and not seen.has(n): seen[n]=true; queue.append(n)
		index+=1
	return seen.size()+occupied.size()==256

static func decode(rows) -> GardenTerrain:
	if not rows is Array or rows.size()>64: return null
	var result := GardenTerrain.new()
	for row in rows:
		if not row is Dictionary or row.size()!=3: return null
		if not PowerupSave.number(row.get("cell"),0,255,true) or not PowerupSave.number(row.get("kind"),ROCK,STREAM,true) or not PowerupSave.number(row.get("style"),0,STYLES-1,true): return null
		var cell := int(row.cell)
		if result.cells.has(cell) or gate_approach(cell): return null
		result.cells[cell]={"kind":int(row.kind),"style":int(row.style)}
	for cell in result.cells:
		for n in adjacent(cell,true):
			if result.cells.has(n) and result.cells[n].kind==result.cells[cell].kind and result.cells[n].style!=result.cells[cell].style: return null
	if not connected(result.cells): return null
	return result

static func generate(seed_value: int = 0) -> GardenTerrain:
	var rng := RandomNumberGenerator.new()
	if seed_value==0: rng.randomize()
	else: rng.seed=seed_value
	for attempt in range(32):
		var result := GardenTerrain.new()
		var water_style := rng.randi_range(0,STYLES-1)
		var x := rng.randi_range(4,10)
		var transpose := rng.randi_range(0,1)==1
		for y in range(2,14):
			if y in [5,8,11]:
				var end := clampi(x+rng.randi_range(-2,2),3,12)
				while x!=end:
					result.cells[(x*16+y) if transpose else (y*16+x)]={"kind":STREAM,"style":water_style}
					x+=1 if end>x else -1
			result.cells[(x*16+y) if transpose else (y*16+x)]={"kind":STREAM,"style":water_style}
		var target := rng.randi_range(39,51)
		for placement in range(600):
			if result.cells.size()>=target: break
			var cluster: Array[int] = [rng.randi_range(0,255)]
			var count := mini(rng.randi_range(1,4),target-result.cells.size())
			for growth in range(12):
				if cluster.size()>=count: break
				var candidates := adjacent(cluster[rng.randi_range(0,cluster.size()-1)])
				var n := candidates[rng.randi_range(0,candidates.size()-1)]
				if n not in cluster: cluster.append(n)
			var allowed := true
			for cell in cluster:
				if gate_approach(cell) or result.cells.has(cell): allowed=false; break
				for n in adjacent(cell,true):
					if result.cells.has(n) and result.cells[n].kind==ROCK: allowed=false; break
			if not allowed: continue
			var style := rng.randi_range(0,STYLES-1)
			for cell in cluster: result.cells[cell]={"kind":ROCK,"style":style}
			if not connected(result.cells):
				for cell in cluster: result.cells.erase(cell)
		if result.cells.size()==target and connected(result.cells): return result
	# Bounded fallback: a known connected layout with 40 occupied tiles.
	var fallback := GardenTerrain.new()
	for y in range(2,14): fallback.cells[y*16+8]={"kind":STREAM,"style":rng.randi_range(0,STYLES-1)}
	var style := rng.randi_range(0,STYLES-1)
	for cell in fallback.cells: fallback.cells[cell].style=style
	for origin in [17,21,26,65,74,177,186]:
		style=rng.randi_range(0,STYLES-1)
		for offset in [0,1,16,17]: fallback.cells[origin+offset]={"kind":ROCK,"style":style}
	return fallback
