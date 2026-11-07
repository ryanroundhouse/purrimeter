extends SceneTree
var failures := 0
var capture_dir := ""
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(6): await process_frame
func capture_image(name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
func veteran() -> Session:
	var g := Session.fresh(42,5); g.achievements.unlocked_level=5
	g.coins=Amount.of(10000)
	for cell in range(1,255):
		if g.build(0,cell): break
	g.best=20; g.run_best=5; g.level=6; g.auto_start=true; g.speed=2
	g.achievements.highest("best",50); g.achievements.highest("kills",5000); g.achievements.evaluate()
	CatSkins.equip(g.achievements,0,"scout_golden")
	g.rebirth()
	return g
func fresh_progress(g: Session) -> bool:
	return g.garden_level==1 and g.level==1 and g.coins.label()=="200" and g.towers.is_empty() and g.enemies.is_empty() and g.best==0 and g.rebirths==0 and g.pending_draft.is_empty() and g.draft_ranks.is_empty() and g.powerup_ranks.is_empty() and g.training==0 and not g.legacy_endless and not g.completed and g.achievements.unlocked_level==1 and g.achievements.earned.is_empty() and g.achievements.values.values().all(func(value): return value==0) and g.skin_id(0)=="scout_default"
func load_local(save: String, book: String) -> Session:
	var loaded := Session.new()
	check(SaveStore.read_achievements(loaded.achievements,book,save),"local achievement record readable")
	check(SaveStore.read_into(loaded,save),"local garden readable")
	return loaded
func persistence() -> void:
	var dir := ProjectSettings.globalize_path("res://../build/reset-tests-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	var save := dir.path_join("save.json"); var book := dir.path_join("achievements.json")
	var old := veteran(); var next := Session.fresh(17); next.paused=true; next.auto_start=true; next.speed=2
	check(SaveStore.write(old,save)==OK and SaveStore.write_achievements(old.achievements,book)==OK,"seed isolated progress files")
	check(SaveStore.reset_progress(next,save,book)==OK,"reset commits native progress")
	var loaded := load_local(save,book)
	check(fresh_progress(loaded) and loaded.auto_start and loaded.paused,"both native files reload as fresh progress with Auto retained")
	check(not FileAccess.file_exists(save+".reset"),"completed reset removes fresh-state recovery record")
	# Failure before the commit point must leave both old records untouched.
	SaveStore.write(old,save); SaveStore.write_achievements(old.achievements,book)
	DirAccess.make_dir_absolute(save+".reset.tmp")
	check(SaveStore.reset_progress(next,save,book)!=OK,"unwritable reset record rejects reset")
	loaded=load_local(save,book)
	check(loaded.achievements.unlocked_level==5 and loaded.achievements.earned.has("level50") and not loaded.pending_draft.is_empty(),"failed commit retains old progression and pending draft")
	DirAccess.remove_absolute(save+".reset.tmp")
	# Simulate interruptions at each normal-file boundary after commitment.
	for blocked in [book,save]:
		SaveStore.write(old,save); SaveStore.write_achievements(old.achievements,book)
		DirAccess.make_dir_absolute(blocked+".tmp")
		check(SaveStore.reset_progress(next,save,book)==OK and FileAccess.file_exists(save+".reset"),"reset is durable when finalizing %s fails" % blocked.get_file())
		loaded=load_local(save,book)
		check(fresh_progress(loaded),"interrupted reset cannot resurrect old player progress")
		DirAccess.remove_absolute(blocked+".tmp")
		check(SaveStore.finish_reset(save,book)==OK,"retry completes interrupted reset")
		check(fresh_progress(load_local(save,book)),"finished recovery remains fresh on next startup")
	# Old exports remain valid transfers after resetting.
	check(loaded.restore(old.snapshot()) and loaded.achievements.unlocked_level==5 and loaded.achievements.earned.has("level50"),"deliberate import restores previous progression")
	var fixture := FileAccess.open("res://../build/reset-browser-fixture.json",FileAccess.WRITE)
	fixture.store_string(JSON.stringify(old.snapshot(),"",true,true)); fixture.close()
	for file in DirAccess.get_files_at(dir): DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
func reset_button(app: Control) -> Button:
	for child in app.page.find_children("*","Button",true,false):
		if child.text=="Reset all progress": return child
	return null
func run() -> void:
	if "--multiplayer-test" not in OS.get_cmdline_user_args(): quit(1); return
	var args := OS.get_cmdline_user_args(); var at := args.find("--reset-capture")
	if at>=0: capture_dir=args[at+1]; DirAccess.make_dir_recursive_absolute(capture_dir)
	persistence()
	root.size=Vector2i(1280,900)
	var app=load("res://app.tscn").instantiate(); root.add_child(app); await settle()
	var v=app.local_view
	v.game=veteran(); v.connect_game(); v.game.paused=true
	v.audio.set_mute(true); v.route_on=false
	app.network.display_name="Reset tester"; app.network.chat_sound=false
	var identity: String=app.network.id; var address: String=app.network.address
	v.fanfare.book=v.game.achievements; v.fanfare.ids=["first"]; v.fanfare.skin_ids=["scout_ginger"]
	app.show_menu(); await settle()
	var before: Dictionary=v.game.snapshot()
	check(reset_button(app)!=null,"reset appears on main menu")
	reset_button(app).pressed.emit(); await settle()
	check(app.reset_dialog.visible and app.reset_dialog.is_visible_in_tree(),"confirmation is visible over the hidden garden")
	check(root.gui_get_focus_owner()==app.reset_dialog.cancel_button,"confirmation defaults to Cancel")
	app.go_back(); await settle()
	check(not app.reset_dialog.visible and v.game.snapshot()==before,"Back cancels without changing progression")
	app.confirm_reset_progress(); app.reset_dialog.cancel_button.pressed.emit()
	check(v.game.snapshot()==before,"Cancel button retains every progress field")
	# Desktop and responsive/browser/native-mobile layouts share this flow.
	var dimensions := [Vector2i(1280,900)]
	if GamePlatform.responsive(): dimensions=[Vector2i(1280,900),Vector2i(390,844),Vector2i(844,390)]
	if GamePlatform.native_mobile_controls(): dimensions=[Vector2i(844,390),Vector2i(640,320),Vector2i(1280,800)]
	for viewport in dimensions:
		root.size=viewport; await settle(); app.show_menu(); await settle()
		var reset := reset_button(app)
		if GamePlatform.native_mobile_controls():
			var menu: AndroidMenus=app.page.get_child(0); menu.scroll.ensure_control_visible(reset); await settle()
		await capture_image("menu-%dx%d" % [viewport.x,viewport.y])
		check(reset.size.y>=48,"reset has a 48px target at %s" % viewport)
		app.confirm_reset_progress(); await settle()
		check(Rect2(Vector2.ZERO,app.size).encloses(app.reset_dialog.panel.get_rect()),"confirmation fits %s" % viewport)
		check(app.reset_dialog.panel.get_global_rect().encloses(app.reset_dialog.accept_button.get_global_rect()),"destructive action stays in bounds at %s" % viewport)
		check(app.reset_dialog.cancel_button.size.y>=48,"Cancel stays touch-sized at %s" % viewport)
		check(app.reset_dialog.footer.vertical==(app.size.x<520),"confirmation actions use available width at %s" % viewport)
		check(app.reset_dialog.body.get_child(0).size.y<=app.reset_dialog.scroll.size.y,"complete loss warning is visible at %s" % viewport)
		await capture_image("confirmation-%dx%d" % [viewport.x,viewport.y])
		app.reset_dialog.close()
	app.confirm_reset_progress(); app.reset_dialog.accept_button.pressed.emit(); await settle()
	check(app.screen=="menu" and fresh_progress(v.game),"confirmed reset stays on menu with a fresh level-one garden")
	check(v.game.paused and not v.game.active and v.game.auto_start and v.game.auto_start_remaining==0 and v.game.speed==2,"reset preserves Auto and speed but requires manual Start")
	check(v.audio.muted and not v.route_on and app.network.display_name=="Reset tester" and not app.network.chat_sound and app.network.id==identity and app.network.address==address,"reset retains audio, route, identity and connection preferences")
	check(v.fanfare.book==v.game.achievements and v.fanfare.ids.is_empty() and v.fanfare.skin_ids.is_empty(),"old achievement and skin celebrations are discarded")
	await capture_image("success")
	app.open_achievements(); check(app.achievement_panel.game==v.game,"achievement panel uses fresh garden"); app.go_back()
	app.show_game(false); await settle(); app.open_pause(); await settle()
	check(not app.overlay.find_children("*","Button",true,false).any(func(b): return b.text=="Reset all progress"),"reset is absent from pause menu")
	app.close_pause(); app.show_menu(); await settle()
	# A read-only garden cannot be replaced, and the failure stays on the menu.
	v.read_only=true; before=v.game.snapshot()
	app.confirm_reset_progress(); app.reset_dialog.accept_button.pressed.emit(); await settle()
	check(v.game.snapshot()==before and app.notice.contains("unchanged") and app.screen=="menu","failed reset preserves live state and explains failure")
	v.read_only=false
	app.queue_free(); await process_frame
	print("Reset progress: %d failure(s)" % failures); quit(1 if failures else 0)
