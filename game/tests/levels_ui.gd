extends SceneTree
var failures := 0
var capture_dir := ""
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(6): await process_frame
func capture_image(name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
func run() -> void:
	if "--multiplayer-test" not in OS.get_cmdline_user_args(): quit(1); return
	var args := OS.get_cmdline_user_args(); var at := args.find("--levels-capture")
	if at>=0: capture_dir=args[at+1]; DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size=Vector2i(1280,900)
	var app=load("res://app.tscn").instantiate(); root.add_child(app)
	await settle(); app.show_game(false); await settle()
	var v=app.local_view; v.testing=true
	v.game=Session.fresh(42); v.connect_game(); v.game.paused=true
	v.action("new"); await settle()
	check(v.confirm.level_buttons.size()==5 and not v.confirm.level_buttons[1].disabled and v.confirm.level_buttons[2].disabled,"New Garden shows all five levels and locks unavailable ones")
	for selected in range(1,6):
		var choice: Button=v.confirm.level_buttons[selected]
		var labels := choice.find_children("*","Label",true,false)
		check(labels.any(func(l): return l.text==GardenLevels.level_name(selected)),"level %d shows its landscape name" % selected)
		check(labels.any(func(l): return l.text==GardenLevels.terrain_profile(selected).summary),"level %d describes its obstacles" % selected)
		check(choice.find_children("*","Control",true,false).any(func(c): return c.get_script()==preload("res://ui/level_terrain_icon.gd") and c.terrain_texture!=null),"level %d has a terrain icon, including locked choices" % selected)
	var original: Dictionary=v.game.snapshot()
	await capture_image("picker-locked")
	v.confirm.close(); check(v.game.snapshot()==original and v.game.paused,"cancel selection preserves paused garden")
	v.game.achievements.unlocked_level=4
	v.action("new"); await settle(); await capture_image("picker-desktop")
	v.confirm.level_buttons[3].pressed.emit(); await settle()
	check(v.confirm.visible and v.game.garden_level==1,"choosing a level asks before replacing the current garden")
	v.confirm.close(); check(v.game.garden_level==1,"cancelling replacement preserves the selected garden")
	v.action("new"); v.confirm.level_buttons[3].pressed.emit(); v.confirm.accept_button.pressed.emit(); await settle()
	check(v.game.garden_level==3 and v.game.level==1 and v.game.achievements.unlocked_level==4,"confirmation creates selected unlocked level")
	v.game.level=30; v.game.start(); v.game.spawned=v.game.wave_plan.size(); v.game.step(0.01)
	await settle()
	check(v.confirm.visible and v.game.completed and not v.game.active,"victory opens automatically after final wave")
	await capture_image("victory-desktop")
	v.confirm.accept_button.pressed.emit(); await settle()
	check(v.game.garden_level==3 and v.confirm.visible,"Next level confirms garden replacement")
	v.confirm.accept_button.pressed.emit(); await settle()
	check(v.game.garden_level==4 and not v.game.completed and v.game.level==1,"Next level creates fresh garden at next level")
	for dimensions in [Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions; await settle(); app.layout_game(); await settle()
		v.action("new"); await settle()
		check(Rect2(Vector2.ZERO,v.size).encloses(v.confirm.panel.get_rect()),"picker fits %s" % dimensions)
		check(v.confirm.level_buttons.values().all(func(b): return b.size.y>=48 and b.size.x<=v.confirm.scroll.size.x+1),"choices fit with 48px touch targets at %s" % dimensions)
		await capture_image("picker-%dx%d" % [dimensions.x,dimensions.y])
		v.confirm.close(); v.game.level=40; v.game.start(); v.game.spawned=v.game.wave_plan.size(); v.game.step(0.01); v.victory_presented=false
		await settle()
		check(Rect2(Vector2.ZERO,v.size).encloses(v.confirm.panel.get_rect()),"victory fits %s" % dimensions)
		check(v.confirm.body.size.y<=v.confirm.scroll.size.y+1,"victory heading and explanation fit without clipping at %s" % dimensions)
		await capture_image("victory-%dx%d" % [dimensions.x,dimensions.y])
		v.confirm.close(); v.new_garden(4); await settle()
	app.queue_free(); await process_frame
	print("Level UI: %d failure(s)" % failures); quit(1 if failures else 0)
