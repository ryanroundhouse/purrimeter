extends SceneTree
var failures := 0
var app: Control
var capture_dir := ""

func check(ok: bool, message: String) -> void:
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+message)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))

func run() -> void:
	if "--multiplayer-test" not in OS.get_cmdline_user_args():
		push_error("Use -- --multiplayer-test to isolate player data."); quit(1); return
	var args := OS.get_cmdline_user_args(); var at := args.find("--achievement-capture")
	if at>=0 and at+1<args.size(): capture_dir=args[at+1]
	app=load("res://app.tscn").instantiate(); root.add_child(app)
	await process_frame; await process_frame
	await capture("achievements-main-menu")
	app.open_achievements()
	await process_frame; await process_frame
	var panel = app.achievement_panel
	check(panel.visible and panel.entries.size()==30,"main menu exposes all 30 achievements")
	check(panel.panel.size.x<=root.get_visible_rect().size.x and panel.panel.size.y<=root.get_visible_rect().size.y,"achievement frame fits viewport")
	await capture("achievements-all")
	panel.filters["Earned"].pressed.emit(); await process_frame
	check(panel.entries.is_empty(),"earned filter has an honest fresh-player empty state")
	await capture("achievements-empty")
	panel.filters["All"].pressed.emit()
	panel.selection="medic"; panel.refresh_details(); await process_frame
	await capture("achievements-challenge")
	var escape := InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	Input.parse_input_event(escape); await process_frame
	check(not panel.visible and app.screen=="menu","Escape closes achievements without leaving main menu")
	app.show_game(false); app.local_view.game.paused=false
	app.open_achievements(); await process_frame
	check(app.local_view.game.paused and not app.local_view.gameplay_enabled,"opening achievements freezes local combat and inputs")
	app.layout_game()
	check(not app.local_view.gameplay_enabled,"layout refresh cannot enable gameplay behind achievement menu")
	panel.close()
	check(not app.local_view.game.paused and app.local_view.gameplay_enabled,"closing restores a previously running garden")
	app.open_pause(); await capture("achievements-pause-menu"); app.open_achievements(); panel.close()
	check(app.pause_open and app.local_view.game.paused and not app.local_view.gameplay_enabled,"opening from Escape returns to the paused menu")
	app.close_pause()
	var g: Session=app.local_view.game; g.coins=Amount.from_power(40)
	g.build(0,119); g.upgrade(119); g.buy_powerup("training")
	app.open_achievements(); panel.filters["Earned"].pressed.emit(); panel.selection="upgrade"; panel.refresh_details()
	await process_frame; await capture("achievements-earned")
	check(panel.entries.size()==2,"earned filter and count reflect gameplay")
	panel.close()
	var f=app.local_view.fanfare
	f.advance(0.1,true); check(f.visible and f.ids.size()==1,"live achievement starts one banner")
	var elapsed: float=f.clock
	f.advance(1,false); check(not f.visible and f.clock==elapsed,"hidden or unfocused banner freezes without consuming queue")
	f.advance(0.1,true)
	await capture("achievements-fanfare")
	var first: String=f.ids[0]
	for i in range(42): f.advance(0.1,true)
	check(not g.achievements.pending.has(first) and not g.achievements.pending.is_empty(),"completed banner acknowledges only its own unlock")
	var book=g.achievements
	app.local_view.new_garden()
	check(app.local_view.game.achievements==book and book.earned.has("upgrade"),"New Garden keeps actual UI achievement book")
	g=app.local_view.game
	g.achievements.acknowledge(g.achievements.pending.duplicate()); f.ids.clear(); f.skin_ids.clear()
	var saved := Session.new(); saved.best=25; saved.kills=150
	var legacy:=saved.snapshot(); legacy.erase("achievements"); legacy.erase("achievement_run")
	g.restore(legacy)
	f.advance(.1,true)
	check(f.ids.size()>1 and f.heading.contains("added"),"legacy unlocks are grouped into one summary")
	await capture("achievements-summary")
	app.open_achievements(); panel.filters["In Progress"].pressed.emit()
	check(not panel.entries.has("first") and panel.entries.has("level50"),"in-progress filter excludes earned entries")
	for row in Achievements.ITEMS:
		panel.selection=row[0]; panel.refresh_details(); await process_frame
		check(panel.details.size.x>200 and panel.details.position.x+panel.details.size.x<=panel.body.size.x+1,"detail fits: "+row[1])
	panel.close()
	print("Achievement UI checks: %d failure(s)" % failures)
	app.queue_free(); await process_frame; quit(1 if failures else 0)
