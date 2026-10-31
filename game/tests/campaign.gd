extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g=Session.new()
	for x in [2,5,8,11]: g.build(0,7*16+x)
	var attempts=0
	while attempts<60 and g.best<10:
		attempts+=1
		# Spend only legitimately earned coins, favoring efficient early upgrades.
		for pass_index in range(5):
			for t in g.towers:
				if t.tier<6: g.upgrade(t.cell)
		if g.towers.size()<6:
			for entry in [[1,9*16+6],[2,9*16+9]]:
				if g.tower_at(entry[1]).is_empty(): g.build(entry[0],entry[1])
		for i in range(10):
			if not g.train(): break
		var attempt_level=g.level
		g.start()
		for tick in range(18000):
			g.step(1.0/60)
			if not g.active: break
		print("Attempt ",attempts," level ",attempt_level," -> ",g.level," best ",g.best," coins ",g.coins.label()," training ",g.training)
		if g.best>=5 and g.rebirths==0 and g.can_rebirth():
			g.rebirth(); print("Rebirth earned: +",g.bonus_points,"%")
	print("Campaign best=",g.best," rebirths=",g.rebirths," attempts=",attempts)
	quit(0 if g.best>=10 and g.rebirths>=1 else 1)
