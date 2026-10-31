extends SceneTree
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks+=1
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures+=1

func close(a: float, b: float) -> bool:
	return absf(a-b)<0.00001*maxf(1.0,absf(b))

func session() -> Session:
	var g := Session.new(); g.coins=Amount.of(1e12); g.start(); g.spawned=g.wave_plan.size()
	return g

func enemy(g: Session, cell: int = 128, kind: int = 0, boss: int = -1) -> Dictionary:
	var e := g.spawn_enemy({"kind":kind,"boss":boss}); e.cell=cell; e.hp_power=100.0
	Frenzy.initialize(e)
	return e

func cross(g: Session, e: Dictionary, to: int) -> void:
	e.next=to; e.progress=0.0
	g.step(Routes.step_length(e.cell,to)/g.foe_speed(e)+0.000001)

func enrage(e: Dictionary) -> void:
	e.frustration=Frenzy.LIMIT; e.frenzied=true

func build(g: Session, cell: int, hp: float = 1.0) -> void:
	g.build(1,cell); g.tower_at(cell).cooldown=10000; g.tower_at(cell).hp=hp

func json_copy(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data,"",true,true))

func _initialize() -> void:
	call_deferred("run")

func counting() -> void:
	for boss in [-1,0,1,2,3]:
		for kind in range(4 if boss<0 else 1):
			var g := session(); var e := enemy(g,128,kind,boss)
			cross(g,e,129)
			check(e.frustration==0,"first visit is free: kind %d boss %d"%[kind,boss])
			for i in range(11): cross(g,e,128 if e.cell==129 else 129)
			check(e.frustration==11 and not e.frenzied,"eleven repeated tiles tolerated: kind %d boss %d"%[kind,boss])
			cross(g,e,128 if e.cell==129 else 129)
			check(e.frustration==12 and e.frenzied,"twelfth repeated tile triggers frenzy: kind %d boss %d"%[kind,boss])
	var g := session(); var e := enemy(g,51)
	cross(g,e,68); cross(g,e,51)
	check(close(e.frustration,sqrt(2.0)),"diagonal revisit counts physical distance")
	cross(g,e,52)
	check(close(e.frustration,sqrt(2.0)),"new ground does not erase frustration")
	var before: float = e.frustration
	g.paused=true; build(g,100); g.sell(100); g.step(30)
	check(e.frustration==before,"paused construction and sale do not add frustration")
	g.paused=false; e.stun=0.8; e.control_guard=1.0; g.step(0.1)
	check(e.frustration==before and e.next==-1,"stun time does not add frustration")
	e.stun=0.0; e.slow=100.0; cross(g,e,51)
	check(close(e.frustration,before+1.0),"slow charges distance, not elapsed time")
	var fresh := enemy(g)
	check(fresh.frustration==0 and not fresh.frenzied,"new enemy has independent history")

func exploit() -> void:
	var g := session()
	for y in range(1,16): build(g,y*16+8,0.001)
	var e := enemy(g,8*16+7)
	var top_open := true
	var switches := 0
	var frenzy_switches := 0
	var saw_frenzy := false
	var monotonic := true
	for i in range(1600):
		if not g.active: break
		if not e.frenzied and e.next<0:
			if top_open and e.cell/16<=4:
				build(g,8,0.001); g.sell(248); top_open=false; switches+=1
			elif not top_open and e.cell/16>=11:
				build(g,248,0.001); g.sell(8); top_open=true; switches+=1
		elif e.frenzied and i%10==0:
			build(g,8 if top_open else 248,0.001)
			g.sell(248 if top_open else 8); top_open=not top_open; frenzy_switches+=1
		var was_frenzied: bool = e.frenzied
		var previous: int = e.cell
		g.step(0.1)
		if was_frenzied and previous!=e.cell:
			monotonic=monotonic and Routes.exit_distance_squared(e.cell)<Routes.exit_distance_squared(previous)
		saw_frenzy=saw_frenzy or e.frenzied
	check(switches>=2 and saw_frenzy,"alternating distant openings reproduces backtracking and triggers frenzy")
	check(frenzy_switches>0 and monotonic and not g.active and g.last_defeat==1,"continued opening switches cannot stop frenzied breach and escape")

func static_maze() -> void:
	var g := session()
	for x in [3,6,9,12]:
		var gap := 1 if x in [3,9] else 14
		for y in range(16):
			if y!=gap: build(g,y*16+x)
	var e := enemy(g)
	for i in range(2000):
		if not g.active: break
		g.step(0.1)
	check(not g.active and e.visited.size()>50 and e.frustration==0 and not e.frenzied,"long unchanged winding maze never triggers frenzy")

func routes_and_commitment() -> void:
	# Dense corner-touching obstacles still leave every forward-only route breachable.
	var costs := {}
	for cell in range(256):
		if cell not in [Routes.ENTRANCE,Routes.EXIT] and cell%3!=0: costs[cell]=10.0+cell%7
	var field := Routes.field(costs,1.0,true)
	var correct := true
	for cell in range(256):
		if cell==Routes.EXIT: continue
		var to: int = field.next[cell]
		correct=correct and to in Routes.neighbors(cell,costs) and Routes.exit_distance_squared(to)<Routes.exit_distance_squared(cell)
	check(correct,"forward-only routes from every square respect tower corners and reduce exit distance")
	var g := session(); build(g,135)
	var e := enemy(g,134); enrage(e)
	g.step(0.01)
	check(e.frenzy_target==135 and e.next==-1,"frenzy attacks an obstruction despite an open detour")
	var target := g.tower_at(135)
	var hp: float = target.hp
	build(g,100); g.repair(135); g.upgrade(135); g.step(0.01)
	check(e.frenzy_target==135 and target.hp<1.0,"repair, upgrade, and unrelated construction retain attack commitment")
	check(e.frustration==12 and close(g.foe_speed(e),1.25) and close(g.foe_dps(e),12.0),"attacking retains frenzy without stat boosts")
	var expected: float = g.destruction_time(e,target)+1.0/g.foe_speed(e)+g.field_for(e,135).distance[135]
	check(close(g.remaining(e),expected),"target priority includes committed destruction and forward route")
	e.stun=0.5; e.control_guard=1.0; hp=target.hp; g.step(0.1)
	check(target.hp==hp and e.next==-1 and e.frenzy_target==135,"stun still stops a frenzied attack")
	e.stun=0; e.slow=2.0
	check(close(g.foe_speed(e),1.25*0.52),"frenzy retains Frost vulnerability")
	g.sell(135)
	check(not g.build(0,135),"sold committed target stays reserved for advancement")
	g.step(0.01)
	check(e.next==135 and e.frenzy_target==-1,"sale makes enemy advance into committed opening")
	var move_time := g.remaining(e)
	check(close(move_time,(1.0-e.progress)/g.foe_speed(e)+g.field_for(e,135).distance[135]),"moving frenzy estimate uses time exactly once")

	var diagonal := session()
	for y in range(16): build(diagonal,y*16+(8 if y<8 else 7),0.001 if y==8 else 1.0)
	var d := enemy(diagonal,118); enrage(d); diagonal.step(0.001)
	check(d.frenzy_target==135,"frenzy can commit to a clear diagonal attack")
	check(not diagonal.build(0,119) and not diagonal.build(0,134),"committed diagonal attack reserves both clearance squares")
	for i in range(200):
		diagonal.step(0.01)
		if d.cell==135: break
	check(d.cell==135 and diagonal.tower_at(135).is_empty(),"destroyed diagonal obstruction permits entry")
	check(diagonal.build(0,119) and diagonal.build(0,134),"attack clearance releases after crossing completes")

func saves() -> void:
	var g := session(); var e := enemy(g)
	cross(g,e,129); cross(g,e,128)
	var loaded := Session.new()
	check(loaded.restore(json_copy(g.snapshot())) and loaded.enemies[0].visited==e.visited and loaded.enemies[0].frustration==1,"partial frustration and history survive JSON save")
	var old := g.snapshot()
	for key in Frenzy.KEYS: old.enemies[0].erase(key)
	check(loaded.restore(json_copy(old)) and loaded.enemies[0].visited==[128] and not loaded.enemies[0].frenzied,"older saves initialize tracking at restored position")
	build(g,129); enrage(e); g.step(0.01)
	var saved := json_copy(g.snapshot())
	check(loaded.restore(saved) and loaded.paused and loaded.enemies[0].frenzy_target==129 and loaded.enemies[0].frenzied,"frenzy and attack commitment restore paused")
	g.sell(129)
	check(loaded.restore(json_copy(g.snapshot())) and not loaded.build(0,129),"sold-target commitment survives save/load")
	loaded.paused=false; loaded.step(0.01)
	check(loaded.enemies[0].next==129,"restored sold-target commitment advances into opening")
	var crossing := Session.new()
	check(crossing.restore(json_copy(loaded.snapshot())) and crossing.enemies[0].frenzied and crossing.enemies[0].next==129 and close(crossing.remaining(crossing.enemies[0]),loaded.remaining(loaded.enemies[0])),"mid-crossing frenzy save preserves movement and arrival estimate")
	var baseline := loaded.snapshot()
	var mutations := [{"frustration":-1},{"frustration":13},{"frustration":NAN},{"frenzied":false},{"frenzied":1},{"visited":[128,128]},{"visited":[256]},{"visited":[128.5]},{"visited":[]},{"frenzy_target":130},{"frenzy_target":127},{"frenzy_target":129.5}]
	for mutation in mutations:
		var bad := saved.duplicate(true)
		for key in mutation: bad.enemies[0][key]=mutation[key]
		check(not loaded.restore(bad) and loaded.snapshot()==baseline,"invalid frenzy save rejected atomically: "+str(mutation))
	var partial := saved.duplicate(true); partial.enemies[0].erase("visited")
	check(not loaded.restore(partial) and loaded.snapshot()==baseline,"partial frenzy extension rejected atomically")
	var blocked := session()
	for y in range(16): build(blocked,y*16+(8 if y<8 else 7),0.001 if y==8 else 1.0)
	var d := enemy(blocked,118); enrage(d); blocked.step(0.001)
	var corner := blocked.snapshot(); var tower: Dictionary = corner.towers[0].duplicate(); tower.cell=119; corner.towers.append(tower)
	check(not loaded.restore(corner) and loaded.snapshot()==baseline,"saved diagonal attack cannot cross an occupied corner")

func run() -> void:
	counting(); exploit(); static_maze(); routes_and_commitment(); saves()
	print("%d frenzy checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
