extends Control
## In-game dialogs with bounded, wrapping content and native keyboard controls.
signal dismissed

const INK := Color("131c26")
const PANEL := Color("202e3a")
const CREAM := Color("f4edd7")
const MUTED := Color("b0c3bd")
const MINT := Color("89dfb5")
const GOLD := Color("ffc46b")
const LINE := Color("3d514e")

var panel: PanelContainer
var body: VBoxContainer
var footer: HBoxContainer
var scroll: ScrollContainer
var accept_button: Button
var cancel_button: Button
var desired_size := Vector2(640,520)
var on_accept := Callable()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color=Color(INK,0.82)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(layout_panel)
	hide()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func surface(color: Color, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	return style

func label(parent: Node, value: String, font_size: int = 18, color: Color = MUTED) -> Label:
	var item := Label.new()
	item.text=value
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	item.add_theme_constant_override("line_spacing",4)
	item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(item)
	return item

func section(parent: Node, heading: String, copy: String) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation",6)
	parent.add_child(group)
	label(group,heading,20,CREAM)
	label(group,copy)

func separator(parent: Node) -> void:
	var line := HSeparator.new()
	var style := StyleBoxLine.new(); style.color=LINE; style.thickness=1
	line.add_theme_stylebox_override("separator",style)
	parent.add_child(line)

func begin_dialog(heading: String, subtitle: String, dimensions: Vector2) -> void:
	if is_instance_valid(panel): panel.hide(); panel.queue_free()
	desired_size=dimensions
	on_accept=Callable(); cancel_button=null
	panel=PanelContainer.new(); add_child(panel)
	var frame := surface(PANEL,12)
	frame.set_border_width_all(1); frame.border_color=LINE
	frame.content_margin_left=32; frame.content_margin_right=32
	frame.content_margin_top=28; frame.content_margin_bottom=28
	panel.add_theme_stylebox_override("panel",frame)
	var column := VBoxContainer.new(); panel.add_child(column)
	column.add_theme_constant_override("separation",20)
	var header := VBoxContainer.new(); column.add_child(header)
	header.add_theme_constant_override("separation",8)
	label(header,heading,30,CREAM)
	if not subtitle.is_empty(): label(header,subtitle,18)
	separator(column)
	scroll=ScrollContainer.new(); column.add_child(scroll)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	body=VBoxContainer.new(); scroll.add_child(body)
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",20)
	separator(column)
	footer=HBoxContainer.new(); column.add_child(footer)
	footer.add_theme_constant_override("separation",12)
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	show(); layout_panel()

func layout_panel() -> void:
	if not is_instance_valid(panel): return
	panel.size=desired_size.min(size-Vector2(64,64))
	panel.position=(size-panel.size)/2

func make_button(value: String, primary: bool, callback: Callable) -> Button:
	var item := Button.new()
	item.text=value; item.custom_minimum_size=Vector2(144,48)
	item.add_theme_font_size_override("font_size",18)
	for state in ["normal","hover","pressed"]:
		var fill := MINT if primary else INK
		if state=="hover": fill=fill.lightened(0.10)
		if state=="pressed": fill=fill.darkened(0.08)
		var style := surface(fill)
		style.content_margin_left=20; style.content_margin_right=20
		item.add_theme_stylebox_override(state,style)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		item.add_theme_color_override(state,INK if primary else CREAM)
	var focus := surface(Color.TRANSPARENT)
	focus.set_border_width_all(2); focus.border_color=MINT
	focus.set_expand_margin_all(3)
	item.add_theme_stylebox_override("focus",focus)
	item.pressed.connect(callback)
	footer.add_child(item)
	return item

func finish_dialog(accept_text: String, callback: Callable, cancellable: bool) -> void:
	on_accept=callback
	if cancellable: cancel_button=make_button("Cancel",false,close)
	accept_button=make_button(accept_text,true,accept)
	var first := cancel_button if cancellable else accept_button
	first.focus_next=first.get_path_to(accept_button)
	first.focus_previous=first.get_path_to(accept_button)
	accept_button.focus_next=accept_button.get_path_to(first)
	accept_button.focus_previous=accept_button.get_path_to(first)
	first.grab_focus()
	layout_panel.call_deferred()

func close() -> void:
	if not visible: return
	on_accept=Callable()
	var focused := get_viewport().gui_get_focus_owner()
	if focused!=null and is_ancestor_of(focused): focused.release_focus()
	hide(); dismissed.emit()

func accept() -> void:
	if not visible: return
	var callback := on_accept
	close()
	if callback.is_valid(): callback.call()

func show_confirmation(heading: String, message: String, callback: Callable, accept_text: String) -> void:
	begin_dialog(heading,"",Vector2(640,300))
	label(body,message,19,CREAM)
	finish_dialog(accept_text,callback,true)

func show_rebirth(run_best: int, bonus: float, callback: Callable) -> void:
	begin_dialog("Rebirth your patrol?","Start a new run with lasting rewards.",Vector2(640,530))
	var gain := run_best*10.0
	var reward := VBoxContainer.new(); body.add_child(reward)
	reward.add_theme_constant_override("separation",6)
	label(reward,"+%s%% permanent coin rewards" % Amount.of(gain).label(),25,MINT)
	label(reward,"Total coin bonus: +%s%% → +%s%%" % [Amount.of(bonus).label(),Amount.of(bonus+gain).label()],17,GOLD)
	section(body,"Keep your patrol","Keep all coins, surviving cats, their upgrades, powerups and discoveries. Surviving cats return at full health.")
	section(body,"Start again at level 1","Clear level 5 again to unlock your next rebirth.")
	finish_dialog("Rebirth patrol",callback,true)

func show_help() -> void:
	begin_dialog("How to play","Build a maze of cats. Guard the garden's exit.",Vector2(880,740))
	var columns := HBoxContainer.new(); body.add_child(columns)
	columns.add_theme_constant_override("separation",32)
	var rules := VBoxContainer.new(); columns.add_child(rules)
	rules.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rules.size_flags_stretch_ratio=1.15
	rules.add_theme_constant_override("separation",22)
	section(rules,"Defend the garden","Foes follow open routes or attack cats. Backtracking turns them red; sweat marks frenzy and a breakout toward the exit. One escape ends the attempt: lose a level.")
	section(rules,"Grow your patrol","Cats have five upgrades. Powerup icons show effects and rank requirements; Owned shows purchases. Clear level 5 to rebirth. Bosses arrive every tenth level.")
	section(rules,"Keep your progress","Autosaves keep progress. Export / Import transfers saves. Defeat keeps coins and surviving cats, including damage.")
	var controls := VBoxContainer.new(); columns.add_child(controls)
	controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation",10)
	label(controls,"Your controls",20,CREAM)
	for pair in [["Click","Choose a cat, then a tile"],["1 / 2 / 3","Select a cat"],["Space","Pause / resume"],["N","Start the next attempt"],["Esc","Cancel / close panel"],["Tab / Shift+Tab","Move between controls"],["Arrow keys","Choose a garden tile"],["Enter","Activate / recruit / inspect"]]:
		var row := HBoxContainer.new(); controls.add_child(row)
		row.add_theme_constant_override("separation",12)
		var key := label(row,pair[0],16,MINT)
		key.custom_minimum_size.x=132; key.size_flags_horizontal=Control.SIZE_FILL
		label(row,pair[1],16)
	separator(controls)
	label(controls,"Build, upgrade and repair while paused. Leaving the window pauses combat.",16,MUTED)
	finish_dialog("Got it",Callable(),false)
