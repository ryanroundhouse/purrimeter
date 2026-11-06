extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func settled() -> void:
	for _i in range(5): await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	var app=load("res://app.tscn").instantiate(); root.add_child(app)
	for viewport in [Vector2i(844,390),Vector2i(640,320),Vector2i(1280,800)]:
		root.size=viewport; app.show_menu(); await settled()
		var main: AndroidMenus=app.page.get_child(0)
		check(Rect2(Vector2.ZERO,app.size).encloses(main.panel.get_rect()),"main menu fits %s"%viewport)
		check(main.hero.size.x>app.size.x*0.3,"main menu preserves artwork beside controls")
		for id in ["single","multiplayer","achievements","skins","settings","updates"]:
			check(main.controls[id].size.y>=48,"main %s has a touch target"%id)
		main.controls.single.pressed.emit(); await settled()
		check(app.screen=="single","Single player enters existing garden")
		app.local_view.game.start(); app.open_pause(); await settled()
		var menu: AndroidMenus=app.overlay
		check(app.local_view.game.paused and not app.local_view.gameplay_enabled,"menu stops combat and field input")
		check(Rect2(Vector2.ZERO,app.size).encloses(menu.panel.get_rect()),"pause menu fits %s"%viewport)
		check(menu.panel.size.x<app.size.x*0.63,"pause menu leaves field visible")
		for id in menu.controls:
			check(menu.controls[id].size.y>=48,"pause %s has a touch target"%id)
		check(menu.panel.get_global_rect().encloses(menu.controls.resume.get_global_rect()),"Resume always visible")
		check(menu.panel.get_global_rect().encloses(menu.controls.stay_paused.get_global_rect()),"stay-paused close always visible")
		if viewport.y<500:
			menu.scroll.scroll_vertical=100
			await settled()
			check(menu.scroll.scroll_vertical>0,"scroll position survives rendering")
		var route: bool=app.local_view.route_on
		menu.controls.route.pressed.emit(); check(app.local_view.route_on!=route,"route toggle remains connected")
		menu.controls.achievements.pressed.emit(); app.go_back()
		check(app.pause_open and not app.achievement_panel.visible,"Back returns from achievements to paused menu")
		menu.controls.skins.pressed.emit(); app.go_back()
		check(app.pause_open and not app.skins_panel.visible,"Back returns from skins to paused menu")
		menu.controls.stay_paused.pressed.emit()
		check(not app.pause_open and app.local_view.game.paused,"close keeps tactical pause")
		app.open_pause(); await settled(); app.overlay.controls.resume.pressed.emit()
		check(not app.pause_open and not app.local_view.game.paused,"Resume restarts combat")
		app.open_pause(); await settled(); app.overlay.controls.new.pressed.emit()
		check(app.local_view.confirm.visible,"New garden still requires confirmation")
		app.go_back(); check(not app.local_view.confirm.visible,"Back dismisses New garden confirmation")
		app.open_pause(); await settled(); app.overlay.controls.main.pressed.emit()
		check(app.local_view.confirm.visible and app.screen=="single","Main menu return remains confirmed")
		app.local_view.confirm.accept_button.pressed.emit(); await settled()
		check(app.screen=="menu" and app.local_view.game.paused,"confirmed return saves and pauses garden")
	app.queue_free(); await process_frame
	print("Android menus: %d failure(s)"%failures); quit(1 if failures else 0)
