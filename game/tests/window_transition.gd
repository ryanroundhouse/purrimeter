extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	print(('PASS ' if ok else 'FAIL ')+message)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var app=load('res://app.tscn').instantiate(); root.add_child(app)
	await process_frame; await process_frame
	root.size=Vector2i(1400,820)
	await create_timer(0.1).timeout
	var chosen_size=root.size
	app.show_create()
	await process_frame; await process_frame
	var create_page=app.page
	app.network.id='local'; app.network.room={'id':'test','name':'Transition test','owner':'local','players':[{'id':'local','name':'Local','connected':true}]}
	app.show_game(true)
	await create_timer(0.2).timeout
	check(root.size==chosen_size,'creating a multiplayer game preserves the chosen native window size')
	check(not is_instance_valid(create_page),'Create page is removed after entering gameplay')
	check(app.size==Vector2(1920,1080),'multiplayer fills its logical viewport')
	check(app.local_view.visible and app.local_view.gameplay_enabled,'local gameplay remains visible and interactive')
	app.show_menu()
	await create_timer(0.2).timeout
	check(root.size==chosen_size,'returning to the menu preserves the chosen native window size')
	app.show_game(false); await process_frame
	check(root.size==chosen_size and app.local_view.visible,'single player uses the same native window')
	app.queue_free(); await process_frame
	print('Window transition checks: %d failure(s)'%failures)
	quit(1 if failures else 0)
