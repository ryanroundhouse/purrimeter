extends SceneTree
func _initialize() -> void:
	for selected in range(2,6):
		var g := Session.fresh(42,selected); g.achievements.unlocked_level=5; g.draft_seed=1847
		for entry in [[3,115],[0,120],[0,123]]:
			if not g.build(entry[0],entry[1]):
				for cell in range(112,128):
					if g.build(entry[0],cell): break
		var attempts := 0
		while attempts<60 and g.best<10:
			attempts+=1
			for pass_index in range(5):
				for t in g.towers:
					if t.tier<6: g.upgrade(t.cell)
			if g.towers.size()<6:
				for kind in [2,1,0]:
					for cell in range(144,160):
						if g.build(kind,cell): break
			for i in range(10):
				if not g.train(): break
			g.start()
			for tick in range(18000):
				g.step(1.0/60)
				if not g.active: break
			if g.best>=5 and g.rebirths==0 and g.can_rebirth():
				g.rebirth(); g.choose_draft(g.pending_draft.offers[0])
		print('AIR CAMPAIGN level=',selected,' best=',g.best,' attempts=',attempts,' cats=',g.towers.size(),' training=',g.training)
		if g.best<10: quit(1); return
	quit()
