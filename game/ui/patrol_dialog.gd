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
var footer: BoxContainer
var scroll: ScrollContainer
var accept_button: Button
var cancel_button: Button
var desired_size := Vector2(640,520)
var on_accept := Callable()
var level_buttons: Dictionary = {}

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
	level_buttons.clear()
	panel=PanelContainer.new(); add_child(panel)
	var frame := surface(PANEL,12)
	frame.set_border_width_all(1); frame.border_color=LINE
	frame.content_margin_left=16 if size.x<650 else 32; frame.content_margin_right=frame.content_margin_left
	frame.content_margin_top=16 if size.y<650 else 28; frame.content_margin_bottom=frame.content_margin_top
	panel.add_theme_stylebox_override("panel",frame)
	var column := VBoxContainer.new(); panel.add_child(column)
	column.add_theme_constant_override("separation",10 if size.y<650 else 20)
	var header := VBoxContainer.new(); column.add_child(header)
	header.add_theme_constant_override("separation",8)
	label(header,heading,24 if size.x<650 else 30,CREAM)
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
	footer=VBoxContainer.new() if size.x<650 else HBoxContainer.new(); column.add_child(footer)
	footer.add_theme_constant_override("separation",12)
	var spacer := Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	show(); layout_panel()

func layout_panel() -> void:
	if not is_instance_valid(panel): return
	for row in panel.find_children("*","BoxContainer",true,false):
		if row.has_meta("phone_stack"): row.vertical=size.x<650
	for control in panel.find_children("*","Control",true,false):
		if control.has_meta("wide_min"): control.custom_minimum_size.x=0 if size.x<650 else float(control.get_meta("wide_min"))
		if control.has_meta("phone_grid"): control.columns=2 if size.x<650 else 5
	panel.size=desired_size.min(size-Vector2(16,16) if size.x<650 or size.y<650 else size-Vector2(64,64))
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

func show_levels(g: Session, callback: Callable) -> void:
	begin_dialog("Choose a garden","Five landscapes to master. Unlock each by clearing the one before it.",Vector2(720,820))
	body.add_theme_constant_override("separation",8)
	var available: Array[Button] = []
	for selected in range(1,GardenLevels.COUNT+1):
		var unlocked := selected<=g.achievements.unlocked_level
		var item := make_button("",false,func(): close(); callback.call(selected))
		item.reparent(body); item.disabled=not unlocked
		item.custom_minimum_size=Vector2(0,88 if unlocked else 104)
		item.add_theme_stylebox_override("disabled",surface(Color("1b2832")))
		var margin := MarginContainer.new(); item.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,12)
		for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
		var row := HBoxContainer.new(); margin.add_child(row); row.add_theme_constant_override("separation",14)
		var icon := preload("res://ui/level_terrain_icon.gd").new(); icon.selected_level=selected
		icon.custom_minimum_size=Vector2(72,72); icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER; row.add_child(icon)
		var copy := VBoxContainer.new(); copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; copy.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		copy.add_theme_constant_override("separation",1); row.add_child(copy)
		label(copy,GardenLevels.level_name(selected),20,CREAM if unlocked else MUTED)
		label(copy,"Level %d · %s" % [selected,"Endless" if selected==5 else "%d waves" % GardenLevels.wave_limit(selected)],14,MINT if unlocked else MUTED)
		label(copy,GardenLevels.terrain_profile(selected).summary,14,MUTED)
		if not unlocked: label(copy,"Locked · beat level %d" % (selected-1),14,GOLD)
		# The whole row is one keyboard/touch target, including its icon and copy.
		margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
		for child in margin.find_children("*","Control",true,false): child.mouse_filter=Control.MOUSE_FILTER_IGNORE
		item.tooltip_text="%s. %s. Terrain icons are examples; each new garden has a fresh layout." % [GardenLevels.title(selected),GardenLevels.terrain_profile(selected).summary]
		level_buttons[selected]=item
		if unlocked: available.append(item)
	finish_dialog("Keep garden",Callable(),false)
	# Include the choices in the keyboard loop, rather than trapping focus in the footer.
	var controls: Array[Button] = available.duplicate()
	controls.append(accept_button)
	for i in range(controls.size()):
		controls[i].focus_next=controls[i].get_path_to(controls[(i+1)%controls.size()])
		controls[i].focus_previous=controls[i].get_path_to(controls[posmod(i-1,controls.size())])
	available[0].grab_focus()

func show_victory(g: Session, next_level: Callable, choose_level: Callable) -> void:
	begin_dialog("Level %d complete!" % g.garden_level,"All %d waves cleared. Your next challenge is ready." % g.wave_limit(),Vector2(640,620 if size.x<650 else 440))
	label(body,"%s unlocked" % GardenLevels.title(g.garden_level+1),24,MINT)
	label(body,"Keep this garden to view or export, or start a fresh garden for your next challenge.",18,CREAM)
	make_button("View garden",false,close)
	make_button("Choose level",false,func(): close(); choose_level.call())
	accept_button=make_button("Next level",true,func(): close(); next_level.call())
	accept_button.grab_focus()
	layout_panel.call_deferred()

func show_rebirth(run_best: int, _bonus: float, callback: Callable) -> void:
	begin_dialog("Rebirth your patrol?","Confirm before seeing your offers. No cancellation or rerolls afterward.",Vector2(680,size.y-16 if size.x<650 else 650))
	var reward := VBoxContainer.new(); body.add_child(reward)
	reward.add_theme_constant_override("separation",6)
	label(reward,"Choose one permanent improvement",25,MINT)
	label(reward,"Cleared wave %d this run · deeper runs favor stronger offers" % run_best,17,GOLD)
	section(body,"Keep your patrol","Keep all coins, surviving cats, their upgrades, powerups and discoveries. Surviving cats return at full health.")
	section(body,"Commit, then choose","Return to wave 1 and reveal up to three offers. No cancellation or rerolls. Offers stay saved until you choose. Start wave 1 manually afterward.")
	finish_dialog("Rebirth patrol",callback,true)

func show_help() -> void:
	begin_dialog("How to play","Build a maze of cats. Guard the garden's exit.",Vector2(880,740))
	var columns := HBoxContainer.new(); body.add_child(columns)
	columns.add_theme_constant_override("separation",32)
	var rules := VBoxContainer.new(); columns.add_child(rules)
	rules.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rules.size_flags_stretch_ratio=1.15
	rules.add_theme_constant_override("separation",22)
	section(rules,"Defend the garden","Foes follow open routes or attack cats. Backtracking turns them red; sweat marks frenzy and a breakout toward the exit. One escape ends the attempt: lose a wave.")
	section(rules,"Grow your patrol","Cats have five upgrades. Powerup icons show effects and rank requirements; Owned shows purchases. Clear wave 5 to rebirth. Bosses arrive every tenth wave.")
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
