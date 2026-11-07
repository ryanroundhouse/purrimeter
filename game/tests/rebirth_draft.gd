extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+message)
func near(a: float,b: float) -> bool: return absf(a-b)<0.000001
func portable(g: Session) -> Dictionary: return JSON.parse_string(JSON.stringify(g.snapshot(),"",true,true))
func ready_garden(depth: int = 5) -> Session:
	var g := Session.new(); g.garden_level=5; g.achievements.unlocked_level=5; g.best=depth; g.run_best=depth; g.level=depth+1; g.draft_seed=17; return g
func combat(kind: int) -> Session:
	var g := Session.new(); g.coins=Amount.of(10000); g.build(kind,129); g.start(); return g
func foe(g: Session, cell: int = 130) -> Dictionary:
	var e := g.spawn_enemy({"kind":0,"boss":-1}); e.cell=cell; e.hp_power=4.0; Frenzy.initialize(e); return e
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g := ready_garden(); g.build(0,100); g.towers[0].hp=0.2; g.bonus_points=150
	var combat_rng := g.combat_seed; var money := g.coins.power
	check(RebirthDraft.ITEMS.size()==12 and g.rebirth(),"twelve authored rewards and rebirth commits")
	check(g.pending_draft.offers.size()==3 and g.pending_draft.depth==5 and g.rebirths==1,"first rebirth offers three eligible distinct improvements")
	check(g.bonus_points==150 and g.coins.power==money and g.towers[0].hp==1,"rebirth preserves legacy income, coins and healed cats")
	check(g.combat_seed==combat_rng,"draft sampling does not consume combat randomness")
	var frozen := g.snapshot(); g.paused=false; g.step(5)
	check(g.snapshot()==frozen and not g.start() and not g.rebirth() and not g.build(1,101) and not g.buy_powerup("training") and not g.sell(100),"pending draft blocks simulation and purchases even if pause is toggled")
	var loaded := Session.new()
	check(loaded.restore(portable(g)) and loaded.pending_draft==g.pending_draft and loaded.draft_seed==g.draft_seed and loaded.paused,"portable reload preserves the same pending offers and random stream")
	var picked: String = g.pending_draft.offers[0]
	var unchosen: String = g.pending_draft.offers[1]
	check(not g.choose_draft("triad") and g.choose_draft(picked) and not g.choose_draft(picked),"only an offered reward can be granted, exactly once")
	check(g.draft_rank(picked)==1 and RebirthDraft.eligible(g,unchosen) and g.pending_draft.is_empty(),"one rank persists while unchosen offers remain in the pool")
	check(not RebirthDraft.eligible(g,picked),"next rank enforces its own milestones")
	g.best=30; g.rebirths=5; g.draft_ranks={"spotter":1,"front":1}
	check(RebirthDraft.eligible(g,"triad") and not RebirthDraft.eligible(g,"thermal"),"draft prerequisites and paid-power prerequisites are independent")
	g.powerup_ranks.embers=1
	check(RebirthDraft.eligible(g,"thermal") and RebirthDraft.eligible(g,"cinder"),"Hot Embers unlocks both burn synergies")
	g.draft_ranks.triad=3
	check(not RebirthDraft.eligible(g,"triad"),"maximum-rank improvements leave the pool")
	var counted := ready_garden(10); counted.rebirths=1; counted.rebirth()
	check(RebirthDraft.eligible(counted,"spotter"),"eligibility counts the newly committed rebirth")
	for count in [0,1,2,3]:
		var small := ready_garden()
		for index in range(4-count): small.draft_ranks[RebirthDraft.ITEMS[index][0]]=1
		small.rebirth()
		check(small.pending_draft.offers.size()==maxi(1,count),"small eligible pool size %d has the expected offer count"%count)
		if count==0:
			check(small.pending_draft.offers==[RebirthDraft.FALLBACK],"locked future rewards do not prevent income fallback")
			small.bonus_points=100; small.choose_draft(RebirthDraft.FALLBACK)
			check(small.bonus_points==110,"fallback adds percentage points, not compounded income")
	var shallow := 0; var deep := 0
	for trial in range(1000):
		var sample := ready_garden(50); sample.rebirths=20; sample.powerup_ranks={"embers":1,"focus":1}; sample.draft_ranks={"supply":1,"spotter":1,"front":1}
		# Identical streams compare weighted draws with the same eligible pool.
		sample.draft_seed=(trial+1)*7919
		for id in RebirthDraft.draw(sample,5): shallow+=1 if RebirthDraft.definition(id).band==2 else 0
		sample.draft_seed=(trial+1)*7919
		for id in RebirthDraft.draw(sample,30): deep+=1 if RebirthDraft.definition(id).band==2 else 0
	check(deep>shallow*2,"deeper-run weights materially favor Keystone offers (%d vs %d)"%[deep,shallow])
	var live := ready_garden(); var before := live.snapshot()
	var staged := DraftTransaction.prepare(live)
	check(staged!=null and live.snapshot()==before,"preparing a rebirth does not mutate the live garden")
	check(not DraftTransaction.commit(live,staged,func(_next): return ERR_CANT_CREATE) and live.snapshot()==before,"failed durable write cannot commit or reveal a rebirth")
	var path := "/tmp/purrimeter-draft-test-%d.json"%OS.get_process_id()
	check(DraftTransaction.commit(live,staged,func(next): return SaveStore.write(next,path)),"successful write publishes the committed draft")
	var disk := Session.new()
	check(SaveStore.read_into(disk,path) and disk.pending_draft==live.pending_draft,"disk contains the exact revealed offers")
	before=live.snapshot(); picked=live.pending_draft.offers[0]; staged=DraftTransaction.prepare(live,picked)
	check(not DraftTransaction.commit(live,staged,func(_next): return ERR_FILE_CANT_WRITE) and live.snapshot()==before,"failed choice save retains the unresolved offers")
	check(DraftTransaction.commit(live,staged,func(next): return SaveStore.write(next,path)) and SaveStore.read_into(disk,path) and disk.draft_rank(picked)==1 and disk.pending_draft.is_empty(),"reward commit survives reopen without duplication")
	DirAccess.remove_absolute(path)
	var pending := ready_garden(); pending.rebirth(); var good := portable(pending)
	for mutation in [{"draft_seed":0},{"draft_ranks":{"mixed":4}},{"draft_ranks":{"unknown":1}},{"draft_streak":6},{"draft_rescue_used":1},{"pending_draft":{"depth":5,"rebirth":1,"offers":["mixed","mixed","guard"]}},{"pending_draft":{"depth":5,"rebirth":1,"offers":["triad"]}},{"pending_draft":{"depth":6,"rebirth":1,"offers":["mixed","salvage","guard"]}}]:
		var bad := good.duplicate(true); bad.merge(mutation,true); before=loaded.snapshot()
		check(not loaded.restore(bad) and loaded.snapshot()==before,"malformed draft import is atomic: "+str(mutation))
	var legacy := ready_garden(25); legacy.rebirths=20; legacy.bonus_points=1000; legacy.training=8; legacy.powerup_ranks={"quick":3}
	var old := portable(legacy); old.version=3
	for key in ["draft_ranks","draft_seed","draft_streak","draft_rescue_used","pending_draft"]: old.erase(key)
	check(loaded.restore(old) and loaded.draft_ranks.is_empty() and loaded.bonus_points==1000 and loaded.training==8 and loaded.powerup_rank("quick")==3,"version-three migration preserves all earned strength without retroactive picks")
	check(loaded.achievements.earned.has("gold"),"legacy rebirth history earns the revised twenty-rebirth achievement")
	old.rebirths=1; old.achievements.earned.gold=true; old.achievements.values.bonus=1000
	check(Session.new().restore(old),"legacy Golden Garden achievement and bonus metric remain importable")
	combat_checks()
	if "--browser-fixture" in OS.get_cmdline_user_args():
		var fixture := ready_garden(30); fixture.rebirths=5; fixture.powerup_ranks={"embers":1,"focus":1}; fixture.draft_ranks={"supply":1,"spotter":1,"front":1}
		SaveStore.write(fixture,ProjectSettings.globalize_path("res://../build/draft-browser-fixture.json"))
	print("DRAFT RESULT: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)

func combat_checks() -> void:
	var g := combat(0); var t: Dictionary = g.towers[0]; var interval := g.cat_stat(t,"interval")
	g.draft_ranks={"mixed":2}; g.build(1,145); g.build(2,146)
	check(near(g.cat_stat(t,"interval"),interval/1.16),"Mixed Patrol gives one proximity benefit despite multiple neighbors")
	g.sell(145); g.sell(146); check(near(g.cat_stat(t,"interval"),interval),"Mixed Patrol responds to actual placement")
	g.draft_ranks={"supply":2,"treasure":2}; g.coins=Amount.of(0)
	DraftCombat.clear_level(g); var first := g.coins.numeric(); DraftCombat.clear_level(g)
	check(near(first,64*0.6) and near(g.coins.numeric(),64*1.3),"clear income combines Supply Cache and a growing Treasure Trail")
	for i in range(10): DraftCombat.clear_level(g)
	check(g.draft_streak==5,"Treasure Trail streak caps at five")
	g.defeat(); check(g.draft_streak==0,"defeat resets the streak but preserves its owned ranks")
	g.draft_ranks={"salvage":3}; g.coins=Amount.of(0); DraftCombat.destroyed(g,t)
	check(near(g.coins.numeric(),22.5),"Salvage Crew refunds 45% of actual investment")
	g= combat(0); var e := foe(g); e.slow=1; g.draft_ranks={"guard":3}; g.powerup_ranks.fur=5
	check(near(g.foe_dps(e),12*0.4),"Frost Guard and Thick Fur honor the total mitigation cap")
	e.slow=0; check(near(g.foe_dps(e),12*0.7),"Frost Guard requires chill")
	g= combat(0); t=g.towers[0]; e=foe(g); g.build(1,145); var gunner: Dictionary = g.towers[1]
	g.draft_ranks={"spotter":2}; PowerupCombat.attack(g,t,e); var health: float=e.hp
	PowerupCombat.attack(g,gunner,e)
	check(near((health-e.hp)*10000,54) and e.spotter_left==0,"Spotter Bolts boosts one direct Gunner hit and consumes its mark")
	health=e.hp; PowerupCombat.attack(g,gunner,e); check(near((health-e.hp)*10000,36),"consumed mark does not boost a second hit")
	g= combat(2); t=g.towers[0]; e=foe(g); var neighbor := foe(g,131); var far := foe(g,134)
	g.draft_ranks={"front":1}; g.powerup_ranks.lock=3; PowerupCombat.attack(g,t,e)
	check(neighbor.slow>0 and far.slow==0 and neighbor.get("frost_hits",0)==0,"Cold Front slows nearby targets without adding freeze counters")
	g= combat(1); t=g.towers[0]; e=foe(g); neighbor=foe(g,131); far=foe(g,132)
	g.draft_ranks={"cinder":3}; g.powerup_ranks.embers=1; PowerupCombat.attack(g,t,e)
	neighbor.erase("burn_left"); far.erase("burn_left"); e.burn_left=1.5; e.hp=0; PowerupCombat.reward_dead(g)
	check(near(neighbor.burn_left,1.5) and neighbor.burn_relayed and far.get("burn_left",0)==0,"Cinder Relay transfers remaining burn to only one neighbor")
	neighbor.hp=0; PowerupCombat.reward_dead(g); check(far.get("burn_left",0)==0,"transferred burns cannot relay again")
	g= combat(0); t=g.towers[0]; e=foe(g); neighbor=foe(g,131); g.draft_ranks={"steady":2}; g.powerup_ranks.focus=1
	for i in range(5): PowerupCombat.attack(g,t,e)
	e.hp=0; PowerupCombat.reward_dead(g); PowerupCombat.attack(g,t,neighbor)
	check(near((1-neighbor.hp)*10000,14*1.16) and t.focus_hits==5,"Steady Aim carries four stacks to a new target after a kill")
	g= combat(1); t=g.towers[0]; e=foe(g); e.slow=2; g.draft_ranks.thermal=2; g.powerup_ranks.embers=1
	PowerupCombat.attack(g,t,e); check(near((1-e.hp)*10000,36),"Thermal Shock requires a burn already present before the hit")
	health=e.hp; PowerupCombat.attack(g,t,e)
	check(near((health-e.hp)*10000,36*1.7) and e.slow>0 and e.burn_left>0,"Thermal Shock boosts direct damage without consuming statuses")
	g= combat(0); t=g.towers[0]; g.draft_ranks.lives=1; t.hp=0
	check(DraftCombat.rescue(g,t) and near(t.hp,0.35) and not DraftCombat.rescue(g,t),"Nine Lives supplies one shared rescue per attempt")
	var resumed := Session.new(); check(resumed.restore(portable(g)) and resumed.draft_rescue_used,"used rescue charge survives save/load")
	g.defeat(); g.start(); check(not g.draft_rescue_used,"starting a new attempt refreshes Nine Lives")
	g= combat(0); t=g.towers[0]; e=foe(g); g.build(1,145); g.build(2,146); g.draft_ranks.triad=2
	PowerupCombat.attack(g,t,e); PowerupCombat.attack(g,g.towers[1],e); health=e.hp
	check(resumed.restore(portable(g)),"partially completed three-role combo can be saved")
	PowerupCombat.attack(g,g.towers[2],e)
	PowerupCombat.attack(resumed,resumed.towers[2],resumed.enemies[0])
	check(near(resumed.enemies[0].hp,e.hp),"saved combo finishes with identical burst damage after reload")
	check(near((health-e.hp)*10000,10) and near(e.triad_until,3),"Triad Strike adds one burst from a three-role primary-hit combo")
	var combo_data := portable(g)
	var combo_ok := resumed.restore(combo_data)
	check(combo_ok and resumed.enemies[0].triad_until==e.triad_until,"combo cooldown and marks survive save/load")
	health=e.hp
	for cat in g.towers: PowerupCombat.attack(g,cat,e)
	check(near((health-e.hp)*10000,55),"Triad recovery prevents repeat bursts inside the cooldown")
	var bad := portable(g); bad.enemies[0].triad_marks=[0,0,100]
	check(not resumed.restore(bad),"future-dated combo marks are rejected")
	g.draft_ranks={"front":3,"triad":3}; g.powerup_ranks.lock=3; e.boss=0
	for i in range(8): PowerupCombat.attack(g,g.towers[2],e)
	check(e.stun<=0.3 and not PowerupCombat.control(e,1),"draft synergies preserve boss control immunity")
	var wire: Dictionary = JSON.parse_string(JSON.stringify(LiveField.capture(g,1,1),"",true,true))
	var remote := LiveField.decode(wire)
	check(remote!=null and remote.draft_rank("triad")==3 and remote.draft_rank("front")==3,"spectators receive owned draft effects without pending choices")
