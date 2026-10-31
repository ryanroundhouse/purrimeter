class_name PowerupCombat
extends RefCounted
## Secondary hits never recurse into on-hit effects. Damage stays logarithmic.
static func roll(g, chance: float) -> bool:
	if chance<=0: return false
	g.combat_seed=(g.combat_seed*48271)%2147483647
	return float(g.combat_seed)/2147483647.0<chance

static func hit_power(g, t: Dictionary, e: Dictionary, base: float) -> float:
	var multiplier := 1.0
	if e.slow>0 and t.kind!=2: multiplier*=1.0+0.08*g.powerup_rank("brittle")
	if t.kind==0:
		if e.boss>=0: multiplier*=1.0+0.2*g.powerup_rank("giant")
		if e.hp<0.3: multiplier*=1.0+0.15*g.powerup_rank("finish")
	elif t.kind==1 and e.attack>0: multiplier*=1.0+0.2*g.powerup_rank("siege")
	return base+log(multiplier)/log(10.0)

static func control(e: Dictionary, duration: float) -> bool:
	if e.get("control_guard",0.0)>0.0: return false
	e["stun"]=minf(duration,0.3) if e.boss>=0 else duration
	# Shared freeze/stun immunity prevents multiple cats from locking a target.
	e["control_guard"]=e.stun+(3.0 if e.boss>=0 else 0.8)
	return true

static func attack(g, t: Dictionary, target: Dictionary) -> void:
	var center := Vector2(t.cell%16,t.cell/16)
	var point: Vector2 = g.position(target)
	var base: float = g.cat_stat(t,"damage_power")
	if roll(g,0.04*g.powerup_rank("lucky")):
		base+=log(2.0+0.25*g.powerup_rank("heavy"))/log(10.0)
	if t.kind==0:
		var stacks: int = mini(5,int(t.get("focus_hits",0))) if t.get("focus_target",-1)==target.id else 0
		t["focus_target"]=target.id; t["focus_hits"]=mini(5,stacks+1)
		base+=log(1.0+stacks*0.04*g.powerup_rank("focus"))/log(10.0)
		g.damage(target,hit_power(g,t,target,base))
		var pierced: Array = []
		var direction := (point-center).normalized()
		for e in g.enemies:
			if e.id==target.id or e.hp<=0: continue
			var offset: Vector2 = g.position(e)-point
			if offset.dot(direction)>0 and offset.dot(direction)<=3.0 and absf(offset.cross(direction))<=0.45:
				pierced.append(e)
		pierced.sort_custom(func(a,b): return g.position(a).distance_squared_to(point)<g.position(b).distance_squared_to(point))
		for i in range(mini(pierced.size(),g.powerup_rank("needle"))):
			var e: Dictionary = pierced[i]
			g.damage(e,hit_power(g,t,e,base+log(0.6)/log(10.0)))
			g.shots.append({"from":point,"to":g.position(e),"kind":0,"tier":t.tier,"life":0.24})
		var arcs: Array = g.enemies.filter(func(e): return e.id!=target.id and e.hp>0 and g.position(e).distance_to(point)<=2.0)
		arcs.sort_custom(func(a,b): return g.position(a).distance_squared_to(point)<g.position(b).distance_squared_to(point))
		for i in range(mini(arcs.size(),g.powerup_rank("static"))):
			var e: Dictionary = arcs[i]
			g.damage(e,hit_power(g,t,e,base+log(0.35)/log(10.0)))
			g.shots.append({"from":point,"to":g.position(e),"kind":0,"tier":t.tier,"life":0.24})
	elif t.kind==1:
		var radius: float = 1.35+0.15*g.powerup_rank("blast")
		for e in g.enemies:
			if e.hp<=0 or g.position(e).distance_to(point)>radius: continue
			var power := hit_power(g,t,e,base)
			g.damage(e,power)
			var burn: int = g.powerup_rank("embers")
			if burn>0:
				var burn_power := power+log(0.08*burn)/log(10.0)
				if e.get("burn_left",0.0)<=0 or burn_power>=e.get("burn_power",Amount.ZERO):
					e["burn_power"]=burn_power; e["burn_left"]=3.0
			if roll(g,0.1*g.powerup_rank("concussion")): control(e,0.45)
		if g.powerup_rank("aftershock")>0:
			g.aftershocks.append({"x":point.x,"y":point.y,"radius":radius,"power":base+log(0.4)/log(10.0),"delay":0.45,"tier":t.tier})
	else:
		g.damage(target,hit_power(g,t,target,base))
		target.slow=maxf(target.slow,1.8+0.4*g.powerup_rank("linger"))
		target["frost_hits"]=int(target.get("frost_hits",0))+1
		if g.powerup_rank("lock")>0 and target.frost_hits%4==0: control(target,0.3*g.powerup_rank("lock"))

static func tick(g, dt: float) -> void:
	for e in g.enemies:
		e["stun"]=maxf(0,e.get("stun",0.0)-dt)
		e["control_guard"]=maxf(0,e.get("control_guard",0.0)-dt)
		var burn_time: float = minf(dt,e.get("burn_left",0.0))
		if burn_time>0 and e.hp>0:
			g.damage(e,e.burn_power+log(burn_time)/log(10.0))
			e.burn_left=maxf(0,e.burn_left-dt)
	for echo in g.aftershocks:
		echo.delay-=dt
		if echo.delay>0: continue
		var point := Vector2(echo.x,echo.y)
		for e in g.enemies:
			if e.hp>0 and g.position(e).distance_to(point)<=echo.radius:
				g.damage(e,hit_power(g,{"kind":1},e,echo.power))
		g.shots.append({"from":point,"to":point,"kind":1,"tier":int(echo.tier),"life":0.24})
	g.aftershocks=g.aftershocks.filter(func(echo): return echo.delay>0)
	for t in g.towers: t.hp=minf(1.0,t.hp+0.002*g.powerup_rank("aid")*dt)

static func reward_dead(g) -> void:
	var any_kills := false
	for e in g.enemies:
		if e.hp>0: continue
		var multiplier: float = (1.0+g.bonus_points/100.0)*(1.0+0.1*g.powerup_rank("bounty"))
		if e.boss>=0: multiplier*=1.0+0.2*g.powerup_rank("purse")
		g.coins=g.coins.plus(Amount.from_power(e.bounty_power).times(multiplier)); g.kills+=1
		g.sound.emit("coin",1); any_kills=true
		if e.slow>0 and g.powerup_rank("winter")>0:
			for other in g.enemies:
				if other.hp>0 and g.position(other).distance_to(g.position(e))<=1.5: other.slow=maxf(other.slow,1.2)
	g.enemies=g.enemies.filter(func(e): return e.hp>0)
	if any_kills: g.refresh_powerups()
