class_name GameSound
extends Node
const MUSIC_DB := -13.0
const CROSSFADE_SECONDS := 0.5
var music: AudioStreamPlayer
var boss_music: AudioStreamPlayer
var boss_themes: Array[AudioStreamWAV] = []
var current_theme := 0 # Zero is the garden; 1–5 are boss themes.
var effects: Dictionary = {}
var last: Dictionary = {}
var muted := false
var quiet := false
var focused := true
var _gains := Vector2(1.0,0.0)
var _fade_from := Vector2(1.0,0.0)
var _fade_elapsed := CROSSFADE_SECONDS

func setup(silent: bool = false) -> void:
	quiet=silent
	music=AudioStreamPlayer.new(); add_child(music)
	music.stream=looping_stream("res://assets/garden.wav")
	boss_music=AudioStreamPlayer.new(); add_child(boss_music)
	for theme in range(1,6):
		boss_themes.append(looping_stream("res://assets/boss_music_%d.wav" % theme))
	for name in ["bolt","cannon","frost","coin","build","upgrade","wave","clear","escape","break","win","lose","boss","rebirth"]:
		var path: String = "res://assets/"+name+".wav"
		if not ResourceLoader.exists(path): path="res://assets/wave.wav"
		effects[name]=[]
		for i in range(3):
			var player := AudioStreamPlayer.new()
			player.stream=load(path); player.volume_db=-15; add_child(player); effects[name].append(player)
	update_volumes()
	music.play()
	update_pause()

func looping_stream(path: String) -> AudioStreamWAV:
	var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	return stream

func set_level(level: int, active: bool, restart: bool = false) -> void:
	var theme := (int(level/10)-1)%5+1 if active and level%10==0 else 0
	if theme==current_theme and not (restart and theme>0): return
	current_theme=theme
	if theme>0:
		boss_music.stop()
		boss_music.stream=boss_themes[theme-1]
		_gains.y=0.0
		boss_music.play()
	_fade_from=_gains
	_fade_elapsed=0.0
	update_volumes()
	update_pause()

func _process(delta: float) -> void:
	# Real-time fades: independent of combat speed and tactical pause.
	if quiet or muted or not focused or _fade_elapsed>=CROSSFADE_SECONDS: return
	_fade_elapsed=minf(CROSSFADE_SECONDS,_fade_elapsed+delta)
	var target := Vector2(1.0,0.0) if current_theme==0 else Vector2(0.0,1.0)
	_gains=_fade_from.lerp(target,_fade_elapsed/CROSSFADE_SECONDS)
	update_volumes()
	if _fade_elapsed>=CROSSFADE_SECONDS:
		if current_theme==0: boss_music.stop()
		update_pause()

func update_volumes() -> void:
	music.volume_db=MUSIC_DB+linear_to_db(maxf(_gains.x,0.0001))
	boss_music.volume_db=MUSIC_DB+linear_to_db(maxf(_gains.y,0.0001))

func update_pause() -> void:
	var blocked := quiet or muted or not focused
	var fading := _fade_elapsed<CROSSFADE_SECONDS
	music.stream_paused=blocked or (current_theme>0 and (not fading or _gains.x==0.0))
	boss_music.stream_paused=blocked or (current_theme==0 and not fading)

func play(name: String, tier: int = 1) -> void:
	if muted or quiet or not effects.has(name): return
	var now := Time.get_ticks_msec()
	if now-last.get(name,0)<75: return
	last[name]=now
	for player in effects[name]:
		if not player.playing:
			player.pitch_scale=1.0+(tier-1)*0.045 if name in ["bolt","frost"] else 1.0-(tier-1)*0.025
			player.play(); break

func set_mute(value: bool) -> void:
	muted=value
	update_pause()
	if value:
		for pool in effects.values():
			for player in pool: player.stop()

func focus(active: bool) -> void:
	focused=active
	if music: update_pause()
