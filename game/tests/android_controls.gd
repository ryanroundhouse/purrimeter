extends SceneTree
## Android input/layout regression checks against the real Session, isolated from saves.
var failures := 0
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func control(view: Control, id: String) -> Dictionary:
	for item in view.buttons:
		if item.id==id: return item
	return {}
func painted(view: Control) -> void:
	view.queue_redraw()
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
func touch(mobile: AndroidGarden, point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new(); event.position=point; event.pressed=pressed; event.index=index; mobile.handle(event)
func run() -> void:
	var app=load("res://app.tscn").instantiate(); root.add_child(app)
	for viewport in [Vector2i(844,390),Vector2i(640,320),Vector2i(1280,800)]:
		root.size=viewport; await process_frame; await process_frame
		app.show_game(false); var view=app.local_view; view.new_garden(); var mobile: AndroidGarden=view.mobile
		view.game.coins=Amount.of(10000); mobile.focused_camera=true
		await painted(view)
		check(mobile.field.size==view.size,"field occupies viewport %s"%viewport)
		check(is_equal_approx((mobile.transform*view.BOARD).size.x,view.size.x),"initial camera fills width without stretching")
		for id in ["start","speed","auto_start","menu","mobile_fit","mobile_powerups","android_recruit"]:
			var b=control(view,id)
			check(not b.is_empty() and b.rect.size.x>=48 and b.rect.size.y>=48,"%s has a touch target at %s"%[id,viewport])
		mobile.act("android_recruit"); await painted(view)
		check(not control(view,"cat0").is_empty(),"Recruit reveals cats")
		check(app.local_view.mobile.dismiss_layer() and not mobile.recruit_open,"Back closes recruitment palette")
		mobile.act("cat0"); await painted(view)
		var point: Vector2=mobile.transform*view.center(119)
		mobile.tap(point)
		check(mobile.pending==119 and view.game.towers.is_empty(),"tile preview does not buy")
		mobile.act("mobile_confirm")
		check(view.game.towers.size()==1,"Confirm purchases once")
		mobile.pending=119; var balance: float=view.game.coins.power; mobile.act("mobile_confirm")
		check(view.game.coins.power==balance,"occupied tile is revalidated")
		await painted(view)
		var start=control(view,"start"); var confirm=control(view,"mobile_confirm")
		check(not start.rect.intersects(confirm.rect),"Start and Confirm do not overlap")
		mobile.tap(start.rect.get_center()); check(view.game.active and view.placing==0,"Start works during placement")
		view.game.paused=true; await painted(view)
		mobile.tap(control(view,"resume").rect.get_center()); check(not view.game.paused,"Resume works during placement")
		app.open_pause(); app.go_back()
		check(not app.pause_open and view.placing==0,"Back closes Menu before the underlying placement")
		mobile.act("mobile_cancel"); view.game.paused=false; mobile.open_panel("powerups"); await painted(view)
		check(not view.game.paused,"Powerups does not pause combat")
		var pause=control(view,"pause")
		check(not mobile.sheet.get_rect().intersects(pause.rect),"Pause remains outside the panel")
		touch(mobile,pause.rect.get_center(),true); touch(mobile,pause.rect.get_center(),false)
		check(view.game.paused,"touch Pause works with Powerups open")
		check(Rect2(Vector2.ZERO,view.size).encloses(mobile.sheet.get_rect()),"panel fits screen")
		# A gesture retains ownership when it crosses a native panel.
		var outside: Vector2=Vector2(mobile.sheet.position.x-36,view.size.y/2)
		touch(mobile,outside,true)
		var crossing := InputEventScreenDrag.new(); crossing.index=0; crossing.position=mobile.sheet.get_rect().get_center(); mobile.handle(crossing)
		touch(mobile,crossing.position,false)
		check(mobile.touches.is_empty(),"field drag released over a panel leaves no stuck touch")
		mobile.close_panel(); await painted(view)
		# A drag starting on chrome cannot move the field or activate that control.
		var before: Vector2=mobile.pan; var power=control(view,"mobile_powerups")
		touch(mobile,power.rect.get_center(),true)
		var drag := InputEventScreenDrag.new(); drag.index=0; drag.position=power.rect.get_center()+Vector2(0,-40); mobile.handle(drag)
		touch(mobile,drag.position,false)
		check(mobile.pan==before and mobile.panel.is_empty(),"dragging a control never pans or opens it")
		mobile.focused_camera=false; mobile.zoom=1; mobile.pan=Vector2.ZERO; mobile.layout(); await painted(view)
		var middle: Vector2=mobile.field.get_center()
		touch(mobile,middle-Vector2(40,0),true,0); touch(mobile,middle+Vector2(40,0),true,1)
		drag.index=1; drag.position=middle+Vector2(120,0); mobile.handle(drag)
		touch(mobile,middle,false,0); touch(mobile,middle,false,1)
		check(mobile.zoom>1 and mobile.pending==-1,"pinch zooms without placing a cat")
		mobile.act("mobile_fit"); check(mobile.zoom==1 and mobile.pan==Vector2.ZERO,"Fit resets camera")
		mobile.act("mobile_fit"); check(is_equal_approx(mobile.zoom,mobile.focus_zoom()),"Focus restores enlarged field")
		view.read_only=true; mobile.act("cat1"); mobile.act("mobile_confirm"); mobile.act("speed")
		check(view.placing==-1 and view.game.speed==1,"read-only garden rejects mutations")
		mobile.act("mobile_powerups"); check(mobile.panel=="powerups","read-only garden allows Powerups inspection")
		mobile.close_panel(); view.read_only=false
		await painted(view)
		for b in view.buttons: check(Rect2(Vector2.ZERO,view.size).encloses(b.rect),"%s bounds at %s"%[b.id,viewport])
	# Pause must freeze automatic countdown as well as active combat.
	var countdown_view=app.local_view
	countdown_view.new_garden(); countdown_view.game.active=false; countdown_view.game.auto_start=true
	countdown_view.game.auto_start_remaining=3; countdown_view.game.paused=false
	await painted(countdown_view)
	var pause_countdown=control(countdown_view,"pause")
	check(not pause_countdown.is_empty(),"countdown exposes Pause")
	if not pause_countdown.is_empty(): countdown_view.mobile.tap(pause_countdown.rect.get_center())
	var remaining: float=countdown_view.game.auto_start_remaining
	countdown_view.game.step(0.5)
	check(countdown_view.game.paused and countdown_view.game.auto_start_remaining==remaining,"Pause freezes countdown")
	await painted(countdown_view)
	check(not control(countdown_view,"resume").is_empty(),"paused countdown exposes Resume")
	countdown_view.action("start")
	root.size=Vector2i(640,320); await process_frame; await process_frame
	app.network.id="mine"; app.network.room={"id":"room","name":"Android test","owner":"mine","players":[{"id":"mine","name":"Mine","connected":true},{"id":"friend","name":"Friend","connected":true}]}
	app.show_game(true); await process_frame; await process_frame
	var local: Control=app.local_view
	local.game.paused=false; local.mobile.act("android_recruit"); await painted(local)
	check(Rect2(Vector2.ZERO,local.size).encloses(local.mobile.palette),"recruitment fits the shorter multiplayer field")
	for id in ["cat0","cat1","cat2"]:
		check(not control(local,id).rect.intersects(control(local,"pause").rect),"multiplayer recruitment leaves Pause accessible")
	app.receive_field("friend",LiveField.capture(local.game,1,1,[])); app.expand_field("friend"); await process_frame
	var remote: Control=app.remote_cards.friend.view
	remote.selected=119; remote.mobile.open_panel("inspect"); await painted(remote)
	app.go_back()
	check(remote.mobile.panel.is_empty() and app.expanded=="friend","Back closes remote inspection before leaving its field")
	app.go_back()
	check(app.expanded.is_empty() and not local.game.paused,"Back from remote field preserves local running combat")
	app.queue_free(); await process_frame
	print("Android controls: %d failure(s)"%failures); quit(1 if failures else 0)
