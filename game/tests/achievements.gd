extends SceneTree
var checks := 0
var failures := 0
var earned := {}

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+message)

func garden(level: int = 1, kind: int = 0) -> Session:
	var g := Session.new(); g.garden_level=5; g.achievements.unlocked_level=5; g.level=level; g.coins=Amount.from_power(100)
	g.build(kind,119)
	return g

func clear(g: Session) -> void:
	g.spawned=g.wave_plan.size()
	for e in g.enemies: e.hp=0
	g.step(1.0/60)
	for id in g.achievements.earned: earned[id]=true

func enemy_kill(g: Session, boss: int = -1, slow: float = 0, frenzy: bool = false) -> void:
	var e := g.spawn_enemy({"kind":0,"boss":boss})
	e.slow=slow; e.frenzied=frenzy; e.hp=0
	PowerupCombat.reward_dead(g)
	for id in g.achievements.earned: earned[id]=true

func _initialize() -> void:
	var ids := {}
	for row in Achievements.ITEMS:
		ids[row[0]]=true
		check(ResourceLoader.exists("res://assets/powerups/"+row[6]+".svg"),"icon exists for "+row[1])
	check(ids.size()==30,"catalog has exactly 30 distinct achievements")
	var g := garden()
	g.build(1,120); g.build(2,121); g.upgrade(119); g.buy_powerup("training")
	g.start(); clear(g)
	for id in ["first","crew","upgrade","power"]: check(g.achievements.earned.has(id),"real actions earn "+id)
	g.level=5; g.start(); clear(g); g.rebirth()
	check(g.achievements.earned.has("rebirth"),"first rebirth recognized")
	for id in g.achievements.earned: earned[id]=true
	g= garden(10); g.start(); clear(g)
	for id in ["solo","bolt","basic","idle","unhurt","boss_level"]: check(g.achievements.earned.has(id),"clean base-tier solo clear earns "+id)
	g=garden(5,1); g.start(); clear(g)
	check(g.achievements.earned.has("cannon"),"Cannon-only challenge")
	g=garden(10); g.start(); g.upgrade(119)
	g.build(1,120); g.sell(120)
	var snapshot := g.snapshot()
	var resumed := Session.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(snapshot))),"active attempt restores from portable JSON")
	check(resumed.paused,"restore keeps combat paused")
	resumed.paused=false; clear(resumed)
	for id in ["solo","bolt","basic","idle"]: check(not resumed.achievements.earned.has(id),"save/load cannot erase broken condition: "+id)
	g=garden(5); g.start(); g.tower_at(119).hp=0.4; g.repair(119); clear(g)
	check(g.achievements.earned.has("medic"),"repaired cat survives to clear")
	g=garden(5); g.start(); g.tower_at(119).hp=0.4; g.repair(119); g.sell(119); g.build(0,119); clear(g)
	check(not g.achievements.earned.has("medic"),"replacement at same tile is not the repaired cat")
	g=garden(10); g.sell(119)
	for y in range(16):
		g.build(1,y*16+1); g.towers.back().cooldown=1000
	g.start(); g.spawned=g.wave_plan.size()
	var attacker:=g.spawn_enemy({"kind":3,"boss":-1}); attacker.cell=128
	g.step(1.0/60)
	check(g.achievement_run.attempt.failed.has("unhurt"),"enemy attack invalidates damage-free challenge")
	g.repair(129); clear(g)
	check(not g.achievements.earned.has("unhurt"),"repair does not undo damage eligibility")
	g=garden(10); g.start(); enemy_kill(g,0,1.0,true)
	check(g.achievements.earned.has("cold") and g.achievements.earned.has("frenzy"),"kill records chilled boss and frenzy conditions")
	check(not g.achievements.earned.has("boss_level"),"boss kill alone does not clear its escorts")
	g.achievements.values.kills=99; enemy_kill(g)
	check(g.achievements.earned.has("kills100"),"100th enemy awards milestone")
	g.achievements.values.kills=4999; g.achievements.values.bosses=24; enemy_kill(g,0)
	check(g.achievements.earned.has("kills5000") and g.achievements.earned.has("bosses"),"kill can award two milestones once")
	var previous := g.achievements.pending.duplicate(); PowerupCombat.reward_dead(g)
	check(g.achievements.pending==previous,"dead enemies never award twice")
	g.achievements.values.recruits=49; g.build(1,120)
	g.achievements.values.repairs=24; g.tower_at(119).hp=0.5; g.repair(119)
	g.achievements.values.upgrades=99; g.upgrade(119)
	g.achievements.values.ranks=24; g.buy_powerup("training")
	g.achievements.values.rebirths=19; g.best=100; g.run_best=100; g.rebirth()
	for id in ["recruits","repairs","upgrades","ranks","rebirths","gold"]: check(g.achievements.earned.has(id),"threshold action earns "+id)
	for id in g.achievements.earned: earned[id]=true
	g=garden(10)
	for i in range(5): g.start(); clear(g)
	check(g.achievements.earned.has("streak"),"five consecutive qualifying clears")
	g=garden(10)
	for i in range(3): g.start(); clear(g)
	g.start(); g.defeat()
	check(g.achievement_run.is_empty(),"defeat resets attempt and streak")
	g.level=25; g.start(); clear(g)
	g.level=50; g.start(); clear(g)
	check(g.achievements.earned.has("level25") and g.achievements.earned.has("level50"),"high level milestones")
	g=garden(); g.build(1,120); g.build(2,121)
	for cell in [119,120,121]:
		for i in range(5): g.upgrade(cell)
	check(g.achievements.earned.has("dream"),"simultaneous Mythic trio")
	g.best=100; g.kills=100000; g.rebirths=10
	for row in Powerups.ITEMS:
		g.buy_powerup(row[0])
		while row[3]>0 and g.powerup_rank(row[0])<row[3]: g.buy_powerup(row[0])
	check(g.achievements.earned.has("toys") and g.achievements.earned.has("school"),"full powerup collection and capped ranks")
	for id in g.achievements.earned: earned[id]=true
	check(earned.size()==30,"all 30 achievements exercised by gameplay events")
	var book := g.achievements; var old := book.snapshot()
	var fresh := Session.new(); fresh.achievements=book
	check(fresh.achievement_run.is_empty() and book.earned.has("dream"),"fresh garden keeps book but no attempt")
	fresh.coins=Amount.from_power(50); fresh.build(0,119)
	check(book.values.recruits==old.values.recruits+1,"new garden adds lifetime activity")
	var before := fresh.snapshot()
	check(fresh.restore(g.snapshot()),"import supports earned achievements")
	var imported := book.snapshot()
	check(fresh.restore(g.snapshot()) and book.snapshot()==imported,"repeat import does not add counters or duplicate pending unlocks")
	var invalid := fresh.snapshot(); invalid.achievements.values.kills="many"
	before=fresh.snapshot()
	check(not fresh.restore(invalid) and fresh.snapshot()==before,"malformed achievement import is atomic")
	invalid=before.duplicate(true); invalid.achievement_run={"attempt":{"level":10,"failed":{},"repaired":[]}}
	check(not fresh.restore(invalid) and fresh.snapshot()==before,"inactive save cannot claim active eligibility")
	g=garden(10); g.start(); snapshot=g.snapshot(); snapshot.erase("achievements"); snapshot.erase("achievement_run")
	snapshot.version=5; snapshot.kills=100; snapshot.best=25
	resumed=Session.new(); check(resumed.restore(snapshot),"legacy save migration")
	check(resumed.achievements.earned.has("kills100") and resumed.achievements.earned.has("level25"),"legacy recorded progress credited")
	resumed.paused=false; clear(resumed)
	check(not resumed.achievements.earned.has("solo") and not resumed.achievements.earned.has("idle"),"legacy unfinished attempts do not invent tactical history")
	check(not resumed.achievements.summary.is_empty(),"retroactive achievements use one summary")
	var path := "/tmp/purrimeter-achievement-profile-%d.json" % OS.get_process_id()
	check(SaveStore.write_achievements(book,path)==OK,"player profile saves atomically")
	var loaded := Achievements.new()
	check(SaveStore.read_achievements(loaded,path) and loaded.snapshot()==book.snapshot(),"profile survives without garden")
	loaded.acknowledge(loaded.pending.duplicate()); SaveStore.write_achievements(loaded,path)
	var acknowledged := Achievements.new(); SaveStore.read_achievements(acknowledged,path)
	check(acknowledged.pending.is_empty(),"acknowledged celebrations stay acknowledged on restart")
	DirAccess.remove_absolute(path)
	print("RESULT: %d achievement checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
