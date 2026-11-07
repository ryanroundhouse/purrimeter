extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func rich() -> Session:
	var g := Session.new(); g.garden_level=2; g.achievements.unlocked_level=2; g.coins=Amount.of(1000000)
	return g
func foe(g: Session, kind: int, cell: int) -> Dictionary:
	if g.wave_plan.is_empty(): g.wave_plan=Balance.plan(g.level,g.garden_level)
	var e := g.spawn_enemy({"kind":kind,"boss":-1}); e.cell=cell; e.hp_power=5; Frenzy.initialize(e)
	return e
func transfer(g: Session) -> Dictionary:
	return JSON.parse_string(JSON.stringify(g.snapshot(),"",true,true))
func _initialize() -> void:
	var locked := Session.new()
	check(not locked.build(Balance.ANTI_AIR,115) and locked.towers.is_empty(),"Ranger cannot be recruited before beating level one")
	check(not CatSkins.unlocked(locked.achievements,"ranger_default"),"Ranger skin follows level unlock")
	locked.level=10; locked.start(); locked.spawned=locked.wave_plan.size(); locked.step(.01)
	check(locked.completed and locked.cat_unlocked(Balance.ANTI_AIR),"level one victory unlocks Ranger")
	var replay := locked.replacement(1)
	check(replay.build(Balance.ANTI_AIR,115) and not replay.air_incoming(),"Ranger can be used on level-one replays without adding flyers")
	check(CatSkins.equip(replay.achievements,3,"ranger_default"),"unlocked Ranger default can be equipped")
	var veteran := rich(); var loaded := Session.new()
	check(loaded.restore(transfer(veteran)) and loaded.cat_unlocked(3),"existing level-two unlock grants Ranger on restore")
	for selected in range(1,6):
		var mixed := 0; var grounded := 0
		for wave in range(1,61):
			var plan := Balance.plan(wave,selected)
			check(plan.size()==Balance.plan(wave).size(),"level %d wave %d preserves enemy count"%[selected,wave])
			var air_count := plan.filter(func(e): return Balance.flying(e)).size()
			if air_count>0: mixed+=1
			else: grounded+=1
			check(plan.filter(func(e): return e.boss>=0).size()==(1 if wave%10==0 else 0),"boss cadence retained %d/%d"%[selected,wave])
			var g := rich(); g.garden_level=selected; g.level=wave; g.wave_plan=plan
			var total := 0.0
			for entry in plan: total+=g.enemy_health_share(entry,g.normal_wave_weight())
			check(absf(total-1)<.000001,"mixed roster retains health and bounty budgets %d/%d"%[selected,wave])
		check(mixed==0 if selected==1 else mixed>0 and grounded>0,"level %d has the agreed mix of air and ground waves"%selected)
		if selected>1: check(Balance.preview(1,selected).contains("Moth (air)"),"first-wave preview identifies air in level %d"%selected)
	# Actual firing must obey the target matrix, including when only an ineligible target exists.
	for kind in range(4):
		for target_kind in [0,Balance.MOTH]:
			var g := rich(); g.build(kind,115); g.start(); g.spawned=g.wave_plan.size()
			var e := foe(g,target_kind,131); g.step(.01)
			var expected: bool = kind in [0,2] or (kind==1 and target_kind==0) or (kind==3 and target_kind==Balance.MOTH)
			check((e.hp<1)==expected and (not g.shots.is_empty())==expected,"tower %d fires only at eligible target %d"%[kind,target_kind])
	# Cannon's complete damage family is ground-only, even with an air unit closer to a dying burn.
	var cannon := rich(); cannon.build(1,115); cannon.start(); cannon.spawned=cannon.wave_plan.size()
	cannon.powerup_ranks={"embers":2,"aftershock":1,"concussion":3}; cannon.draft_ranks={"cinder":3}; cannon.combat_seed=1
	var ground := foe(cannon,0,131); var air := foe(cannon,4,131); var neighbor := foe(cannon,0,132)
	PowerupCombat.attack(cannon,cannon.towers[0],ground)
	check(ground.hp<1 and air.hp==1 and air.get("burn_left",0)==0 and air.get("stun",0)==0,"Cannon splash, burn and stun exclude air")
	PowerupCombat.tick(cannon,.5)
	check(air.hp==1 and ground.hp<1,"delayed aftershock also excludes air")
	neighbor.erase("burn_left"); neighbor.erase("burn_power"); ground.hp=0; DraftCombat.death(cannon,ground)
	check(neighbor.get("burn_left",0)>0 and air.get("burn_left",0)==0,"Cinder Relay skips the closer flying target")
	# Shared Frost control and Bolt secondary hits cross the air/ground boundary.
	var frost := rich(); frost.build(2,115); var moth := foe(frost,4,131); var grunt := foe(frost,0,132)
	frost.powerup_ranks={"lock":1,"linger":1}; frost.draft_ranks={"front":1}
	for i in range(4): PowerupCombat.attack(frost,frost.towers[0],moth)
	check(moth.slow>0 and moth.get("stun",0)>0 and grunt.slow>0,"Frost slows and freezes air and spreads to ground")
	var bolt := rich(); bolt.build(0,130); var primary := foe(bolt,0,131); var flying := foe(bolt,4,132)
	bolt.powerup_ranks={"needle":1,"static":1}; PowerupCombat.attack(bolt,bolt.towers[0],primary)
	check(flying.hp<1,"Bolt pierce and chain cross from ground to air")
	var ranger := rich(); ranger.build(3,115); moth=foe(ranger,4,131); moth.slow=2
	ranger.powerup_ranks={"brittle":2,"quick":1,"eyes":1}; ranger.training=1
	var before: float = moth.hp; PowerupCombat.attack(ranger,ranger.towers[0],moth)
	check(absf((before-moth.hp)*100000-26*1.25*1.16)<.00001,"Ranger receives training and Brittle Ice")
	check(ranger.cat_stat(ranger.towers[0],"range")>4.2 and ranger.cat_stat(ranger.towers[0],"interval")<.6,"Ranger receives generic range and speed buffs")
	# Triad works in air, retaining partial progress through save transfer.
	var combo := rich(); combo.start(); combo.spawned=combo.wave_plan.size(); combo.draft_ranks={"triad":1}
	moth=foe(combo,4,131)
	DraftCombat.primary(combo,{"kind":0},moth,2,false); DraftCombat.primary(combo,{"kind":2},moth,2,false)
	var resumed := Session.new(); check(resumed.restore(transfer(combo)),"partial air Triad round-trips")
	DraftCombat.primary(resumed,{"kind":3},resumed.enemies[0],2,false)
	check(resumed.enemies[0].hp<1 and resumed.enemies[0].triad_until>0,"Bolt + Frost + Ranger triggers Triad")
	# Direct flight traverses terrain and cats, does not hurt them, reserves no tiles, never frenzies.
	var flight := rich(); flight.terrain.cells[134]={"kind":0,"style":0}; flight.build(1,133)
	flight.start(); flight.spawned=flight.wave_plan.size(); moth=foe(flight,4,132); flight.towers[0].cooldown=999
	moth.next=133; moth.progress=.5
	check(flight.remaining(moth)<9,"air threat priority uses straight flight time")
	check(flight.build(1,132),"a cat can be built directly below a flyer")
	flight.towers[1].cooldown=999
	for i in range(200): flight.step(.02)
	check(moth.cell>134 and moth.cell/16==8 and moth.frustration==0 and not moth.frenzied,"Moth crosses tower and rock without routing or frenzy")
	check(flight.towers.all(func(t): return t.hp==1),"Moth never damages cats")
	moth.cell=133; moth.next=134; moth.progress=.4; Frenzy.initialize(moth)
	var saved := transfer(flight); resumed=Session.new()
	check(resumed.restore(saved) and resumed.enemies[0].next==134,"flying across tower and terrain restores exactly")
	var remote := LiveField.decode(LiveField.capture(flight,1,1))
	check(remote!=null and remote.enemies[0].kind==4 and remote.wave_plan==flight.wave_plan,"spectators accept flight over terrain and retain mixed roster")
	var original := transfer(resumed)
	for mutation in [{"cell":117},{"next":132},{"boss":0},{"frenzied":true},{"frenzied":"no"},{"burn_left":1}]:
		var bad := saved.duplicate(true); bad.enemies[0].merge(mutation,true)
		check(not resumed.restore(bad) and transfer(resumed)==original,"invalid flight is rejected atomically: %s"%mutation)
	flight.enemies[0].cell=142; flight.enemies[0].next=143; flight.enemies[0].progress=.99
	flight.step(.1); check(not flight.active and flight.last_defeat==1,"flying escape triggers ordinary defeat")
	# A pre-feature active wave keeps its original plan after upgrading and re-saving.
	var old := rich(); old.start(); old.wave_plan=Balance.plan(1); old.spawned=3; old.spawn_enemy(old.wave_plan[0]); old.enemies[0].hp=.5
	var legacy_save := transfer(old); legacy_save.version=6; legacy_save.erase("wave_roster_level"); legacy_save.cat_milestones=[0,0,0]
	resumed=Session.new(); check(resumed.restore(legacy_save),"version-six active garden migrates")
	check(resumed.wave_plan==Balance.plan(1) and resumed.spawned==3 and resumed.enemies[0].hp==.5,"migration preserves active enemies and unspawned roster")
	loaded=Session.new(); check(loaded.restore(transfer(resumed)) and loaded.wave_plan==Balance.plan(1),"re-saving retains legacy active roster")
	loaded.defeat(); loaded.start(); check(loaded.wave_plan.any(func(e): return Balance.flying(e)),"next started wave adopts flyers after migration")
	var legacy := Session.new(); legacy.garden_level=5; legacy.legacy_endless=true
	legacy.start(); check(not legacy.wave_plan.any(func(e): return Balance.flying(e)),"legacy endless without level-two unlock stays ground-only")
	legacy.defeat(); legacy.achievements.unlocked_level=2; legacy.start()
	check(legacy.wave_plan.any(func(e): return Balance.flying(e)),"legacy endless adopts flyers once Ranger unlock is earned")
	var crew := rich()
	for kind in [0,2,3]: crew.build(kind,100+kind); crew.towers.back().tier=6
	crew.achievements.record(crew,"upgrade")
	check(not crew.achievements.earned.has("crew") and not crew.achievements.earned.has("dream"),"Ranger does not substitute for original-role achievements")
	crew.build(1,101); crew.towers.back().tier=6; crew.achievements.record(crew,"upgrade")
	check(crew.achievements.earned.has("crew") and crew.achievements.earned.has("dream"),"original three roles still earn Whole Crew and Dream Team")
	print("Air combat: %d failure(s)"%failures)
	quit(1 if failures else 0)
