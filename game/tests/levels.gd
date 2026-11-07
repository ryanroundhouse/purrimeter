extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func clear_wave(g: Session) -> void:
	check(g.start(),"wave %d starts in level %d" % [g.level,g.garden_level])
	g.spawned=g.wave_plan.size(); g.step(0.01)
func transfer(g: Session) -> Dictionary:
	return JSON.parse_string(JSON.stringify(g.snapshot(),"",true,true))
func run() -> void:
	var g := Session.new()
	check(g.garden_level==1 and g.level==1 and g.achievements.unlocked_level==1,"new players start in level one")
	check(g.replacement(0)==null and g.replacement(2)==null and g.replacement(6)==null,"locked and invalid levels cannot replace a garden")
	var final_wave := Session.new(); final_wave.level=10; final_wave.best=9; final_wave.run_best=9; final_wave.start()
	final_wave.spawned=final_wave.wave_plan.size()
	var boss := final_wave.spawn_enemy({"kind":2,"boss":0})
	final_wave.spawn_enemy({"kind":0,"boss":-1})
	boss.hp=0; final_wave.step(0.01)
	check(not final_wave.completed and final_wave.achievements.unlocked_level==1 and final_wave.active,"killing the boss alone does not beat the final wave")
	final_wave.defeat()
	check(final_wave.level==9 and final_wave.achievements.unlocked_level==1,"escaping final-wave escort does not unlock another level")
	for selected in range(1,5):
		g.set_auto_start(true)
		for wave in range(1,selected*10+1):
			clear_wave(g)
			if wave<selected*10: check(not g.completed and g.auto_start_remaining==3,"nonfinal clear continues within the level")
		check(g.completed and g.level==selected*10 and not g.active and g.paused and g.auto_start_remaining==0,"final boss wave ends level %d" % selected)
		check(g.achievements.unlocked_level==selected+1,"victory unlocks only the next level")
		var frozen := transfer(g)
		g.step(10); g.start(); g.rebirth(); g.defeat(); g.set_auto_start(false); g.build(0,100)
		check(transfer(g)==frozen,"completed garden cannot resume, rebirth, defeat, recruit or schedule Auto")
		var loaded := Session.new()
		check(loaded.restore(frozen) and loaded.completed and not loaded.start(),"completed save reloads as victory")
		var remote := LiveField.decode(LiveField.capture(g,1,1))
		check(remote!=null and remote.garden_level==selected and remote.completed,"spectators see completed level %d" % selected)
		var replay := g.replacement(1)
		check(replay!=null and replay.garden_level==1 and replay.achievements.unlocked_level==selected+1,"replaying an earlier level preserves unlocks")
		g=g.replacement(selected+1)
		check(g.level==1 and g.best==0 and g.towers.is_empty() and g.coins.label()=="200" and not g.completed and not g.legacy_endless,"next level starts a fresh garden")
	g.level=50; clear_wave(g)
	check(g.level==51 and not g.completed,"endless continues beyond wave fifty")
	var later := g.replacement(3)
	later.level=5; clear_wave(later)
	check(later.rebirth() and later.garden_level==3 and later.level==1 and not later.pending_draft.is_empty(),"rebirth returns to wave one in the selected level")
	var draft := Session.new()
	check(draft.restore(transfer(later)) and draft.garden_level==3 and draft.pending_draft==later.pending_draft,"pending draft retains selected level through transfer")
	later.choose_draft(later.pending_draft.offers[0]); later.level=2; later.start(); later.defeat()
	check(later.garden_level==3 and later.level==1 and later.achievements.unlocked_level==5,"defeat loses one wave without changing level or unlocks")
	for best_wave in [0,9,10,19,20,29,30,39,40,75]:
		var old := Session.new().snapshot()
		old.version=5; old.best=best_wave; old.run_best=best_wave; old.level=best_wave+1
		old.erase("garden_level"); old.erase("completed"); old.erase("legacy_endless")
		old.achievements.version=1; old.achievements.erase("unlocked_level")
		var legacy := Session.new()
		check(legacy.restore(old) and legacy.garden_level==5 and legacy.legacy_endless and legacy.level==best_wave+1,"legacy garden preserved at depth %d" % best_wave)
		check(legacy.achievements.unlocked_level==GardenLevels.legacy_unlock(best_wave),"legacy credit uses highest cleared wave %d" % best_wave)
		var imported := Session.new()
		check(imported.restore(transfer(legacy)) and imported.legacy_endless,"legacy exception survives export and import")
		if best_wave<40: check(imported.replacement(5)==null,"legacy exception does not unlock a new endless garden")
		check(not imported.replacement(1).legacy_endless,"replacing legacy garden ends its exception")
	var historical := Session.new().snapshot(); historical.version=5
	historical.achievements.version=1; historical.achievements.erase("unlocked_level"); historical.achievements.values.best=30
	var veteran := Session.new()
	check(veteran.restore(historical) and veteran.achievements.unlocked_level==4,"legacy migration credits achievement history after New Garden")
	var lower := Session.new()
	check(veteran.restore(transfer(lower)) and veteran.achievements.unlocked_level==4,"import cannot remove destination unlocks")
	check(lower.restore(transfer(g)) and lower.achievements.unlocked_level==5,"import adds source unlocks")
	# Future wave records never substitute for actually completing a selected level.
	var earned := Session.new(); earned.achievements.highest("best",100)
	var merged := Session.new()
	check(merged.restore(transfer(earned)) and merged.achievements.unlocked_level==1,"new-format best wave alone cannot unlock levels")
	var valid := transfer(later)
	for edit in [{"garden_level":0},{"garden_level":6},{"garden_level":2.5},{"completed":"yes"},{"legacy_endless":true},{"completed":true},{"level":31},{"best":31}]:
		var bad := valid.duplicate(true); bad.merge(edit,true)
		var before := transfer(lower)
		check(not lower.restore(bad) and transfer(lower)==before,"invalid progression rejected atomically: %s" % edit)
	var locked := Session.new().snapshot(); locked.garden_level=2
	check(not Session.new().restore(locked),"save cannot select a locked level")
	var broken := transfer(g); broken.achievements.unlocked_level=6
	check(not Session.new().restore(broken),"invalid player-wide unlock rejected")
	var old_wire := LiveField.capture(g,1,1); old_wire.garden.erase("garden_level"); old_wire.garden.erase("completed")
	check(LiveField.decode(old_wire).garden_level==5,"older multiplayer fields display as endless")
	print("Five levels: %d failure(s)" % failures)
	quit(1 if failures else 0)
