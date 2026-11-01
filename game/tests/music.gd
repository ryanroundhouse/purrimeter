extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Exercise the actual scene wiring without touching player saves or preferences.
	if not "--music-test" in OS.get_cmdline_user_args():
		push_error("Run with -- --music-test to isolate player data."); quit(1); return
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var audio: GameSound = scene.audio
	AudioServer.set_bus_mute(0,true)
	audio.quiet=false; audio.focus(true); audio.set_process(false)
	await create_timer(.12).timeout
	check(audio.music.playing and not audio.music.stream_paused and audio.current_theme==0,"fresh garden plays regular music")
	var unique := {}
	for stream in audio.boss_themes:
		unique[hash(stream.data)]=true
		check(stream.get_length()>40.0 and stream.get_length()<60.0 and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"boss theme is a complete looping score")
	check(unique.size()==5,"all five boss scores contain different audio")
	scene.game.level=10; scene.action("start")
	check(audio.current_theme==1 and scene.game.enemies.is_empty(),"manual Start selects boss music before any enemy spawns")
	audio._process(.25)
	check(absf(audio.music.volume_db-audio.boss_music.volume_db)<.01 and not audio.music.stream_paused,"halfway through crossfade both tracks have equal gain")
	audio._process(.25)
	check(audio.music.stream_paused and not audio.boss_music.stream_paused and is_equal_approx(audio.boss_music.volume_db,GameSound.MUSIC_DB),"half-second fade leaves only boss music playing")
	var garden_position := audio.music.get_playback_position()
	await create_timer(.12).timeout
	check(absf(audio.music.get_playback_position()-garden_position)<.02,"garden playback position is held during the boss level")
	var boss_position := audio.boss_music.get_playback_position()
	scene.game.changed.emit()
	await create_timer(.12).timeout
	check(audio.boss_music.get_playback_position()>boss_position,"ordinary gameplay changes do not restart the theme")
	scene.action("pause")
	check(scene.game.paused and not audio.boss_music.stream_paused,"tactical pause keeps boss music playing")
	scene.action("speed")
	check(scene.game.speed==2 and audio.boss_music.pitch_scale==1.0,"double combat speed leaves music tempo unchanged")
	audio.set_mute(true)
	check(audio.music.stream_paused and audio.boss_music.stream_paused,"mute pauses both music players")
	audio.focus(false); audio.set_mute(false)
	check(audio.boss_music.stream_paused,"unmuting while unfocused does not resume music")
	audio.set_mute(true); audio.focus(true)
	check(audio.boss_music.stream_paused,"regaining focus while muted does not resume music")
	audio.set_mute(false)
	check(not audio.boss_music.stream_paused,"music resumes when focused and unmuted")
	# A boss can die before its escorts; music follows the level, not the boss.
	var boss: Dictionary = scene.game.spawn_enemy({"kind":0,"boss":0})
	scene.game.spawn_enemy({"kind":0,"boss":-1})
	scene.game.enemies.erase(boss); scene.game.changed.emit()
	check(audio.current_theme==1,"remaining escorts keep the boss theme after boss death")
	scene.game.paused=false; scene.game.enemies.clear(); scene.game.spawned=scene.game.wave_plan.size()
	scene.game.set_auto_start(true); scene.game.step(.01)
	check(audio.current_theme==0 and scene.game.auto_start_remaining==3.0,"boss clear returns to garden music during countdown")
	audio._process(.5)
	check(not audio.music.stream_paused and not audio.boss_music.playing and audio.music.get_playback_position()>=garden_position,"garden resumes its previous position after clear")
	scene.game.paused=false; scene.game.step(3.0,3.0)
	check(scene.game.active and scene.game.level==11 and audio.current_theme==0,"ordinary auto-start stays on garden music")
	scene.game.defeat()
	check(scene.game.level==10 and audio.current_theme==0,"preparation for a boss retry uses garden music")
	scene.action("start"); audio._process(.5)
	check(audio.current_theme==1 and audio.boss_music.get_playback_position()<.1,"boss retry restarts the same theme")
	scene.game.defeat(); audio._process(.5)
	check(audio.current_theme==0 and scene.game.level==9,"boss defeat returns to garden music")
	for level in [20,30,40,50,60,100,1000000000]:
		scene.game.level=level; scene.game.start()
		var expected := (int(level/10)-1)%5+1
		check(audio.current_theme==expected and audio.boss_music.stream==audio.boss_themes[expected-1],"correct theme at level %d" % level)
		scene.game.defeat()
	# Auto-start into a boss level uses the same signal path as manual Start.
	scene.game.level=9; scene.game.start(); scene.game.spawned=scene.game.wave_plan.size(); scene.game.step(.01)
	scene.game.step(3.0,3.0)
	check(scene.game.active and scene.game.level==10 and audio.current_theme==1,"auto-start into level 10 selects boss music")
	audio._process(.5)
	audio.boss_music.seek(8.0)
	var saved: Dictionary = scene.game.snapshot()
	var path := "/tmp/purrimeter-boss-music-test-%d.json"%OS.get_process_id()
	check(SaveStore.write(scene.game,path)==OK,"temporary boss save written")
	scene.file_action="import"; scene.file_selected(path); scene.confirm.accept()
	check(scene.game.active and scene.game.paused and audio.current_theme==1 and audio.boss_music.get_playback_position()<.1,"actual import restarts the theme even when importing the same boss level")
	DirAccess.remove_absolute(path)
	check(not saved.has("music") and not saved.has("music_position"),"save format does not store audio state")
	audio._process(.5)
	audio.boss_music.seek(audio.boss_music.stream.get_length()-.08)
	await create_timer(.25).timeout
	check(audio.boss_music.playing and audio.boss_music.get_playback_position()<1.0,"boss score loops past its end without stopping")
	scene.action("new"); scene.confirm.accept(); audio._process(.5)
	check(not scene.game.active and audio.current_theme==0 and not audio.music.stream_paused,"New Garden exits boss music")
	scene.game.level=10; scene.game.start(); audio._process(.5)
	scene.game.spawned=scene.game.wave_plan.size(); scene.game.step(.01)
	scene.game.rebirth(); audio._process(.5)
	check(scene.game.level==1 and audio.current_theme==0,"rebirth keeps regular music")
	scene.game.choose_draft(scene.game.pending_draft.offers[0]); scene.draft_panel.finish_choice()
	# Freeze a transition and change the selected level while muted.
	scene.game.level=20; scene.game.start(); audio._process(.2)
	audio.set_mute(true)
	var volume := audio.boss_music.volume_db
	audio._process(2.0)
	check(audio.boss_music.volume_db==volume,"muting freezes an in-progress crossfade")
	scene.game.defeat(); audio.set_mute(false); audio._process(.5)
	check(audio.current_theme==0 and not audio.boss_music.playing,"ending a muted boss level cannot resume stale boss music")
	scene.game.level=30; scene.game.start(); audio._process(.2); scene.game.defeat(); audio._process(.5)
	check(audio.current_theme==0 and not audio.boss_music.playing and not audio.music.stream_paused,"rapid start and defeat settle on garden music")
	scene.game.level=9; scene.game.run_best=8; scene.game.start(); scene.game.set_auto_start(true)
	audio.last.clear(); audio.play("cannon")
	check(audio.effects.cannon.any(func(p): return p.playing),"combat effect starts while focused")
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not scene.game.paused and audio.music.stream_paused and not audio.effects.cannon.any(func(p): return p.playing),"focus loss silences music and existing effects without pausing combat")
	audio.play("frost")
	check(not audio.last.has("frost"),"unfocused combat does not start new effects")
	scene.game.spawned=scene.game.wave_plan.size(); scene.game.enemies.clear(); scene.game.step(0.01)
	scene.game.step(3.0,3.0)
	check(scene.game.active and scene.game.level==10 and audio.current_theme==1,"unfocused auto-start continues into the boss level")
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_IN); audio._process(.5)
	check(not audio.boss_music.stream_paused and not scene.game.paused,"focus return uses the current boss theme and preserves running combat")
	scene.game.paused=true
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT); scene._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(scene.game.paused,"focus changes preserve an explicit pause")
	scene.game.rebirth(); audio._process(.5)
	check(not scene.game.active and scene.game.level==1 and audio.current_theme==0,"mid-boss rebirth ends combat and boss music")
	scene.queue_free()
	await process_frame
	print("Boss music: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
