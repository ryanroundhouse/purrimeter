extends SceneTree
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+label)

func near(a: float, b: float) -> bool:
	return absf(a-b)<0.000001

func spawn_next(g: Session) -> Dictionary:
	var e := g.spawn_enemy(g.wave_plan[g.spawned])
	g.spawned+=1
	return e

func _initialize() -> void:
	var g := Session.new()
	check(g.level_health_fraction()==0.0,"no active attempt has no level health")
	g.start()
	check(near(g.level_health_fraction(),1.0),"unspawned wave starts at full health")
	var e := spawn_next(g)
	check(near(g.level_health_fraction(),1.0),"arrival does not change total health")
	g.damage(e,Amount.of(19).power)
	check(near(g.level_health_fraction(),285.0/304.0),"damage subtracts actual HP including unspawned enemies")
	g.damage(e,Amount.of(1000).power)
	check(near(g.level_health_fraction(),266.0/304.0),"overkill cannot subtract health belonging to another enemy")
	PowerupCombat.reward_dead(g)
	check(near(g.level_health_fraction(),266.0/304.0),"removing a dead enemy preserves remaining health")
	spawn_next(g)
	check(near(g.level_health_fraction(),266.0/304.0),"later arrival cannot refill the bar")
	var restored := Session.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(g.snapshot()))) and near(restored.level_health_fraction(),g.level_health_fraction()),"save restoration preserves partial wave health")
	var before := restored.level_health_fraction()
	restored.step(10)
	check(near(restored.level_health_fraction(),before),"paused restored wave preserves health")
	for level in [4,10,100,2000,1000000000]:
		g=Session.new(); g.level=level; g.start()
		var full_through_arrivals := true
		while g.spawned<g.wave_plan.size():
			spawn_next(g)
			full_through_arrivals=full_through_arrivals and near(g.level_health_fraction(),1.0)
		check(full_through_arrivals,"full health stays stable through arrivals at level %d" % level)
		if level%10==0:
			for foe in g.enemies: foe.hp=0.5 if foe.boss>=0 else 0.0
			check(near(g.level_health_fraction(),0.3),"half-health boss alone retains 30 percent at level %d" % level)
		else:
			var grunt: Dictionary = g.enemies[0]
			var brute: Dictionary = g.enemies.back()
			grunt.hp=0.0; var grunt_loss := 1.0-g.level_health_fraction()
			grunt.hp=1.0; brute.hp=0.0; var brute_loss := 1.0-g.level_health_fraction()
			check(near(brute_loss/grunt_loss,150.0/38.0),"brutes contribute proportionally more health than grunts")
		for foe in g.enemies: foe.hp=0.0
		check(g.level_health_fraction()==0.0,"fully damaged wave is empty at level %d" % level)
		PowerupCombat.reward_dead(g); g.step(0.01)
		check(not g.active and g.level_health_fraction()==0.0,"cleared attempt does not show refilled next level")
	g=Session.new(); g.start(); spawn_next(g); g.defeat()
	check(not g.active and g.level_health_fraction()==0.0,"defeat removes active level health")
	print("%d level-health checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
