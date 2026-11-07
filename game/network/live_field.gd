class_name LiveField
extends RefCounted
## Bounded, read-only field replication. Never applies remote data to a saved garden.
const COUNTERS := ["level","best","run_best","rebirths","training","kills","spawned"]
const VALUES := ["bonus_points","elapsed","auto_start_remaining"]
const TOWER_KEYS := ["cell","kind","tier","hp","spent","cooldown","flash"]
const ENEMY_KEYS := ["id","kind","boss","cell","next","progress","hp","hp_power","bounty_power","slow","attack","frustration","stun","burn_left"]
const MAX_SOUNDS := 128
const SOUND_NAMES := ["bolt","cannon","frost","coin","build","upgrade","wave","clear","escape","break","win","lose","boss","rebirth"]

static func capture(g: Session, revision: int, sequence: int, sounds: Array = []) -> Dictionary:
	var garden := {}
	for key in COUNTERS+VALUES: garden[key]=g.get(key)
	garden.coins=g.coins.power
	garden.terrain=g.terrain.snapshot()
	garden.unlocked_level=g.achievements.unlocked_level
	garden.skins={}
	for kind in range(Balance.CATS.size()): garden.skins[str(kind)]=g.skin_id(kind)
	garden.wave_roster_level=g.wave_roster_level if g.active else g.flyer_level()
	garden.active=g.active; garden.auto_start=g.auto_start
	garden.garden_level=g.garden_level; garden.completed=g.completed
	garden.powerups=g.powerup_ranks.duplicate(); garden.discovered=g.discovered.duplicate(); garden.cat_milestones=g.cat_milestones.duplicate()
	garden.draft_ranks=g.draft_ranks.duplicate(); garden.draft_rescue_used=g.draft_rescue_used
	garden.towers=[]; garden.enemies=[]
	for t in g.towers:
		var row := {}
		for key in TOWER_KEYS: row[key]=t.get(key,0)
		garden.towers.append(row)
	for e in g.enemies:
		var row := {}
		for key in ENEMY_KEYS: row[key]=e.get(key,0)
		row.frenzied=e.get("frenzied",false); garden.enemies.append(row)
	var shots := []
	for s in g.shots.slice(0,1024):
		shots.append({"from":[s.from.x,s.from.y],"to":[s.to.x,s.to.y],"kind":s.kind,"tier":s.tier,"life":s.life})
	return {"revision":revision,"sequence":sequence,"garden":garden,"paused":g.paused,"speed":g.speed,"shots":shots,"sounds":sounds.duplicate(true)}

static func decode(data: Dictionary) -> Session:
	if not PowerupSave.number(data.get("revision"),0,1e9,true) or not PowerupSave.number(data.get("sequence"),0,9e15,true): return null
	if not data.get("paused") is bool or not PowerupSave.number(data.get("speed"),1,2,true): return null
	# Optional for older clients. Strict ordering lets receivers discard replayed effects.
	var sounds = data.get("sounds",[])
	if not sounds is Array or sounds.size()>MAX_SOUNDS: return null
	var last_sound_id := 0
	for sound in sounds:
		if not sound is Dictionary or not PowerupSave.number(sound.get("id"),1,9e15,true) or not PowerupSave.number(sound.get("tier"),1,6,true): return null
		if not sound.get("name") in SOUND_NAMES or int(sound.id)<=last_sound_id: return null
		last_sound_id=int(sound.id)
	if not data.get("garden") is Dictionary: return null
	var d: Dictionary=data.garden
	var terrain := GardenTerrain.decode(d.get("terrain",[]))
	if terrain==null: return null
	if not CatSkins.valid_choices(d.get("skins",{})): return null
	if not DraftSave.valid_ranks(d.get("draft_ranks",{})) or not d.get("draft_rescue_used",false) is bool: return null
	for key in COUNTERS:
		if not PowerupSave.number(d.get(key),0,9e15 if key in ["training","kills"] else 1e9,true): return null
	if d.level<1: return null
	for key in VALUES+["coins"]:
		if not PowerupSave.number(d.get(key),-1e100,1e16): return null
	if not d.get("active") is bool or not d.get("auto_start") is bool or d.auto_start_remaining<0 or d.auto_start_remaining>3: return null
	if not PowerupSave.number(d.get("garden_level",5),1,5,true) or not d.get("completed",false) is bool: return null
	var limit := GardenLevels.wave_limit(int(d.get("garden_level",5)))
	if limit>0 and (d.level>limit or d.best>limit or d.run_best>limit): return null
	if d.get("completed",false) and (limit==0 or d.level!=limit or d.best!=limit or d.run_best!=limit or d.active or d.auto_start_remaining>0): return null
	if not d.get("powerups") is Dictionary or d.powerups.size()>30 or not d.get("discovered") is Dictionary or d.discovered.size()>30: return null
	for id in d.powerups:
		var definition := Powerups.definition(str(id))
		if definition.is_empty() or not PowerupSave.number(d.powerups[id],0,definition.cap,true): return null
	for id in d.discovered:
		if Powerups.definition(str(id)).is_empty() or not d.discovered[id] is bool: return null
	if not d.get("cat_milestones") is Array or d.cat_milestones.size() not in [3,4]: return null
	for n in d.cat_milestones:
		if not PowerupSave.number(n,0,6,true): return null
	if not d.get("towers") is Array or d.towers.size()>254 or not d.get("enemies") is Array or d.enemies.size()>100: return null
	var cells := terrain.blockers(); var ids := {}
	for t in d.towers:
		if not t is Dictionary: return null
		for key in TOWER_KEYS:
			if not PowerupSave.number(t.get(key),-1e100,1e16): return null
		if not PowerupSave.number(t.cell,0,255,true) or not PowerupSave.number(t.kind,0,3,true) or not PowerupSave.number(t.tier,1,6,true) or t.hp<0 or t.hp>1 or cells.has(int(t.cell)): return null
		cells[int(t.cell)]=true
	for e in d.enemies:
		if not e is Dictionary or not e.get("frenzied") is bool: return null
		for key in ENEMY_KEYS:
			if not PowerupSave.number(e.get(key),-1e100,1e16): return null
		for key in ["id","kind","boss","cell","next"]:
			var high: float = 1e9 if key=="id" else (4 if key=="kind" else (3 if key=="boss" else 255))
			if not PowerupSave.number(e[key],-1 if key in ["boss","next"] else 0,high,true): return null
		if e.hp<0 or e.hp>1 or e.progress<0 or e.progress>1 or ids.has(int(e.id)): return null
		if int(e.kind)==Balance.MOTH:
			if not Balance.valid_flight(e): return null
		else:
			if terrain.cells.has(int(e.cell)) or terrain.cells.has(int(e.next)): return null
			if e.next>=0 and int(e.next) not in Routes.neighbors(int(e.cell),cells): return null
		ids[int(e.id)]=true
	if not data.get("shots") is Array or data.shots.size()>1024: return null
	for s in data.shots:
		if not s is Dictionary or not PowerupSave.number(s.get("kind"),0,3,true) or not PowerupSave.number(s.get("tier"),1,6,true) or not PowerupSave.number(s.get("life"),0,0.25): return null
		for key in ["from","to"]:
			if not s.get(key) is Array or s[key].size()!=2: return null
			for n in s[key]:
				if not PowerupSave.number(n,0,15): return null
	if not PowerupSave.number(d.get("wave_roster_level",1),1,5,true): return null
	if not PowerupSave.number(d.get("unlocked_level",1),1,5,true): return null
	var g := Session.new()
	g.viewed_unlock_level=int(d.get("unlocked_level",1)); g.viewed_roster_level=int(d.get("wave_roster_level",1))
	g.terrain=terrain
	g.garden_level=int(d.get("garden_level",5)); g.completed=d.get("completed",false)
	g.viewed_skins=d.get("skins",{}).duplicate()
	for key in COUNTERS: g.set(key,int(d[key]))
	for key in VALUES: g.set(key,float(d[key]))
	g.coins=Amount.from_power(float(d.coins)); g.active=d.active; g.auto_start=d.auto_start
	g.paused=data.paused; g.speed=int(data.speed)
	g.powerup_ranks=d.powerups.duplicate(); g.discovered=d.discovered.duplicate(); g.cat_milestones=d.cat_milestones.duplicate()
	g.draft_ranks=d.get("draft_ranks",{}).duplicate(); g.draft_rescue_used=d.get("draft_rescue_used",false)
	g.towers=d.towers.duplicate(true); g.enemies=d.enemies.duplicate(true)
	for t in g.towers:
		for key in ["cell","kind","tier"]: t[key]=int(t[key])
	for e in g.enemies:
		for key in ["id","kind","boss","cell","next"]: e[key]=int(e[key])
	for s in data.shots:
		g.shots.append({"from":Vector2(s.from[0],s.from[1]),"to":Vector2(s.to[0],s.to[1]),"kind":int(s.kind),"tier":int(s.tier),"life":float(s.life)})
	g.wave_roster_level=int(d.get("wave_roster_level",1))
	g.wave_plan=Balance.plan(g.level,g.wave_roster_level) if g.active else []
	while g.cat_milestones.size()<Balance.CATS.size(): g.cat_milestones.append(0)
	return g
