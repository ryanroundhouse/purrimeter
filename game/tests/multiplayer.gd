extends SceneTree
var failures := 0
var app: Control
var guests: Array[GardenNetwork] = []
var errors: Array[String] = []
var incoming: Array[String] = []

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ")+message)
	if not condition: failures+=1

func until(predicate: Callable, seconds: float = 5.0) -> bool:
	var end := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if predicate.call(): return true
		await create_timer(0.02).timeout
	return predicate.call()

func _initialize() -> void: run.call_deferred()

func snapshot(name: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/multiplayer-"+name+".png"))

func fixture(level: int) -> Session:
	var g := Session.new(); g.coins=Amount.of(10000); g.level=level; g.best=level-1; g.run_best=level-1
	g.build(0,119); g.build(1,134); g.build(2,152); g.start()
	for i in range(90): g.step(1.0/60)
	g.paused=true; return g

func guest(name: String, address: String) -> GardenNetwork:
	var net := GardenNetwork.new(); net.isolated=true; root.add_child(net); net.display_name=name; net.address=address; net.connect_server(); guests.append(net)
	net.issue.connect(func(code, _message): errors.append(code))
	return net

func check_resume_after_chat() -> void:
	# Native mouse position is needed by the custom-drawn field's hit testing.
	# Headless runs still exercise keyboard focus; native runs cover the click.
	app.local_view.game.start(); app.local_view.game.paused=true
	app.chat_input.grab_focus()
	var key := InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=true
	Input.parse_input_event(key); await process_frame
	check(app.local_view.game.paused,"Space in chat does not resume combat")
	if DisplayServer.get_name()!="headless":
		var at: Vector2=app.local_view.get_global_transform()*Vector2(826,47)
		root.warp_mouse(at)
		await until(func(): return Rect2(772,25,108,44).has_point(app.local_view.get_local_mouse_position()))
		var click := InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=at
		root.push_input(click,true); await process_frame
		click.pressed=false; root.push_input(click,true); await process_frame
		check(not app.local_view.game.paused and not app.chat_input.has_focus(),"clicking Resume after chat returns control to the connected garden")
		var elapsed: float=app.local_view.game.elapsed
		app.local_view.game.step(0.1)
		check(app.local_view.game.elapsed>elapsed,"resumed multiplayer garden advances combat")
	app.chat_input.clear(); app.chat_input.release_focus()
	app.local_view.game.paused=true
	Input.parse_input_event(key); await process_frame
	check(not app.local_view.game.paused,"Space resumes multiplayer after leaving chat")
	app.local_view.game.paused=true

func run() -> void:
	var g := fixture(10)
	var state: Dictionary=JSON.parse_string(JSON.stringify(LiveField.capture(g,0,1),"",true,true))
	var copy := LiveField.decode(state)
	check(copy!=null and copy.level==10 and copy.paused and copy.towers.size()==3 and copy.enemies.size()==g.enemies.size(),"live representation round-trips combat independently of saves")
	var malformed := state.duplicate(true); malformed.garden.towers[0].kind=99
	check(LiveField.decode(malformed)==null,"remote artwork indexes are validated")
	malformed=state.duplicate(true); malformed.garden.enemies[0].progress="not a number"
	check(LiveField.decode(malformed)==null,"malformed remote positions are rejected")
	app=load("res://app.tscn").instantiate(); root.add_child(app)
	await process_frame; await process_frame
	check(app.screen=="menu" and not app.local_view.visible,"launch opens the main menu")
	await snapshot("menu")
	app.show_game(false); app.local_view.game.coins=Amount.of(1000); app.local_view.action("cat0"); app.local_view.interact_cell(119)
	var escape := InputEventKey.new(); escape.pressed=true; escape.keycode=KEY_ESCAPE
	Input.parse_input_event(escape); await process_frame
	check(app.local_view.placing==-1 and not app.pause_open,"first Escape cancels placement")
	Input.parse_input_event(escape); await process_frame
	check(app.pause_open and app.local_view.game.paused,"next Escape opens the pause menu")
	await snapshot("pause")
	Input.parse_input_event(escape); await process_frame
	check(not app.pause_open and app.local_view.game.paused,"closing the menu leaves the garden paused")
	app.local_view.queue_redraw(); await process_frame
	check(not app.local_view.buttons.any(func(b): return b.id in ["export","import"]),"import and export moved out of the gameplay toolbar")
	app.show_menu(); app.show_settings("menu"); await snapshot("settings")
	var address := "ws://127.0.0.1:18080/ws"
	var args := OS.get_cmdline_user_args(); var arg := args.find("--server")
	if arg>=0 and arg+1<args.size(): address=args[arg+1]
	app.network.address=address; app.network.display_name="Rowan"; app.show_browser(); app.network.connect_server()
	if not await until(func(): return app.network.authenticated):
		check(false,"local relay connection (start build/purrimeter-relay on port 18080)"); app.queue_free(); await process_frame; quit(1); return
	app.network.create_game("Evening garden","cats")
	check(await until(func(): return app.screen=="multiplayer"),"creating a game enters gameplay immediately")
	var room_id: String=app.network.room.id
	var b := guest("Robin",address)
	var c := guest("Robin",address)
	check(await until(func(): return b.authenticated and c.authenticated),"three Godot clients authenticate")
	b.join_game(room_id,"wrong")
	check(await until(func(): return "password" in errors),"wrong password rejected with actionable error")
	check(b.room.is_empty(),"wrong password never grants membership")
	b.join_game(room_id,"cats")
	check(await until(func(): return b.room.get("id")==room_id and app.remote_cards.size()==1),"second player joins with the correct password")
	await check_resume_after_chat()
	b.publish(state)
	check(await until(func(): return app.remote_cards.has(b.id) and app.remote_cards[b.id].view.game.level==10),"remote field shows independent level and deployed cats")
	var moving: Control=app.remote_cards[b.id].view
	var first_position: Vector2=moving.enemy_position(moving.game.enemies[0])
	g.paused=false
	for i in range(30): g.step(1.0/60)
	b.publish(LiveField.capture(g,0,2))
	check(await until(func(): return moving.remote_sequence==2),"moving enemy updates arrive while local combat is paused")
	await create_timer(0.15).timeout
	check(moving.enemy_position(moving.game.enemies[0]).distance_to(first_position)>0.1,"remote enemy positions interpolate to the latest field state")
	check(LiveField.capture(g,0,3).has("shots"),"field protocol carries attack effects")
	await snapshot("two-players")
	var local_scale: Vector2=app.local_view.scale
	c.join_game(room_id,"cats")
	check(await until(func(): return c.room.get("id")==room_id and app.remote_cards.size()==2),"third player joins the same game")
	var third := fixture(22); third.rebirths=5; third.speed=2; c.publish(LiveField.capture(third,0,1))
	check(await until(func(): return app.remote_cards.has(c.id) and app.remote_cards[c.id].view.game.level==22),"third player's progression and speed remain independent")
	check(local_scale.x>0 and app.local_view.scale==local_scale and app.remote_cards[b.id].view.scale.x>0 and app.remote_cards[b.id].view.scale.x<local_scale.x,"third player shares the right-hand area without shrinking the local field")
	check(app.remote_cards[b.id].name.text!=app.remote_cards[c.id].name.text,"duplicate names have distinct visible suffixes")
	await snapshot("three-players")
	if "--screenshots" in args and DisplayServer.get_name()!="headless":
		var previous_size := root.size; root.size=Vector2i(1280,720)
		await snapshot("three-players-small"); root.size=previous_size; await process_frame
	c.chat_received.connect(func(_id,_author,text): incoming.append(text))
	app.local_view.game.paused=false
	var chat_key := InputEventKey.new(); chat_key.pressed=true; chat_key.keycode=KEY_T; Input.parse_input_event(chat_key); await process_frame
	check(app.chat_input.has_focus() and not app.local_view.game.paused,"T focuses chat without pausing combat")
	app.chat_input.text="1 N Space should stay in chat"
	var key := InputEventKey.new(); key.pressed=true; key.keycode=KEY_2; app.local_view._input(key)
	check(app.local_view.placing==-1,"chat focus suppresses gameplay shortcuts")
	app.send_chat()
	check(await until(func(): return "1 N Space should stay in chat" in incoming),"chat reaches the other players")
	app.toggle_mute(b.id); b.say("muted message"); await create_timer(0.15).timeout
	check(not app.transcript.any(func(line): return "muted message" in line),"muted player's messages are hidden")
	app.chat_input.release_focus(); app.expand_field(b.id); await process_frame
	var viewer: Control=app.remote_cards[b.id].view
	viewer.interact_cell(119); var before: Dictionary=viewer.game.snapshot(); viewer.action("sell"); viewer.action("new")
	check(viewer.game.snapshot()==before and viewer.selected==119 and app.local_view.game.paused,"expanded inspection is read-only and pauses only local combat")
	await snapshot("inspect")
	viewer.selected=-1; viewer.selected_enemy=-1; Input.parse_input_event(escape); await process_frame
	check(app.expanded.is_empty(),"Escape closes an expanded remote field")
	app.close_expanded()
	app.local_view.gameplay_enabled=true
	app.local_view.file_action="import"
	var import_path := ProjectSettings.globalize_path("res://../build/multiplayer-import.json")
	SaveStore.write(third,import_path); app.local_view.file_selected(import_path); app.local_view.confirm.accept_button.pressed.emit()
	check(app.local_view.game.level==22 and app.local_view.game.paused and app.network.room.id==room_id,"import replaces the local garden while preserving membership")
	var saved: Dictionary=app.local_view.game.snapshot(); var badfile := FileAccess.open(import_path,FileAccess.WRITE); badfile.store_string("{\"version\":0}"); badfile.close()
	app.local_view.file_selected(import_path); app.local_view.confirm.accept_button.pressed.emit()
	check(app.local_view.game.snapshot()==saved,"failed import leaves current progress unchanged")
	var old_revision: int=app.revision; app.local_view.action("new"); app.local_view.confirm.accept_button.pressed.emit()
	check(app.local_view.game.level==1 and app.local_view.game.paused and app.revision==old_revision+1 and app.network.room.id==room_id,"New Garden retains multiplayer membership and advances the field revision")
	var replacement := LiveField.capture(Session.new(),1,2); b.publish(replacement)
	check(await until(func(): return viewer.game.level==1 and viewer.remote_revision==1),"live remote garden replacement clears the previous field")
	check(viewer.selected==-1,"replacement clears stale remote inspection")
	viewer.receive_field(state); check(viewer.remote_revision==1,"stale pre-import snapshots cannot restore old enemies")
	# A transport break must preserve the visit and authenticate a reserved-place resume.
	var original_id: String=app.network.id; var original_chat: int=app.transcript.size()
	app.network.socket.close(1000,"test connection interruption")
	check(await until(func(): return app.network.reconnecting),"connection loss enters the reconnect state")
	check(app.local_view.game.paused,"connection loss pauses local combat")
	check(await until(func(): return app.network.authenticated and not app.network.reconnecting,8),"client automatically rejoins its reserved place")
	check(app.network.id==original_id and app.network.room.id==room_id and app.transcript.size()==original_chat and app.remote_cards.size()==2,"reconnect preserves identity, chat and remote viewers")
	app.network.kick(c.id)
	check(await until(func(): return c.room.is_empty() and app.remote_cards.size()==1),"owner can remove a third player")
	c.join_game(room_id,"cats"); check(await until(func(): return "banned" in errors),"removed installation cannot rejoin that game")
	app.network.leave_game(); app.show_game(false)
	check(await until(func(): return b.room.get("owner")==b.id),"ownership transfers when the creator leaves")
	b.refresh(); await create_timer(0.1).timeout
	app.show_browser(); app.network.refresh(); await create_timer(0.1).timeout; await snapshot("browser")
	for net in guests: net.disconnect_server(); net.queue_free()
	app.network.disconnect_server(); app.queue_free()
	var invalid_identity := GardenNetwork.new(); invalid_identity.isolated=true; root.add_child(invalid_identity)
	check(invalid_identity.valid_address("wss://purrimeter.graham.pub/ws") and invalid_identity.valid_address("ws://127.0.0.1:8080/ws") and not invalid_identity.valid_address("ws://127.0.0.1:8080@remote.example/ws") and not invalid_identity.valid_address("ws://remote.example/ws"),"unencrypted server addresses are restricted to actual loopback hosts")
	invalid_identity.reconnecting=true; invalid_identity.room={"id":"expired-room"}
	invalid_identity._receive({"type":"error","code":"identity","message":"Reset identity"})
	check(not invalid_identity.reconnecting and invalid_identity.room.is_empty(),"invalid reconnect credentials stop retries and release the local visit")
	invalid_identity.queue_free()
	await process_frame; await process_frame
	print("Multiplayer checks: %d failure(s)"%failures)
	quit(0 if failures==0 else 1)
