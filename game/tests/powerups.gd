extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func near(a: float, b: float) -> bool: return absf(a-b)<0.000001
func rich() -> Session:
	var g := Session.new(); g.garden_level=5; g.achievements.unlocked_level=5; g.coins=Amount.of(1e12); return g
func foe(g: Session, cell: int, boss: int = -1) -> Dictionary:
	if g.wave_plan.is_empty(): g.wave_plan=Balance.plan(g.level)
	var e := g.spawn_enemy({"kind":0,"boss":boss}); e.cell=cell; e.hp_power=4.0
	Frenzy.initialize(e)
	return e
func json_copy(data: Dictionary) -> Dictionary: return JSON.parse_string(JSON.stringify(data,"",true,true))
func _initialize(): call_deferred("run")
func run() -> void:
	var g := rich()
	check(Powerups.ITEMS.size()==30 and g.discovered=={"training":true},"30 powerups; only training discovered in a new garden")
	check(g.train() and g.training==1,"training rank one is available at challenge one")
	var before := g.snapshot(); check(not g.train() and g.snapshot()==before,"coins alone cannot bypass the next training milestone")
	g.kills=24
	check(g.train() and g.train() and g.training==3 and not g.train(),"earned lifetime kills allow consecutive eligible ranks then stop at the next gate")
	g.best=2; g.refresh_powerups()
	check(g.discovered.has("quick") and not g.discovered.has("eyes"),"discovery reveals only qualified icons")
	check(g.buy_powerup("quick") and not g.buy_powerup("quick"),"each capped rank has a separate prerequisite")
	g.best=9; g.run_best=9; g.refresh_powerups(); g.rebirth(); g.choose_draft(g.pending_draft.offers[0])
	check(g.discovered.has("eyes") and g.powerup_rank("quick")==1 and g.training==3,"rebirth retains discoveries and ranks")
	g.build(0,100); g.best=4; g.refresh_powerups(); g.sell(100)
	check(g.discovered.has("needle") and g.cat_milestones[0]==1 and g.can_buy_powerup("needle"),"sold qualifying cat does not remove discovery or achievement credit")
	g.defeat()
	check(g.discovered.has("needle") and g.powerup_rank("quick")==1,"defeat retains collection")
	var all := rich(); all.best=100; all.kills=100000; all.rebirths=20; all.cat_milestones=[6,6,6]
	for row in Powerups.ITEMS:
		var id: String=row[0]
		if id=="training": continue
		var ok := true
		for rank in range(row[3]): ok=all.buy_powerup(id) and ok
		check(ok and all.powerup_complete(id) and not all.buy_powerup(id),"purchase and cap: "+id)
	check(all.discovered.size()==30,"all 30 discoveries reachable through earned milestone types")
	var restored := Session.new()
	check(restored.restore(json_copy(all.snapshot())) and restored.powerup_ranks==all.powerup_ranks and restored.discovered==all.discovered,"full collection survives portable JSON")
	var legacy := rich(); legacy.training=26; legacy.kills=12; legacy.best=12; legacy.rebirths=2; legacy.build(1,100); legacy.towers[0].tier=4
	var old := legacy.snapshot(); old.version=2
	for key in ["powerups","discovered","cat_milestones","combat_seed","aftershocks"]: old.erase(key)
	check(restored.restore(json_copy(old)) and restored.training==26 and restored.kills==12,"v2 migration preserves high training even below new prerequisites")
	check(restored.cat_milestones==[0,4,0] and restored.discovered.has("blast") and not restored.discovered.has("needle"),"migration credits surviving cats without inventing sold-cat history")
	check(not restored.train() and restored.training==26,"migrated training must meet next rank gate")
	var baseline := restored.snapshot()
	var mutations := [{"powerups":{"quick":6}},{"powerups":{"unknown":1}},{"powerups":{"training":2}},{"cat_milestones":[7,0,0]},{"cat_milestones":[1.5,0,0]},{"discovered":{"needle":"yes"}},{"combat_seed":0},{"aftershocks":[{"delay":0.1}]}]
	for mutation in mutations:
		var bad := baseline.duplicate(true); bad.merge(mutation,true)
		check(not restored.restore(bad) and restored.snapshot()==baseline,"invalid powerup import is atomic: "+str(mutation))
	var stats := rich(); stats.build(0,100); var cat: Dictionary=stats.towers[0]; cat.hp=0.4
	var hp := stats.cat_stat(cat,"hp_power"); var interval := stats.cat_stat(cat,"interval"); var reach := stats.cat_stat(cat,"range")
	stats.powerup_ranks={"beds":2,"quick":2,"eyes":2,"stand":1,"fur":2}
	check(near(pow(10,stats.cat_stat(cat,"hp_power")-hp),1.3) and cat.hp==0.4,"beds increase health without free percentage healing")
	check(near(stats.cat_stat(cat,"interval"),interval/1.16) and near(stats.cat_stat(cat,"range"),reach+0.3),"quick paws and keen eyes affect actual cat stats")
	cat.hp=0.2; check(near(stats.cat_stat(cat,"interval"),interval/1.16/1.3),"last stand applies only at low health")
	var enemy := foe(stats,120)
	check(near(stats.foe_dps(enemy),12*0.88),"thick fur reduces actual incoming damage and breach estimates")
	stats.powerup_ranks={"thrifty":5,"equipment":5,"repair":5}; stats.coins=Amount.of(10000)
	var coins := stats.coins.numeric(); stats.build(1,110)
	check(near(coins-stats.coins.numeric(),60) and near(Amount.from_power(stats.towers[1].spent).numeric(),60),"discounted recruitment charges and records actual investment")
	check(near(stats.upgrade_cost(cat).numeric(),45) and near(stats.repair_cost(cat).numeric(),8),"tier and repair discounts use current ranks")
	stats.powerup_ranks={"aid":5}; cat.hp=0.5; stats.active=true; PowerupCombat.tick(stats,2)
	check(near(cat.hp,0.52),"first aid heals maximum-health fraction during combat")
	stats.powerup_ranks={"catnap":2}; stats.enemies.clear(); stats.start(); stats.spawned=stats.wave_plan.size(); stats.step(0.01)
	check(near(cat.hp,0.62),"catnap heals survivors once on a successful clear")
	var bolt := rich(); bolt.build(0,129); cat=bolt.towers[0]
	var target := foe(bolt,130); var behind := foe(bolt,131); var beside := foe(bolt,114)
	bolt.powerup_ranks={"needle":1}; PowerupCombat.attack(bolt,cat,target)
	check(near((1-behind.hp)*10000,8.4) and beside.hp==1,"piercing hits a target behind the primary, not off the line")
	bolt.powerup_ranks={"static":1}; target.hp=1; behind.hp=1; beside.hp=1; PowerupCombat.attack(bolt,cat,target)
	check(near((2-behind.hp-beside.hp)*10000,4.9),"chain hit damages exactly one nearby secondary target without recursion")
	bolt.powerup_ranks={"focus":2}; cat.erase("focus_target"); cat.erase("focus_hits"); target.hp=1
	PowerupCombat.attack(bolt,cat,target); var first_hit: float = 1-target.hp
	PowerupCombat.attack(bolt,cat,target); check(near((1-target.hp-first_hit)/first_hit,1.08),"focus fire ramps consecutive hits")
	PowerupCombat.attack(bolt,cat,behind); check(cat.focus_hits==1,"focus fire resets when switching enemies")
	bolt.powerup_ranks={"lucky":5,"heavy":2}; bolt.combat_seed=1; target.hp=1; PowerupCombat.attack(bolt,cat,target)
	check(near((1-target.hp)*10000,35),"critical chance and heavy claws produce amplified damage")
	bolt.powerup_ranks={"giant":2,"finish":2,"brittle":2}; target.boss=0; target.hp=0.2; target.slow=1
	PowerupCombat.attack(bolt,cat,target)
	check(near((0.2-target.hp)*10000,14*1.4*1.3*1.16),"boss, finishing, and chilled-target bonuses combine")
	var cannon := rich(); cannon.build(1,129); cat=cannon.towers[0]; target=foe(cannon,130); var outer := foe(cannon,132)
	cannon.powerup_ranks={"blast":5,"embers":2,"aftershock":1,"concussion":3,"siege":2}; target.attack=0.1; cannon.combat_seed=1
	PowerupCombat.attack(cannon,cat,target)
	check(outer.hp<1 and near((1-target.hp)*10000,36*1.4),"wider blast and siege shells affect their intended enemies")
	check(target.get("burn_left",0)==3 and target.get("stun",0)>0 and cannon.aftershocks.size()==1,"cannon adds burning, concussion, and exactly one delayed echo")
	var hp_before: float=target.hp; PowerupCombat.tick(cannon,0.2)
	check(near((hp_before-target.hp)*10000,36*1.4*0.16*0.2),"burn damage integrates over elapsed time")
	cannon.active=true; cannon.spawned=cannon.wave_plan.size()
	var copy := Session.new()
	check(copy.restore(json_copy(cannon.snapshot())),"burn, stun, random stream, and pending aftershock restore mid-combat")
	PowerupCombat.tick(cannon,0.3); PowerupCombat.tick(copy,0.3)
	check(near(cannon.enemies[0].hp,copy.enemies[0].hp) and cannon.aftershocks.is_empty() and copy.aftershocks.is_empty(),"restored echo fires once with identical damage")
	check(near(cannon.enemies[0].burn_left,2.5),"echo does not restart burning or trigger another echo")
	var frost := rich(); frost.build(2,129); cat=frost.towers[0]; target=foe(frost,130,0)
	frost.powerup_ranks={"chill":5,"linger":5,"lock":3}
	for i in range(4): PowerupCombat.attack(frost,cat,target)
	check(near(target.slow,3.8) and near(frost.foe_speed(target),0.55*0.32),"deep chill and lingering cold improve frost slow")
	check(near(target.stun,0.3) and not PowerupCombat.control(target,0.9),"boss freeze duration is bounded and overlapping controls are rejected")
	PowerupCombat.tick(frost,0.31)
	check(target.stun==0 and not PowerupCombat.control(target,0.9),"boss can move during recovery window")
	PowerupCombat.tick(frost,3.0)
	check(PowerupCombat.control(target,0.9),"boss becomes controllable again after recovery")
	var income := rich(); income.coins=Amount.of(0); income.bonus_points=100; target=foe(income,130,0); target.hp=0; target.slow=1; target.bounty_power=log(10.0)/log(10.0)
	var neighbor := foe(income,131); var distant := foe(income,135)
	income.powerup_ranks={"bounty":2,"purse":2,"winter":1}
	PowerupCombat.reward_dead(income)
	check(near(income.coins.numeric(),33.6) and income.kills==1,"bounty and boss purse multiply rebirth income once")
	check(near(neighbor.slow,1.2) and distant.slow==0,"winter gift spreads slow only within radius")
	PowerupCombat.reward_dead(income); check(income.kills==1 and near(income.coins.numeric(),33.6),"new death effects do not duplicate kill rewards")
	print("POWERUPS RESULT: %d checks, %d failures"%[checks,failures]); quit(0 if failures==0 else 1)
