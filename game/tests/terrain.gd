extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL "+label)
func portable(g: Session) -> Dictionary:
	return JSON.parse_string(JSON.stringify(g.snapshot(),"",true,true))
func _initialize() -> void: run.call_deferred()
func components(terrain: GardenTerrain, kind: int, diagonals: bool) -> Array:
	var seen := {}; var groups := []
	for cell in terrain.cells:
		if terrain.cells[cell].kind!=kind or seen.has(cell): continue
		var group: Array[int] = [cell]; seen[cell]=true; var i := 0
		while i<group.size():
			for n in GardenTerrain.adjacent(group[i],diagonals):
				if not seen.has(n) and terrain.cells.has(n) and terrain.cells[n].kind==kind: seen[n]=true; group.append(n)
			i+=1
		groups.append(group)
	return groups
func generation() -> void:
	var layouts := {}; var water_styles := {}
	for seed_value in range(1,151):
		var t := GardenTerrain.generate(seed_value)
		check(t.cells.size()>=39 and t.cells.size()<=51,"coverage seed %d"%seed_value)
		check(GardenTerrain.decode(t.snapshot())!=null,"valid connected layout seed %d"%seed_value)
		check(t.snapshot()==GardenTerrain.generate(seed_value).snapshot(),"reproducible seed %d"%seed_value)
		var rocks := components(t,GardenTerrain.ROCK,true)
		for group in rocks: check(group.size()<=4,"rock formation size seed %d"%seed_value)
		var streams := components(t,GardenTerrain.STREAM,false)
		check(streams.size()==1,"single continuous stream")
		var ends := 0
		for cell in streams[0]:
			water_styles[t.cells[cell].style]=true
			var degree := 0
			for n in GardenTerrain.adjacent(cell):
				if t.cells.has(n) and t.cells[n].kind==GardenTerrain.STREAM: degree+=1
			check(degree in [1,2],"stream is narrow and unbranched")
			if degree==1:
				ends+=1; check(cell%16>0 and cell%16<15 and cell/16>0 and cell/16<15,"stream endpoints inside field")
		check(ends==2,"stream has two ends")
		layouts[hash(t.snapshot())]=true
	check(layouts.size()>140 and water_styles.size()==3,"layout and stream style variety")
func gameplay() -> void:
	var g := Session.fresh(7); g.coins=Amount.of(1e12)
	var original := g.terrain.snapshot(); var balance := g.coins.power
	for row in original:
		for kind in range(3): check(not g.build(kind,row.cell),"cannot recruit on terrain")
		check(not g.sell(row.cell) and not g.upgrade(row.cell) and not g.repair(row.cell),"terrain is not a tower")
	check(g.coins.power==balance and g.towers.is_empty(),"invalid recruitment spends nothing")
	var route := g.preview_route()
	check(route.back()==Routes.EXIT,"preview reaches exit")
	for cell in route: check(not g.terrain.cells.has(cell),"preview avoids obstacles")
	# Full tower blockade must still leave a terrain-safe breach route.
	for cell in range(256):
		if cell not in [Routes.ENTRANCE,Routes.EXIT] and not g.terrain.cells.has(cell): g.build(0,cell)
	var e := {"kind":0,"boss":-1,"slow":0.0,"frenzied":true}
	var field := g.field_for(e,Routes.ENTRANCE); var distance := g.terrain.distances()
	for cell in range(256):
		if cell==Routes.EXIT or g.terrain.cells.has(cell): continue
		var to: int = field.next[cell]
		check(to>=0 and not g.terrain.cells.has(to) and distance[to]<distance[cell],"all frenzy positions can breach toward exit")
	g.defeat(); check(g.terrain.snapshot()==original,"defeat keeps terrain")
	g.run_best=5; g.best=5; g.level=6; g.rebirth()
	check(g.terrain.snapshot()==original,"rebirth keeps terrain")
	var loaded := Session.new()
	check(loaded.restore(portable(g)) and loaded.terrain.snapshot()==original,"rebirth save retains terrain and styles")
	# A U-shaped terrain pocket requires a physically backward step to escape.
	g=Session.new(); var rows := []
	for cell in [102,103,104,120,134,135,136]: rows.append({"cell":cell,"kind":0,"style":0})
	g.terrain=GardenTerrain.decode(rows); g.start(); g.spawned=g.wave_plan.size()
	var foe := g.spawn_enemy({"kind":0,"boss":-1}); foe.cell=119; Frenzy.initialize(foe); foe.frenzied=true; foe.frustration=12.0
	g.step(0.01)
	check(foe.next==118,"frenzy takes a physically backward terrain detour")
	check(loaded.restore(portable(g)) and loaded.enemies[0].next==118,"backward terrain detour restores mid-crossing")
	for i in range(1500):
		if not g.active: break
		g.step(0.05)
	check(not g.active and g.last_defeat==1,"frenzy escapes permanent terrain pocket")
	# A cat in a diagonal clearance square must be breached cardinally.
	g=Session.new(); g.terrain=GardenTerrain.decode([{"cell":84,"kind":0,"style":0}]); g.coins=Amount.of(1000)
	g.build(0,119); g.build(0,134)
	for t in g.towers: t.cooldown=1e6; t.hp=0.001
	g.start(); g.spawned=g.wave_plan.size(); foe=g.spawn_enemy({"kind":0,"boss":-1}); foe.cell=118; foe.hp_power=100; Frenzy.initialize(foe); foe.frenzied=true; foe.frustration=12.0
	g.step(0.001)
	check(foe.frenzy_target in [119,134],"blocked diagonal attacks a side cat")
	check(foe.next==-1,"does not cut occupied corner")
	for i in range(100):
		g.step(0.02)
		if foe.cell!=118: break
	check(foe.cell in [119,134],"side cat destruction opens monotonic route")
	# Permanent geometry never participates in ranged hit tests.
	g=Session.new(); g.terrain=GardenTerrain.decode([{"cell":136,"kind":0,"style":0}])
	g.build(0,135); g.start(); g.spawned=g.wave_plan.size()
	foe=g.spawn_enemy({"kind":0,"boss":-1}); foe.cell=137; foe.hp_power=3.0; Frenzy.initialize(foe)
	var terrain_before := g.terrain.snapshot()
	g.step(0.01)
	check(foe.hp<1.0,"cats shoot across rock terrain")
	check(g.terrain.snapshot()==terrain_before,"combat never damages or removes obstacles")
func persistence() -> void:
	var g := Session.fresh(42); var saved := portable(g); var restored := Session.new()
	check(restored.restore(saved) and restored.terrain.snapshot()==g.terrain.snapshot(),"JSON terrain round trip")
	var remote := LiveField.decode(JSON.parse_string(JSON.stringify(LiveField.capture(g,1,1))))
	check(remote!=null and remote.terrain.snapshot()==g.terrain.snapshot(),"remote view retains terrain styles")
	var old := saved.duplicate(true); old.version=4; old.erase("terrain")
	check(restored.restore(old) and restored.terrain.cells.is_empty(),"legacy garden remains empty")
	var old_field := LiveField.capture(Session.new(),1,2); old_field.garden.erase("terrain")
	check(LiveField.decode(old_field)!=null and LiveField.decode(old_field).terrain.cells.is_empty(),"legacy remote fields remain empty")
	var malformed := [null,{},[{"cell":128,"kind":0,"style":0}],[{"cell":40.5,"kind":0,"style":0}],[{"cell":40,"kind":2,"style":0}],[{"cell":40,"kind":0,"style":3}],[{"cell":40,"kind":0,"style":0},{"cell":40,"kind":0,"style":0}],[{"cell":40,"kind":0,"style":0},{"cell":41,"kind":0,"style":1}]]
	for rows in malformed:
		var bad := saved.duplicate(true); bad.terrain=rows
		var before := restored.snapshot()
		check(not restored.restore(bad) and restored.snapshot()==before,"invalid terrain rejected atomically")
		var visible := LiveField.capture(g,1,3); visible.garden.terrain=rows
		check(LiveField.decode(visible)==null,"invalid visible terrain rejected")
	var isolated := []
	for cell in [1,16]: isolated.append({"cell":cell,"kind":0,"style":0})
	check(GardenTerrain.decode(isolated)==null,"corner-connected terrain cannot isolate ground")
	var missing := saved.duplicate(true); missing.erase("terrain")
	check(not restored.restore(missing),"version five requires explicit terrain")
	var overlap := Session.new(); overlap.coins=Amount.of(1000); overlap.build(0,40)
	var bad := portable(overlap); bad.terrain=[{"cell":40,"kind":0,"style":0}]
	check(not restored.restore(bad),"tower cannot overlap terrain on restore")
	overlap=Session.new(); overlap.start(); var e := overlap.spawn_enemy({"kind":0,"boss":-1}); e.cell=40; Frenzy.initialize(e)
	bad=portable(overlap); bad.terrain=[{"cell":40,"kind":0,"style":0}]
	check(not restored.restore(bad),"enemy cannot overlap terrain on restore")
func run() -> void:
	generation(); gameplay(); persistence()
	print("%d terrain checks, %d failures"%[checks,failures]); quit(1 if failures else 0)
