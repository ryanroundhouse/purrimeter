extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(390,844)
	var app=load("res://app.tscn").instantiate(); root.add_child(app)
	await process_frame; await process_frame
	app.show_game(false); await process_frame
	var view=app.local_view; var mobile=view.mobile
	mobile.layout()
	check(view.compact() and view.size.x==390,"phone uses its actual width")
	view.game.coins=Amount.of(10000)
	mobile.act("cat0")
	var point=mobile.transform*view.center(119)
	mobile.tap(point)
	check(mobile.pending==119 and view.game.towers.is_empty(),"tile tap previews without buying")
	mobile.act("mobile_confirm")
	check(view.game.towers.size()==1 and view.game.towers[0].cell==119,"confirmation recruits at the previewed tile")
	mobile.pending=120
	view.game.build(0,120)
	var coins=view.game.coins.power
	mobile.act("mobile_confirm")
	check(view.game.coins.power==coins and view.game.towers.size()==2,"confirmation revalidates occupied tiles without spending")
	mobile.act("mobile_cancel")
	mobile.zoom=2; mobile.pan=Vector2(20,-10); mobile.layout()
	mobile.tap(mobile.transform*view.center(119))
	check(view.selected==119 and mobile.panel=="inspect","zoomed tap inspects the correct cat")
	mobile.close_panel()
	view.game.start(); view.game.paused=false
	view.browser_event("hidden","")
	check(view.game.paused,"browser interruption pauses combat")
	view.browser_event("visible","")
	check(view.game.paused,"returning requires explicit resume")
	view.game.paused=false; mobile.open_panel("powerups")
	check(not view.game.paused,"opening powerups preserves running combat")
	mobile.close_panel()
	view.buttons=[{"id":"mobile_powerups","enabled":true,"rect":Rect2(0,0,44,44)}]; view.focus_id="mobile_powerups"
	var enter := InputEventKey.new(); enter.keycode=KEY_ENTER; enter.pressed=true
	view._input(enter)
	check(mobile.panel=="powerups","keyboard activates compact-only actions")
	mobile.close_panel()
	root.size=Vector2i(844,390); await process_frame; await process_frame
	app.layout_game(); mobile.layout()
	check(mobile.field.end.y<=view.size.y and view.game.towers.size()==2,"rotation preserves the garden and fits the board")
	app.network.id="mine"; app.network.room={"id":"room","name":"Phone test","owner":"mine","players":[{"id":"mine","name":"Mine","connected":true},{"id":"friend","name":"Friend","connected":true}]}
	app.show_game(true); await process_frame
	view.game.paused=false; app.expand_field("friend")
	check(not view.visible and not view.game.paused and app.remote_cards.friend.card.visible,"phone remote view preserves local combat")
	app.receive_chat("friend","Friend","Hello")
	check(app.unread==1,"closed phone chat counts unread messages")
	app.close_expanded()
	app.mobile_chat=true; app.phone_layout(); await process_frame; await process_frame
	var chat=app.page.get_node("Chat")
	check(chat.get_rect().end.y<=app.size.y,"phone chat stays inside the viewport")
	app.mobile_chat=false
	root.size=Vector2i(360,740); await process_frame; await process_frame
	app.layout_game(); app.open_pause(); await process_frame
	check(view.game.paused and app.pause_open,"phone menu pauses combat")
	app.open_achievements(); await process_frame; await process_frame
	check(app.achievement_panel.panel.size.x<=360,"achievement panel fits a narrow phone")
	app.achievement_panel.close(); app.open_skins(); await process_frame; await process_frame
	check(app.skins_panel.panel.size.x<=360,"skin panel fits a narrow phone")
	app.queue_free(); await process_frame
	print("Mobile checks: %d failure(s)"%failures); quit(1 if failures else 0)
