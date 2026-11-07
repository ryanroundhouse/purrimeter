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

func menu_button(text: String) -> Button:
	for control in app.overlay.find_children("*","Button",true,false):
		if control.text==text: return control
	return null

func check_view_audio(g: Session, net: GardenNetwork) -> void:
	var view: Control=app.remote_cards[net.id].view
	app.local_view.audio.quiet=false; view.audio.quiet=false
	app.app_focused=true; app.sync_audio_selection()
	check(not app.local_view.audio.enabled and view.audio.enabled and view.audio.current_theme==1,"View selects only the remote boss theme")
	check(app.remote_cards.values().all(func(item): return item.view==view or not item.view.audio.enabled),"small previews remain silent")
	var sounds := [{"id":1,"name":"build","tier":1}]
	net.publish(LiveField.capture(g,0,10,sounds))
	await until(func(): return view.remote_sequence==10)
	check(not view.audio.last.has("build"),"entering View discards previously buffered effects")
	sounds.append({"id":2,"name":"cannon","tier":4})
	net.publish(LiveField.capture(g,0,11,sounds))
	await until(func(): return view.remote_sequence==11)
	check(view.audio.last.has("cannon") and view.audio.effects.cannon.any(func(p): return p.playing and is_equal_approx(p.pitch_scale,0.925)),"fresh remote effects arrive through the relay with tower tier pitch")
	var played: int=view.audio.last.get("cannon",-1)
	await create_timer(.1).timeout
	net.publish(LiveField.capture(g,0,12,sounds)); await until(func(): return view.remote_sequence==12)
	check(view.audio.last.get("cannon",-1)==played,"repeated snapshot history never replays an effect")
	app.local_view.action("sound")
	check(view.audio.muted and view.audio.music.stream_paused and view.audio.boss_music.stream_paused,"viewer Sound setting controls remote music and effects")
	app.local_view.action("sound")
	app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT); app.local_view._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	sounds.append({"id":3,"name":"frost","tier":2})
	net.publish(LiveField.capture(g,0,13,sounds)); await until(func(): return view.remote_sequence==13)
	check(not app.local_view.game.paused and view.audio.boss_music.stream_paused and not view.audio.last.has("frost"),"unfocused viewing keeps local combat running but silences remote audio")
	app._notification(NOTIFICATION_APPLICATION_FOCUS_IN); app.local_view._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	net.publish(LiveField.capture(g,0,14,sounds)); await until(func(): return view.remote_sequence==14)
	check(not view.audio.last.has("frost") and not view.audio.boss_music.stream_paused,"focus return restores music without replaying missed effects")
	view.remote_connected=false; app.sync_audio_selection()
	check(not view.audio.enabled and view.audio.boss_music.stream_paused,"disconnected viewed garden becomes silent")
	view.remote_connected=true; app.sync_audio_selection()
	net.publish(LiveField.capture(g,0,15,sounds)); await until(func(): return view.remote_sequence==15)
	check(view.audio.enabled and not view.audio.last.has("frost"),"reconnected garden resumes without stale effects")
	app.close_expanded()
	check(app.local_view.audio.enabled and not view.audio.enabled and not app.local_view.game.paused,"closing View restores local audio without pausing running combat")
	app.local_view.game.paused=true; app.expand_field(net.id); app.close_expanded()
	check(app.local_view.game.paused,"viewing and closing preserves a manual pause")
	app.local_view.game.paused=false; app.expand_field(net.id)
	# Source sounds remain available to other viewers even when this client is muted.
	app.local_view.audio.set_mute(true); app.local_view.game.sound.emit("upgrade",6)
	check(app.local_view.live_sounds().any(func(s): return s.name=="upgrade" and s.tier==6),"muted local garden still publishes sound events")
	app.local_view.audio.set_mute(false); app.sync_audio_selection()

func snapshot(name: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/multiplayer-"+name+".png"))

func fixture(level: int) -> Session:
	var g := Session.new(); g.coins=Amount.of(10000); g.level=level; g.best=level-1; g.run_best=level-1
	g.terrain=GardenTerrain.decode([{"cell":70,"kind":GardenTerrain.ROCK,"style":2},{"cell":71,"kind":GardenTerrain.ROCK,"style":2},{"cell":72,"kind":GardenTerrain.STREAM,"style":1}])
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
	AudioServer.set_bus_mute(0,true)
	var g := fixture(10)
	g.achievements.award("first",true); CatSkins.equip(g.achievements,0,"scout_ginger")
	var state: Dictionary=JSON.parse_string(JSON.stringify(LiveField.capture(g,0,1),"",true,true))
	var copy := LiveField.decode(state)
	check(copy!=null and copy.level==10 and copy.paused and copy.towers.size()==3 and copy.enemies.size()==g.enemies.size(),"live representation round-trips combat independently of saves")
	var malformed := state.duplicate(true); malformed.garden.towers[0].kind=99
	check(LiveField.decode(malformed)==null,"remote artwork indexes are validated")
	malformed=state.duplicate(true); malformed.garden.enemies[0].progress="not a number"
	check(LiveField.decode(malformed)==null,"malformed remote positions are rejected")
	malformed=state.duplicate(true); malformed.sounds=[{"id":1,"name":"unknown","tier":1}]
	check(LiveField.decode(malformed)==null,"unknown remote sound names are rejected")
	malformed.sounds=[{"id":1,"name":"bolt","tier":7}]
	check(LiveField.decode(malformed)==null,"invalid remote sound tiers are rejected")
	malformed.sounds=[{"id":2,"name":"bolt","tier":1},{"id":1,"name":"coin","tier":1}]
	check(LiveField.decode(malformed)==null,"out-of-order sound identities are rejected")
	malformed=state.duplicate(true); malformed.erase("sounds")
	check(LiveField.decode(malformed)!=null,"older clients without sound events remain compatible")
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
	var route := menu_button("Route on"); var sound := menu_button("Sound on")
	check(route!=null and sound!=null and menu_button("New garden")!=null,"Escape menu contains route, sound and New Garden")
	if route!=null and sound!=null:
		route.pressed.emit(); sound.pressed.emit()
		check(not app.local_view.route_on and app.local_view.audio.muted and route.text=="Route off" and sound.text=="Sound off" and app.pause_open,"menu toggles update state and labels without dismissing the menu")
		route.pressed.emit(); sound.pressed.emit()
	await snapshot("pause")
	if "--screenshots" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		var previous_size := root.size; root.size=Vector2i(1280,720)
		await snapshot("pause-small"); root.size=previous_size; await process_frame
	Input.parse_input_event(escape); await process_frame
	check(not app.pause_open and app.local_view.game.paused,"closing the menu leaves the garden paused")
	app.local_view.queue_redraw(); await process_frame
	check(not app.local_view.buttons.any(func(b): return b.id in ["export","import","sound","route","new"]),"menu actions are absent from the gameplay toolbar")
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
	check(moving.game.terrain.snapshot()==g.terrain.snapshot(),"relay preserves obstacle geometry and connected styles")
	check(moving.game.skin_id(0)=="scout_ginger" and not CatSkins.unlocked(moving.game.achievements,"scout_ginger"),"relay shows owner's equipped skin without transferring unlocks")
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
	app.network.report(b.id)
	check(await until(func(): return "Report sent" in app.notice),"reporting a player is acknowledged by the relay")
	check(app.remote_cards[b.id].report.visible and app.remote_cards[b.id].mute.text=="Unmute","desktop cards offer Report beside Mute")
	app.chat_input.release_focus(); app.expand_field(b.id); await process_frame
	var viewer: Control=app.remote_cards[b.id].view
	viewer.interact_cell(119); var before: Dictionary=viewer.game.snapshot(); viewer.action("sell"); viewer.action("new")
	check(viewer.game.snapshot()==before and viewer.selected==119 and not app.local_view.game.paused,"expanded inspection is read-only and preserves running local combat")
	await check_view_audio(g,b)
	await snapshot("inspect")
	viewer.selected=-1; viewer.selected_enemy=-1; Input.parse_input_event(escape); await process_frame
	check(app.expanded.is_empty(),"Escape closes an expanded remote field")
	app.close_expanded()
	app.local_view.gameplay_enabled=true
	app.local_view.file_action="import"
	var import_path := ProjectSettings.globalize_path("res://../build/multiplayer-import.json")
	SaveStore.write(third,import_path); app.local_view.file_selected(import_path); app.local_view.confirm.accept_button.pressed.emit()
	check(app.local_view.game.level==22 and app.local_view.game.paused and app.network.room.id==room_id,"import replaces the local garden while preserving membership")
	app.show_updates()
	await until(func(): return app.screen=="updates",1.0)
	check(app.remote_cards.is_empty() and not app.network.room.is_empty(),"updates clear remote controls while retaining multiplayer membership")
	app.updater.changed.emit()
	check(app.get_viewport().gui_get_focus_owner() is Button,"update state changes retain a keyboard action")
	app.show_game(true)
	await until(func(): return not app.remote_cards.is_empty(),1.0)
	check(app.screen=="multiplayer" and not app.remote_cards.is_empty(),"returning from updates rebuilds remote gardens")
	viewer=app.remote_cards[b.id].view
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
