extends SceneTree
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks+=1
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures+=1

func close(a: float, b: float, tolerance: float = 0.00001) -> bool:
	return absf(a-b)<=tolerance*maxf(1.0,absf(b))

func equivalent(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int): return close(float(a),float(b),1e-10)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]): return false
		return true
	return a==b

func rich() -> Session:
	var g := Session.new(); g.garden_level=5; g.achievements.unlocked_level=5; g.coins=Amount.of(1000000); return g

func put_enemy(g: Session, kind: int, cell: int, boss: int = -1) -> Dictionary:
	if g.wave_plan.is_empty(): g.wave_plan=Balance.plan(g.level)
	var e := g.spawn_enemy({"kind":kind,"boss":boss}); e.cell=cell
	Frenzy.initialize(e)
	return e

func _initialize() -> void:
	call_deferred("run")

func diagonal_checks() -> void:
	var empty := Routes.field({})
	check(close(empty.distance[126],sqrt(2.0)),"open diagonal uses physical distance")
	check(close(empty.distance[0],7+8*sqrt(2.0)),"shortest route combines straight and diagonal steps")
	check(Routes.neighbors(119).size()==8 and Routes.neighbors(0).size()==3 and Routes.neighbors(15).size()==3 and not 16 in Routes.neighbors(15),"eight directions respect board edges")
	var all_corners := true
	for destination in [102,104,134,136]:
		for side in Routes.clearance_cells(119,destination):
			if destination in Routes.neighbors(119,{side:-1.0}): all_corners=false
	check(all_corners,"either side tower blocks each diagonal direction")
	check(close(Routes.field({127:-1.0}).distance[126],2.0) and close(Routes.field({142:-1.0}).distance[126],2.0),"single tower forces an orthogonal detour around its corner")
	var diagonal_wall := {}
	for i in range(16): diagonal_wall[i*17]=-1.0
	check(Routes.field(diagonal_wall).distance[Routes.ENTRANCE]>=Routes.INF,"corner-touching towers seal the field")
	var breach_costs := diagonal_wall.duplicate()
	for cell in breach_costs: breach_costs[cell]=1.0
	check(Routes.field(breach_costs).distance[Routes.ENTRANCE]<Routes.INF,"corner wall remains breachable")

	for boss in [-1,0,1,2,3]:
		for kind in range(4 if boss<0 else 1):
			for slowed in [false,true]:
				var motion := rich(); motion.start(); motion.spawned=motion.wave_plan.size()
				var e := put_enemy(motion,kind,126,boss); e.next=143; e.progress=0.5; e.slow=10.0 if slowed else 0.0
				var speed := motion.foe_speed(e)
				var before := motion.position(e)
				check(close(motion.remaining(e),sqrt(2.0)*0.5/speed),"diagonal arrival estimate: kind %d boss %d slow %s"%[kind,boss,slowed])
				motion.step(0.05)
				check(close(before.distance_to(motion.position(e)),speed*0.05),"constant diagonal speed: kind %d boss %d slow %s"%[kind,boss,slowed])

	var crossing := rich(); crossing.start(); crossing.spawned=crossing.wave_plan.size()
	var mover := put_enemy(crossing,0,130); mover.next=147; mover.progress=0.5
	check(not crossing.build(0,131) and not crossing.build(0,146),"both diagonal clearance squares reject construction")
	check(not crossing.build(0,130) and not crossing.build(0,147),"diagonal departure and destination remain reserved")
	crossing.paused=true
	check(not crossing.build(0,131),"tactical pause retains diagonal clearance reservations")
	var saved := crossing.snapshot()
	var restored := Session.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved,"",true,true))),"mid-diagonal JSON save restores")
	check(not restored.build(0,146) and close(restored.position(restored.enemies[0]).distance_to(crossing.position(mover)),0.0),"restored crossing preserves position and clearance")
	var template := rich(); template.build(0,100)
	for side in [131,146]:
		var bad := saved.duplicate(true); var tower: Dictionary = template.towers[0].duplicate(true); tower.cell=side; bad.towers.append(tower)
		var unchanged := restored.snapshot()
		check(not restored.restore(bad) and restored.snapshot()==unchanged,"import rejects corner obstruction at %d without changing live game"%side)
	crossing.paused=false; restored.paused=false
	for i in range(40):
		crossing.step(1.0/60); restored.step(1.0/60)
		if mover.cell==147: break
	check(equivalent(crossing.snapshot(),restored.snapshot()),"mid-diagonal restore reproduces movement")
	check(mover.cell==147 and crossing.build(0,131) and crossing.build(0,146),"clearance squares release after diagonal arrival")

	# This wall changes columns at a corner. Its weak lower corner is
	# reachable diagonally from 118 while both required side squares are empty.
	var wall := rich()
	for y in range(16):
		wall.build(1,y*16+(8 if y<8 else 7)); wall.towers.back().cooldown=1000
	wall.tower_at(135).hp=0.01; wall.invalidate_routes()
	wall.start(); wall.spawned=wall.wave_plan.size()
	var attacker := put_enemy(wall,3,118)
	check(wall.field_for(attacker,118).next[118]==135 and wall.open_field.distance[118]>=Routes.INF,"sealed enemy chooses diagonal attack with clear sides")
	var hp: float = wall.tower_at(135).hp
	var expected_damage := pow(10.0,log(wall.foe_dps(attacker)*0.01)/log(10.0)-wall.cat_stat(wall.tower_at(135),"hp_power"))
	wall.step(0.01)
	check(close(wall.tower_at(135).hp,hp-expected_damage) and attacker.cell==118 and attacker.next==-1,"diagonal attack deals normal damage without entering tower")
	wall.build(1,134); wall.tower_at(134).cooldown=1000
	check(wall.field_for(attacker,118).next[118]!=135,"side tower blocks diagonal attack as well as movement")
	wall.sell(134)
	for i in range(30): wall.step(1.0/60)
	check(wall.tower_at(135).is_empty() and (attacker.next==135 or attacker.cell==135),"enemy destroys corner tower before crossing diagonally")

func auto_start_checks() -> void:
	var g := rich()
	g.step(10.0)
	check(not g.auto_start and not g.active and g.auto_start_remaining==0.0,"auto-start defaults off and a new garden waits for Start")
	g.start(); g.spawned=g.wave_plan.size(); g.step(0.01)
	check(not g.active and g.auto_start_remaining==0.0,"default-off leaves a cleared level waiting for Start")
	g.set_auto_start(true)
	check(g.level==2 and not g.active and close(g.auto_start_remaining,3.0),"successful clear schedules a three-second countdown")
	g.step(1.0,0.5)
	check(close(g.auto_start_remaining,2.5) and not g.active,"2x combat time uses real seconds for countdown")
	g.paused=true
	var frozen := g.snapshot(); g.step(20.0,10.0)
	check(g.snapshot()==frozen,"pause freezes countdown and animation time")
	check(g.build(0,119) and close(g.auto_start_remaining,2.5),"building during countdown does not reset it")
	var resumed := Session.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(g.snapshot(),"",true,true))) and resumed.paused and close(resumed.auto_start_remaining,2.5),"saved countdown restores at remaining time and stays paused")
	resumed.step(10.0)
	check(not resumed.active and close(resumed.auto_start_remaining,2.5),"loading does not start a pending wave until resumed")
	resumed.paused=false; resumed.step(2.49)
	check(not resumed.active,"countdown waits for its full duration")
	resumed.step(0.01)
	check(resumed.active and resumed.level==2 and resumed.auto_start_remaining==0.0 and resumed.spawned==0,"countdown starts the next level exactly once")
	resumed.step(0.01)
	check(resumed.spawned==1 and resumed.level==2,"automatic start spawns the new wave")
	g.set_auto_start(false); g.paused=false; g.step(10.0)
	check(not g.active and g.auto_start_remaining==0.0,"turning auto-start off cancels the countdown")
	var off := Session.new()
	check(off.restore(g.snapshot()) and not off.auto_start,"disabled option persists with the garden")
	g.set_auto_start(true)
	check(close(g.auto_start_remaining,3.0),"enabling between cleared levels starts a fresh countdown")
	g.step(0.5); g.start()
	check(g.active and g.auto_start_remaining==0.0,"manual Start skips the countdown")
	g.set_auto_start(false); g.set_auto_start(true)
	check(g.active and g.auto_start_remaining==0.0,"toggling during combat does not schedule another wave")
	g.spawned=g.wave_plan.size(); g.step(0.01)
	check(not g.active and close(g.auto_start_remaining,3.0),"enabled option applies to the next successful clear")
	g.set_auto_start(false); g.start(); g.spawned=g.wave_plan.size(); g.step(0.01); g.step(10.0)
	check(not g.active and g.auto_start_remaining==0.0,"disabled auto-start leaves cleared levels waiting")
	var reborn := rich(); reborn.set_auto_start(true); reborn.level=5; reborn.start(); reborn.spawned=reborn.wave_plan.size(); reborn.step(0.01)
	check(reborn.can_rebirth() and reborn.auto_start_remaining>0.0,"rebirth is available during the countdown after level five")
	check(reborn.rebirth() and reborn.auto_start and reborn.auto_start_remaining==0.0,"rebirth cancels countdown and keeps the option")
	reborn.set_auto_start(false); reborn.set_auto_start(true); reborn.step(10.0)
	check(not reborn.active and reborn.level==1,"rebirth and re-enabling wait for a manual first start")
	var defeated := rich(); defeated.set_auto_start(true); defeated.level=6; defeated.run_best=5; defeated.best=5; defeated.start(); put_enemy(defeated,0,Routes.EXIT); defeated.step(0.01)
	defeated.set_auto_start(false); defeated.set_auto_start(true); defeated.paused=false; defeated.step(10.0)
	check(not defeated.active and defeated.level==5 and defeated.auto_start_remaining==0.0,"defeat never triggers an automatic retry")
	var old_save := defeated.snapshot(); old_save.erase("auto_start"); old_save.erase("auto_start_remaining")
	check(off.restore(old_save) and not off.auto_start and off.auto_start_remaining==0.0,"older saves default off without scheduling a level")
	var transitions_restore := true
	for cleared_level in range(1,21):
		var transition := rich(); transition.set_auto_start(true); transition.level=cleared_level; transition.start(); transition.spawned=transition.wave_plan.size(); transition.step(0.01)
		var loaded := Session.new()
		if not loaded.restore(transition.snapshot()) or not close(loaded.auto_start_remaining,3.0): transitions_restore=false
	check(transitions_restore,"countdown saves restore across all first-cycle levels and boss transitions")
	var replay := rich(); replay.set_auto_start(true); replay.level=4; replay.best=9; replay.run_best=9; replay.start(); replay.spawned=replay.wave_plan.size(); replay.step(0.01)
	replay.set_auto_start(false); replay.set_auto_start(true)
	check(replay.level==5 and close(replay.auto_start_remaining,3.0),"re-enabling after clearing a replayed lower level also starts countdown")
	check(off.restore(replay.snapshot()) and close(off.auto_start_remaining,3.0),"countdown save restores below the run's highest cleared level")
	var valid := resumed.snapshot(); var unchanged := resumed.snapshot()
	for invalid in [{"auto_start":"yes"},{"auto_start_remaining":-1.0},{"auto_start_remaining":4.0},{"auto_start_remaining":"3"},{"auto_start_remaining":1.0}]:
		var bad := valid.duplicate(true); bad.merge(invalid,true)
		check(not resumed.restore(bad) and resumed.snapshot()==unchanged,"invalid auto-start save rejected without changing live game: %s"%str(invalid))

func run() -> void:
	auto_start_checks()
	diagonal_checks()
	check(close(Amount.of(200).minus(Amount.of(50)).numeric(),150),"large-number subtraction")
	check(close(Amount.of(0).plus(Amount.of(0.25)).plus(Amount.of(0.25)).numeric(),0.5),"fractional coin rewards retained")
	check(Amount.from_power(10000).times(2).power>10000,"large numbers do not overflow")
	check(Amount.from_power(10000).label().contains("e10000"),"huge values have compact labels")
	check(Amount.of(50).enough(Amount.of(50)) and Amount.of(50).minus(Amount.of(50)).is_zero(),"exact-price purchases")
	var g := Session.new()
	check(g.level==1 and close(g.coins.numeric(),200),"fresh game starts at level one")
	check(not g.build(0,Routes.ENTRANCE) and not g.build(0,Routes.EXIT),"gate construction rejected")
	check(g.preview_route().size()==16,"shortest unobstructed route")
	g.build(0,132)
	check(not 132 in g.preview_route() and close(g.open_field.distance[Routes.ENTRANCE],13+2*sqrt(2.0)),"shortest diagonal open detour wins over destructive shortcut")
	g.coins=Amount.of(10000)
	for tier in range(2,7):
		check(g.upgrade(132) and g.towers[0].tier==tier,"upgrade reaches tier %d"%tier)
	check(not g.upgrade(132),"five upgrades is the cap")
	check(close(pow(10,g.cat_stat(g.towers[0],"damage_power")),14*32),"sixth tier damage progression")
	g.towers[0].hp=0.37
	var previous_hp := g.cat_stat(g.towers[0],"hp_power")
	var training_cost := g.training_cost().numeric()
	check(g.train() and close(g.towers[0].hp,0.37),"training preserves health fraction")
	check(close(pow(10,g.cat_stat(g.towers[0],"hp_power")-previous_hp),1.25),"training increases maximum health 25 percent")
	check(close(g.training_cost().numeric(),training_cost*1.5),"training cost increases 50 percent")
	var spent: float=g.towers[0].spent
	check(g.repair(132) and g.towers[0].hp==1.0 and g.towers[0].spent==spent,"repair heals without adding resale investment")
	var expected := g.coins.plus(g.refund(g.towers[0])).numeric()
	check(g.sell(132) and g.towers.is_empty() and close(g.coins.numeric(),expected),"sell clears tile and refunds correctly")
	var wall := rich()
	for y in range(16): wall.build(1,y*16+5)
	wall.tower_at(117).hp=0.001; wall.invalidate_routes()
	check(117 in wall.preview_route() and not 133 in wall.preview_route(),"blocked route chooses nearby weak tower")
	var moving := Session.new(); moving.start()
	var mover := put_enemy(moving,0,130); mover.next=131; mover.progress=0.5
	check(not moving.build(0,130) and not moving.build(0,131),"both crossing cells reserved")
	var lost := rich(); lost.build(1,99); lost.towers[0].hp=0.42; lost.level=8; lost.run_best=7; lost.best=7; lost.training=3; lost.bonus_points=50
	lost.start(); put_enemy(lost,0,Routes.EXIT)
	var coins_before := lost.coins.numeric()
	lost.step(1.0/60)
	check(lost.level==7 and not lost.active and lost.paused,"first escape immediately drops one level")
	check(close(lost.coins.numeric(),coins_before) and lost.towers.size()==1 and close(lost.towers[0].hp,0.42),"defeat retains current coins and damaged survivors")
	check(lost.enemies.is_empty() and lost.training==3 and lost.bonus_points==50,"defeat clears enemies and retains permanent upgrades")
	check(lost.can_rebirth(),"rebirth stays unlocked after falling backwards")
	check(lost.rebirth() and lost.level==1 and lost.run_best==0 and lost.best==7,"rebirth resets run but preserves lifetime best")
	check(lost.towers[0].hp==1.0 and close(lost.coins.numeric(),coins_before) and lost.training==3,"rebirth keeps possessions and heals")
	check(lost.bonus_points==50 and lost.rebirths==1 and not lost.can_rebirth(),"rebirth preserves legacy bonus and requires requalification")
	lost.choose_draft(lost.pending_draft.offers[0]); lost.run_best=5; lost.best=7; lost.level=6; lost.rebirth()
	check(lost.bonus_points==50 and not lost.pending_draft.is_empty(),"future rebirths award drafts instead of automatic income")
	var mid := rich(); mid.build(1,99); mid.level=9; mid.run_best=8; mid.best=8; mid.auto_start=true
	mid.start(); put_enemy(mid,0,130); mid.towers[0].hp=0.3
	var retained_coins := mid.coins.power
	check(mid.can_rebirth() and mid.rebirth(),"rebirth is available during an unlocked active level")
	check(not mid.active and mid.level==1 and mid.run_best==0 and mid.bonus_points==0 and mid.pending_draft.depth==8 and mid.best==8,"mid-level draft depth counts only completed levels")
	check(mid.enemies.is_empty() and mid.wave_plan.is_empty() and mid.shots.is_empty() and mid.aftershocks.is_empty() and mid.towers[0].hp==1.0 and mid.coins.power==retained_coins,"mid-level rebirth clears combat and retains earned possessions")
	mid.step(4.0,4.0)
	check(not mid.active and mid.level==1 and mid.auto_start_remaining==0.0 and mid.run_best==0,"rebirth cannot falsely clear level one or trigger auto-start")
	mid.level=5; mid.run_best=4; mid.start()
	check(not mid.can_rebirth() and not mid.rebirth(),"unfinished level five does not unlock rebirth")
	var rescue := Session.new(); rescue.coins=Amount.of(1); rescue.defeat()
	check(rescue.level==1 and close(rescue.coins.numeric(),50),"empty level-one patrol receives emergency scout funds")
	rescue.build(0,100); rescue.towers[0].hp=0.1; rescue.coins=Amount.of(0); rescue.defeat()
	check(rescue.coins.is_zero() and rescue.towers[0].hp==0.1,"recovery does not erase ordinary defeat consequences")
	for level in [1,2,9,10,11,20,30,40,50,100,2000]:
		var budget := Session.new(); budget.level=level; budget.wave_plan=Balance.plan(level)
		var total_share := 0.0; var bounty_share := 0.0; var boss_count := 0
		for entry in budget.wave_plan:
			var e := budget.spawn_enemy(entry)
			total_share+=pow(10,e.hp_power-Balance.health_power(level))
			bounty_share+=pow(10,e.bounty_power-Balance.bounty(level).power)
			if e.boss>=0:
				boss_count+=1
				check(close(pow(10,e.hp_power-Balance.health_power(level)),0.6),"boss owns 60 percent of health at %d"%level)
		check(close(total_share,1) and close(bounty_share,1),"exact health and reward budgets at level %d"%level)
		check(boss_count==(1 if level%10==0 else 0),"boss schedule at level %d"%level)
	check(close(pow(10,Balance.health_power(10)-Balance.health_power(9)),2),"boss level still exactly doubles health")
	check(close(pow(10,Balance.bounty(10).power-Balance.bounty(9).power),1.5),"bounty scales by 1.5")
	var kinds: Array = []
	for level in [10,20,30,40,50]:
		for entry in Balance.plan(level):
			if entry.boss>=0: kinds.append(entry.boss)
	check(kinds==[0,1,2,3,0],"four varied bosses cycle")
	var cleared := Session.new(); cleared.level=5; cleared.start(); cleared.spawned=cleared.wave_plan.size(); cleared.step(0.01)
	check(cleared.level==6 and cleared.run_best==5 and cleared.best==5 and cleared.can_rebirth(),"clearing fifth level unlocks rebirth")
	cleared.garden_level=5; cleared.achievements.unlocked_level=5; cleared.level=20; cleared.start(); cleared.spawned=cleared.wave_plan.size(); cleared.step(0.01)
	check(cleared.level==21 and not cleared.active,"progression continues beyond twenty")
	var combat := rich(); combat.build(0,115); combat.start(); combat.spawned=combat.wave_plan.size(); combat.bonus_points=50
	var victim := put_enemy(combat,0,131); victim.hp=0.01
	var reward_before := combat.coins.numeric(); var expected_reward := Amount.from_power(victim.bounty_power).times(1.5).numeric()
	combat.step(0.01)
	check(combat.kills==1 and close(combat.coins.numeric()-reward_before,expected_reward),"kill pays boosted bounty once")
	var splash := rich(); splash.build(1,115); splash.start(); splash.spawned=splash.wave_plan.size()
	var a := put_enemy(splash,2,131); var b := put_enemy(splash,2,132)
	a.hp_power=4; b.hp_power=4; splash.step(0.01)
	check(a.hp<1 and close(a.hp,b.hp),"splash affects nearby enemies")
	var frost := rich(); frost.build(2,115); frost.build(2,116); frost.start(); frost.spawned=frost.wave_plan.size()
	var chilly := put_enemy(frost,2,131); chilly.hp_power=4; frost.step(0.01)
	check(close(frost.foe_speed(chilly),Balance.FOES[2].speed*0.52),"multiple frost effects do not multiply slow")
	var breach := rich()
	for y in range(16): breach.build(1,y*16+1); breach.towers.back().cooldown=1000; breach.towers.back().hp=0.01
	breach.start(); breach.spawned=breach.wave_plan.size(); put_enemy(breach,3,128); put_enemy(breach,3,128)
	for i in range(30): breach.step(1.0/60)
	check(breach.towers.size()==15,"enemies attack and destroy shared blocking tower")
	check(breach.enemies[0].next>=0 or breach.enemies[0].cell!=128,"enemy walks through destroyed tower")
	var original := rich(); original.build(0,115); original.start()
	for i in range(100): original.step(1.0/60)
	original.training=3; original.bonus_points=70; original.rebirths=2; original.best=7; original.run_best=0
	var saved := original.snapshot(); var resumed := Session.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(saved,"",true,true))),"portable JSON restores")
	check(resumed.paused and resumed.training==3 and resumed.bonus_points==70 and resumed.rebirths==2,"save includes permanent progression and resumes paused")
	resumed.paused=false
	for i in range(300): original.step(1.0/60); resumed.step(1.0/60)
	check(equivalent(original.snapshot(),resumed.snapshot()),"mid-wave restore reproduces gameplay within floating-point precision")
	var bad := saved.duplicate(true); bad.towers[0].tier=7
	var unchanged := resumed.snapshot()
	check(not resumed.restore(bad) and resumed.snapshot()==unchanged,"invalid imports leave live run unchanged")
	var stop := Session.new(); stop.start(); stop.paused=true
	var paused_state := stop.snapshot(); stop.step(0.05)
	check(stop.snapshot()==paused_state,"tactical pause freezes simulation")
	var fixture := "res://.godot/test-patrol.json"
	check(SaveStore.write(original,fixture)==OK,"save writes atomically to disk")
	original.coins=original.coins.plus(Amount.of(9))
	check(SaveStore.write(original,fixture)==OK,"autosave replaces existing save")
	var disk := Session.new()
	check(SaveStore.read_into(disk,fixture) and equivalent(disk.snapshot(),original.snapshot()),"disk save restores full progression")
	DirAccess.remove_absolute(fixture)
	print("RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
