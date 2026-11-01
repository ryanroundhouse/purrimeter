extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+message)
func _initialize() -> void:
	var g := Session.new()
	for kind in range(3):
		check(CatSkins.for_kind(kind).size()==5,"five skins for type %d" % kind)
		check(g.skin_id(kind)==CatSkins.DEFAULTS[kind],"new player starts with default %d" % kind)
	for row in CatSkins.ITEMS:
		if row[3].is_empty(): continue
		check(not CatSkins.equip(g.achievements,row[2],row[0]),"cannot equip locked "+row[0])
		g.achievements.award(row[3],true)
		check(CatSkins.unlocked(g.achievements,row[0]),"achievement unlocks "+row[0])
		check(CatSkins.equip(g.achievements,row[2],row[0]),"can equip "+row[0])
		check(not CatSkins.equip(g.achievements,(row[2]+1)%3,row[0]),"skin cannot cross cat types")
		check(ResourceLoader.exists("res://assets/"+row[4]+".png"),"bundled art for "+row[0])
		check(SkinBounds.DATA.has(row[0]) and SkinBounds.DATA[row[0]].size()==6,"six measured tiers for "+row[0])
	# Every generated pose must produce a valid isolated outline, including the
	# tall Sage staffs whose rectangular bounds can overlap adjacent frames.
	var poses := 0
	for row in CatSkins.ITEMS:
		if row[3].is_empty(): continue
		for tier in range(1,7):
			for frame in range(4):
				var geometry := CatSkinArt.frame_outline(row[0],tier,frame)
				if geometry.points.size()<3 or Geometry2D.triangulate_polygon(geometry.points).is_empty():
					check(false,"invalid sprite outline: %s tier %d frame %d" % [row[0],tier,frame])
				poses+=1
	check(poses==288,"all 288 new poses have renderable isolated outlines")
	var profile_path := "/tmp/purrimeter-skins-profile-test.json"
	check(SaveStore.write_achievements(g.achievements,profile_path)==OK,"write player cosmetics")
	var loaded := Achievements.new()
	check(SaveStore.read_achievements(loaded,profile_path),"load player cosmetics")
	check(loaded.skin_choices==g.achievements.skin_choices,"profile restart restores all selections")
	var saved := g.snapshot()
	var other := Session.new()
	other.achievements.award("first",true); CatSkins.equip(other.achievements,0,"scout_ginger")
	check(other.restore(saved),"import selected skins and achievements")
	check(other.skin_id(0)=="scout_ginger" and other.skin_id(1)=="gunner_royal" and other.skin_id(2)=="sage_aurora","local preference wins; missing preferences adopt import")
	var earned_count := other.achievements.earned.size()
	check(other.restore(saved) and other.achievements.earned.size()==earned_count,"repeat import is idempotent")
	var original := other.snapshot()
	for invalid in [{"0":"sage_aurora"},{"0":"unknown"},{"3":"scout_default"},{"0":7}]:
		var bad := saved.duplicate(true); bad.achievements.skin_choices=invalid
		check(not other.restore(bad) and other.snapshot()==original,"invalid selection rejects whole import atomically")
	var locked := Session.new().snapshot(); locked.achievements.skin_choices={"0":"scout_golden"}
	var safe := Session.new(); safe.restore(locked)
	check(safe.skin_id(0)=="scout_default","unearned imported selection cannot bypass unlock")
	var old := Session.new().snapshot(); old.achievements.erase("skin_choices"); old.achievements.erase("seen_skins")
	var legacy := Session.new(); check(legacy.restore(old) and legacy.skin_id(0)=="scout_default","pre-skin saves retain default appearances")
	var payload := LiveField.capture(g,1,1)
	var remote := LiveField.decode(payload)
	check(remote!=null and remote.skin_id(2)=="sage_aurora" and remote.achievements.earned.is_empty(),"spectators see owner's skin without gaining achievements")
	check(not CatSkins.unlocked(remote.achievements,"sage_aurora"),"viewing skin grants no local ownership")
	payload.garden.skins={"2":"scout_ginger"}
	check(LiveField.decode(payload)==null,"replication rejects wrong-type skin")
	payload.garden.erase("skins")
	check(LiveField.decode(payload).skin_id(2)=="sage_default","older multiplayer frames use defaults")
	var combat := Session.new(); combat.coins=Amount.of(10000); combat.build(0,119)
	var before := combat.cat_stat(combat.towers[0],"damage_power")
	combat.achievements.award("first",false); CatSkins.equip(combat.achievements,0,"scout_ginger")
	check(combat.cat_stat(combat.towers[0],"damage_power")==before,"equipping has no combat effect")
	combat.run_best=5; combat.best=5; combat.rebirth()
	check(combat.skin_id(0)=="scout_ginger","rebirth retains selected skin")
	var history := Achievements.new(); history.earned={"first":true,"upgrade":true}
	check(CatSkins.unseen_rewards(history).size()==2,"existing earned badges grant retroactive skin summary")
	history.acknowledge(["first","upgrade"])
	check(CatSkins.unseen_rewards(history).is_empty(),"acknowledged skin rewards are not announced again")
	DirAccess.remove_absolute(profile_path)
	print("Cat skins checks: %d failure(s)" % failures)
	quit(1 if failures else 0)
