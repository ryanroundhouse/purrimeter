class_name DraftCombat
extends RefCounted
## Primary-hit synergies only. Bonus damage uses Session.damage, never attack.
static func speed_factor(g, t: Dictionary) -> float:
	var rank: int = g.draft_rank("mixed")
	if rank==0: return 1.0
	var cell := Vector2(t.cell%16,t.cell/16)
	for other in g.towers:
		if other.kind!=t.kind and cell.distance_squared_to(Vector2(other.cell%16,other.cell/16))<=4.0: return 1.0+0.08*rank
	return 1.0

static func primary(g, t: Dictionary, e: Dictionary, base: float, was_burning: bool) -> void:
	var point: Vector2 = g.position(e)
	if t.kind==0 and g.draft_rank("spotter")>0: e["spotter_left"]=3.0
	if t.kind==1:
		var extra := 0.0
		if e.get("spotter_left",0.0)>0 and g.draft_rank("spotter")>0:
			extra+=0.25*g.draft_rank("spotter"); e.spotter_left=0.0
		if was_burning and e.slow>0: extra+=0.35*g.draft_rank("thermal")
		if extra>0: g.damage(e,base+log(extra)/log(10.0))
	if t.kind==2 and g.draft_rank("front")>0:
		var neighbors: Array = g.enemies.filter(func(other): return other.id!=e.id and other.hp>0 and g.position(other).distance_squared_to(point)<=2.25)
		neighbors.sort_custom(func(a,b): return g.position(a).distance_squared_to(point)<g.position(b).distance_squared_to(point))
		for other in neighbors.slice(0,g.draft_rank("front")): other.slow=maxf(other.slow,1.8+0.4*g.powerup_rank("linger"))
	if e.hp<=0 or g.draft_rank("triad")==0 or e.get("triad_until",0.0)>g.elapsed: return
	var marks: Array = e.get("triad_marks",[-1.0,-1.0,-1.0])
	marks[t.kind]=g.elapsed; e["triad_marks"]=marks
	if marks.all(func(at): return at>=0.0 and g.elapsed-at<=3.0):
		g.damage(e,base+log(0.5*g.draft_rank("triad"))/log(10.0))
		e.triad_marks=[-1.0,-1.0,-1.0]; e["triad_until"]=g.elapsed+3.0

static func death(g, e: Dictionary) -> void:
	if g.draft_rank("steady")>0:
		for t in g.towers:
			if t.get("focus_target",0)==e.id:
				t["focus_credit"]=mini(int(t.get("focus_hits",0)),mini(5,2*g.draft_rank("steady")))
	if g.draft_rank("cinder")==0 or e.get("burn_left",0.0)<=0 or e.get("burn_relayed",false): return
	var neighbors: Array = g.enemies.filter(func(other): return other.hp>0 and g.position(other).distance_squared_to(g.position(e))<=4.0)
	neighbors.sort_custom(func(a,b): return g.position(a).distance_squared_to(g.position(e))<g.position(b).distance_squared_to(g.position(e)))
	if neighbors.is_empty(): return
	var other: Dictionary = neighbors[0]
	var power: float = e.burn_power+log(0.4+0.2*g.draft_rank("cinder"))/log(10.0)
	if other.get("burn_left",0.0)<=0 or power>other.get("burn_power",Amount.ZERO):
		other["burn_power"]=power; other["burn_left"]=e.burn_left; other["burn_relayed"]=true

static func rescue(g, t: Dictionary) -> bool:
	if g.draft_rank("lives")==0 or g.draft_rescue_used: return false
	g.draft_rescue_used=true; t.hp=0.35; g.invalidate_routes()
	g.notice.emit("Nine Lives saved your %s. Charge returns next attempt."%Balance.CATS[t.kind].name)
	return true

static func destroyed(g, t: Dictionary) -> void:
	if g.draft_rank("salvage")>0: g.coins=g.coins.plus(Amount.from_power(t.spent).times(0.15*g.draft_rank("salvage")))

static func clear_level(g) -> void:
	g.draft_streak=mini(5,g.draft_streak+1)
	var fraction: float = 0.25*g.draft_rank("supply")+0.05*g.draft_rank("treasure")*g.draft_streak
	if fraction>0: g.coins=g.coins.plus(Balance.bounty(g.level).times(fraction))

static func reset_attempt(g) -> void:
	g.draft_rescue_used=false
	for t in g.towers:
		for key in ["focus_target","focus_hits","focus_credit"]: t.erase(key)
