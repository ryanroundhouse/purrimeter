extends "res://ui/patrol_dialog.gd"
## One responsive surface for choosing a committed reward and inspecting its catalog.
signal chosen(id: String)
var game: Session
var locked := false
var selected_id := ""
var cards: Dictionary = {}
var selection_note: Label
var backup_button: Button

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if not locked: close()

func close() -> void:
	if not locked: super.close()

func finish_choice() -> void:
	locked=false; super.close()

func show_draft(session: Session) -> void:
	game=session; locked=true; selected_id=""; cards.clear(); backup_button=null
	begin_dialog("Rebirth Draft","Rebirth %d · cleared wave %d this run\nChoose one permanent improvement."%[game.rebirths,game.pending_draft.depth],Vector2(1080,780))
	var grid := GridContainer.new(); grid.columns=3 if size.x>=800 else 1
	grid.set_meta("draft_grid",true); grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",14); grid.add_theme_constant_override("v_separation",14); body.add_child(grid)
	for id in game.pending_draft.offers: add_card(grid,id,true)
	selection_note=label(body,"Select a card to preview your choice. Nothing is selected yet.",17,MUTED)
	accept_button=make_button("Choose improvement",true,func():
		if selected_id.is_empty(): return
		accept_button.disabled=true; chosen.emit(selected_id))
	accept_button.disabled=true
	accept_button.add_theme_stylebox_override("disabled",surface(INK,6))
	accept_button.add_theme_color_override("font_disabled_color",MUTED)
	label(footer,"Session only · export to keep" if BrowserPlatform.session_only() else "Saved offers · no rerolls",15,MUTED)
	var focusables: Array = cards.values()+[accept_button]
	for index in range(focusables.size()):
		var control: Control = focusables[index]
		control.focus_next=control.get_path_to(focusables[(index+1)%focusables.size()])
		control.focus_previous=control.get_path_to(focusables[(index+focusables.size()-1)%focusables.size()])
	layout_panel.call_deferred()
	if not cards.is_empty(): cards.values()[0].grab_focus.call_deferred()

func show_collection(session: Session) -> void:
	game=session; locked=false; selected_id=""; cards.clear()
	begin_dialog("Draft Collection","Permanent within this garden. Earn one improvement per rebirth.\nDeeper runs favor stronger offers; New Garden resets this collection.",Vector2(1080,740))
	var grid := GridContainer.new(); grid.columns=3 if size.x>=800 else 1
	grid.set_meta("draft_grid",true); grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",14); grid.add_theme_constant_override("v_separation",14); body.add_child(grid)
	for row in RebirthDraft.ITEMS: add_card(grid,row[0],false)
	add_card(grid,RebirthDraft.FALLBACK,false)
	finish_dialog("Back to garden",Callable(),false)
	var scrollbar := scroll.get_v_scroll_bar()
	scrollbar.focus_mode=Control.FOCUS_ALL
	accept_button.focus_next=accept_button.get_path_to(scrollbar); accept_button.focus_previous=accept_button.focus_next
	scrollbar.focus_next=scrollbar.get_path_to(accept_button); scrollbar.focus_previous=scrollbar.focus_next

func add_card(parent: Control, id: String, selectable: bool) -> void:
	var d := RebirthDraft.definition(id)
	var rank := game.draft_rank(id)
	var accent: Color = [MINT,Color("78cfff"),GOLD][d.band]
	var card: Control = Button.new() if selectable else PanelContainer.new()
	parent.add_child(card); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var frame := surface(INK,6); frame.set_border_width_all(1); frame.border_color=LINE
	if selectable:
		card.add_theme_stylebox_override("normal",frame)
		var hover := frame.duplicate(); hover.border_color=accent; card.add_theme_stylebox_override("hover",hover)
		card.add_theme_stylebox_override("pressed",hover)
		var focus := surface(Color.TRANSPARENT,6); focus.set_border_width_all(2); focus.border_color=CREAM
		card.add_theme_stylebox_override("focus",focus)
		card.pressed.connect(func(): select_card(id))
		cards[id]=card
	else: card.add_theme_stylebox_override("panel",frame)
	var margin := MarginContainer.new(); card.add_child(margin)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	if selectable:
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new(); margin.add_child(column); column.add_theme_constant_override("separation",10)
	var heading := HBoxContainer.new(); column.add_child(heading); heading.add_theme_constant_override("separation",12)
	var icon := TextureRect.new(); heading.add_child(icon)
	icon.texture=load("res://assets/drafts/"+id+".svg")
	icon.custom_minimum_size=Vector2(40,40); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	icon.modulate=Color(accent,1.0 if selectable or rank>0 else 0.5)
	label(heading,d.name,23,CREAM)
	label(column,"%s · %s"%["Fallback" if id==RebirthDraft.FALLBACK else RebirthDraft.BANDS[d.band],"Rank %d to %d"%[rank,rank+1] if selectable else ("Rank %d / %d"%[rank,d.cap] if d.cap>0 else "Rank %d · unlimited"%rank)],16,accent)
	label(column,d.description,17,MUTED)
	if id==RebirthDraft.FALLBACK and selectable:
		label(column,"Coin bonus: +%s%% to +%s%%"%[Amount.of(game.bonus_points).label(),Amount.of(game.bonus_points+10).label()],18,GOLD)
	else:
		if rank>0: label(column,"Now: "+RebirthDraft.effect(id,rank),16,MUTED)
		if d.cap==0 or rank<d.cap:
			label(column,"Next: "+RebirthDraft.effect(id,rank+1),18,CREAM)
	if not selectable:
		label(column,("Eligible now\n" if RebirthDraft.eligible(game,id) else "")+RebirthDraft.requirements(game,id),16,accent)
	if selectable:
		for child in card.find_children("*","Control",true,false): child.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size.y=340
		# Buttons do not derive minimum height from children. Measure wrapped content after layout.
		column.minimum_size_changed.connect(func(): card.custom_minimum_size.y=maxf(280,column.get_combined_minimum_size().y+32))

func select_card(id: String) -> void:
	selected_id=id
	for key in cards:
		for state in ["normal","hover","pressed"]:
			var fill := Color("304b40") if key==id else INK
			var frame := surface(fill.lightened(0.06) if state=="hover" else fill,6)
			frame.set_border_width_all(2 if key==id else 1); frame.border_color=MINT if key==id else LINE
			cards[key].add_theme_stylebox_override(state,frame)
	selection_note.text="Selected: %s · rank %d. This choice lasts until New Garden."%[RebirthDraft.definition(id).name,game.draft_rank(id)+1]
	accept_button.text="Choose "+RebirthDraft.definition(id).name
	accept_button.disabled=false

func show_save_error(message: String, export_backup: Callable) -> void:
	selection_note.text=message
	for card in cards.values(): card.disabled=false
	accept_button.text="Retry saving choice"; accept_button.disabled=false
	if not is_instance_valid(backup_button):
		backup_button=make_button("Export backup",false,export_backup)
		accept_button.focus_next=accept_button.get_path_to(backup_button)
		backup_button.focus_previous=backup_button.get_path_to(accept_button)
		backup_button.focus_next=backup_button.get_path_to(cards.values()[0])
		cards.values()[0].focus_previous=cards.values()[0].get_path_to(backup_button)
	layout_panel.call_deferred()

func layout_panel() -> void:
	if is_instance_valid(panel):
		if locked: desired_size.y=size.y-16 if size.x<800 else 780
		for grid in panel.find_children("*","GridContainer",true,false):
			if grid.has_meta("draft_grid"): grid.columns=3 if size.x>=800 else 1
	super.layout_panel()
