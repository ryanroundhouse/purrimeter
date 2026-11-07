extends SceneTree
var failures := 0
var capture_dir := ""
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(8): await process_frame
func capture_image(name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
func run() -> void:
	if "--multiplayer-test" not in OS.get_cmdline_user_args(): quit(1); return
	var args := OS.get_cmdline_user_args(); var at := args.find("--air-capture")
	if at>=0: capture_dir=args[at+1]; DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size=Vector2i(1280,900)
	var app=load("res://app.tscn").instantiate(); root.add_child(app)
	await settle(); app.show_game(false); await settle()
	var v=app.local_view; v.testing=true
	v.game=Session.new(); v.connect_game(); v.game.paused=true; await settle()
	v.action("cat3"); check(v.placing==-1,"locked Ranger cannot be selected through shortcuts")
	if v.mobile is AndroidGarden: v.mobile.recruit_open=true; await settle()
	check(v.buttons.any(func(b): return b.id=="cat3" and not b.enabled),"recruitment shows locked Ranger")
	await capture_image("recruit-locked")
	v.game=Session.fresh(42,2); v.game.achievements.unlocked_level=2; v.game.coins=Amount.of(10000); v.connect_game(); v.game.paused=true
	await settle(); v.action("cat3")
	check(v.placing==3,"Ranger becomes selectable with existing level-two unlock")
	var cell := -1
	for candidate in [115,116,117,118]:
		if v.game.placement_error(candidate,3).is_empty(): cell=candidate; break
	check(cell>=0 and v.game.build(3,cell),"Ranger recruits through shared placement validation")
	v.placing=-1; v.selected=cell
	check(v.game.towers[0].kind==3,"recruit action creates Ranger")
	v.game.start(); v.game.spawned=v.game.wave_plan.size()
	var moth: Dictionary=v.game.spawn_enemy({"kind":4,"boss":-1}); moth.cell=135; moth.next=136; moth.progress=.35; moth.hp=.72; Frenzy.initialize(moth)
	v.game.paused=true; v.game.elapsed=1.2
	await settle()
	if v.mobile is AndroidGarden: v.mobile.recruit_open=true; await settle()
	check(v.buttons.any(func(b): return b.id=="cat3" and b.enabled),"fourth recruit appears unlocked")
	check(v.buttons.all(func(b): return Rect2(Vector2.ZERO,v.size).encloses(b.rect)),"desktop fourth recruit fits all control bounds")
	await capture_image("ranger-and-moth")
	v.selected=-1; v.selected_enemy=moth.id
	if v.compact(): v.mobile.open_panel("inspect")
	await settle(); await capture_image("moth-inspector")
	v.mobile.close_panel(); v.selected_enemy=-1
	# A Moth remains inspectable when flying across permanent terrain.
	var rock := -1
	for c in v.game.terrain.cells:
		if c/16==8: rock=c; break
	if rock>=0:
		moth.cell=rock; moth.next=-1; moth.progress=0
		v.interact_cell(rock,v.enemy_rect(moth).get_center())
		check(v.selected_enemy==moth.id,"Moth can be inspected above a rock")
	v.selected_enemy=-1; moth.cell=135; moth.next=136; moth.progress=.35
	var dimensions_to_check := [Vector2i(844,390),Vector2i(640,360)] if GamePlatform.native_mobile_controls() else [Vector2i(844,390),Vector2i(640,360),Vector2i(390,844)]
	for dimensions in dimensions_to_check:
		root.size=dimensions; await settle(); app.layout_game(); await settle()
		v.placing=-1; v.selected=-1
		if v.mobile is AndroidGarden: v.mobile.recruit_open=true
		await settle()
		var recruits: Array=v.buttons.filter(func(b): return b.id in ["cat0","cat1","cat2","cat3"])
		check(recruits.size()==4,"four recruit controls at %s"%dimensions)
		check(recruits.all(func(b): return Rect2(Vector2.ZERO,v.size).encloses(b.rect) and b.rect.size.x>=44 and b.rect.size.y>=44),"four recruits fit with touch targets at %s"%dimensions)
		await capture_image("recruit-%dx%d"%[dimensions.x,dimensions.y])
		v.mobile.act("cat3"); check(v.placing==3,"touch selects Ranger at %s"%dimensions)
		v.mobile.act("mobile_cancel")
	root.size=Vector2i(640,360) if GamePlatform.native_mobile_controls() else Vector2i(360,740); await settle(); app.layout_game(); app.open_skins(); await settle()
	var skins=app.skins_panel
	check(skins.tabs.size()==4 and skins.panel.size.x<=root.size.x,"four skin tabs fit phone")
	skins.tabs[3].pressed.emit(); await settle()
	check(skins.cards.size()==1 and skins.cards.has("ranger_default"),"Ranger has one default skin")
	for tier in range(1,7):
		for frame in range(4):
			var source := CatSkinArt.source("ranger_default",tier,frame)
			check(source.size.x>100 and source.size.y>100,"Ranger tier %d frame %d has measured art"%[tier,frame])
	await capture_image("ranger-skin-phone")
	app.queue_free(); await process_frame
	print("Air UI: %d failure(s)"%failures); quit(1 if failures else 0)
