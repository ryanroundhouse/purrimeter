extends Control
signal menu_requested
signal garden_replaced
signal audio_settings_changed
const PatrolDialog = preload("res://ui/patrol_dialog.gd")
const INK := Color("131c26")
const PANEL := Color("202e3a")
const CREAM := Color("f4edd7")
const MUTED := Color("b0c3bd")
const LINE := Color("3d514e")
const DISABLED := Color("94a9a3")
const MINT := Color("89dfb5")
const GOLD := Color("ffc46b")
const PINK := Color("fa7897")
const BOARD := Rect2(28,134,704,704)
const TILE := 44.0
var game := Session.new()
var audio := GameSound.new()
var font: Font = ThemeDB.fallback_font
var cat_textures: Array = []
var enemy_texture: Texture2D
var bosses: Texture2D
var selected_powerup := "training"
var powerup_tab := "available"
var powerup_page := 0
var powerup_icons: Dictionary = {}
const POWERUPS_PER_PAGE := 8
var selected := -1
var selected_enemy := -1
var placing := -1
var hover := -1
var route_on := true
var buttons: Array = []
var focus_id := ""
var keyboard_cell := 119
var status := "Welcome, commander. Recruit a cat and guard the garden."
var ui_clock := 0.0
var save_clock := 0.0
var accumulator := 0.0
var testing := false
var startup_save_valid := true
var preview := false
var preview_path := ""
var preview_gallery := false
var confirm: PatrolDialog
var file_dialog: FileDialog
var file_action := ""
var prefs := ConfigFile.new()
var read_only := false
var remote_compact := false
var remote_connected := true
var gameplay_enabled := true
var hosted := false
var remote_revision := -1
var remote_sequence := -1
var remote_from := {}
var remote_to := {}
var remote_clock := 0.1
var remote_sound_id := 0
var skip_remote_sounds := true
var sound_sequence := 0
var recent_sounds: Array = []
var fanfare: Control
var achievement_save_valid := true
var mobile: MobileGarden
var browser_blocked := false
var draft_panel: Control
var draft_saving := false

func compact() -> bool:
	return (OS.has_feature("web") or "--mobile-test" in OS.get_cmdline_user_args()) and (size.x<1100 or size.y<720 or BrowserPlatform.touch())


func _ready() -> void:
	mobile=MobileGarden.new(self)
	testing="--smoke-test" in OS.get_cmdline_user_args() or "--music-test" in OS.get_cmdline_user_args()
	preview="--preview" in OS.get_cmdline_user_args()
	preview_gallery="--gallery" in OS.get_cmdline_user_args()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for name in ["tuxedo","chunky","siamese"]:
		cat_textures.append(load("res://assets/"+name+".png") if ResourceLoader.exists("res://assets/"+name+".png") else load("res://assets/characters.png"))
	for row in Powerups.ITEMS: powerup_icons[row[0]]=load("res://assets/powerups/"+row[0]+".svg")
	enemy_texture=load("res://assets/characters.png")
	bosses=load("res://assets/bosses.png") if ResourceLoader.exists("res://assets/bosses.png") else enemy_texture
	audio.enabled=not read_only
	add_child(audio); audio.setup(testing or preview or "--multiplayer-test" in OS.get_cmdline_user_args() or "--app-preview" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless")
	connect_game()
	if not testing and not preview and not read_only:
		achievement_save_valid=SaveStore.read_achievements(game.achievements) if not OS.has_feature("web") else true
		if BrowserPlatform.enabled():
			startup_save_valid=BrowserPlatform.load_garden(game)
			if not startup_save_valid: browser_blocked=true; status="Saved garden could not be read. Export a backup before replacing it."
		elif FileAccess.file_exists(SaveStore.SAVE_PATH):
			startup_save_valid=SaveStore.read_into(game)
			status="Welcome back. Your patrol is paused and ready." if startup_save_valid else "Save could not be read. A fresh garden is ready."
		if BrowserPlatform.enabled(): BrowserPlatform.load_settings("audio",prefs)
		else: prefs.load("user://settings.cfg")
		audio.set_mute(prefs.get_value("audio","muted",false))
	if not achievement_save_valid: status="Achievement record could not be read. Export your garden to keep a recovery copy."
	if not testing and not preview and not read_only: save_achievements()
	fanfare=preload("res://ui/achievement_fanfare.gd").new(); add_child(fanfare)
	fanfare.book=game.achievements; fanfare.audio=audio; fanfare.persist=save_achievements
	sync_music(true)
	confirm=PatrolDialog.new(); add_child(confirm)
	draft_panel=preload("res://ui/draft_panel.gd").new(); add_child(draft_panel)
	draft_panel.chosen.connect(commit_draft)
	file_dialog=FileDialog.new(); add_child(file_dialog)
	file_dialog.access=FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters=PackedStringArray(["*.json ; Purrimeter save"])
	file_dialog.file_selected.connect(file_selected)
	get_tree().auto_accept_quit=false
	if preview and not read_only: make_preview(); capture.call_deferred()
	if "--smoke-test" in OS.get_cmdline_user_args() and not read_only: smoke_test.call_deferred()

func connect_game() -> void:
	selected_enemy=-1
	recent_sounds.clear()
	if not game.achievements.earned_now.is_connected(on_achievement): game.achievements.earned_now.connect(on_achievement)
	game.sound.connect(play_game_sound)
	game.notice.connect(func(message): status=message)
	game.changed.connect(func(): save_clock=4.0; sync_music(); validate_selection())
	sync_music(true)

func sync_music(restart: bool = false) -> void:
	audio.set_level(game.level,game.active,restart)

func play_game_sound(name: String, tier: int = 1) -> void:
	audio.play(name,tier)
	# Spectators use their own preferences, independently of the owner's mute/focus state.
	sound_sequence+=1
	recent_sounds.append({"id":sound_sequence,"name":name,"tier":tier,"at":Time.get_ticks_msec()})
	if recent_sounds.size()>LiveField.MAX_SOUNDS: recent_sounds.pop_front()

func live_sounds() -> Array:
	var cutoff := Time.get_ticks_msec()-500
	while not recent_sounds.is_empty() and recent_sounds[0].at<cutoff: recent_sounds.pop_front()
	var result := []
	for sound in recent_sounds: result.append({"id":sound.id,"name":sound.name,"tier":sound.tier})
	return result

func _notification(what: int) -> void:
	if read_only: return
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if not hosted: save_game(); get_tree().quit()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		audio.focus(false)
		if OS.has_feature("web"): game.paused=true
		save_game()
	if what==NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready(): audio.focus(true)

func _process(delta: float) -> void:
	ui_clock+=minf(delta,0.1)
	if mobile!=null: mobile.process(delta)
	if browser_blocked or not BrowserPlatform.may_save(): game.paused=true
	if read_only:
		if remote_connected: remote_clock=minf(0.1,remote_clock+delta)
	elif not preview and not testing:
		accumulator+=minf(delta,0.1)*game.speed
		while accumulator>=1.0/60.0:
			game.step(1.0/60.0,1.0/(60.0*game.speed)); accumulator-=1.0/60.0
		save_clock+=delta
		if save_clock>=4.0: save_game(); save_clock=0.0
	validate_selection()
	if not read_only and gameplay_enabled and not draft_saving and not game.pending_draft.is_empty() and not draft_panel.visible and not confirm.visible and not file_dialog.visible:
		mobile.close_panel(); draft_panel.show_draft(game)
	if fanfare!=null and not read_only:
		fanfare.advance(delta,is_visible_in_tree() and gameplay_enabled and audio.focused and not confirm.visible and not file_dialog.visible and not draft_panel.visible and not draft_saving)
	queue_redraw()

func on_achievement(_id: String) -> void:
	save_achievements()

func save_achievements() -> void:
	if read_only or testing or preview or not achievement_save_valid or OS.has_feature("web"): return
	if SaveStore.write_achievements(game.achievements)!=OK: status="Unable to save achievements. Export your garden to keep your progress."

func new_garden() -> void:
	draft_panel.finish_choice()
	browser_blocked=false; startup_save_valid=true
	var book := game.achievements
	game=Session.new(); game.achievements=book; game.paused=true; connect_game()
	selected=-1; selected_enemy=-1; placing=-1; selected_powerup="training"; powerup_tab="available"; powerup_page=0
	status="A fresh garden. Your achievements are yours to keep."
	save_game(); garden_replaced.emit()

func save_game() -> void:
	if read_only or testing or preview or browser_blocked or draft_saving: return
	if BrowserPlatform.enabled():
		BrowserPlatform.save_garden(game); return
	save_achievements()
	if SaveStore.write(game)!=OK: status="Unable to save. Use Export Save to keep your progress."

func commit_draft(choice: String = "") -> void:
	if draft_saving or read_only: return
	game.paused=true
	var next := DraftTransaction.prepare(game,choice)
	if next==null: status="This draft is no longer available."; return
	draft_saving=true
	if not choice.is_empty():
		for card in draft_panel.cards.values(): card.disabled=true
	var saved := testing or preview
	if not saved:
		if BrowserPlatform.enabled(): saved=await BrowserPlatform.commit_garden(next)
		else: saved=SaveStore.write(next)==OK
	if saved:
		DraftTransaction.publish(game,next)
		draft_saving=false; save_achievements()
		selected=-1; selected_enemy=-1; placing=-1; mobile.close_panel()
		if choice.is_empty():
			status="Offers stay fixed in this session. Export a backup to keep them." if BrowserPlatform.session_only() else "Choose one lasting improvement. Your offers are saved."
			draft_panel.show_draft(game); play_game_sound("rebirth",6)
		else:
			draft_panel.finish_choice()
			status="%s · rank %d. Start level 1 when ready."%[RebirthDraft.definition(choice).name,game.draft_rank(choice)]
			play_game_sound("upgrade",6)
	else:
		draft_saving=false
		status="Could not save the draft. Your garden is unchanged. Free storage and retry, or export a backup."
		if choice.is_empty():
			confirm.show_confirmation("Rebirth could not be saved",status,func(): commit_draft(),"Retry save")
		else:
			draft_panel.show_save_error(status,func(): action("export"))

func cell_at(p: Vector2) -> int:
	if not BOARD.has_point(p): return -1
	return int((p.y-BOARD.position.y)/TILE)*16+int((p.x-BOARD.position.x)/TILE)

func enemy_position(e: Dictionary) -> Vector2:
	if read_only and remote_to.has(e.id):
		return (remote_from.get(e.id,remote_to[e.id]) as Vector2).lerp(remote_to[e.id],clampf(remote_clock/0.1,0,1))
	return game.position(e)

func receive_field(data: Dictionary) -> bool:
	if not read_only: return false
	var next_game := LiveField.decode(data)
	if next_game==null: return false
	var revision := int(data.revision)
	var sequence := int(data.sequence)
	if revision<remote_revision or (revision==remote_revision and sequence<=remote_sequence): return false
	var prior := {}
	var replaced := revision!=remote_revision
	if revision==remote_revision:
		for e in game.enemies: prior[e.id]=enemy_position(e)
	else:
		selected=-1; selected_enemy=-1; selected_powerup="training"; powerup_page=0
	remote_revision=revision; remote_sequence=sequence; remote_from={}; remote_to={}
	game=next_game; remote_clock=0.0
	if replaced: remote_sound_id=0
	sync_music(replaced)
	for sound in data.get("sounds",[]):
		if int(sound.id)<=remote_sound_id: continue
		remote_sound_id=int(sound.id)
		if sound.name=="wave": sync_music(true)
		if not replaced and not skip_remote_sounds: audio.play(sound.name,int(sound.tier))
	skip_remote_sounds=false
	for e in game.enemies:
		remote_to[e.id]=game.position(e); remote_from[e.id]=prior.get(e.id,remote_to[e.id])
	validate_selection(); queue_redraw(); return true

func _input(event: InputEvent) -> void:
	if not gameplay_enabled or not is_visible_in_tree() or (read_only and remote_compact): return
	var typing := get_viewport().gui_get_focus_owner()
	# Typing suppresses shortcuts, but a garden click must be able to leave chat.
	if event is InputEventKey and (typing is LineEdit or typing is TextEdit): return
	if typing!=null and not is_ancestor_of(typing) and event is InputEventKey: return
	if confirm.visible or file_dialog.visible or draft_panel.visible or draft_saving or not game.pending_draft.is_empty(): return
	if compact() and mobile.handle(event): return
	if event is InputEventMouseButton and not Rect2(Vector2.ZERO,size).has_point(get_local_mouse_position()): return
	if event is InputEventMouseMotion:
		focus_id=""; hover=cell_at(get_local_mouse_position())
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if typing!=null and not is_ancestor_of(typing): typing.release_focus()
		focus_id=""
		click_at(get_local_mouse_position())
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				step_focus(-1 if event.shift_pressed else 1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
				if focus_id=="board": interact_cell(keyboard_cell)
				else:
					for b in buttons:
						if b.id==focus_id and b.enabled:
							if compact(): mobile.act(b.id)
							else: action(b.id)
							break
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				if focus_id=="board":
					var column := keyboard_cell%16
					var row := keyboard_cell/16
					column=clampi(column+int(event.keycode==KEY_RIGHT)-int(event.keycode==KEY_LEFT),0,15)
					row=clampi(row+int(event.keycode==KEY_DOWN)-int(event.keycode==KEY_UP),0,15)
					keyboard_cell=row*16+column; hover=keyboard_cell
			KEY_SPACE: action("pause")
			KEY_ESCAPE:
				if placing>=0 or selected>=0 or selected_enemy>=0:
					placing=-1; selected=-1; selected_enemy=-1; focus_id=""
				elif not read_only: menu_requested.emit()
				else: return
				get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3:
				action("cat%d" % (event.keycode-KEY_1)); focus_id="board"; hover=keyboard_cell
			KEY_N: action("start")

func step_focus(direction: int) -> void:
	var ids: Array[String] = []
	for b in buttons:
		if b.enabled: ids.append(b.id)
	if ids.is_empty(): return
	var index := ids.find(focus_id)
	if index<0: index=-1 if direction>0 else 0
	focus_id=ids[posmod(index+direction,ids.size())]
	if focus_id=="board": hover=keyboard_cell

func click_at(point: Vector2) -> void:
	for i in range(buttons.size()-1,-1,-1):
		var b: Dictionary=buttons[i]
		if b.id!="board" and b.rect.has_point(point):
			if b.enabled: action(b.id)
			return
	interact_cell(cell_at(point),point)

func interact_cell(cell: int, point: Vector2 = Vector2.INF) -> void:
	if cell<0: return
	keyboard_cell=cell
	selected_enemy=-1
	if not game.tower_at(cell).is_empty(): selected=cell; placing=-1
	elif placing>=0:
		if game.build(placing,cell): status=Balance.CATS[placing].name+" reporting for duty."
	else:
		selected=-1
		var enemies := sorted_enemies()
		enemies.reverse()
		for e in enemies:
			var hit := cell_at(BOARD.position+(enemy_position(e)+Vector2.ONE*0.5)*TILE)==cell if point==Vector2.INF else enemy_rect(e).has_point(point)
			if e.hp>0 and hit:
				selected_enemy=e.id; break

func inspected_enemy() -> Dictionary:
	if game.active:
		for e in game.enemies:
			if e.id==selected_enemy and e.hp>0: return e
	return {}

func validate_selection() -> void:
	if selected_enemy>=0 and inspected_enemy().is_empty():
		selected_enemy=-1
		if focus_id=="powerup_back": focus_id=""

func sorted_enemies() -> Array:
	var enemies := game.enemies.duplicate()
	enemies.sort_custom(func(a,b):
		var ay := enemy_position(a).y
		var by := enemy_position(b).y
		return a.id<b.id if ay==by else ay<by)
	return enemies

func enemy_rect(e: Dictionary) -> Rect2:
	var p := BOARD.position+(enemy_position(e)+Vector2.ONE*0.5)*TILE
	if e.boss>=0: return Rect2(p-Vector2(61,74),Vector2(122,122))
	var extent := 42.0 if e.kind==2 else 36.0
	return Rect2(p-Vector2(extent/2,extent/2+4),Vector2.ONE*extent)

func action(id: String) -> void:
	if draft_saving: return
	if not game.pending_draft.is_empty() and id not in ["export","menu"]: return
	if browser_blocked and id not in ["export","import","menu","help","new"]: return
	if read_only and not (id.begins_with("powerup:") or id in ["powerup_back","powerup_available","powerup_owned","powerup_prev","powerup_next","draft_collection"]): return
	if id.begins_with("powerup:"):
		selected_powerup=id.trim_prefix("powerup:"); queue_redraw(); return
	if id.begins_with("cat"):
		placing=int(id.trim_prefix("cat")); selected=-1; selected_enemy=-1; status="Click a tile to recruit "+Balance.CATS[placing].name+". Esc cancels."
		if not focus_id.is_empty(): focus_id="board"; hover=keyboard_cell
		return
	match id:
		"draft_collection":
			game.paused=true; mobile.close_panel(); draft_panel.show_collection(game)
		"menu": menu_requested.emit()
		"pause": game.paused=not game.paused
		"resume": game.paused=false
		"speed": game.speed=2 if game.speed==1 else 1
		"route": route_on=not route_on
		"auto_start":
			game.set_auto_start(not game.auto_start)
			status="Auto-start on. Cleared levels continue after a 3-second countdown." if game.auto_start else "Auto-start off. Start each level when you are ready."
		"sound":
			audio.set_mute(not audio.muted)
			if not testing and not preview: prefs.set_value("audio","muted",audio.muted); BrowserPlatform.save_settings("audio",prefs) if BrowserPlatform.enabled() else prefs.save("user://settings.cfg")
			audio_settings_changed.emit()
		"start":
			if game.start(): status="Level %d · %s" % [game.level,Balance.title(game.level)]
		"upgrade": game.upgrade(selected)
		"repair": game.repair(selected)
		"sell": game.sell(selected); selected=-1
		"train": game.train()
		"powerup_back": selected=-1; selected_enemy=-1; placing=-1; focus_id=""
		"powerup_available", "powerup_owned":
			powerup_tab="owned" if id=="powerup_owned" else "available"; powerup_page=0
		"powerup_prev": powerup_page=maxi(0,powerup_page-1)
		"powerup_next": powerup_page+=1
		"powerup_buy":
			if game.buy_powerup(selected_powerup):
				status="%s · Rank %d purchased."%[Powerups.definition(selected_powerup).name,game.powerup_rank(selected_powerup)]
		"rebirth":
			if game.can_rebirth():
				game.paused=true
				confirm.show_rebirth(game.run_best,game.bonus_points,commit_draft)
		"new": ask("Start a completely new garden?","This resets coins, cats, powerups, discoveries, draft improvements, best level and rebirth bonuses. Your achievements and lifetime achievement progress remain.","New garden",new_garden)
		"export":
			if BrowserPlatform.enabled():
				game.paused=true; BrowserPlatform.current.bridge.exportSave(str(BrowserPlatform.current.bridge.initial()) if not startup_save_valid else JSON.stringify(game.snapshot(),"\t",true,true)); return
			game.paused=true; file_action="export"; file_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE; file_dialog.current_file="purrimeter-save.json"; file_dialog.title="Export your patrol"; file_dialog.popup_centered_ratio(0.65)
		"import":
			if BrowserPlatform.enabled():
				game.paused=true; BrowserPlatform.current.bridge.importSave(); return
			game.paused=true; file_action="import"; file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE; file_dialog.title="Import a patrol"; file_dialog.popup_centered_ratio(0.65)
		"help":
			game.paused=true; confirm.show_help()
	queue_redraw()

func ask(title: String, message: String, accept_text: String, callback: Callable) -> void:
	game.paused=true
	confirm.show_confirmation(title,message,callback,accept_text)

func file_selected(path: String) -> void:
	if file_action=="export": status="Patrol exported." if SaveStore.write(game,path)==OK else "Export failed. Choose a writable folder."
	else:
		ask("Replace this patrol?","Importing replaces your current progress with the selected save.","Replace patrol",func():
			if SaveStore.read_into(game,path): sync_music(true); selected=-1; selected_enemy=-1; placing=-1; selected_powerup="training"; powerup_tab="available"; powerup_page=0; status="Patrol imported and paused."; save_game(); garden_replaced.emit()
			else: status="Invalid save. Your current patrol has not changed.")

func box(rect: Rect2, color: Color, radius: float = 0.0) -> void:
	if radius<=0: draw_rect(rect,color); return
	var style := StyleBoxFlat.new(); style.bg_color=color
	style.corner_radius_top_left=int(radius); style.corner_radius_top_right=int(radius); style.corner_radius_bottom_left=int(radius); style.corner_radius_bottom_right=int(radius)
	draw_style_box(style,rect)

func text(value: String, at: Vector2, size: int = 16, color: Color = CREAM, width: float = -1) -> void:
	draw_string(font,at+Vector2(0,size),value,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)

func wrapped(value: String, at: Vector2, width: float, size: int = 14, color: Color = MUTED) -> void:
	var paragraph := TextParagraph.new()
	paragraph.add_string(value,font,size); paragraph.width=width
	paragraph.draw(get_canvas_item(),at,color)

func button(label: String, rect: Rect2, id: String, enabled: bool = true, lit: bool = false) -> void:
	if read_only and not (id.begins_with("powerup:") or id in ["powerup_back","powerup_available","powerup_owned","powerup_prev","powerup_next"]): enabled=false
	var hovered := focus_id.is_empty() and rect.has_point(get_local_mouse_position())
	var fill := MINT if lit and enabled else PANEL
	if hovered and enabled: fill=fill.lightened(0.1)
	box(rect,fill,6)
	var color := INK if lit and enabled else (CREAM if enabled else DISABLED)
	if id=="sell" or id=="new": color=PINK if enabled else DISABLED
	text_fit(label,rect.position+Vector2(12,(rect.size.y-20)/2),rect.size.x-24,16,color)
	if focus_id==id: draw_rect(rect.grow(3),MINT,false,2)
	buttons.append({"rect":rect,"id":id,"enabled":enabled})

func checkbox(label: String, rect: Rect2, id: String, checked: bool) -> void:
	var hovered := focus_id.is_empty() and rect.has_point(get_local_mouse_position())
	if hovered: box(rect,PANEL,6)
	var mark := Rect2(rect.position+Vector2(8,12),Vector2(20,20))
	box(mark,MINT if checked else PANEL,3)
	if checked:
		draw_polyline(PackedVector2Array([mark.position+Vector2(4,10),mark.position+Vector2(8,14),mark.position+Vector2(16,5)]),INK,2.5,true)
	else: draw_rect(mark,CREAM,false,1.5)
	text(label,rect.position+Vector2(38,12),16,CREAM)
	if focus_id==id: draw_rect(rect.grow(3),MINT,false,2)
	buttons.append({"rect":rect,"id":id,"enabled":true})

func text_fit(value: String, at: Vector2, width: float, font_size: int = 16, color: Color = CREAM) -> void:
	var fitted := value
	while fitted.length()>0 and font.get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
		fitted=fitted.left(fitted.length()-1)
	if fitted!=value:
		while fitted.length()>0 and font.get_string_size(fitted+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
			fitted=fitted.left(fitted.length()-1)
		fitted+="…"
	text(fitted,at,font_size,color)

func right_text(value: String, right: Vector2, font_size: int = 16, color: Color = CREAM) -> void:
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	text(value,right-Vector2(width,0),font_size,color)

func center(cell: int) -> Vector2:
	return BOARD.position+Vector2(cell%16,cell/16)*TILE+Vector2.ONE*TILE/2

func cat_sprite(kind: int, tier: int, frame: int, rect: Rect2, alpha: float = 1.0) -> void:
	CatSkinArt.draw(self,game.skin_id(kind),tier,frame,rect,Color(1,1,1,alpha))

func enemy_sprite(kind: int, frame: int, rect: Rect2, tint: Color = Color.WHITE, painter: CanvasItem = null) -> void:
	var bands := [Vector2(802,940),Vector2(980,1138),Vector2(1150,1357),Vector2(1360,1607)]
	var columns := [[0,237,474,718,948],[0,239,478,732,948],[0,240,478,730,948],[0,237,474,726,948]]
	var bounds: Vector2=bands[kind]
	var source := Rect2(columns[kind][frame],bounds.x,columns[kind][frame+1]-columns[kind][frame],bounds.y-bounds.x)
	var scale := minf(rect.size.x/260.0,rect.size.y/250.0)
	var target := Rect2(Vector2(rect.get_center().x-source.size.x*scale/2,rect.end.y-source.size.y*scale),source.size*scale)
	(self if painter==null else painter).draw_texture_rect_region(enemy_texture,target,source,tint,false,true)

func boss_sprite(kind: int, frame: int, rect: Rect2, tint: Color = Color.WHITE, painter: CanvasItem = null) -> void:
	var cell := bosses.get_size()/4.0
	(self if painter==null else painter).draw_texture_rect_region(bosses,rect,Rect2(Vector2(frame,kind)*cell,cell),tint,false,true)

func frenzy_sweat(e: Dictionary, p: Vector2) -> void:
	var large: bool = e.boss>=0
	var radius := 4.5 if large else 2.5
	var spread := 42.0 if large else 17.0
	var head := -51.0 if large else -21.0
	for i in range(3):
		var phase := fposmod(game.elapsed*1.7+e.id*0.17+i/3.0,1.0)
		var at := p+Vector2(spread*(-1.0 if i%2==0 else 1.0),head+phase*(26.0 if large else 14.0))
		var tint := Color(0.65,0.94,1.0,1.0-phase*0.65)
		# Outline keeps droplets readable on pale and already-red sprites.
		draw_circle(at,radius+1.0,Color(0.07,0.14,0.2,tint.a))
		draw_colored_polygon(PackedVector2Array([at+Vector2(-radius,0),at+Vector2(0,-radius*2),at+Vector2(radius,0)]),tint)
		draw_circle(at,radius,tint)

func bar(rect: Rect2, fraction: float, color: Color, track: Color = INK) -> void:
	box(rect,track,2); box(Rect2(rect.position,Vector2(rect.size.x*clampf(fraction,0,1),rect.size.y)),color,2)

func _draw() -> void:
	if compact() and not remote_compact:
		if mobile!=null: mobile.draw()
		return
	if read_only and remote_compact:
		buttons.clear(); draw_board(); return
	box(Rect2(Vector2.ZERO,size),INK)
	if preview_gallery: draw_gallery(); return
	buttons.clear()
	text("GARDEN VIEW" if read_only else "PURRIMETER",Vector2(28,20),32)
	text("Read-only · inspect cats, enemies and powerups" if read_only else "The Garden Guard",Vector2(30,59),16,MUTED)
	right_text(game.coins.label(),Vector2(492,18),32,GOLD)
	right_text("coins",Vector2(492,58),15,MUTED)
	text_fit("Level %d" % game.level,Vector2(528,24),204,25,MINT)
	text_fit("Personal best  %d" % game.best,Vector2(528,60),204,15,MUTED)
	button("Resume" if game.paused else "Pause",Rect2(772,25,108,44),"pause")
	button("%d× Speed" % game.speed,Rect2(888,25,108,44),"speed",true,game.speed==2)
	button("Menu · Esc",Rect2(1004,25,248,44),"menu")
	draw_line(Vector2(28,90),Vector2(1252,90),LINE,1)
	draw_board()
	buttons.append({"rect":BOARD,"id":"board","enabled":true})
	if focus_id=="board":
		draw_rect(BOARD.grow(7),MINT,false,2)
		draw_rect(Rect2(center(keyboard_cell)-Vector2.ONE*21,Vector2.ONE*42),CREAM,false,2)
	draw_countdown()
	draw_sidebar()
	var message := status
	if placing>=0 and hover>=0:
		var error := game.placement_error(hover,placing)
		if not error.is_empty(): message=error
	if focus_id=="board":
		message="Arrows move · Enter %s · Esc cancels" % ("recruits" if placing>=0 else "inspects")
	text_fit(message,Vector2(28,851),704,16,CREAM)

func draw_countdown() -> void:
	if game.auto_start_remaining<=0.0: return
	var count := ceili(game.auto_start_remaining)
	var progress := clampf(count-game.auto_start_remaining,0.0,1.0)
	var scale := lerpf(1.15,0.55,1.0-pow(1.0-progress,3.0))
	var alpha := 1.0-pow(progress,1.5)
	var label := str(count)
	var font_size := 200
	var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline := (font.get_ascent(font_size)-font.get_descent(font_size))/2.0
	draw_set_transform(BOARD.get_center(),0.0,Vector2.ONE*scale)
	draw_string_outline(font,Vector2(-width/2.0,baseline),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,8,Color(INK,alpha))
	draw_string(font,Vector2(-width/2.0,baseline),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(GOLD,alpha))
	draw_set_transform(Vector2.ZERO)

func draw_board() -> void:
	box(BOARD.grow(5),Color("526f5c"),5)
	for y in range(16):
		for x in range(16):
			var r := Rect2(BOARD.position+Vector2(x,y)*TILE,Vector2.ONE*TILE)
			box(r,Color("30483c") if (x+y)%2==0 else Color("2d4439"))
			if (x*13+y*7)%9==0:
				box(Rect2(r.position+Vector2(9,30),Vector2(2,5)),Color("48634a")); box(Rect2(r.position+Vector2(13,27),Vector2(2,7)),Color("48634a"))
	for gate in [Routes.ENTRANCE,Routes.EXIT]:
		var p := center(gate)
		box(Rect2(p-Vector2.ONE*22,Vector2.ONE*44),Color(GOLD if gate==Routes.ENTRANCE else MINT,0.25))
		text("IN" if gate==Routes.ENTRANCE else "OUT",p-Vector2(16,9),12,GOLD if gate==Routes.ENTRANCE else MINT)
	if route_on:
		var route := game.preview_route()
		var breach := false
		for cell in route:
			if not game.tower_at(cell).is_empty(): breach=true
		for cell in route:
			if cell not in [Routes.ENTRANCE,Routes.EXIT]: box(Rect2(center(cell)-Vector2.ONE*2,Vector2.ONE*4),Color(GOLD if breach else MINT,0.3))
	var selected_tower := game.tower_at(selected)
	if not selected_tower.is_empty(): range_circle(selected,game.cat_stat(selected_tower,"range"),Balance.CATS[selected_tower.kind].color)
	if placing>=0 and hover>=0:
		var good := game.placement_error(hover,placing).is_empty()
		range_circle(hover,Balance.CATS[placing].range,MINT if good else PINK)
		box(Rect2(center(hover)-Vector2.ONE*22,Vector2.ONE*44),Color(MINT if good else PINK,0.25))
		cat_sprite(placing,1,0,Rect2(center(hover)-Vector2(24,29),Vector2(48,48)),0.65)
	for t in game.towers:
		var p := center(t.cell)
		box(Rect2(p+Vector2(-17,11),Vector2(34,7)),Color(0,0,0,0.22),3)
		if t.cell==selected: draw_rect(Rect2(p-Vector2.ONE*22,Vector2.ONE*44),MINT,false,2)
		var frame: int = 2 if t.flash>0 else [0,1,3,1][int(game.elapsed*2.5+t.cell)%4]
		cat_sprite(t.kind,t.tier,frame,Rect2(p-Vector2(26,30),Vector2(52,52)))
		for i in range(t.tier): box(Rect2(p+Vector2(-13+i*5,18),Vector2(3,3)),GOLD)
		if t.hp<0.999: bar(Rect2(p+Vector2(-16,-24),Vector2(32,3)),t.hp,MINT)
	for e in sorted_enemies():
		var p := BOARD.position+(enemy_position(e)+Vector2.ONE*0.5)*TILE
		var frame := 2 if e.attack>0 else int(game.elapsed*5+e.id)%4
		var frustration := clampf(e.get("frustration",0.0)/Frenzy.LIMIT,0.0,1.0)
		var tint := Color.WHITE.lerp(Color(1.0,0.28,0.22),frustration)
		if e.boss>=0:
			boss_sprite(e.boss,frame,enemy_rect(e),tint)
		else:
			enemy_sprite(e.kind,frame,enemy_rect(e),tint)
			bar(Rect2(p-Vector2(13,23),Vector2(26,3)),e.hp,Color.CYAN if e.slow>0 else PINK)
		if e.slow>0: draw_arc(p,17,0,TAU,20,Color(0.5,0.85,1,0.6),1.5)
		if e.get("frenzied",false): frenzy_sweat(e,p)
	var inspected := inspected_enemy()
	if not inspected.is_empty(): draw_rect(enemy_rect(inspected).grow(3),GOLD,false,2)
	for shot in game.shots: draw_shot(shot)
	for e in game.enemies:
		if e.boss>=0 and not remote_compact:
			text_fit(Balance.BOSSES[e.boss].name,Vector2(282,104),235,14,Balance.BOSSES[e.boss].color)
			bar(Rect2(530,110,150,7),e.hp,Balance.BOSSES[e.boss].color)
			right_text("%d%%" % roundi(e.hp*100),Vector2(732,103),14,MUTED)

func range_circle(cell: int, radius: float, color: Color) -> void:
	# Clip the circle to the board by drawing only visible arc segments.
	var p := center(cell)
	var previous := p+Vector2.RIGHT*radius*TILE
	for i in range(1,97):
		var point := p+Vector2.from_angle(TAU*i/96.0)*radius*TILE
		if BOARD.has_point(previous) and BOARD.has_point(point): draw_line(previous,point,Color(color,0.55),1.5)
		previous=point

func draw_shot(s: Dictionary) -> void:
	var a: Vector2=BOARD.position+(s.from+Vector2.ONE*0.5)*TILE
	var b: Vector2=BOARD.position+(s.to+Vector2.ONE*0.5)*TILE
	var fade: float=s.life/0.24
	var color: Color=Balance.CATS[s.kind].color
	var tier: int=s.tier
	var normal := (b-a).normalized().orthogonal()
	if s.kind==0:
		var shades := [Color("d7ad77"),Color("e6d392"),Color("dce6ed"),Color("7bd7ff"),Color("ffe184"),Color("67ffc5")]
		color=shades[tier-1]
		if tier>=4: draw_line(a,b,Color(color,fade*0.2),6+tier*1.5)
		draw_line(a,b,Color(color,fade),1+tier*0.65)
		var tip := a.lerp(b,1.0-fade)
		draw_colored_polygon(PackedVector2Array([tip+(b-a).normalized()*7,tip+normal*(2+tier),tip-normal*(2+tier)]),Color(color,fade))
		if tier>=5:
			for i in range(3): draw_circle(a.lerp(b,(i+0.5)/3.0),2,Color.WHITE*Color(1,1,1,fade))
	elif s.kind==1:
		var tip := a.lerp(b,1.0-fade)
		draw_circle(tip,3+tier*0.7,Color("ffa664"))
		var radius: float=(1.0-fade)*(14+tier*5)
		draw_arc(b,radius,0,TAU,20,Color(color,fade),1.5+tier*0.5)
		if tier>=3: draw_arc(b,radius*0.65,0,TAU,16,Color(GOLD,fade),2)
		if tier>=4:
			for i in range(tier+2):
				var end := b+Vector2.from_angle(TAU*i/(tier+2))*radius
				draw_line(end,end+Vector2.from_angle(TAU*i/(tier+2))*7,Color(GOLD,fade),2)
	else:
		draw_line(a,b,Color(color,fade*0.65),1+tier*0.4)
		for i in range(tier):
			var offset := normal*sin(ui_clock*15+i*2)*float(tier+2)
			var p := a.lerp(b,fmod(1.0-fade+i*0.15,1.0))+offset
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-4-tier),p+Vector2(3,0),p+Vector2(0,4+tier),p+Vector2(-3,0)]),Color(color,fade))
		if tier>=4: draw_arc(b,10+tier*2,ui_clock*4,ui_clock*4+PI*1.6,20,Color(color,fade),2)

func draw_sidebar() -> void:
	text("Their patrol" if read_only else "Recruit your patrol",Vector2(772,103),22)
	right_text("Read-only" if read_only else "Keys 1 / 2 / 3",Vector2(1252,110),14,MUTED)
	for kind in range(3):
		var y := 143+kind*73
		var r := Rect2(772,y,480,65)
		var chosen := placing==kind
		var hovered := focus_id.is_empty() and r.has_point(get_local_mouse_position())
		box(r,Color("304b40") if chosen else (PANEL.lightened(0.07) if hovered else PANEL),6)
		if chosen or focus_id=="cat%d"%kind: draw_rect(r,MINT,false,2)
		cat_sprite(kind,1,[0,1,3,1][int(game.elapsed*2)%4],Rect2(780,y-2,69,69))
		text(Balance.CATS[kind].name,Vector2(861,y+6),20)
		text(Balance.CATS[kind].role,Vector2(861,y+35),14,MUTED)
		var affordable := game.coins.enough(game.recruit_cost(kind))
		right_text("%sc" % game.recruit_cost(kind).label(),Vector2(1238,y+8),18,GOLD if affordable else PINK)
		if chosen: right_text("Selected",Vector2(1238,y+37),13,MINT)
		elif not affordable: right_text("Need coins",Vector2(1238,y+37),13,PINK)
		buttons.append({"rect":r,"id":"cat%d"%kind,"enabled":true})
	draw_line(Vector2(772,371),Vector2(1252,371),LINE,1)
	var t := game.tower_at(selected)
	if not t.is_empty():
		cat_sprite(t.kind,t.tier,[0,1,3,1][int(ui_clock*2.5)%4],Rect2(769,377,62,62))
		text(Balance.CATS[t.kind].name,Vector2(843,384),22)
		text("%s · Tier %d of 6" % [Balance.TIERS[t.tier-1],t.tier],Vector2(843,414),15,MUTED)
		right_text("%d%% health" % roundi(t.hp*100),Vector2(1252,390),16,PINK if t.hp<0.4 else MINT)
		bar(Rect2(1092,419,160,6),t.hp,PINK if t.hp<0.4 else MINT)
		text_fit("Damage %s   ·   Range %.1f tiles" % [Amount.from_power(game.cat_stat(t,"damage_power")).label(),game.cat_stat(t,"range")],Vector2(772,448),480,16,MUTED)
		button("Upgrade · %sc" % game.upgrade_cost(t).label() if t.tier<6 else "Mythic · max tier",Rect2(772,484,232,42),"upgrade",t.tier<6 and game.coins.enough(game.upgrade_cost(t)),true)
		button("Repair · %sc"%game.repair_cost(t).label() if t.hp<0.999999 else "Fully healed",Rect2(1016,484,236,42),"repair",t.hp<0.999999 and game.coins.enough(game.repair_cost(t)))
		button("Sell · +%sc" % game.refund(t).label(),Rect2(1092,532,160,32),"sell")
		if t.tier<6 and not game.coins.enough(game.upgrade_cost(t)):
			text("Earn more coins to upgrade.",Vector2(772,538),14,MUTED)
		button("Back to powerups",Rect2(772,590,200,40),"powerup_back")
	elif not inspected_enemy().is_empty():
		draw_enemy_inspector(inspected_enemy())
	else:
		draw_powerups()
	var rebirth_label := "Rebirth · choose a reward" if game.can_rebirth() else "Rebirth · clear level 5"
	button(rebirth_label,Rect2(772,647,272,38),"rebirth",game.can_rebirth())
	button("Draft Collection",Rect2(1052,647,200,38),"draft_collection")
	# Keep progression metadata with the rebirth controls, above the wave separator.
	right_text("%d rebirths · coins +%s%%" % [game.rebirths,Amount.of(game.bonus_points).label()],Vector2(1252,687),11,MUTED)
	draw_line(Vector2(772,705),Vector2(1252,705),LINE,1)
	text_fit(Balance.title(game.level),Vector2(772,711),480,20,GOLD if game.level%10==0 else CREAM)
	if game.active:
		text("%d on the field · %d / %d arrived" % [game.enemies.size(),game.spawned,game.wave_plan.size()],Vector2(772,741),15,MUTED)
		var health := game.level_health_fraction()
		text("Level health · %d%%" % ceili(health*100.0),Vector2(772,765),14,CREAM)
		bar(Rect2(944,773,308,7),health,PINK,LINE)
	elif game.auto_start_remaining>0.0:
		text("Countdown paused · Space resumes" if game.paused else "Next level in %ds · Space pauses" % ceili(game.auto_start_remaining),Vector2(772,741),15,MUTED)
	else:
		wrapped(Balance.preview(game.level),Vector2(772,741),480,15,MUTED)
	var start_rect := Rect2(772,794,364,44)
	if game.auto_start_remaining>0.0 and game.paused:
		button("Resume countdown",start_rect,"resume",true,true)
	elif game.active and game.paused:
		button("Resume level %d" % game.level,start_rect,"resume",true,true)
	elif game.active:
		button("Wave in progress",start_rect,"start",false)
	else:
		button("Start level %d   ·   N" % game.level,start_rect,"start",true,true)
	checkbox("Auto",Rect2(1148,794,104,44),"auto_start",game.auto_start)

func enemy_effects(e: Dictionary) -> Array[String]:
	var effects: Array[String] = []
	if e.get("frenzied",false): effects.append("Frenzy")
	if e.slow>0: effects.append("Slowed · %.1fs" % e.slow)
	if e.get("stun",0.0)>0: effects.append("Stunned / frozen · %.1fs" % e.stun)
	if e.get("burn_left",0.0)>0: effects.append("Burning · %.1fs" % e.burn_left)
	if effects.is_empty(): effects.append("No active effects")
	return effects

func draw_enemy_inspector(e: Dictionary) -> void:
	var info: Dictionary = Balance.BOSSES[e.boss] if e.boss>=0 else Balance.FOES[e.kind]
	var portrait := Rect2(772,383,84,84)
	var frame := int(ui_clock*5)%4
	if e.boss>=0: boss_sprite(e.boss,frame,portrait)
	else: enemy_sprite(e.kind,frame,portrait)
	text_fit(info.name,Vector2(872,384),380,22)
	text(info.subtitle if e.boss>=0 else "Enemy",Vector2(872,415),15,MUTED)
	var max_health := Amount.from_power(e.hp_power)
	text_fit("Health %s / %s" % [max_health.times(clampf(e.hp,0,1)).label(),max_health.label()],Vector2(872,443),300,16,CREAM)
	right_text("%d%%" % ceili(clampf(e.hp,0,1)*100),Vector2(1252,443),16,PINK)
	bar(Rect2(772,477,480,8),e.hp,PINK,LINE)
	var move_speed := 0.0 if e.get("stun",0.0)>0 else game.foe_speed(e)
	text("Speed %.2f tiles/s" % move_speed,Vector2(772,498),16,MUTED)
	right_text("Tower damage %s HP/s" % Amount.of(game.foe_dps(e)).label(),Vector2(1252,498),16,MUTED)
	var effects := enemy_effects(e)
	for i in range(effects.size()):
		text(effects[i],Vector2(772+(i%2)*240,534+(i/2)*23),15,GOLD if effects[0]!="No active effects" else MUTED)
	button("Back to powerups",Rect2(772,590,200,40),"powerup_back")

func powerup_list() -> Array[String]:
	game.refresh_powerups()
	var ids: Array[String] = []
	for row in Powerups.ITEMS:
		var id: String = row[0]
		if not game.discovered.get(id,false): continue
		if powerup_tab=="owned":
			if game.powerup_rank(id)>0: ids.append(id)
		elif not game.powerup_complete(id): ids.append(id)
	return ids

func draw_powerups() -> void:
	var ids := powerup_list()
	var pages := maxi(1,ceili(ids.size()/float(POWERUPS_PER_PAGE)))
	powerup_page=clampi(powerup_page,0,pages-1)
	var page_ids := ids.slice(powerup_page*POWERUPS_PER_PAGE,(powerup_page+1)*POWERUPS_PER_PAGE)
	if not selected_powerup in page_ids: selected_powerup=page_ids[0] if not page_ids.is_empty() else ""
	text("Powerups",Vector2(772,384),22)
	button("Available",Rect2(890,381,98,34),"powerup_available",true,powerup_tab=="available")
	button("Owned",Rect2(996,381,84,34),"powerup_owned",true,powerup_tab=="owned")
	button("<",Rect2(1090,381,36,34),"powerup_prev",powerup_page>0)
	text("%d / %d"%[powerup_page+1,pages],Vector2(1142,388),15,MUTED)
	button(">",Rect2(1216,381,36,34),"powerup_next",powerup_page<pages-1)
	for i in range(page_ids.size()):
		var id: String = page_ids[i]
		var r := Rect2(772+i*61,427,52,46)
		var chosen := id==selected_powerup
		var locked := not Powerups.eligible(game,id,game.powerup_rank(id)+1) and not game.powerup_complete(id)
		var hovered := focus_id.is_empty() and r.has_point(get_local_mouse_position())
		box(r,Color("304b40") if chosen else (PANEL.lightened(0.1) if hovered else PANEL),5)
		var group: String = Powerups.definition(id).group
		var tint: Color = {"Patrol":MINT,"Economy":GOLD,"Durability":PINK,"Bolt":GOLD,"Cannon":Color("fb8875"),"Frost":Color("78cfff")}[group]
		draw_texture_rect(powerup_icons[id],Rect2(r.position+Vector2(11,5),Vector2(30,30)),false,tint)
		if chosen or focus_id=="powerup:"+id: draw_rect(r.grow(1),MINT if chosen else CREAM,false,2)
		if game.powerup_rank(id)>0: right_text(str(game.powerup_rank(id)),r.end-Vector2(4,15),11,CREAM)
		if locked:
			var p := r.position+Vector2(4,34)
			box(Rect2(p,Vector2(8,7)),GOLD,1); draw_arc(p+Vector2(4,0),3,PI,TAU,8,GOLD,1.5)
		elif game.powerup_complete(id):
			var p := r.position+Vector2(4,37)
			draw_polyline(PackedVector2Array([p,p+Vector2(3,3),p+Vector2(9,-4)]),MINT,1.5,true)
		buttons.append({"rect":r,"id":"powerup:"+id,"enabled":true})
	if ids.is_empty():
		text("Your collection starts here",Vector2(772,490),22)
		wrapped("Purchased powerups appear here. Choose Available to discover your first permanent improvement.",Vector2(772,526),470,16,MUTED)
		return
	var d := Powerups.definition(selected_powerup)
	var rank := game.powerup_rank(selected_powerup)
	var complete := game.powerup_complete(selected_powerup)
	text(d.name,Vector2(772,481),21)
	right_text("Rank %d%s"%[rank," / %d"%d.cap if d.cap>0 else " · unlimited"],Vector2(1252,488),14,MINT)
	wrapped(d.description,Vector2(772,509),480,14,MUTED)
	text_fit("Now: "+Powerups.effect(selected_powerup,rank),Vector2(772,553),480,14,MINT if rank>0 else MUTED)
	text_fit("Complete · all ranks purchased" if complete else "Next: "+Powerups.effect(selected_powerup,rank+1),Vector2(772,574),480,14,CREAM)
	var unlocked := Powerups.eligible(game,selected_powerup,rank+1)
	var requirement := "Permanent for this garden" if complete else Powerups.requirement_text(game,selected_powerup,rank+1)
	wrapped(requirement,Vector2(772,601),282,13,MUTED if unlocked or complete else GOLD)
	var cost := Powerups.cost(selected_powerup,rank)
	var label := "Completed" if complete else ("Buy · %sc"%cost.label())
	if not complete and not unlocked: label="Locked · %sc"%cost.label()
	elif not complete and not game.coins.enough(cost): label="Need %sc"%cost.label()
	button(label,Rect2(1066,597,186,38),"powerup_buy",game.can_buy_powerup(selected_powerup),true)

func draw_gallery() -> void:
	text("THE SIX FORMS OF THE GARDEN GUARD",Vector2(35,18),28)
	text("Recruit → Scout → Veteran → Elite → Royal → Mythic",Vector2(35,60),16,MINT)
	for kind in range(3):
		text(Balance.CATS[kind].name.to_upper(),Vector2(35,104+kind*181),14,Balance.CATS[kind].color)
		for tier in range(1,7):
			var r := Rect2(35+(tier-1)*205,133+kind*181,190,140)
			box(r,PANEL,8); cat_sprite(kind,tier,int(ui_clock*5)%4,Rect2(r.position+Vector2(25,0),Vector2(140,140)))
			text("TIER %d"%tier,r.position+Vector2(7,112),12,MUTED)
	text("EVERY TENTH LEVEL, SOMETHING BIG ARRIVES",Vector2(35,665),19,GOLD)
	for i in range(4):
		boss_sprite(i,int(ui_clock*4)%4,Rect2(45+i*308,697,180,180))
		text(Balance.BOSSES[i].subtitle,Vector2(35+i*308,865),13,MUTED)

func make_preview() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--preview")
	preview_path=args[index+1] if index>=0 and index+1<args.size() else "user://preview.png"
	game.coins=Amount.of(2400); game.level=10; game.best=9; game.run_best=9; game.training=3; game.bonus_points=150; game.rebirths=2
	for kind in range(3):
		for tier in range(1,7):
			var cell := (4+tier)*16+(3+kind*4)
			game.build(kind,cell); game.towers.back().tier=tier
	game.coins=Amount.of(3400); game.start(); game.spawned=game.wave_plan.size()
	var boss := game.spawn_enemy({"kind":2,"boss":0}); boss.cell=8*16+8; boss.hp=0.64
	for kind in range(4):
		var e := game.spawn_enemy({"kind":kind,"boss":-1}); e.cell=8*16+kind+2
	game.paused=true; selected=7*16+3; game.elapsed=2.5
	if "--effects" in OS.get_cmdline_user_args():
		for kind in range(3):
			for tier in range(1,7):
				game.shots.append({"from":Vector2(tier*2,kind*3),"to":Vector2(tier*2+1.5,kind*3+2),"kind":kind,"tier":tier,"life":0.14})
	status="Boss level 10 · Build a maze, evolve your cats, and hold the garden."
	var state_index := args.find("--preview-state")
	if state_index>=0 and state_index+1<args.size():
		match args[state_index+1]:
			"enemy", "enemy-boss", "enemy-effects", "enemy-long":
				selected=-1
				var e: Dictionary = boss if args[state_index+1]=="enemy-boss" else game.enemies.back()
				selected_enemy=e.id; e.hp=0.72
				if args[state_index+1]=="enemy-effects":
					e.slow=1.8; e["stun"]=0.3; e["burn_left"]=2.4; e.frustration=12.0; e.frenzied=true
				if args[state_index+1]=="enemy-long":
					var increase := Balance.health_power(2000)-Balance.health_power(game.level)
					for foe in game.enemies: foe.hp_power+=increase
					game.level=2000
			"frenzy":
				game.towers.clear(); game.enemies.clear(); selected=-1; route_on=false
				for kind in range(4):
					var e := game.spawn_enemy({"kind":kind,"boss":-1}); e.cell=4*16+3+kind*3
					Frenzy.initialize(e); e.frustration=[0.0,4.0,9.0,12.0][kind]; e.frenzied=kind==3
					e.slow=2.0 if kind==3 else 0.0
					var b := game.spawn_enemy({"kind":0,"boss":kind}); b.cell=10*16+3+kind*3
					Frenzy.initialize(b); b.frustration=[0.0,6.0,12.0,12.0][kind]; b.frenzied=kind>=2
					b.slow=2.0 if kind==3 else 0.0
				status="Frustration turns foes red. Red with sweat means frenzy. Cyan rings still show slow."
			"fresh", "recruit", "low-coins":
				game=Session.new(); connect_game(); selected=-1
				status="Welcome, commander. Recruit a cat and guard the garden."
				if args[state_index+1]=="recruit":
					action("cat1"); focus_id="board"; hover=keyboard_cell
				elif args[state_index+1]=="low-coins": game.coins=Amount.of(12)
			"powerups", "powerups-owned", "powerups-locked", "powerups-last", "powerups-empty":
				selected=-1; game.kills=400; game.best=20; game.refresh_powerups()
				game.powerup_ranks={"quick":2,"needle":1,"catnap":5,"winter":1}
				game.refresh_powerups()
				if args[state_index+1]=="powerups-owned": powerup_tab="owned"
				if args[state_index+1]=="powerups-locked": selected_powerup="training"; game.training=26
				if args[state_index+1]=="powerups-last": powerup_page=3
				if args[state_index+1]=="powerups-empty": game=Session.new(); connect_game(); powerup_tab="owned"; status="Welcome, commander. Recruit a cat and guard the garden."
			"help-dialog": action("help")
			"rebirth-dialog":
				game.active=false; game.enemies.clear(); game.run_best=22
				action("rebirth")
			"injured": game.tower_at(selected).hp=0.27
			"rebirth": game.active=false; game.enemies.clear(); game.paused=false
			"countdown", "countdown-two", "countdown-one", "countdown-faded", "countdown-paused", "auto-start-off":
				game.active=false; game.enemies.clear(); game.paused=args[state_index+1]=="countdown-paused"
				game.set_auto_start(true)
				game.auto_start_remaining=2.35 if args[state_index+1]=="countdown-faded" else 3.0
				if args[state_index+1]=="countdown-two": game.auto_start_remaining=2.0
				if args[state_index+1]=="countdown-one": game.auto_start_remaining=1.0
				if args[state_index+1]=="auto-start-off": game.set_auto_start(false)
				status="Level cleared. Space pauses the countdown." if game.auto_start else "Auto-start off. Start each level when you are ready."
			"running": game.paused=false
			"long":
				game.level=2000; game.best=1999; game.training=10000
				game.coins=Amount.from_power(1000); game.bonus_points=99999999
				game.tower_at(selected).tier=6

	var powerup_index := args.find("--preview-powerup")
	if powerup_index>=0 and powerup_index+1<args.size():
		var ids := powerup_list()
		var id: String = args[powerup_index+1]
		if id in ids: selected_powerup=id; powerup_page=ids.find(id)/POWERUPS_PER_PAGE

func capture() -> void:
	for i in range(5): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(preview_path)
	print("Preview: ",preview_path," result=",error)
	get_tree().quit(error)

func smoke_test() -> void:
	await get_tree().process_frame
	# Start the isolated fixture in a known state.
	game.paused=false
	var results := {}
	action("cat0"); click_at(center(115)); results["recruit input"]=game.towers.size()==1
	selected=115; action("upgrade"); results["upgrade control"]=game.towers[0].tier==2
	action("pause"); results["pause control"]=game.paused
	action("speed"); results["speed control"]=game.speed==2
	action("route"); results["route control"]=not route_on
	action("start"); results["start control"]=game.active and not game.paused
	action("sell"); results["sell control"]=game.towers.is_empty()
	results["cat artwork"]=cat_textures.all(func(texture): return texture.get_width()>0)
	results["boss artwork"]=bosses.get_width()>0
	results["music and effects"]=audio.music.stream!=null and audio.effects.size()==15 and audio.effects.has("achievement")
	results["auto-start defaults off"]=not game.auto_start
	# Exercise the input path and rendered hit targets without reading a player save.
	game=Session.new(); connect_game(); focus_id=""; selected=-1; placing=-1; keyboard_cell=119
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	results["rendered controls"]=buttons.size()>10
	step_focus(1); results["keyboard focus starts at toolbar"]=focus_id=="pause"
	step_focus(-1); results["keyboard focus wraps backward"]=focus_id=="auto_start"
	results["menu actions removed from HUD"]=not buttons.any(func(b): return b.id in ["sound","route","new"])
	var key := InputEventKey.new(); key.pressed=true; key.keycode=KEY_2
	_input(key)
	results["keyboard recruit selects garden"]=placing==1 and focus_id=="board"
	key.keycode=KEY_RIGHT; _input(key)
	results["keyboard moves garden cursor"]=keyboard_cell==120
	key.keycode=KEY_ENTER; _input(key)
	results["keyboard places cat"]=not game.tower_at(120).is_empty()
	_input(key)
	results["keyboard inspects cat"]=selected==120 and placing==-1
	game.tower_at(120).hp=0.5
	game.coins=Amount.of(2000)
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	for b in buttons:
		if b.id=="repair": click_at(b.rect.get_center()); break
	results["repair hit target"]=game.tower_at(120).hp==1.0
	action("start"); action("pause")
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	var resume_found := false
	for b in buttons:
		if b.id=="resume":
			resume_found=b.enabled; click_at(b.rect.get_center()); break
	results["paused battle primary action resumes"]=resume_found and not game.paused
	results["all control bounds fit viewport"]=buttons.all(func(b): return Rect2(Vector2.ZERO,size).encloses(b.rect))
	focus_id="auto_start"; key.keycode=KEY_ENTER; _input(key)
	results["auto-start keyboard toggle"]=game.auto_start
	for b in buttons:
		if b.id=="auto_start": click_at(b.rect.get_center()); break
	results["auto-start pointer toggle"]=not game.auto_start
	action("auto_start")
	game.paused=false; game.spawned=game.wave_plan.size(); game.step(0.01)
	action("cat0"); click_at(center(119)); placing=-1
	results["countdown permits map clicks"]=game.auto_start_remaining==3.0 and not game.tower_at(119).is_empty()
	game.paused=true
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	var countdown_resume := false
	for b in buttons:
		if b.id=="resume": countdown_resume=true; click_at(b.rect.get_center()); break
	results["paused countdown can resume"]=countdown_resume and not game.paused and game.auto_start_remaining==3.0
	action("start"); results["start skips countdown"]=game.active and game.auto_start_remaining==0.0
	action("help")
	await get_tree().process_frame; await get_tree().process_frame
	var coins_before := game.coins.label()
	key.keycode=KEY_1; _input(key)
	results["modal blocks gameplay input"]=placing==-1 and game.coins.label()==coins_before
	results["help has one dismissal action"]=confirm.cancel_button==null and confirm.accept_button.text=="Got it"
	results["help panel fits viewport"]=Rect2(Vector2.ZERO,size).encloses(confirm.panel.get_rect())
	results["help copy fits without scrolling"]=confirm.body.size.y<=confirm.scroll.size.y+1
	confirm.accept_button.pressed.emit()
	results["help dismissal keeps combat paused"]=not confirm.visible and game.paused
	game.active=false; game.level=23; game.best=22; game.run_best=22; game.bonus_points=150; game.start()
	game.tower_at(120).hp=0.27
	action("rebirth")
	await get_tree().process_frame; await get_tree().process_frame
	results["rebirth defaults to cancel"]=confirm.cancel_button.has_focus()
	key.keycode=KEY_TAB; Input.parse_input_event(key)
	await get_tree().process_frame
	results["dialog tab reaches confirmation"]=confirm.accept_button.has_focus()
	key.shift_pressed=true; Input.parse_input_event(key)
	await get_tree().process_frame
	results["dialog shift-tab returns to cancel"]=confirm.cancel_button.has_focus()
	key.shift_pressed=false
	results["rebirth copy fits without scrolling"]=confirm.body.size.y<=confirm.scroll.size.y+1
	confirm.cancel_button.pressed.emit()
	results["cancel preserves rebirth state"]=game.level==23 and game.active and game.paused and game.bonus_points==150 and is_equal_approx(game.tower_at(120).hp,0.27)
	action("rebirth")
	key.keycode=KEY_ESCAPE; Input.parse_input_event(key)
	await get_tree().process_frame
	results["escape dismisses without rebirth"]=not confirm.visible and game.level==23
	action("rebirth")
	confirm.accept_button.pressed.emit()
	results["confirm applies rebirth once"]=not confirm.visible and not game.active and game.level==1 and game.bonus_points==150 and game.rebirths==1 and game.tower_at(120).hp==1.0 and game.coins.label()==coins_before
	confirm.accept()
	results["closed dialog cannot repeat action"]=game.rebirths==1 and game.bonus_points==150
	game.choose_draft(game.pending_draft.offers[0]); draft_panel.finish_choice()
	action("help"); confirm.accept_button.pressed.emit()
	results["help does not reuse confirmation callback"]=game.rebirths==1
	await powerup_smoke(results)
	await enemy_inspection_smoke(results)
	var ok := true
	for label in results:
		print(("PASS " if results[label] else "FAIL ")+label)
		ok=ok and results[label]
	print("Native smoke test passed" if ok else "Native smoke test failed")
	get_tree().quit(0 if ok else 1)

func enemy_inspection_smoke(results: Dictionary) -> void:
	game=Session.new(); connect_game(); selected=-1; placing=-1; focus_id=""; selected_powerup="training"
	game.level=10; game.start(); game.paused=true
	var boss := game.spawn_enemy({"kind":2,"boss":0}); boss.cell=119
	var e := game.spawn_enemy({"kind":0,"boss":-1}); e.cell=119
	click_at(center(119))
	results["frontmost enemy wins overlapping click"]=selected_enemy==e.id and selected==-1
	e.next=120; e.progress=0.8
	results["enemy selection follows moving individual"]=inspected_enemy()==e and enemy_rect(e).get_center().x>center(119).x
	click_at(center(119)+Vector2(-45,-40))
	results["boss artwork outside logical tile is selectable"]=selected_enemy==boss.id
	game.build(0,102)
	click_at(center(102))
	results["cat takes priority over overlapping boss artwork"]=selected==102 and selected_enemy==-1
	focus_id="board"; keyboard_cell=119
	var key := InputEventKey.new(); key.pressed=true; key.keycode=KEY_ENTER; _input(key)
	results["keyboard inspects enemy on focused tile"]=selected_enemy==boss.id and selected==-1
	e.progress=0.51; keyboard_cell=120; _input(key)
	results["keyboard can inspect enemy near tile boundary"]=selected_enemy==e.id
	e.progress=0.8
	action("cat0"); click_at(center(119))
	results["recruitment does not select enemies"]=selected_enemy==-1 and placing==0 and game.tower_at(119).is_empty()
	key.keycode=KEY_ESCAPE; _input(key); click_at(center(120))
	results["pointer inspects enemy at interpolated position"]=selected_enemy==e.id
	var before := game.snapshot()
	var clock_before := ui_clock
	_process(0.1)
	results["paused inspector clock advances without combat"]=ui_clock>clock_before and game.snapshot()==before
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	results["enemy inspector has back action without tower actions"]=buttons.any(func(b): return b.id=="powerup_back") and not buttons.any(func(b): return b.id in ["upgrade","repair","sell"])
	action("powerup_back")
	results["enemy inspector returns to previous powerup"]=selected_enemy==-1 and selected_powerup=="training"
	click_at(center(120)); key.keycode=KEY_ESCAPE; _input(key)
	results["escape clears enemy inspection"]=selected_enemy==-1
	click_at(center(120)); e.hp=0; PowerupCombat.reward_dead(game); _process(0.01)
	results["death clears selection without selecting survivor"]=selected_enemy==-1 and not game.enemies.is_empty()
	click_at(center(119)); game.defeat()
	results["defeat immediately clears enemy selection"]=selected_enemy==-1
	game.start(); var last := game.spawn_enemy(game.wave_plan[0]); game.spawned=game.wave_plan.size()
	last.cell=118; click_at(center(118)); game.enemies.clear(); game.step(0.01)
	results["victory immediately clears enemy selection"]=not game.active and selected_enemy==-1
	game.start(); last=game.spawn_enemy(game.wave_plan[0]); last.cell=118; click_at(center(118))
	action("new"); confirm.accept_button.pressed.emit()
	results["new garden clears selected enemy identity"]=selected_enemy==-1 and not game.active

func powerup_smoke(results: Dictionary) -> void:
	game=Session.new(); connect_game(); selected=-1; placing=-1; powerup_tab="available"; powerup_page=0; selected_powerup="training"
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	results["fresh browser only reveals training"]=powerup_list()==["training"] and powerup_icons.size()==30
	focus_id="powerup:training"
	var key := InputEventKey.new(); key.pressed=true; key.keycode=KEY_ENTER; _input(key)
	focus_id="powerup_buy"; _input(key)
	results["powerup purchase by keyboard"]=game.training==1 and is_equal_approx(game.coins.numeric(),100)
	game.coins=Amount.of(10000)
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	var purchase_disabled := false
	for b in buttons:
		if b.id=="powerup_buy": purchase_disabled=not b.enabled; click_at(b.rect.get_center())
	results["rank gate disables rich player's purchase"]=purchase_disabled and game.training==1
	game.best=100; game.kills=100000; game.rebirths=10; game.cat_milestones=[6,6,6]; game.powerup_ranks["lucky"]=1
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	for b in buttons:
		if b.id=="powerup:quick": click_at(b.rect.get_center()); break
	results["icon click selects its details"]=selected_powerup=="quick"
	game.build(0,100); interact_cell(100)
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	var back_found := false
	for b in buttons:
		if b.id=="powerup_back": back_found=true; click_at(b.rect.get_center()); break
	results["cat inspector returns to selected powerup"]=back_found and selected==-1 and selected_powerup=="quick"
	action("powerup_next"); action("powerup_next"); action("powerup_next")
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	results["pagination reaches last discovered icon"]=buttons.any(func(b): return b.id=="powerup:winter")
	game.powerup_ranks["winter"]=1
	action("powerup_owned")
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	results["owned includes completed and repeatable powerups"]=powerup_list()==["training","lucky","winter"]
	action("powerup:winter")
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	results["completed item remains inspectable"]=selected_powerup=="winter" and buttons.any(func(b): return b.id=="powerup_buy" and not b.enabled)
	action("powerup_available")
	results["completed item leaves Available"]=not "winter" in powerup_list()
	var descriptions_fit := true
	var names_fit := true
	for row in Powerups.ITEMS:
		var paragraph := TextParagraph.new(); paragraph.add_string(row[10],font,14); paragraph.width=480
		if paragraph.get_size().y>44: descriptions_fit=false
		var rank_label := "Rank %d / %d"%[row[3],row[3]] if row[3]>0 else "Rank 1000000000 · unlimited"
		if font.get_string_size(row[1],HORIZONTAL_ALIGNMENT_LEFT,-1,21).x+font.get_string_size(rank_label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+16>480: names_fit=false
	results["all 30 descriptions fit detail region"]=descriptions_fit
	results["all names and rank labels fit"]=names_fit
	results["powerup controls fit viewport"]=buttons.all(func(b): return Rect2(Vector2.ZERO,size).encloses(b.rect))
	game=Session.new(); connect_game(); powerup_tab="owned"; powerup_page=0
	queue_redraw(); await get_tree().process_frame; await get_tree().process_frame
	results["empty Owned collection has no purchase target"]=powerup_list().is_empty() and not buttons.any(func(b): return b.id=="powerup_buy")

func browser_event(kind: String, value: String) -> void:
	match kind:
		"hidden": game.paused=true; audio.focus(false); save_game()
		"visible": audio.focus(true)
		"save_error": browser_blocked=true; game.paused=true; status="Autosave unavailable. Export your garden or choose Continue without autosave."
		"session": browser_blocked=false; game.paused=true
		"lost": browser_blocked=true; game.paused=true; gameplay_enabled=false
		"export": action("export")
		"import_error", "reload_failed": status=value if not value.is_empty() else "Save failed. Export your garden before reloading."
		"import":
			var data = JSON.parse_string(value)
			var candidate := Session.new()
			if not data is Dictionary or not candidate.restore(data): status="Invalid save. Your garden has not changed."; return
			ask("Replace this garden?","Importing replaces this garden. Earned achievements are preserved.","Replace garden",func():
				if game.restore(data):
					browser_blocked=false; startup_save_valid=true; selected=-1; selected_enemy=-1; placing=-1; mobile.close_panel(); sync_music(true)
					status="Garden imported and paused."; save_game(); garden_replaced.emit())
