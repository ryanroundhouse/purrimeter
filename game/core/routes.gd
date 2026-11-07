class_name Routes
extends RefCounted
const EXIT := 143 # (15,8)
const ENTRANCE := 128
const INF := 1.0e200

static func clearance_cells(from: int, to: int) -> Array[int]:
	if to < 0 or from%16 == to%16 or from/16 == to/16: return []
	return [from/16*16+to%16, to/16*16+from%16]

static func step_length(from: int, to: int) -> float:
	return sqrt(2.0) if from%16 != to%16 and from/16 != to/16 else 1.0

static func neighbors(cell: int, occupied: Dictionary = {}) -> Array[int]:
	var out: Array[int] = []
	var x := cell%16
	var y := cell/16
	if x < 15: out.append(cell+1)
	if y > 0: out.append(cell-16)
	if y < 15: out.append(cell+16)
	if x > 0: out.append(cell-1)
	for dy in [-1,1]:
		for dx in [-1,1]:
			if x+dx < 0 or x+dx > 15 or y+dy < 0 or y+dy > 15: continue
			var diagonal: int = cell+dy*16+dx
			var sides := clearance_cells(cell,diagonal)
			if not occupied.has(sides[0]) and not occupied.has(sides[1]): out.append(diagonal)
	return out

static func exit_distance_squared(cell: int) -> int:
	var dx := EXIT%16-cell%16
	var dy := EXIT/16-cell/16
	return dx*dx+dy*dy

static func field(costs: Dictionary, speed: float = 1.0, forward_only: bool = false, progress: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
	# Keys are occupied tower or terrain cells: negative costs block entry; nonnegative
	# costs include destruction time. Occupied side cells always block diagonals,
	# including attacks. Rebuild the field when a tower is destroyed.
	var distance := PackedFloat64Array()
	var next := PackedInt32Array()
	var used := PackedByteArray()
	distance.resize(256); distance.fill(INF)
	next.resize(256); next.fill(-1)
	used.resize(256); used.fill(0)
	distance[EXIT] = 0
	for iteration in range(256):
		var at := -1
		var best := INF
		for i in range(256):
			if used[i] == 0 and distance[i] < best:
				at=i; best=distance[i]
		if at < 0: break
		used[at]=1
		if costs.get(at,0.0) < 0: continue
		for n in neighbors(at,costs):
			if costs.get(n,0.0) < 0: continue
			# Reverse search: a forward-only predecessor must be farther away.
			if forward_only:
				if not progress.is_empty():
					if progress[n]<=progress[at]+0.000001: continue
				elif exit_distance_squared(n)<=exit_distance_squared(at): continue
			var candidate: float = best+step_length(n,at)/speed+costs.get(at,0.0)
			if candidate < distance[n]:
				distance[n]=candidate; next[n]=at
	return {"distance":distance, "next":next}
