extends Control
const GameView = preload("res://ui/main.gd")
const INK := Color("131c26")
const PANEL := Color("202e3a")
const CREAM := Color("f4edd7")
const MUTED := Color("b0c3bd")
const MINT := Color("89dfb5")
const GOLD := Color("ffc46b")
const PINK := Color("fa7897")
var local_view: Control
var network: GardenNetwork
var page: Control
var overlay: Control
var screen := "menu"
var return_screen := "menu"
var state_label: Label
var room_list: VBoxContainer
var chat_log: RichTextLabel
var chat_input: LineEdit
var chat_player: AudioStreamPlayer
var remote_cards := {}
var muted := {}
var transcript: Array[String] = []
var expanded := ""
var revision := 0
var sequence := 0
var publish_clock := 0.0
var browser_clock := 0.0
var notice := ""
var pause_open := false
var test_mode := false
var passthrough := false
var app_focused := true
var updater: GameUpdater
var update_note: Label
var update_back := "menu"
var update_poll := 0.0
var achievement_panel: Control
var skins_panel: Control
var mobile_tabs: HBoxContainer
var mobile_chat := false
var unread := 0
var chat_toggle: Button
var browser_platform: BrowserPlatform
var departed_room := {}
var reset_dialog: Control
var reset_in_progress := false

func compact() -> bool:
	return GamePlatform.native_mobile_controls() or GamePlatform.responsive() and (size.x<1100 or size.y<720 or GamePlatform.touch())


func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if GamePlatform.responsive():
		get_window().content_scale_size=Vector2i.ZERO
		get_window().min_size=Vector2i.ZERO
		if GamePlatform.native_mobile():
			get_window().content_scale_factor=GamePlatform.ui_scale()
	browser_platform=BrowserPlatform.new(); add_child(browser_platform)
	test_mode="--multiplayer-test" in OS.get_cmdline_user_args() or "--app-preview" in OS.get_cmdline_user_args()
	passthrough="--smoke-test" in OS.get_cmdline_user_args() or "--preview" in OS.get_cmdline_user_args() or "--music-test" in OS.get_cmdline_user_args()
	theme=make_theme()
	local_view=GameView.new(); local_view.size=Vector2(1280,900); local_view.hosted=not passthrough
	# Test instances never read or write the player's save or preferences.
	if test_mode: local_view.read_only=true
	add_child(local_view)
	browser_platform.event_received.connect(func(kind, value):
		local_view.browser_event(kind,value)
		if kind=="hidden": app_focused=false; sync_audio_selection()
		if kind=="visible": app_focused=true; sync_audio_selection()
		if kind=="lost" and network!=null: network.disconnect_server()
		if kind=="resize": layout_game())
	if test_mode: local_view.read_only=false; local_view.testing=true; local_view.audio.quiet=true
	if passthrough: return
	network=GardenNetwork.new(); network.isolated=test_mode; add_child(network)
	local_view.game.paused=true
	local_view.menu_requested.connect(open_pause)
	local_view.audio_settings_changed.connect(sync_audio_selection)
	local_view.garden_replaced.connect(func(): revision+=1; publish_clock=1.0)
	network.status_changed.connect(set_status)
	network.issue.connect(func(_code, message): set_status(message))
	network.games_changed.connect(func(_games): if screen=="browser": populate_games())
	network.entered.connect(func():
		local_view.game.paused=true
		departed_room={}
		if screen!="multiplayer": show_game(true)
		publish_clock=1.0)
	network.room_changed.connect(update_room)
	network.field_received.connect(receive_field)
	network.chat_received.connect(receive_chat)
	network.interrupted.connect(func():
		departed_room=network.room.duplicate(true)
		local_view.game.paused=true; local_view.save_game()
		for item in remote_cards.values(): item.view.remote_connected=false
		sync_audio_selection(); set_status("Connection lost. Your garden is paused; reconnecting…"))
	network.departed.connect(on_departed)
	chat_player=AudioStreamPlayer.new(); add_child(chat_player); chat_player.stream=load("res://assets/coin.wav"); chat_player.volume_db=-22
	resized.connect(layout_game)
	updater=GameUpdater.new(); updater.isolated=test_mode; add_child(updater)
	updater.changed.connect(update_controls)
	updater.ready_to_exit.connect(finish_update)
	network.release_changed.connect(func(): updater.check(network.address))
	achievement_panel=preload("res://ui/achievements_panel.gd").new(); add_child(achievement_panel)
	if OS.has_feature("web") and not local_view.startup_save_valid: notice="Your saved garden could not be read. Open Single player → Menu to export a recovery copy, import a backup, or confirm a New Garden."
	show_menu()
	if not test_mode:
		updater.check(network.address)
		acknowledge_update.call_deferred()
	if "--app-preview" in OS.get_cmdline_user_args(): preview_app.call_deferred()

func make_theme() -> Theme:
	var result := Theme.new(); result.default_font_size=GamePlatform.ui_font_size(16) if GamePlatform.native_mobile_controls() else 18
	var surface := AndroidGarden.SURFACE if GamePlatform.native_mobile_controls() else PANEL
	for type in ["Label","Button","LineEdit","CheckButton","RichTextLabel"]: result.set_color("font_color",type,CREAM)
	result.set_color("font_placeholder_color","LineEdit",MUTED)
	result.set_color("font_disabled_color","Button",MUTED.darkened(0.15))
	result.set_color("caret_color","LineEdit",MINT)
	result.set_color("selection_color","LineEdit",Color("416957"))
	for type in ["Button","LineEdit","PanelContainer"]:
		for state in ["normal","hover","pressed","disabled","focus","panel"]:
			var style := StyleBoxFlat.new(); style.bg_color=surface.lightened(0.1) if state=="hover" else surface
			style.set_corner_radius_all(12 if GamePlatform.native_mobile_controls() else 6); style.content_margin_left=16; style.content_margin_right=16; style.content_margin_top=12; style.content_margin_bottom=12
			if state=="focus": style.bg_color=Color.TRANSPARENT; style.set_border_width_all(2); style.border_color=MINT
			if state=="pressed": style.bg_color=Color("39584b")
			result.set_stylebox(state,type,style)
	return result

func label(value: String, font_size: int = 18, color: Color = CREAM) -> Label:
	var l := Label.new(); l.text=value;
	if GamePlatform.responsive(): l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	GamePlatform.apply_font(l,font_size); l.add_theme_color_override("font_color",color); return l

func button(value: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new(); b.text=value; b.clip_text=GamePlatform.native_mobile_controls(); b.custom_minimum_size.y=48; b.pressed.connect(callback)
	# Clipped text contributes nothing to the minimum width, so a button inside a
	# horizontal row (chat Send, Mute, Report, Kick) would collapse to zero width.
	if b.clip_text: b.custom_minimum_size.x=clampf(value.length()*10+36,64,260)
	if primary:
		var accent := GOLD if GamePlatform.native_mobile_controls() else MINT
		for state in ["normal","hover","pressed"]:
			var s := theme.get_stylebox(state,"Button").duplicate() as StyleBoxFlat; s.bg_color=accent.lightened(0.12) if state=="hover" else accent; b.add_theme_stylebox_override(state,s)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(state,INK)
	return b

func input(placeholder: String, value: String, limit: int, secret: bool = false) -> LineEdit:
	var edit := LineEdit.new(); edit.placeholder_text=placeholder; edit.text=value; edit.max_length=limit; edit.secret=secret; edit.custom_minimum_size.y=48; return edit

func column(parent: Node, gap: int = 16) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",gap); parent.add_child(box); return box

func row(parent: Node, gap: int = 12) -> BoxContainer:
	var box: BoxContainer=VBoxContainer.new() if compact() else HBoxContainer.new(); box.add_theme_constant_override("separation",gap); parent.add_child(box); return box

func clear_page(next: String) -> void:
	if is_instance_valid(achievement_panel) and achievement_panel.visible: achievement_panel.close()
	if is_instance_valid(skins_panel) and skins_panel.visible: skins_panel.close()
	close_pause()
	if is_instance_valid(page): page.hide(); page.queue_free()
	page=Control.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(page)
	mobile_tabs=null; chat_toggle=null; mobile_chat=false
	screen=next; state_label=null; room_list=null; chat_log=null; chat_input=null
	local_view.hide(); local_view.gameplay_enabled=false; local_view.game.paused=true
	queue_redraw()

func configure_window(wide: bool) -> void:
	if GamePlatform.responsive(): return
	var window := get_window()
	var desired := Vector2i(1920,1080) if wide else Vector2i(1280,900)
	if window.content_scale_size==desired: return
	# Keep the native window stable across screens. Resizing it while replacing
	# the scene can leave a stale macOS framebuffer until the next manual resize.
	# Only the logical canvas changes; the player controls the physical window.
	window.content_scale_size=desired

func title_page(title: String, subtitle: String) -> VBoxContainer:
	var margin := MarginContainer.new(); page.add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,100)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,64)
	var holder: Node=margin
	if GamePlatform.responsive() or compact():
		for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
		var scroller := ScrollContainer.new(); margin.add_child(scroller); scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroller.follow_focus=true
		holder=scroller
	var box := column(holder,20); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_child(label(title,32 if compact() else 38))
	var sub := label(subtitle,18,MUTED); sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(sub)
	state_label=label(notice,17,GOLD); state_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return box

func show_menu() -> void:
	if network!=null: network.disconnect_server()
	clear_remotes(); transcript.clear(); muted.clear(); configure_window(false); clear_page("menu")
	if GamePlatform.native_mobile_controls():
		var menus := AndroidMenus.new(); menus.app=self; page.add_child(menus); return
	var box: VBoxContainer
	if GamePlatform.responsive() or compact(): box=title_page("Purrimeter","The Garden Guard")
	else:
		box=column(page,14); box.position=Vector2(100,130); box.size=Vector2(450,650)
		box.add_child(label("PURRIMETER",48)); box.add_child(label("The Garden Guard",24,MINT))
	if not notice.is_empty():
		var note := label(notice,16,GOLD); note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(note)
	var description := label("Build your patrol. Grow your garden.\nKeep good company.",21,MUTED); box.add_child(description)
	var space := Control.new(); space.custom_minimum_size.y=22; box.add_child(space)
	box.add_child(button("Single player",func(): show_game(false),true))
	box.add_child(label("Your garden · %s" % local_view.game.progress_label(),16,MUTED))
	box.add_child(button("Multiplayer",func(): notice=""; show_browser(); network.connect_server()))
	box.add_child(label("Up to 3 gardeners · Live fields and chat",16,MUTED))
	box.add_child(button("Achievements",open_achievements))
	box.add_child(button("Cat Skins",open_skins))
	box.add_child(button("Connection settings",func(): show_settings("menu")))
	if not GamePlatform.responsive(): box.add_child(button("Quit",quit_game))
	var updates := column(box if GamePlatform.responsive() or compact() else page,10)
	if not GamePlatform.responsive() and not compact(): updates.position=Vector2(650,670); updates.size=Vector2(500,180)
	updates.add_child(label("Game version · "+str(GameUpdater.build().version),16,MUTED))
	update_note=label(updater.message if updater!=null else "Check for game updates.",17,GOLD); update_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; updates.add_child(update_note)
	updates.add_child(button("Check for updates",func(): show_updates(); if updater.state in ["idle","error","current","newer"]: updater.check(network.address)))
	updates.add_child(HSeparator.new())
	var reset := button("Reset all progress",confirm_reset_progress)
	reset.name="ResetAllProgress"; reset.add_theme_color_override("font_color",PINK)
	updates.add_child(reset)

func confirm_reset_progress() -> void:
	if screen!="menu" or reset_in_progress: return
	if not is_instance_valid(reset_dialog):
		reset_dialog=preload("res://ui/patrol_dialog.gd").new(); add_child(reset_dialog)
	move_child(reset_dialog,get_child_count()-1)
	reset_dialog.set_process_input(true)
	reset_dialog.begin_dialog("Reset all progress?","Start from scratch at level one." if size.y>=500 else "",Vector2(640,660 if size.x<650 else 540))
	reset_dialog.label(reset_dialog.body,"Erase your garden, coins, cats, powerups, rebirth rewards, level unlocks, achievements and their progress, and earned cat skins. There is no undo.",19,CREAM)
	reset_dialog.label(reset_dialog.body,"Preferences and multiplayer identity stay. For a backup, cancel and export from the pause menu. Importing an old export can restore its progress.",17,MUTED)
	reset_dialog.finish_dialog("Reset all progress",perform_reset_progress,true)
	# Keep both actions on one row when they fit, leaving short landscapes room for the warning.
	reset_dialog.footer.set_meta("stack_below",520)
	reset_dialog.layout_panel()

func perform_reset_progress() -> void:
	if screen!="menu" or reset_in_progress: return
	reset_in_progress=true
	reset_dialog.begin_dialog("Resetting progress…","",Vector2(640,240))
	reset_dialog.label(reset_dialog.body,"Preparing your fresh garden.",19,CREAM)
	reset_dialog.set_process_input(false)
	var saved: bool=await local_view.reset_all_progress()
	reset_in_progress=false
	reset_dialog.set_process_input(true); reset_dialog.close()
	if saved:
		notice="Progress reset. Level one is ready."
		if BrowserPlatform.session_only(): notice="Progress reset for this session only. Autosave is unavailable; export your garden to keep it."
	else:
		notice="Could not save the reset. Your progress is unchanged. Free storage and try again."
	show_menu()

func show_settings(back: String) -> void:
	return_screen=back; configure_window(false); clear_page("settings")
	var box := title_page("Connection settings","Choose how other gardeners see you and which server to visit.")
	box.add_child(label("Player name",18,MINT))
	var name_edit := input("Your name",network.display_name,24); box.add_child(name_edit)
	box.add_child(label("Server address",18,MINT))
	var server_edit := input("wss://your-server/ws",network.address,256); box.add_child(server_edit)
	box.add_child(label("Your garden stays on this device. Your name can change before joining.",16,MUTED))
	var sound := CheckButton.new(); sound.text="Chat notification sound"; sound.button_pressed=network.chat_sound; box.add_child(sound)
	box.add_child(state_label)
	var actions := row(box)
	actions.add_child(button("Save settings",func():
		if name_edit.text.strip_edges().is_empty(): set_status("Enter a player name."); return
		if not server_edit.text.strip_edges().is_empty() and not network.valid_address(server_edit.text.strip_edges()): set_status("Use wss://hostname/ws. Plain ws:// is supported only for local testing."); return
		network.disconnect_server(); network.display_name=name_edit.text.strip_edges(); network.address=server_edit.text.strip_edges(); network.chat_sound=sound.button_pressed; network.save_settings(); updater.cancel_worker(); updater.check(network.address); notice="Settings saved."
		if return_screen=="browser": show_browser(); network.connect_server()
		else: show_menu(),true))
	actions.add_child(button("Back",func():
		if return_screen=="browser": show_browser()
		else: show_menu()))
	box.add_child(button("Reset identity for this server",func():
		network.disconnect_server(); network.reset_identity(); set_status("Multiplayer identity reset. Your garden is unchanged.")))

func show_browser() -> void:
	configure_window(false); clear_page("browser")
	var box := title_page("Open gardens","Join a garden or make room for others. Everyone keeps their own progress.")
	var toolbar := row(box)
	toolbar.add_child(button("Create game",show_create,true))
	toolbar.add_child(button("Refresh",func():
		if network.authenticated: network.refresh()
		else: network.connect_server()))
	toolbar.add_child(button("Connection settings",func(): show_settings("browser")))
	toolbar.add_child(button("Main menu",show_menu))
	box.add_child(state_label)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	if GamePlatform.responsive() or compact(): scroll.custom_minimum_size.y=300
	room_list=column(scroll,12); room_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	populate_games(); network.refresh()

func populate_games() -> void:
	if not is_instance_valid(room_list): return
	for child in room_list.get_children(): child.hide(); child.queue_free()
	if network.games.is_empty():
		room_list.add_child(label("No open gardens yet",26))
		var help := "Create a game and start playing while you wait for company." if network.authenticated else "Connect to your server to see available games."
		room_list.add_child(label(help,18,MUTED)); return
	var games := network.games.duplicate(); games.sort_custom(func(a,b): return str(a.get("name","")).naturalnocasecmp_to(str(b.get("name","")))<0)
	for game in games:
		if not game is Dictionary: continue
		var panel := PanelContainer.new(); room_list.add_child(panel); var line := row(panel,18)
		var name_label := label(str(game.get("name","Garden")),22); name_label.autowrap_mode=TextServer.AUTOWRAP_OFF; name_label.custom_minimum_size.y=30; name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; line.add_child(name_label)
		if game.get("locked",false):
			var icon := TextureRect.new(); icon.texture=load("res://assets/powerups/lock.svg"); icon.custom_minimum_size=Vector2(24,24); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.tooltip_text="Password required"; line.add_child(icon)
		line.add_child(label("%d / 3"%int(game.get("count",0)),18,MUTED))
		line.add_child(button("Join game",func():
			if game.get("locked",false): show_join(game)
			else: network.join_game(str(game.id))))

func show_create() -> void:
	clear_page("create")
	var box := title_page("Create a garden","You can start playing immediately. Up to two other players can join.")
	box.add_child(label("Game name",18,MINT)); var name_edit := input("Name your game","",40); box.add_child(name_edit)
	box.add_child(label("Password · optional",18,MINT)); var password := input("Leave empty for an open game","",64,true); box.add_child(password)
	box.add_child(label("The name and password stay fixed until this game closes.",16,MUTED)); box.add_child(state_label)
	var actions := row(box)
	actions.add_child(button("Create game",func():
		if not network.authenticated: set_status("Connect to the server before creating a game."); return
		if name_edit.text.strip_edges().is_empty(): set_status("Give your game a name."); return
		network.create_game(name_edit.text,password.text),true))
	actions.add_child(button("Back to games",show_browser)); name_edit.grab_focus()

func show_join(game: Dictionary) -> void:
	clear_page("join")
	var box := title_page("Join "+str(game.name),"This garden requires a password.")
	var password := input("Game password","",64,true); box.add_child(password); box.add_child(state_label)
	var actions := row(box); actions.add_child(button("Join game",func(): network.join_game(str(game.id),password.text),true)); actions.add_child(button("Back to games",show_browser))
	password.text_submitted.connect(func(_text): network.join_game(str(game.id),password.text)); password.grab_focus()

func show_game(online: bool) -> void:
	local_view.mobile.close_panel()
	configure_window(online); clear_page("multiplayer" if online else "single")
	page.mouse_filter=Control.MOUSE_FILTER_IGNORE
	local_view.show(); local_view.gameplay_enabled=true; local_view.game.paused=true
	if online:
		var header := label(str(network.room.get("name","Garden")),26); header.position=Vector2(28,16); header.size=Vector2(1000,48); header.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; page.add_child(header)
		state_label=label("",17,MUTED); state_label.position=Vector2(28,58); state_label.size=Vector2(1240,28); page.add_child(state_label)
		var chat_panel := PanelContainer.new(); chat_panel.name="Chat"; page.add_child(chat_panel)
		var chat_content: Node=chat_panel
		if compact():
			var chat_scroll := ScrollContainer.new(); chat_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; chat_scroll.follow_focus=true; chat_panel.add_child(chat_scroll); chat_content=chat_scroll
		var chat_column := column(chat_content,8); chat_column.name="ChatColumn"; chat_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var chat_header := HBoxContainer.new(); chat_column.add_child(chat_header); var title := label("Garden chat",20,MINT); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; chat_header.add_child(title)
		var sound := CheckButton.new(); sound.text="Sound"; sound.button_pressed=network.chat_sound; sound.toggled.connect(func(value): network.chat_sound=value; network.save_settings()); chat_header.add_child(sound)
		chat_log=RichTextLabel.new(); chat_log.custom_minimum_size.y=180 if compact() else 0; chat_log.bbcode_enabled=false; chat_log.scroll_following=true; chat_log.selection_enabled=true; chat_log.size_flags_vertical=Control.SIZE_EXPAND_FILL; chat_column.add_child(chat_log)
		for entry in transcript: chat_log.append_text(entry+"\n")
		var compose := HBoxContainer.new(); chat_column.add_child(compose); chat_input=input("Message… · T to chat","",400); chat_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL; compose.add_child(chat_input)
		chat_input.text_submitted.connect(func(_value): send_chat()); compose.add_child(button("Send",send_chat))
		update_room(network.room)
	layout_game()

func clear_remotes() -> void:
	for item in remote_cards.values():
		item.view.audio.set_enabled(false)
		if is_instance_valid(item.card): item.card.queue_free()
	remote_cards.clear(); expanded=""
	sync_audio_selection()

func update_room(room: Dictionary) -> void:
	if screen!="multiplayer": return
	var present := {}
	for member in room.get("players",[]):
		var player := str(member.id)
		if player==network.id: continue
		present[player]=true
		if not remote_cards.has(player):
			var card := Control.new(); card.clip_contents=true; page.add_child(card)
			var name_label := label(str(member.name),20); name_label.position=Vector2(12,4); card.add_child(name_label)
			var details := label("Waiting for field…",15,MUTED); details.position=Vector2(12,34); card.add_child(details)
			var view := GameView.new(); view.read_only=true; view.remote_compact=true; view.route_on=false; view.gameplay_enabled=false; view.mouse_filter=Control.MOUSE_FILTER_IGNORE; card.add_child(view)
			var inspect := button("View",func(): expand_field(player)); inspect.custom_minimum_size.y=36; card.add_child(inspect)
			var mute := button("Mute",func(): toggle_mute(player)); mute.custom_minimum_size.y=36; card.add_child(mute)
			var kick := button("Kick",func():
				local_view.ask("Remove this player?","They cannot rejoin this game with their current multiplayer identity.","Remove player",func(): network.kick(player)))
			kick.custom_minimum_size.y=36; card.add_child(kick)
			var report := button("Report",func(): confirm_report(player)); report.custom_minimum_size.y=36; card.add_child(report)
			for small in [inspect,mute,report,kick]:
				small.add_theme_font_size_override("font_size",16)
				for state in ["normal","hover","pressed"]:
					var compact := theme.get_stylebox(state,"Button").duplicate() as StyleBoxFlat
					compact.content_margin_top=6; compact.content_margin_bottom=6; small.add_theme_stylebox_override(state,compact)
			remote_cards[player]={"card":card,"name":name_label,"details":details,"view":view,"inspect":inspect,"mute":mute,"report":report,"kick":kick,"member":member}
		var item: Dictionary=remote_cards[player]; item.member=member; item.name.text=str(member.name)
		item.view.remote_connected=member.get("connected",false)
		item.kick.visible=room.get("owner","")==network.id
		update_remote_label(item)
	for player in remote_cards.keys():
		if not present.has(player):
			if expanded==player: close_expanded()
			remote_cards[player].card.queue_free(); remote_cards.erase(player)
	layout_game()

func update_remote_label(item: Dictionary) -> void:
	var view: Control=item.view
	if not item.member.get("connected",false): item.details.text="Reconnecting · place reserved"; return
	if view.remote_revision<0: item.details.text="Waiting for field…"; return
	item.details.text="%s · %s"%[view.game.progress_label(),"Complete" if view.game.completed else ("Paused" if view.game.paused else "%d×"%view.game.speed)]

func receive_field(player: String, data: Dictionary) -> void:
	if remote_cards.has(player):
		var item: Dictionary=remote_cards[player]
		if item.view.receive_field(data): update_remote_label(item); sync_audio_selection()

func sync_audio_selection() -> void:
	if not is_instance_valid(local_view): return
	local_view.audio.set_enabled(expanded.is_empty())
	local_view.audio.focus(app_focused)
	for player in remote_cards:
		var view: Control=remote_cards[player].view
		var selected: bool=player==expanded and view.remote_connected and view.remote_revision>=0
		if view.audio.enabled!=selected or view.audio.focused!=app_focused or view.audio.muted!=local_view.audio.muted:
			view.skip_remote_sounds=true
		view.audio.set_enabled(selected)
		view.audio.set_mute(local_view.audio.muted)
		view.audio.focus(app_focused)

func toggle_mute(player: String) -> void:
	muted[player]=not muted.get(player,false)
	if remote_cards.has(player): remote_cards[player].mute.text="Unmute" if muted[player] else "Mute"

func confirm_report(player: String) -> void:
	local_view.ask("Report this player’s chat?","Their recent messages go to the server operator for review, and they are muted for you. Nobody else is notified.","Report and mute",func():
		network.report(player)
		if not muted.get(player,false): toggle_mute(player)
		if compact(): phone_layout())

func leave_updates() -> void:
	if update_back in ["single","multiplayer"]: show_game(update_back=="multiplayer" and not network.room.is_empty())
	elif update_back=="browser": show_browser()
	else: show_menu()

## Android back button: step out of the innermost layer, never quit from the menu.
func go_back() -> void:
	if reset_in_progress: return
	if is_instance_valid(reset_dialog) and reset_dialog.visible: reset_dialog.close(); return
	if not is_instance_valid(local_view) or local_view.draft_saving or (is_instance_valid(local_view.draft_panel) and local_view.draft_panel.visible): return
	if local_view.confirm.visible: local_view.confirm.close(); return
	if is_instance_valid(achievement_panel) and achievement_panel.visible: achievement_panel.close(); return
	if is_instance_valid(skins_panel) and skins_panel.visible: skins_panel.close(); return
	if mobile_chat: mobile_chat=false; phone_layout(); return
	if pause_open: close_pause(); return
	var viewed: Control=remote_cards[expanded].view if not expanded.is_empty() and remote_cards.has(expanded) else local_view
	if viewed.compact() and viewed.mobile.dismiss_layer(): return
	if not expanded.is_empty(): close_expanded()
	elif screen in ["single","multiplayer"]:
		if local_view.placing>=0 or local_view.selected>=0 or local_view.selected_enemy>=0: local_view.placing=-1; local_view.selected=-1; local_view.selected_enemy=-1
		else: open_pause()
	elif screen=="updates": leave_updates()
	elif screen!="menu": show_menu()

func receive_chat(player: String, author: String, message: String) -> void:
	if screen!="multiplayer" or muted.get(player,false): return
	var entry := author+": "+message
	transcript.append(entry)
	if transcript.size()>200: transcript.pop_front()
	if is_instance_valid(chat_log): chat_log.text="\n".join(transcript)+"\n"
	if compact() and not mobile_chat and player!=network.id: unread+=1; update_chat_button()
	if player!=network.id and network.chat_sound and not test_mode: chat_player.play()

func send_chat() -> void:
	if not is_instance_valid(chat_input) or chat_input.text.strip_edges().is_empty(): return
	if network.say(chat_input.text): chat_input.clear()
	else:
		set_status("Chat is unavailable while disconnected. Your message has not been sent.")
		if compact() and is_instance_valid(chat_log): chat_log.append_text("Not sent. Wait for reconnection and try Send again.\n")

func set_status(message: String) -> void:
	notice=message
	if is_instance_valid(state_label): state_label.text=message
	if compact() and screen in ["single","multiplayer"]: local_view.status=message

func on_departed(reason: String) -> void:
	clear_remotes(); transcript.clear(); muted.clear()
	if not reason.is_empty():
		local_view.game.paused=true; show_game(false); local_view.status=reason; notice=reason
		if GamePlatform.responsive() and not departed_room.is_empty():
			local_view.ask("Your garden is paused",reason+" Continue offline, or try to rejoin the same garden.","Rejoin",func():
				var target: Dictionary=departed_room.duplicate(true)
				show_browser(); network.connect_server()
				show_join(target))
			local_view.confirm.cancel_button.text="Continue offline"

func layout_game() -> void:
	if not is_instance_valid(local_view) or passthrough: return
	if compact() and screen in ["single","multiplayer"]:
		phone_layout(); return
	if screen=="single":
		local_view.position=Vector2.ZERO; local_view.scale=Vector2.ONE; local_view.size=Vector2(1280,900)
		if GamePlatform.responsive():
			local_view.scale=Vector2.ONE*minf(size.x/1280,size.y/900)
			local_view.position=(size-Vector2(1280,900)*local_view.scale)/2
		return
	if screen!="multiplayer": return
	var left_scale := minf((size.x*0.68)/1280.0,(size.y-100)/900.0)
	local_view.scale=Vector2.ONE*left_scale; local_view.position=Vector2(0,96); local_view.size=Vector2(1280,900)
	var right_x := size.x*0.69; var width := size.x-right_x-24
	var chat := page.get_node_or_null("Chat") as Control
	if chat!=null: chat.position=Vector2(right_x,size.y-214); chat.size=Vector2(width,190)
	var index := 0; var count := maxi(1,remote_cards.size())
	var card_height := (size.y-324-16*(count-1))/count
	for player in remote_cards:
		var item: Dictionary=remote_cards[player]; var card: Control=item.card; var view: Control=item.view
		card.visible=expanded.is_empty() or expanded==player
		if expanded==player:
			card.position=Vector2(16,90); card.size=Vector2(size.x-32,size.y-106)
			var fit := minf(card.size.x/1280.0,(card.size.y-56)/900.0)
			view.remote_compact=false; view.gameplay_enabled=true; view.position=Vector2((card.size.x-1280*fit)/2,56); view.scale=Vector2.ONE*fit; view.size=Vector2(1280,900)
			item.inspect.text="Close"; item.inspect.position=Vector2(card.size.x-96,4); item.inspect.size=Vector2(84,36)
			item.mute.hide(); item.report.hide(); item.kick.hide()
		else:
			card.position=Vector2(right_x,94+index*(card_height+16)); card.size=Vector2(width,card_height)
			var square := minf(width-(132 if count==2 else 24),card_height-(68 if count==2 else 104)); var fit := square/704.0
			var field_x := 12.0 if count==2 else (width-square)/2
			var field_y := 60.0 if count==2 else 96.0
			view.remote_compact=true; view.gameplay_enabled=false; view.position=Vector2(field_x-28*fit,field_y-134*fit); view.scale=Vector2.ONE*fit; view.size=Vector2(760,850)
			item.inspect.text="View"; item.inspect.position=Vector2(12,57); item.inspect.size=Vector2(76,34)
			item.mute.show(); item.mute.position=Vector2(96,57); item.mute.size=Vector2(92,34)
			item.report.show(); item.report.position=Vector2(196,57); item.report.size=Vector2(84,34)
			item.kick.visible=network.room.get("owner","")==network.id; item.kick.position=Vector2(288,57); item.kick.size=Vector2(76,34)
			if count==2:
				item.inspect.position=Vector2(width-104,60); item.inspect.size.x=92
				item.mute.position=Vector2(width-104,102)
				item.report.position=Vector2(width-104,144); item.report.size.x=92
				item.kick.position=Vector2(width-104,186); item.kick.size.x=92
		item.name.size=Vector2(card.size.x-120,28); item.name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		index+=1
	if chat!=null: chat.visible=expanded.is_empty()
	local_view.visible=expanded.is_empty(); local_view.gameplay_enabled=expanded.is_empty() and not pause_open and not (is_instance_valid(achievement_panel) and achievement_panel.visible) and not (is_instance_valid(skins_panel) and skins_panel.visible)
	sync_audio_selection()
	queue_redraw()

func expand_field(player: String) -> void:
	if expanded==player: close_expanded(); return
	if not remote_cards.has(player): return
	expanded=player; layout_game()

func close_expanded() -> void:
	expanded=""; layout_game()

func open_achievements() -> void:
	if achievement_panel.visible: return
	var was_paused: bool = local_view.game.paused
	var was_enabled: bool = local_view.gameplay_enabled
	local_view.game.paused=true; local_view.gameplay_enabled=false
	move_child(achievement_panel,get_child_count()-1)
	achievement_panel.open(local_view.game)
	achievement_panel.dismissed.connect(func():
		local_view.game.paused=was_paused if not GamePlatform.responsive() else true
		local_view.gameplay_enabled=was_enabled and not pause_open
		local_view.save_game(),CONNECT_ONE_SHOT)

func open_skins() -> void:
	if not is_instance_valid(skins_panel):
		skins_panel=preload("res://ui/skins_panel.gd").new(); add_child(skins_panel)
		skins_panel.equipped.connect(func(): local_view.save_game(); publish_clock=1.0; queue_redraw())
	if skins_panel.visible: return
	var was_paused: bool = local_view.game.paused
	var was_enabled: bool = local_view.gameplay_enabled
	local_view.game.paused=true; local_view.gameplay_enabled=false
	move_child(skins_panel,get_child_count()-1)
	skins_panel.open(local_view.game)
	skins_panel.dismissed.connect(func():
		local_view.game.paused=was_paused if not GamePlatform.responsive() else true
		local_view.gameplay_enabled=was_enabled and not pause_open
		local_view.save_game(),CONNECT_ONE_SHOT)

func confirm_main_menu() -> void:
	# The pause overlay frees itself before this dialog is answered. A lambda owned
	# by that overlay would be invalid by then, so the callback must live here.
	local_view.ask("Return to the main menu?","Your garden will be saved. You will leave this multiplayer game." if screen=="multiplayer" else "Your garden will be saved and paused.","Main menu",return_to_main_menu)

func return_to_main_menu() -> void:
	local_view.save_game(); show_menu()

func open_pause() -> void:
	if local_view.draft_saving or (is_instance_valid(local_view.draft_panel) and local_view.draft_panel.visible): return
	if screen not in ["single","multiplayer"] or pause_open: return
	if not expanded.is_empty(): close_expanded()
	local_view.mobile.close_panel()
	local_view.game.paused=true; local_view.gameplay_enabled=false; pause_open=true
	if GamePlatform.native_mobile_controls():
		var menus := AndroidMenus.new(); menus.app=self; menus.paused=true; overlay=menus; add_child(menus); return
	overlay=Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(overlay)
	var shade := ColorRect.new(); shade.color=Color(INK,0.93); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(center)
	var holder: Node=center
	if GamePlatform.responsive() or compact():
		center.queue_free()
		var margin := MarginContainer.new(); overlay.add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
		var scroller := ScrollContainer.new(); margin.add_child(scroller); scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; holder=scroller
	var box := column(holder,8); box.custom_minimum_size.x=0 if compact() else 420; box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_child(label("Garden paused",32,MINT)); box.add_child(label("Other gardeners can keep playing.",17,MUTED) if screen=="multiplayer" else label("Your patrol is waiting for you.",17,MUTED))
	var resume := button("Resume",func(): close_pause(); local_view.game.paused=false,true); box.add_child(resume)
	var settings := row(box)
	var route := button("Route on" if local_view.route_on else "Route off",local_view.action.bind("route"))
	route.toggle_mode=true; route.button_pressed=local_view.route_on; route.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	route.pressed.connect(func(): route.text="Route on" if local_view.route_on else "Route off")
	settings.add_child(route)
	var sound := button("Sound off" if local_view.audio.muted else "Sound on",local_view.action.bind("sound"))
	sound.toggle_mode=true; sound.button_pressed=not local_view.audio.muted; sound.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	sound.pressed.connect(func(): sound.text="Sound off" if local_view.audio.muted else "Sound on")
	settings.add_child(sound)
	box.add_child(button("Achievements",open_achievements))
	box.add_child(button("Cat Skins",open_skins))
	box.add_child(button("Export garden",func(): close_pause(); local_view.action("export")))
	box.add_child(button("Import garden",func(): close_pause(); local_view.action("import")))
	box.add_child(button("New garden",func(): close_pause(); local_view.action("new")))
	box.add_child(button("How to play",func(): close_pause(); local_view.action("help")))
	box.add_child(button("Game updates",func(): close_pause(); show_updates()))
	if screen=="multiplayer":
		box.add_child(button("Continue offline",func(): close_pause(); network.leave_game(); show_game(false)))
	box.add_child(button("Main menu",func():
		close_pause(); confirm_main_menu()))
	box.add_child(button("Close menu · stay paused",close_pause)); resume.grab_focus()

func close_pause() -> void:
	if is_instance_valid(overlay): overlay.hide(); overlay.queue_free()
	overlay=null; pause_open=false
	if is_instance_valid(local_view): local_view.gameplay_enabled=screen in ["single","multiplayer"] and expanded.is_empty()

func _input(event: InputEvent) -> void:
	if reset_in_progress or (is_instance_valid(reset_dialog) and reset_dialog.visible): return
	if passthrough or not event is InputEventKey or not event.pressed or event.echo: return
	if local_view.draft_saving or (is_instance_valid(local_view.draft_panel) and local_view.draft_panel.visible): return
	if is_instance_valid(achievement_panel) and achievement_panel.visible: return
	if is_instance_valid(skins_panel) and skins_panel.visible: return
	var focused := get_viewport().gui_get_focus_owner()
	if event.keycode==KEY_T and screen=="multiplayer" and not pause_open and expanded.is_empty() and not local_view.confirm.visible and not local_view.file_dialog.visible and not focused is LineEdit:
		chat_input.grab_focus(); get_viewport().set_input_as_handled(); return
	if event.keycode!=KEY_ESCAPE: return
	if focused is LineEdit:
		focused.release_focus(); get_viewport().set_input_as_handled(); return
	if local_view.confirm.visible or local_view.file_dialog.visible: return
	var viewed: Control=remote_cards[expanded].view if not expanded.is_empty() and remote_cards.has(expanded) else local_view
	if pause_open: close_pause(); get_viewport().set_input_as_handled()
	elif viewed.compact() and viewed.mobile.dismiss_layer(): get_viewport().set_input_as_handled()
	elif not expanded.is_empty(): close_expanded(); get_viewport().set_input_as_handled()
	elif screen in ["single","multiplayer"] and not local_view.confirm.visible and not local_view.file_dialog.visible:
		if local_view.placing>=0 or local_view.selected>=0 or local_view.selected_enemy>=0:
			local_view.placing=-1; local_view.selected=-1; local_view.selected_enemy=-1
		else: open_pause()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if passthrough or network==null: return
	if not test_mode and updater!=null:
		update_poll+=delta
		if update_poll>=60.0:
			update_poll=0.0
			if updater.state not in ["downloaded","downloading","preparing"]: updater.check(network.address)
	if screen=="browser":
		browser_clock+=delta
		if browser_clock>=3: browser_clock=0; network.refresh()
	if screen=="multiplayer":
		publish_clock+=delta
		if publish_clock>=0.1:
			publish_clock=0; sequence+=1; network.publish(LiveField.capture(local_view.game,revision,sequence,local_view.live_sounds()))

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and not passthrough: quit_game()
	if not is_node_ready() or passthrough: return
	if what==NOTIFICATION_WM_GO_BACK_REQUEST: go_back()
	# Android backgrounds the whole activity: pause and save like a hidden browser tab.
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_RESUMED:
		app_focused=what==NOTIFICATION_APPLICATION_RESUMED
		if app_focused and GamePlatform.android():
			GamePlatform.font_sizes.clear()
			theme.default_font_size=GamePlatform.ui_font_size(16)
			GamePlatform.refresh_fonts(self)
		if is_instance_valid(local_view): local_view.browser_event("visible" if app_focused else "hidden","")
		sync_audio_selection()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_APPLICATION_FOCUS_IN:
		app_focused=what==NOTIFICATION_APPLICATION_FOCUS_IN
		sync_audio_selection()

func quit_game() -> void:
	if is_instance_valid(local_view): local_view.save_game()
	if is_instance_valid(network): network.disconnect_server()
	get_tree().quit()

func _draw() -> void:
	if passthrough: return
	draw_rect(Rect2(Vector2.ZERO,size),INK)
	if not GamePlatform.responsive() and not compact() and screen=="menu" and is_instance_valid(local_view) and not local_view.cat_textures.is_empty():
		for i in range(3):
			var at := Vector2(690+i*155,520-i*62)
			CatSkinArt.draw(self,local_view.game.skin_id(i),4,0,Rect2(at-Vector2(110,220),Vector2(220,220)))
		draw_line(Vector2(648,572),Vector2(1160,572),Color("3d514e"),2)
		draw_string(ThemeDB.fallback_font,Vector2(690,620),"A little garden. A formidable patrol.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,MUTED)
	if not compact() and screen=="multiplayer" and remote_cards.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(size.x*0.69+20,180),"Room for good company",HORIZONTAL_ALIGNMENT_LEFT,-1,24,MINT)
		draw_string(ThemeDB.fallback_font,Vector2(size.x*0.69+20,218),"Keep playing while others join.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,MUTED)

func silence_fanfare() -> void:
	if local_view.fanfare!=null: local_view.fanfare.queue_free(); local_view.fanfare=null

## Store screenshot scenes: staged with the demonstration garden, never a player's save.
func preview_scene(scene: String) -> void:
	match scene:
		"main-menu":
			local_view.make_preview(); show_menu(); silence_fanfare()
		"pause":
			show_game(false); local_view.make_preview(); local_view.game.paused=true; silence_fanfare(); open_pause()
		"garden", "placement", "inspect", "powerups", "achievements", "rebirth":
			show_game(false); local_view.make_preview(); local_view.game.paused=true; silence_fanfare()
			if scene=="placement": local_view.selected=-1; local_view.mobile.act("cat2"); local_view.mobile.pending=9*16+12
			if scene=="inspect": local_view.mobile.open_panel("inspect")
			if scene=="powerups": local_view.mobile.act("mobile_powerups")
			if scene=="achievements": open_achievements()
			if scene=="rebirth": local_view.game.active=false; local_view.game.enemies.clear(); local_view.game.run_best=22; local_view.action("rebirth")
		"multiplayer", "chat":
			network.id="mine"; network.display_name="You"
			network.room={"id":"room","name":"Sunny corner","owner":"mine","players":[{"id":"mine","name":"You","connected":true},{"id":"maple","name":"Maple","connected":true},{"id":"pepper","name":"Pepper","connected":true}]}
			show_game(true); local_view.make_preview(); local_view.game.paused=true; silence_fanfare()
			for player in ["maple","pepper"]: receive_field(player,LiveField.capture(local_view.game,1,1,[]))
			receive_chat("maple","Maple","The Thorn Crawler is back on wave 10!")
			receive_chat("mine","You","Holding the corner. Rerouting with the Siamese.")
			receive_chat("pepper","Pepper","My rebirth draft offered Winter Coat. Took it.")
			if scene=="chat": mobile_chat=true
			layout_game()

func preview_app() -> void:
	var scale_index := OS.get_cmdline_user_args().find("--preview-scale")
	if scale_index>=0 and scale_index+1<OS.get_cmdline_user_args().size():
		get_window().content_scale_factor=float(OS.get_cmdline_user_args()[scale_index+1])
		await get_tree().process_frame; await get_tree().process_frame
	var scene_index := OS.get_cmdline_user_args().find("--preview-scene")
	if scene_index>=0 and scene_index+1<OS.get_cmdline_user_args().size():
		preview_scene(OS.get_cmdline_user_args()[scene_index+1])
		for _i in range(4): await get_tree().process_frame
	if "--update-preview" in OS.get_cmdline_user_args():
		var args := OS.get_cmdline_user_args(); var which := args.find("--update-preview")
		var mode := args[which+1] if which+1<args.size() else "available"
		updater.state=mode; updater.latest={"version":"3.1.0"}
		updater.message={"available":"Purrimeter 3.1.0 is available. Update to join multiplayer; single player is always ready.","checking":"Checking for updates… Single player is ready.","downloaded":"Your update is verified and ready. Restarting saves your garden and leaves multiplayer.","error":"This installation cannot be replaced automatically. Install the verified download manually. Single player is still available."}.get(mode,"Checking for updates…")
		if mode=="error":
			var fake := FileAccess.open(updater.work.path_join("package.zip"),FileAccess.WRITE); fake.close()
		show_updates()
	await get_tree().process_frame
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args(); var i := args.find("--app-preview")
	if i+1<args.size():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[i+1])
	get_tree().quit()

func update_controls() -> void:
	if screen=="updates": render_updates()
	elif screen=="menu" and is_instance_valid(update_note): update_note.text=updater.message
	elif updater.state=="available":
		set_status(updater.message)
		local_view.status="An update is available. Open Menu → Game updates when you’re ready."

func show_updates() -> void:
	update_back=screen
	if update_back not in ["single","multiplayer","browser"]: update_back="menu"
	local_view.save_game()
	render_updates()

func render_updates() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_text: String = focused.text if focused is Button else ""
	clear_remotes()
	configure_window(false); clear_page("updates")
	var box := title_page("Game updates","Keep your patrol ready for company. Your garden and settings stay with you.")
	box.add_child(label("Installed · "+str(GameUpdater.build().version),22,MINT))
	if not updater.latest.is_empty(): box.add_child(label("Server release · "+str(updater.latest.version),20,CREAM))
	var detail := label(updater.message,20,GOLD); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(detail)
	var actions := row(box)
	if updater.state=="available":
		if OS.has_feature("web"): actions.add_child(button("Save and reload",func(): BrowserPlatform.current.bridge.reload(JSON.stringify(local_view.game.snapshot(),"",true,true)),true))
		elif GamePlatform.native_mobile(): actions.add_child(button("Update in "+GamePlatform.store_name(),GamePlatform.open_store,true))
		else: actions.add_child(button("Download update",updater.download,true))
	if updater.state=="downloaded": actions.add_child(button("Restart and play",updater.install,true))
	if updater.state=="error": actions.add_child(button("Retry",updater.retry,true))
	if updater.state not in ["checking","downloading","preparing"]: actions.add_child(button("Check for updates",func(): updater.check(network.address)))
	if updater.state=="error" and FileAccess.file_exists(updater.work.path_join("package.zip")):
		box.add_child(button("Show downloaded package",func(): OS.shell_show_in_file_manager(updater.work.path_join("package.zip"))))
		var manual := label("To install manually: quit Purrimeter, extract the downloaded ZIP, then replace Purrimeter.app on Mac. On Windows replace Purrimeter.exe, Purrimeter.pck and PurrimeterUpdater.exe together. Your saved garden lives separately.",18,MUTED); manual.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(manual)
	var spacer := Control.new(); spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(spacer)
	box.add_child(button("Back · keep playing",leave_updates))
	var candidates := page.find_children("*","Button",true,false)
	for candidate in candidates:
		if candidate.text==focus_text: candidate.grab_focus(); return
	if not candidates.is_empty(): candidates[0].grab_focus()

func finish_update() -> void:
	local_view.game.paused=true
	if not local_view.achievement_save_valid or SaveStore.write_achievements(local_view.game.achievements)!=OK or SaveStore.write(local_view.game)!=OK:
		updater.fail("Your garden could not be saved, so the update was cancelled. Export your garden before retrying."); return
	network.save_settings(); network.disconnect_server()
	get_tree().quit()

func acknowledge_update() -> void:
	if not GameUpdater.native(): return
	if "--update-recovered" in OS.get_cmdline_user_args():
		updater.message="The update could not start. Your previous game and garden were restored. Check for updates to retry."; updater.state="error"; update_controls()
	var args := OS.get_cmdline_user_args(); var index := args.find("--update-ack")
	if index<0 or index+1>=args.size() or not local_view.startup_save_valid or not local_view.achievement_save_valid: return
	var expected := ProjectSettings.globalize_path("user://updates/healthy")
	if args[index+1]!=expected: return
	await get_tree().process_frame
	await get_tree().process_frame
	var marker := FileAccess.open(expected,FileAccess.WRITE)
	if marker!=null: marker.store_string("ready"); marker.close()

func update_chat_button() -> void:
	if is_instance_valid(chat_toggle): chat_toggle.text="Close chat" if mobile_chat else ("Chat · %d"%unread if unread>0 else "Chat")

func phone_layout() -> void:
	var online := screen=="multiplayer"
	var top := 56.0 if online else 0.0
	local_view.position=Vector2(0,top); local_view.scale=Vector2.ONE; local_view.size=Vector2(size.x,size.y-top)
	local_view.visible=expanded.is_empty(); local_view.gameplay_enabled=expanded.is_empty() and not pause_open and not mobile_chat
	if not online: return
	for child in page.get_children():
		if child is Label: child.hide()
	if not is_instance_valid(mobile_tabs):
		mobile_tabs=HBoxContainer.new(); page.add_child(mobile_tabs)
	for child in mobile_tabs.get_children(): mobile_tabs.remove_child(child); child.queue_free()
	mobile_tabs.position=Vector2(8,4); mobile_tabs.size=Vector2(size.x-16,48)
	var own := button("Mine",close_expanded); own.size_flags_horizontal=Control.SIZE_EXPAND_FILL; mobile_tabs.add_child(own)
	for player in remote_cards:
		var item: Dictionary=remote_cards[player]
		var tab := button(str(item.member.name),func(): expand_field(player)); tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tab.clip_text=true; tab.custom_minimum_size.x=48; mobile_tabs.add_child(tab)
		item.card.visible=expanded==player
		item.card.position=Vector2(0,top); item.card.size=Vector2(size.x,size.y-top)
		for control in [item.name,item.details,item.inspect,item.mute,item.report,item.kick]: control.hide()
		item.view.position=Vector2.ZERO; item.view.scale=Vector2.ONE; item.view.size=item.card.size
		item.view.remote_compact=false; item.view.gameplay_enabled=expanded==player and not mobile_chat and not pause_open
	chat_toggle=button("Chat",func():
		mobile_chat=not mobile_chat
		if mobile_chat: unread=0
		phone_layout())
	chat_toggle.custom_minimum_size.x=72; mobile_tabs.add_child(chat_toggle); update_chat_button()
	for tab in mobile_tabs.get_children():
		tab.add_theme_font_size_override("font_size",16)
		for state in ["normal","hover","pressed"]:
			var style := theme.get_stylebox(state,"Button").duplicate() as StyleBoxFlat
			style.content_margin_left=8; style.content_margin_right=8; tab.add_theme_stylebox_override(state,style)
	var chat := page.get_node_or_null("Chat") as Control
	if chat!=null:
		chat.position=Vector2(8,60); chat.size=Vector2(size.x-16,size.y-68); chat.visible=mobile_chat
		page.move_child(chat,page.get_child_count()-1)
		var chat_column := chat.find_child("ChatColumn",true,false)
		var members := chat_column.get_node_or_null("Members")
		if members==null:
			members=VBoxContainer.new(); members.name="Members"
			# Moderation stays available on phones inside chat.
			chat_column.add_child(members)
		for child in members.get_children(): members.remove_child(child); child.queue_free()
		for player in remote_cards:
			var item: Dictionary=remote_cards[player]
			var line := HBoxContainer.new(); members.add_child(line)
			var name_label := label(str(item.member.name),16); name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; line.add_child(name_label)
			line.add_child(button("Unmute" if muted.get(player,false) else "Mute",func(): toggle_mute(player); phone_layout()))
			line.add_child(button("Report",func(): mobile_chat=false; close_expanded(); confirm_report(player)))
			if network.room.get("owner","")==network.id: line.add_child(button("Kick",func(): mobile_chat=false; close_expanded(); local_view.ask("Remove player?","Remove this player from the multiplayer game?","Remove",func(): network.kick(player))))
	sync_audio_selection()
