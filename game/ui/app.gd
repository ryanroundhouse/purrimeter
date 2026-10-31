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

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	test_mode="--multiplayer-test" in OS.get_cmdline_user_args() or "--app-preview" in OS.get_cmdline_user_args()
	passthrough="--smoke-test" in OS.get_cmdline_user_args() or "--preview" in OS.get_cmdline_user_args() or "--music-test" in OS.get_cmdline_user_args()
	theme=make_theme()
	local_view=GameView.new(); local_view.size=Vector2(1280,900); local_view.hosted=not passthrough
	# Test instances never read or write the player's save or preferences.
	if test_mode: local_view.read_only=true
	add_child(local_view)
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
		if screen!="multiplayer": show_game(true)
		publish_clock=1.0)
	network.room_changed.connect(update_room)
	network.field_received.connect(receive_field)
	network.chat_received.connect(receive_chat)
	network.interrupted.connect(func():
		local_view.game.paused=true; local_view.save_game()
		for item in remote_cards.values(): item.view.remote_connected=false
		sync_audio_selection(); set_status("Connection lost. Your garden is paused; reconnecting…"))
	network.departed.connect(on_departed)
	chat_player=AudioStreamPlayer.new(); add_child(chat_player); chat_player.stream=load("res://assets/coin.wav"); chat_player.volume_db=-22
	resized.connect(layout_game)
	show_menu()
	if "--app-preview" in OS.get_cmdline_user_args(): preview_app.call_deferred()

func make_theme() -> Theme:
	var result := Theme.new(); result.default_font_size=18
	for type in ["Label","Button","LineEdit","CheckButton","RichTextLabel"]: result.set_color("font_color",type,CREAM)
	result.set_color("font_placeholder_color","LineEdit",MUTED)
	result.set_color("font_disabled_color","Button",MUTED.darkened(0.15))
	result.set_color("caret_color","LineEdit",MINT)
	result.set_color("selection_color","LineEdit",Color("416957"))
	for type in ["Button","LineEdit","PanelContainer"]:
		for state in ["normal","hover","pressed","disabled","focus","panel"]:
			var style := StyleBoxFlat.new(); style.bg_color=PANEL.lightened(0.1) if state=="hover" else PANEL
			style.set_corner_radius_all(6); style.content_margin_left=16; style.content_margin_right=16; style.content_margin_top=12; style.content_margin_bottom=12
			if state=="focus": style.bg_color=Color.TRANSPARENT; style.set_border_width_all(2); style.border_color=MINT
			if state=="pressed": style.bg_color=Color("39584b")
			result.set_stylebox(state,type,style)
	return result

func label(value: String, font_size: int = 18, color: Color = CREAM) -> Label:
	var l := Label.new(); l.text=value; l.add_theme_font_size_override("font_size",font_size); l.add_theme_color_override("font_color",color); return l

func button(value: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new(); b.text=value; b.custom_minimum_size.y=48; b.pressed.connect(callback)
	if primary:
		for state in ["normal","hover","pressed"]:
			var s := theme.get_stylebox(state,"Button").duplicate() as StyleBoxFlat; s.bg_color=MINT.lightened(0.12) if state=="hover" else MINT; b.add_theme_stylebox_override(state,s)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(state,INK)
	return b

func input(placeholder: String, value: String, limit: int, secret: bool = false) -> LineEdit:
	var edit := LineEdit.new(); edit.placeholder_text=placeholder; edit.text=value; edit.max_length=limit; edit.secret=secret; edit.custom_minimum_size.y=48; return edit

func column(parent: Node, gap: int = 16) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",gap); parent.add_child(box); return box

func row(parent: Node, gap: int = 12) -> HBoxContainer:
	var box := HBoxContainer.new(); box.add_theme_constant_override("separation",gap); parent.add_child(box); return box

func clear_page(next: String) -> void:
	close_pause()
	if is_instance_valid(page): page.hide(); page.queue_free()
	page=Control.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(page)
	screen=next; state_label=null; room_list=null; chat_log=null; chat_input=null
	local_view.hide(); local_view.gameplay_enabled=false; local_view.game.paused=true
	queue_redraw()

func configure_window(wide: bool) -> void:
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
	var box := column(margin,20); box.add_child(label(title,38))
	var sub := label(subtitle,18,MUTED); sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(sub)
	state_label=label(notice,17,GOLD); state_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return box

func show_menu() -> void:
	if network!=null: network.disconnect_server()
	clear_remotes(); transcript.clear(); muted.clear(); configure_window(false); clear_page("menu")
	var box := column(page,18); box.position=Vector2(100,172); box.size=Vector2(450,580)
	box.add_child(label("PURRIMETER",48)); box.add_child(label("The Garden Guard",24,MINT))
	var description := label("Build your patrol. Grow your garden.\nKeep good company.",21,MUTED); box.add_child(description)
	var space := Control.new(); space.custom_minimum_size.y=22; box.add_child(space)
	box.add_child(button("Single player",func(): show_game(false),true))
	box.add_child(label("Your garden · Level %d · %d rebirths"%[local_view.game.level,local_view.game.rebirths],16,MUTED))
	box.add_child(button("Multiplayer",func(): notice=""; show_browser(); network.connect_server()))
	box.add_child(label("Up to 3 gardeners · Live fields and chat",16,MUTED))
	box.add_child(button("Connection settings",func(): show_settings("menu")))
	box.add_child(button("Quit",quit_game))
	if not notice.is_empty():
		var note := label(notice,16,GOLD); note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(note)

func show_settings(back: String) -> void:
	return_screen=back; configure_window(false); clear_page("settings")
	var box := title_page("Connection settings","Choose how other gardeners see you and which server to visit.")
	box.add_child(label("Player name",18,MINT))
	var name_edit := input("Your name",network.display_name,24); box.add_child(name_edit)
	box.add_child(label("Server address",18,MINT))
	var server_edit := input("wss://your-server/ws",network.address,256); box.add_child(server_edit)
	box.add_child(label("Your garden stays on this computer. Your name can change before joining.",16,MUTED))
	var sound := CheckButton.new(); sound.text="Chat notification sound"; sound.button_pressed=network.chat_sound; box.add_child(sound)
	box.add_child(state_label)
	var actions := row(box)
	actions.add_child(button("Save settings",func():
		if name_edit.text.strip_edges().is_empty(): set_status("Enter a player name."); return
		if not server_edit.text.strip_edges().is_empty() and not network.valid_address(server_edit.text.strip_edges()): set_status("Use wss://hostname/ws. Plain ws:// is supported only for local testing."); return
		network.disconnect_server(); network.display_name=name_edit.text.strip_edges(); network.address=server_edit.text.strip_edges(); network.chat_sound=sound.button_pressed; network.save_settings(); notice="Settings saved."
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
		var name_label := label(str(game.get("name","Garden")),22); name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; line.add_child(name_label)
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
	configure_window(online); clear_page("multiplayer" if online else "single")
	page.mouse_filter=Control.MOUSE_FILTER_IGNORE
	local_view.show(); local_view.gameplay_enabled=true; local_view.game.paused=true
	if online:
		var header := label(str(network.room.get("name","Garden")),26); header.position=Vector2(28,16); header.size=Vector2(1000,48); header.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; page.add_child(header)
		state_label=label("",17,MUTED); state_label.position=Vector2(28,58); state_label.size=Vector2(1240,28); page.add_child(state_label)
		var chat_panel := PanelContainer.new(); chat_panel.name="Chat"; page.add_child(chat_panel)
		var chat_column := column(chat_panel,8)
		var chat_header := row(chat_column); var title := label("Garden chat",20,MINT); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; chat_header.add_child(title)
		var sound := CheckButton.new(); sound.text="Sound"; sound.button_pressed=network.chat_sound; sound.toggled.connect(func(value): network.chat_sound=value; network.save_settings()); chat_header.add_child(sound)
		chat_log=RichTextLabel.new(); chat_log.bbcode_enabled=false; chat_log.scroll_following=true; chat_log.selection_enabled=true; chat_log.size_flags_vertical=Control.SIZE_EXPAND_FILL; chat_column.add_child(chat_log)
		for entry in transcript: chat_log.append_text(entry+"\n")
		var compose := row(chat_column,8); chat_input=input("Message… · T to chat","",400); chat_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL; compose.add_child(chat_input)
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
			for small in [inspect,mute,kick]:
				small.add_theme_font_size_override("font_size",16)
				for state in ["normal","hover","pressed"]:
					var compact := theme.get_stylebox(state,"Button").duplicate() as StyleBoxFlat
					compact.content_margin_top=6; compact.content_margin_bottom=6; small.add_theme_stylebox_override(state,compact)
			remote_cards[player]={"card":card,"name":name_label,"details":details,"view":view,"inspect":inspect,"mute":mute,"kick":kick,"member":member}
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
	item.details.text="Level %d · %d rebirths · %s"%[view.game.level,view.game.rebirths,"Paused" if view.game.paused else "%d×"%view.game.speed]

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

func receive_chat(player: String, author: String, message: String) -> void:
	if screen!="multiplayer" or muted.get(player,false): return
	var entry := author+": "+message
	transcript.append(entry)
	if transcript.size()>200: transcript.pop_front()
	if is_instance_valid(chat_log): chat_log.text="\n".join(transcript)+"\n"
	if player!=network.id and network.chat_sound and not test_mode: chat_player.play()

func send_chat() -> void:
	if not is_instance_valid(chat_input) or chat_input.text.strip_edges().is_empty(): return
	if network.say(chat_input.text): chat_input.clear()
	else: set_status("Chat is unavailable while disconnected. Your message has not been sent.")

func set_status(message: String) -> void:
	notice=message
	if is_instance_valid(state_label): state_label.text=message

func on_departed(reason: String) -> void:
	clear_remotes(); transcript.clear(); muted.clear()
	if not reason.is_empty():
		local_view.game.paused=true; show_game(false); local_view.status=reason; notice=reason

func layout_game() -> void:
	if not is_instance_valid(local_view) or passthrough: return
	if screen=="single":
		local_view.position=Vector2.ZERO; local_view.scale=Vector2.ONE; local_view.size=Vector2(1280,900); return
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
			item.mute.hide(); item.kick.hide()
		else:
			card.position=Vector2(right_x,94+index*(card_height+16)); card.size=Vector2(width,card_height)
			var square := minf(width-(132 if count==2 else 24),card_height-(68 if count==2 else 104)); var fit := square/704.0
			var field_x := 12.0 if count==2 else (width-square)/2
			var field_y := 60.0 if count==2 else 96.0
			view.remote_compact=true; view.gameplay_enabled=false; view.position=Vector2(field_x-28*fit,field_y-134*fit); view.scale=Vector2.ONE*fit; view.size=Vector2(760,850)
			item.inspect.text="View"; item.inspect.position=Vector2(12,57); item.inspect.size=Vector2(76,34)
			item.mute.show(); item.mute.position=Vector2(96,57); item.mute.size=Vector2(92,34)
			item.kick.visible=network.room.get("owner","")==network.id; item.kick.position=Vector2(196,57); item.kick.size=Vector2(76,34)
			if count==2:
				item.inspect.position=Vector2(width-104,60); item.inspect.size.x=92
				item.mute.position=Vector2(width-104,102)
				item.kick.position=Vector2(width-104,144); item.kick.size.x=92
		item.name.size=Vector2(card.size.x-120,28); item.name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		index+=1
	if chat!=null: chat.visible=expanded.is_empty()
	local_view.visible=expanded.is_empty(); local_view.gameplay_enabled=expanded.is_empty() and not pause_open
	sync_audio_selection()
	queue_redraw()

func expand_field(player: String) -> void:
	if expanded==player: close_expanded(); return
	if not remote_cards.has(player): return
	expanded=player; layout_game()

func close_expanded() -> void:
	expanded=""; layout_game()

func open_pause() -> void:
	if screen not in ["single","multiplayer"] or pause_open: return
	if not expanded.is_empty(): close_expanded()
	local_view.game.paused=true; local_view.gameplay_enabled=false; pause_open=true
	overlay=Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(overlay)
	var shade := ColorRect.new(); shade.color=Color(INK,0.93); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(center)
	var box := column(center,14); box.custom_minimum_size.x=420
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
	box.add_child(button("Export garden",func(): close_pause(); local_view.action("export")))
	box.add_child(button("Import garden",func(): close_pause(); local_view.action("import")))
	box.add_child(button("New garden",func(): close_pause(); local_view.action("new")))
	box.add_child(button("How to play",func(): close_pause(); local_view.action("help")))
	if screen=="multiplayer":
		box.add_child(button("Continue offline",func(): close_pause(); network.leave_game(); show_game(false)))
	box.add_child(button("Main menu",func():
		close_pause(); local_view.ask("Return to the main menu?","Your garden will be saved. You will leave this multiplayer game." if screen=="multiplayer" else "Your garden will be saved and paused.","Main menu",func(): local_view.save_game(); show_menu())))
	box.add_child(button("Close menu · stay paused",close_pause)); resume.grab_focus()

func close_pause() -> void:
	if is_instance_valid(overlay): overlay.hide(); overlay.queue_free()
	overlay=null; pause_open=false
	if is_instance_valid(local_view): local_view.gameplay_enabled=screen in ["single","multiplayer"] and expanded.is_empty()

func _input(event: InputEvent) -> void:
	if passthrough or not event is InputEventKey or not event.pressed or event.echo: return
	var focused := get_viewport().gui_get_focus_owner()
	if event.keycode==KEY_T and screen=="multiplayer" and not pause_open and expanded.is_empty() and not local_view.confirm.visible and not local_view.file_dialog.visible and not focused is LineEdit:
		chat_input.grab_focus(); get_viewport().set_input_as_handled(); return
	if event.keycode!=KEY_ESCAPE: return
	if focused is LineEdit:
		focused.release_focus(); get_viewport().set_input_as_handled(); return
	if pause_open: close_pause(); get_viewport().set_input_as_handled()
	elif not expanded.is_empty(): close_expanded(); get_viewport().set_input_as_handled()
	elif screen in ["single","multiplayer"] and not local_view.confirm.visible and not local_view.file_dialog.visible:
		if local_view.placing>=0 or local_view.selected>=0 or local_view.selected_enemy>=0:
			local_view.placing=-1; local_view.selected=-1; local_view.selected_enemy=-1
		else: open_pause()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if passthrough or network==null: return
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
	if screen=="menu" and is_instance_valid(local_view) and not local_view.cat_textures.is_empty():
		for i in range(3):
			var texture: Texture2D=local_view.cat_textures[i]
			var bounds: Array=SpriteBounds.CATS[i][3][0]
			var src := Rect2(bounds[0],bounds[1],bounds[2],bounds[3]); var fit := 220.0/310.0
			var at := Vector2(690+i*155,520-i*62)
			draw_texture_rect_region(texture,Rect2(at-Vector2(src.size.x*fit/2,src.size.y*fit),src.size*fit),src)
		draw_line(Vector2(648,572),Vector2(1160,572),Color("3d514e"),2)
		draw_string(ThemeDB.fallback_font,Vector2(690,620),"A little garden. A formidable patrol.",HORIZONTAL_ALIGNMENT_LEFT,-1,20,MUTED)
	if screen=="multiplayer" and remote_cards.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(size.x*0.69+20,180),"Room for good company",HORIZONTAL_ALIGNMENT_LEFT,-1,24,MINT)
		draw_string(ThemeDB.fallback_font,Vector2(size.x*0.69+20,218),"Keep playing while others join.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,MUTED)

func preview_app() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args(); var i := args.find("--app-preview")
	if i+1<args.size():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[i+1])
	get_tree().quit()
