extends SceneTree
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
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	var app=load("res://app.tscn").instantiate(); root.add_child(app)
	for viewport in [Vector2i(844,450),Vector2i(390,844),Vector2i(360,640)]:
		root.size=viewport; await process_frame; await process_frame
		app.show_game(false); app.local_view.new_garden()
		var view=app.local_view; var mobile=view.mobile
		await painted(view)
		check(not control(view,"start").is_empty(),"Start is visible before recruitment at %s"%viewport)
		mobile.act("cat0")
		for cell in [119,120,121,122]:
			mobile.pending=cell; mobile.act("mobile_confirm")
		await painted(view)
		check(view.game.coins.label()=="0" and view.placing==0,"reproduce zero coins with recruitment still selected")
		var start=control(view,"start")
		var confirm=control(view,"mobile_confirm")
		var auto=control(view,"auto_start")
		check(not start.is_empty() and start.enabled,"Start stays available during recruitment at %s"%viewport)
		check(not auto.is_empty(),"Auto stays available during recruitment")
		for item in view.buttons:
			check(Rect2(Vector2.ZERO,view.size).encloses(item.rect),"%s fits inside %s"%[item.id,viewport])
		if not start.is_empty():
			check(Rect2(Vector2.ZERO,view.size).encloses(start.rect) and not start.rect.intersects(confirm.rect),"wave and placement controls fit without overlapping")
			mobile.tap(start.rect.get_center())
			check(view.game.active and view.placing==0,"tap starts combat without cancelling recruitment")
			view.game.paused=true; await painted(view)
			var resume=control(view,"resume")
			check(not resume.is_empty() and resume.enabled,"Resume stays available while recruiting during a paused wave")
			if not resume.is_empty(): mobile.tap(resume.rect.get_center()); check(not view.game.paused,"tap resumes combat")
		await painted(view)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/mobile-wave-controls-%dx%d.png"%[viewport.x,viewport.y]))
	app.queue_free(); await process_frame
	print("Mobile wave controls: %d failure(s)"%failures); quit(1 if failures else 0)
