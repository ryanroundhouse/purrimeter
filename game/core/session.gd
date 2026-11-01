class_name Session
extends RefCounted
signal sound(name: String, tier: int)
signal changed
signal notice(message: String)
var achievements := Achievements.new()
var achievement_run: Dictionary = {}
var viewed_skins: Dictionary = {} # Remote presentation only; never grants ownership.

func skin_id(kind: int) -> String:
	return viewed_skins.get(str(kind),CatSkins.selected(achievements,kind))

var towers: Array = []
var enemies: Array = []
var shots: Array = []
var coins := Amount.of(200)
var level := 1 # Challenge ready to start, or currently active. Never last-completed.
var best := 0
var run_best := 0
var rebirths := 0
var bonus_points := 0.0
var draft_ranks: Dictionary = {}
var draft_seed := randi_range(1,2147483646)
var pending_draft: Dictionary = {}
var draft_streak := 0
var draft_rescue_used := false
var training := 0
var kills := 0
var powerup_ranks: Dictionary = {}
var discovered: Dictionary = {"training":true}
var cat_milestones: Array = [0,0,0]
var combat_seed := 1234567
var aftershocks: Array = []
var active := false
var paused := false
var speed := 1
const AUTO_START_DELAY := 3.0
var auto_start := false
var auto_start_remaining := 0.0
var elapsed := 0.0
var spawned := 0
var spawn_clock := 0.0
var next_id := 1
var wave_plan: Array = []
var open_field: Dictionary = {}
var breach_fields: Dictionary = {}
var route_age := 0.0
var last_defeat := 0

func invalidate_routes() -> void:
	open_field.clear(); breach_fields.clear(); route_age=0.0

func cat_stat(t: Dictionary, key: String) -> float:
	var c: Dictionary = Balance.CATS[t.kind]
	match key:
		"range": return c.range+0.3*(t.tier-1)+0.15*powerup_rank("eyes")
		"interval": return c.interval/((1.0+0.12*(t.tier-1))*(1.0+0.08*powerup_rank("quick"))*(1.3 if powerup_rank("stand")>0 and t.hp<0.3 else 1.0)*DraftCombat.speed_factor(self,t))
		"hp_power": return log(c.hp)/log(10.0)+(t.tier-1)*log(1.65)/log(10.0)+training*log(1.25)/log(10.0)+log(1.0+0.15*powerup_rank("beds"))/log(10.0)
		"damage_power": return log(c.damage)/log(10.0)+(t.tier-1)*log(2.0)/log(10.0)+training*log(1.25)/log(10.0)
	return 0

func upgrade_cost(t: Dictionary) -> Amount:
	return Amount.of(Balance.CATS[t.kind].price*1.2*pow(1.8,t.tier-1)*(1.0-0.05*powerup_rank("equipment")))

func repair_cost(t: Dictionary) -> Amount:
	return Amount.from_power(t.spent).times(0.4*(1.0-t.hp)*(1.0-0.1*powerup_rank("repair")))

func refund(t: Dictionary) -> Amount:
	return Amount.from_power(t.spent).times(0.7*t.hp)

func powerup_rank(id: String) -> int:
	return training if id=="training" else int(powerup_ranks.get(id,0))

func draft_rank(id: String) -> int:
	return int(draft_ranks.get(id,0))

func choose_draft(id: String) -> bool:
	if pending_draft.is_empty() or id not in pending_draft.offers: return false
	draft_ranks[id]=draft_rank(id)+1
	if id==RebirthDraft.FALLBACK: bonus_points+=10.0
	pending_draft.clear(); paused=true; invalidate_routes()
	notice.emit("%s · rank %d. Start level 1 when ready."%[RebirthDraft.definition(id).name,draft_rank(id)])
	sound.emit("upgrade",6); changed.emit(); return true

func refresh_powerups() -> void:
	for t in towers: cat_milestones[t.kind]=maxi(cat_milestones[t.kind],t.tier)
	for row in Powerups.ITEMS:
		var id: String = row[0]
		if powerup_rank(id)>0 or Powerups.eligible(self,id,1): discovered[id]=true

func powerup_complete(id: String) -> bool:
	var d := Powerups.definition(id)
	return not d.is_empty() and d.cap>0 and powerup_rank(id)>=d.cap

func can_buy_powerup(id: String) -> bool:
	if not pending_draft.is_empty(): return false
	if Powerups.definition(id).is_empty() or powerup_complete(id): return false
	return Powerups.eligible(self,id,powerup_rank(id)+1) and coins.enough(Powerups.cost(id,powerup_rank(id)))

func buy_powerup(id: String) -> bool:
	if not can_buy_powerup(id): return false
	coins=coins.minus(Powerups.cost(id,powerup_rank(id)))
	if id=="training": training+=1
	else: powerup_ranks[id]=powerup_rank(id)+1
	discovered[id]=true; refresh_powerups()
	achievements.record(self,"powerup")
	invalidate_routes(); sound.emit("upgrade",6); changed.emit(); return true

func training_cost() -> Amount:
	return Powerups.cost("training",training)

func recruit_cost(kind: int) -> Amount:
	return Amount.of(Balance.CATS[kind].price*(1.0-0.05*powerup_rank("thrifty")))

func tower_at(cell: int) -> Dictionary:
	for t in towers:
		if t.cell==cell: return t
	return {}

func placement_error(cell: int, kind: int) -> String:
	if not pending_draft.is_empty(): return "Choose your rebirth improvement first."
	if cell < 0 or cell > 255: return "Choose a tile inside the garden."
	if cell == Routes.ENTRANCE or cell == Routes.EXIT: return "Keep the entrance and exit clear."
	if not tower_at(cell).is_empty(): return "A cat already guards this tile."
	for e in enemies:
		if e.cell==cell or e.next==cell: return "An enemy is crossing this tile."
		if cell in Routes.clearance_cells(e.cell,e.next): return "An enemy needs this corner clear while crossing."
		var committed: int = e.get("frenzy_target",-1)
		if committed==cell: return "A frenzied enemy is advancing into this tile."
		if cell in Routes.clearance_cells(e.cell,committed): return "A frenzied enemy needs this corner clear while attacking."
	if not coins.enough(recruit_cost(kind)): return "Not enough coins."
	return ""

func build(kind: int, cell: int) -> bool:
	var error := placement_error(cell,kind)
	if not error.is_empty(): notice.emit(error); return false
	var price := recruit_cost(kind)
	coins=coins.minus(price)
	towers.append({"cell":cell,"kind":kind,"tier":1,"hp":1.0,"spent":price.power,"cooldown":0.0,"flash":0.0})
	achievements.record(self,"build")
	refresh_powerups(); invalidate_routes(); sound.emit("build",1); changed.emit(); return true

func upgrade(cell: int) -> bool:
	if not pending_draft.is_empty(): return false
	var t := tower_at(cell)
	if t.is_empty() or t.tier>=6: return false
	var cost := upgrade_cost(t)
	if not coins.enough(cost): return false
	coins=coins.minus(cost); t.spent=Amount.from_power(t.spent).plus(cost).power; t.tier+=1
	achievements.record(self,"upgrade")
	refresh_powerups(); invalidate_routes(); sound.emit("upgrade",t.tier); changed.emit(); return true

func repair(cell: int) -> bool:
	if not pending_draft.is_empty(): return false
	var t := tower_at(cell)
	if t.is_empty() or t.hp>=0.999999: return false
	var cost := repair_cost(t)
	if not coins.enough(cost): return false
	coins=coins.minus(cost); t.hp=1.0
	achievements.record(self,"repair",{"cell":cell})
	refresh_powerups(); invalidate_routes(); sound.emit("build",1); changed.emit(); return true

func sell(cell: int) -> bool:
	if not pending_draft.is_empty(): return false
	var t := tower_at(cell)
	if t.is_empty(): return false
	coins=coins.plus(refund(t)); towers.erase(t)
	achievements.record(self,"sell",{"cell":cell})
	invalidate_routes(); recover(); sound.emit("coin",1); changed.emit(); return true

func train() -> bool:
	return buy_powerup("training")

func can_rebirth() -> bool:
	return run_best>=5 and pending_draft.is_empty()

func set_auto_start(enabled: bool) -> void:
	if not pending_draft.is_empty(): return
	if auto_start==enabled: return
	auto_start=enabled
	auto_start_remaining=AUTO_START_DELAY if enabled and not active and last_defeat==0 and level>1 and run_best>=level-1 else 0.0
	changed.emit()

func rebirth() -> bool:
	if not can_rebirth(): return false
	var depth := run_best
	rebirths+=1
	pending_draft={"depth":depth,"rebirth":rebirths,"offers":RebirthDraft.draw(self,depth)}
	run_best=0; level=1; active=false; last_defeat=0; draft_streak=0
	enemies.clear(); shots.clear(); aftershocks.clear(); wave_plan.clear(); spawned=0; spawn_clock=0
	for t in towers: t.hp=1.0; t.cooldown=0.0; t.flash=0.0
	DraftCombat.reset_attempt(self)
	paused=true; auto_start_remaining=0.0; refresh_powerups(); invalidate_routes(); sound.emit("rebirth",6)
	achievements.record(self,"rebirth")
	notice.emit("REBIRTH DRAFT · Choose one permanent improvement.")
	changed.emit(); return true

func recover() -> void:
	if level==1 and towers.is_empty() and not coins.enough(Amount.of(50)):
		coins=Amount.of(50)

func defeat() -> void:
	if not pending_draft.is_empty(): return
	draft_streak=0
	achievements.record(self,"defeat")
	last_defeat=level; level=maxi(1,level-1); active=false; paused=true; auto_start_remaining=0.0
	enemies.clear(); shots.clear(); aftershocks.clear(); wave_plan.clear(); spawned=0; spawn_clock=0
	invalidate_routes(); recover(); sound.emit("lose",1)
	notice.emit("A foe escaped level %d. Regroup at level %d — your coins and surviving cats remain." % [last_defeat,level])
	changed.emit()

func start() -> bool:
	if active or not pending_draft.is_empty(): return false
	DraftCombat.reset_attempt(self)
	wave_plan=Balance.plan(level); spawned=0; spawn_clock=0; active=true; paused=false; auto_start_remaining=0.0
	achievements.record(self,"start")
	last_defeat=0; sound.emit("wave",1); notice.emit("Level %d · %s" % [level,Balance.title(level)]); changed.emit(); return true

func foe_speed(e: Dictionary) -> float:
	var base: float = Balance.BOSSES[e.boss].speed if e.boss>=0 else Balance.FOES[e.kind].speed
	return base*(0.52-0.04*powerup_rank("chill") if e.slow>0 else 1.0)

func foe_dps(e: Dictionary) -> float:
	var base: float = Balance.BOSSES[e.boss].dps if e.boss>=0 else Balance.FOES[e.kind].dps
	var reduction := 0.06*powerup_rank("fur")+(0.1*draft_rank("guard") if e.slow>0 else 0.0)
	return base*(1.0+0.04*(level-1))*(1.0-minf(0.6,reduction))

func field_for(e: Dictionary, cell: int) -> Dictionary:
	var frenzied: bool = e.get("frenzied",false)
	if open_field.is_empty():
		var blockers := {}
		for t in towers: blockers[t.cell]=-1.0
		open_field=Routes.field(blockers)
	if not frenzied and open_field.distance[cell]<Routes.INF: return open_field
	var key: String = "%d:%d:%d:%d" % [e.kind,e.boss,int(e.slow>0),int(frenzied)]
	if not breach_fields.has(key):
		var costs := {}
		for t in towers:
			costs[t.cell]=destruction_time(e,t)
		breach_fields[key]=Routes.field(costs,foe_speed(e),frenzied)
	return breach_fields[key]

func destruction_time(e: Dictionary, t: Dictionary) -> float:
	if t.is_empty(): return 0.0
	var health: float = t.hp+(0.35 if draft_rank("lives")>0 and not draft_rescue_used else 0.0)
	return pow(10.0,clampf(cat_stat(t,"hp_power")+log(maxf(health,1e-300))/log(10.0)-log(foe_dps(e))/log(10.0),-300,150))

func position(e: Dictionary) -> Vector2:
	var start := Vector2(e.cell%16,e.cell/16)
	if e.next>=0: return start.lerp(Vector2(e.next%16,e.next/16),e.progress)
	return start

func remaining(e: Dictionary) -> float:
	var cell: int = e.next if e.next>=0 else e.cell
	var committed: int = e.get("frenzy_target",-1)
	if committed>=0:
		return destruction_time(e,tower_at(committed))+Routes.step_length(e.cell,committed)/foe_speed(e)+field_for(e,committed).distance[committed]
	var f := field_for(e,cell)
	var time: float = f.distance[cell]
	if not e.get("frenzied",false) and open_field.distance[cell]<Routes.INF: time/=foe_speed(e)
	return time+((1.0-e.progress)*Routes.step_length(e.cell,e.next)/foe_speed(e) if e.next>=0 else 0.0)

func preview_route() -> Array[int]:
	var dummy := {"kind":0,"boss":-1,"slow":0.0}
	var f := field_for(dummy,Routes.ENTRANCE)
	var route: Array[int] = [Routes.ENTRANCE]
	for i in range(256):
		var next: int = f.next[route.back()]
		if next<0 or next in route: break
		route.append(next)
		if next==Routes.EXIT: break
	return route

func normal_wave_weight() -> float:
	var normal_weight := 0.0
	for item in wave_plan:
		if item.boss<0: normal_weight+=Balance.FOES[item.kind].weight
	return normal_weight

func enemy_health_share(entry: Dictionary, normal_weight: float) -> float:
	if entry.boss>=0: return 0.6
	return Balance.FOES[entry.kind].weight/normal_weight*(0.4 if level%10==0 else 1.0)

func level_health_fraction() -> float:
	if not active or wave_plan.is_empty(): return 0.0
	var remaining_health := 0.0
	var normal_weight := normal_wave_weight()
	for i in range(spawned,wave_plan.size()):
		remaining_health+=enemy_health_share(wave_plan[i],normal_weight)
	# Ratios stay finite even when absolute level health exceeds floating-point range.
	var total_power := Balance.health_power(level)
	for e in enemies:
		remaining_health+=pow(10.0,e.hp_power-total_power)*clampf(e.hp,0.0,1.0)
	return clampf(remaining_health,0.0,1.0)

func spawn_enemy(entry: Dictionary) -> Dictionary:
	var share := enemy_health_share(entry,normal_wave_weight())
	var e := {"id":next_id,"kind":entry.kind,"boss":entry.boss,"cell":Routes.ENTRANCE,"next":-1,"progress":0.0,"hp":1.0,"hp_power":Balance.health_power(level)+log(share)/log(10.0),"bounty_power":Balance.bounty(level).times(share).power,"slow":0.0,"attack":0.0}
	Frenzy.initialize(e)
	next_id+=1; enemies.append(e)
	if entry.boss>=0: sound.emit("boss",1); notice.emit("BOSS INCOMING · "+Balance.BOSSES[entry.boss].name)
	return e

func damage(e: Dictionary, power: float) -> void:
	e.hp-=pow(10.0,clampf(power-e.hp_power,-300,100))

func step(dt: float, real_dt: float = -1.0) -> void:
	if paused or not pending_draft.is_empty(): return
	elapsed+=dt
	for shot in shots: shot.life-=dt
	shots=shots.filter(func(s): return s.life>0)
	for t in towers:
		t.flash=maxf(0,t.flash-dt); t.cooldown=maxf(0,t.cooldown-dt)
	if not active:
		if auto_start and auto_start_remaining>0.0:
			auto_start_remaining=maxf(0.0,auto_start_remaining-(dt if real_dt<0.0 else real_dt))
			if auto_start_remaining<=0.000001: start()
		return
	PowerupCombat.tick(self,dt)
	route_age+=dt
	if route_age>=0.4: breach_fields.clear(); route_age=0.0
	spawn_clock-=dt
	if spawned<wave_plan.size() and spawn_clock<=0:
		spawn_enemy(wave_plan[spawned]); spawned+=1
		spawn_clock+=maxf(0.3,0.9-0.03*((level-1)%20))
	var priorities := {}
	for e in enemies: priorities[e.id]=remaining(e)
	for t in towers:
		if t.cooldown>0: continue
		var center := Vector2(t.cell%16,t.cell/16)
		var target: Dictionary = {}
		var best_time := Routes.INF
		for e in enemies:
			if e.hp>0 and center.distance_to(position(e))<=cat_stat(t,"range") and priorities[e.id]<best_time:
				target=e; best_time=priorities[e.id]
		if target.is_empty(): continue
		t.cooldown=cat_stat(t,"interval"); t.flash=0.23
		var target_pos := position(target)
		shots.append({"from":center,"to":target_pos,"kind":t.kind,"tier":t.tier,"life":0.24})
		PowerupCombat.attack(self,t,target)
		sound.emit(["bolt","cannon","frost"][t.kind],t.tier)
	PowerupCombat.reward_dead(self)
	for e in enemies:
		e.slow=maxf(0,e.slow-dt); e.attack=maxf(0,e.attack-dt)
		if e.get("stun",0.0)>0: continue
		if e.next<0:
			if e.cell==Routes.EXIT: defeat(); return
			var next: int = e.get("frenzy_target",-1)
			if next<0: next=field_for(e,e.cell).next[e.cell]
			if next>=0:
				var blocker := tower_at(next)
				if not blocker.is_empty():
					if e.get("frenzied",false): e.frenzy_target=next
					achievements.fail_condition(self,"unhurt","A cat took damage during the attempt.")
					blocker.hp-=pow(10.0,clampf(log(foe_dps(e)*dt)/log(10.0)-cat_stat(blocker,"hp_power"),-300,100))
					e.attack=0.15
					if blocker.hp<=0 and not DraftCombat.rescue(self,blocker):
						DraftCombat.destroyed(self,blocker)
						towers.erase(blocker); achievements.record(self,"destroyed",{"cell":blocker.cell}); invalidate_routes(); sound.emit("break",1)
				else:
					e.next=next; e.progress=0.0; e.frenzy_target=-1
		if e.next>=0:
			e.progress+=foe_speed(e)*dt/Routes.step_length(e.cell,e.next)
			if e.progress>=1.0:
				Frenzy.arrive(e,e.next)
				e.cell=e.next; e.next=-1; e.progress=0.0
				if e.cell==Routes.EXIT: defeat(); return
	if spawned>=wave_plan.size() and enemies.is_empty():
		DraftCombat.clear_level(self)
		achievements.record(self,"clear")
		active=false; best=maxi(best,level); run_best=maxi(run_best,level); level+=1
		wave_plan.clear(); aftershocks.clear(); spawned=0; spawn_clock=0.0
		for t in towers: t.hp=minf(1.0,t.hp+0.05*powerup_rank("catnap"))
		refresh_powerups()
		auto_start_remaining=AUTO_START_DELAY if auto_start else 0.0
		sound.emit("clear",1)
		notice.emit("Level cleared. Next level in 3 seconds. Space pauses." if auto_start else "Level cleared. Prepare your patrol, train, or rebirth.")
		changed.emit()

func snapshot() -> Dictionary:
	refresh_powerups()
	return {"version":4,"draft_ranks":draft_ranks.duplicate(),"draft_seed":draft_seed,"pending_draft":pending_draft.duplicate(true),"draft_streak":draft_streak,"draft_rescue_used":draft_rescue_used,"achievements":achievements.snapshot(),"achievement_run":achievement_run.duplicate(true),"powerups":powerup_ranks.duplicate(true),"discovered":discovered.duplicate(true),"cat_milestones":cat_milestones.duplicate(),"combat_seed":combat_seed,"aftershocks":aftershocks.duplicate(true),"coins":coins.power,"towers":towers.duplicate(true),"enemies":enemies.duplicate(true),"level":level,"best":best,"run_best":run_best,"rebirths":rebirths,"bonus_points":bonus_points,"training":training,"kills":kills,"active":active,"spawned":spawned,"spawn_clock":spawn_clock,"next_id":next_id,"elapsed":elapsed,"last_defeat":last_defeat,"auto_start":auto_start,"auto_start_remaining":auto_start_remaining}

func restore(data: Dictionary) -> bool:
	# Validate everything before replacing the live run.
	var ints := ["level","best","run_best","rebirths","training","kills","spawned","next_id","last_defeat"]
	if data.get("version",0)!=2 and data.get("version",0)!=3 and data.get("version",0)!=4: return false
	if not PowerupSave.valid(data): return false
	if data.has("achievements") and not Achievements.valid(data.achievements): return false
	if not Achievements.valid_run(data.get("achievement_run",{})): return false
	var saved_attempt: Dictionary = data.get("achievement_run",{}).get("attempt",{})
	if not saved_attempt.is_empty() and (not data.get("active",false) or saved_attempt.level!=data.get("level")): return false
	for key in ints:
		if not data.has(key) or not (data[key] is float or data[key] is int) or not is_finite(float(data[key])) or data[key]<0 or data[key]>(9e15 if key in ["training","kills"] else 1e9): return false
	if data.level<1 or data.run_best>data.best: return false
	for key in ["coins","bonus_points","spawn_clock","elapsed"]:
		if not data.has(key) or not (data[key] is float or data[key] is int) or not is_finite(float(data[key])): return false
	if data.bonus_points<0 or not data.get("active") is bool: return false
	if not data.get("auto_start",false) is bool: return false
	var remaining_delay = data.get("auto_start_remaining",0.0)
	if not (remaining_delay is float or remaining_delay is int) or not is_finite(float(remaining_delay)) or remaining_delay<0.0 or remaining_delay>AUTO_START_DELAY: return false
	if remaining_delay>0.0 and (data.active or not data.get("auto_start",false) or data.last_defeat!=0 or data.level<=1 or data.run_best<data.level-1): return false
	if not data.get("towers") is Array or not data.get("enemies") is Array: return false
	if data.towers.size()>254 or data.enemies.size()>100: return false
	var cells := {}
	for t in data.towers:
		if not t is Dictionary: return false
		for key in ["cell","kind","tier","hp","spent","cooldown","flash"]:
			if not t.has(key) or not (t[key] is float or t[key] is int) or not is_finite(float(t[key])): return false
		if t.cell<0 or t.cell>255 or t.cell in [Routes.ENTRANCE,Routes.EXIT] or cells.has(int(t.cell)) or t.kind<0 or t.kind>2 or t.tier<1 or t.tier>6 or t.hp<=0 or t.hp>1: return false
		cells[int(t.cell)]=true
	var ids := {}
	for e in data.enemies:
		if not e is Dictionary: return false
		for key in ["id","kind","boss","cell","next","progress","hp","hp_power","bounty_power","slow","attack"]:
			if not e.has(key) or not (e[key] is float or e[key] is int) or not is_finite(float(e[key])): return false
		if e.kind<0 or e.kind>3 or e.boss < -1 or e.boss>3 or e.cell<0 or e.cell>255 or e.next < -1 or e.next>255 or e.progress<0 or e.progress>=1 or e.hp<=0 or e.hp>1 or ids.has(int(e.id)): return false
		if e.next>=0 and not int(e.next) in Routes.neighbors(int(e.cell),cells): return false
		if cells.has(int(e.cell)) or cells.has(int(e.next)): return false
		if not Frenzy.valid(e,cells): return false
		ids[int(e.id)]=true
	var plan := Balance.plan(int(data.level))
	if data.spawned>plan.size() or (not data.active and not data.enemies.is_empty()): return false
	if not DraftSave.valid(data): return false
	for key in ints: set(key,int(data[key]))
	auto_start=data.get("auto_start",false); auto_start_remaining=float(remaining_delay)
	coins=Amount.from_power(float(data.coins)); bonus_points=float(data.bonus_points); spawn_clock=float(data.spawn_clock); elapsed=float(data.elapsed); active=data.active
	towers=data.towers.duplicate(true); enemies=data.enemies.duplicate(true)
	for t in towers:
		for key in ["cell","kind","tier"]: t[key]=int(t[key])
	for e in enemies:
		for key in ["id","kind","boss","cell","next"]: e[key]=int(e[key])
		Frenzy.restore(e)
	PowerupSave.apply(self,data)
	DraftSave.apply(self,data)
	refresh_powerups()
	achievement_run=data.get("achievement_run",{}).duplicate(true)
	if data.has("achievements"): achievements.merge(data.achievements)
	else: achievements.credit_saved(self)
	if data.version<4: achievements.highest("rebirths",rebirths); achievements.evaluate(true)
	wave_plan=plan if active else []; paused=true; shots.clear(); invalidate_routes(); return true
