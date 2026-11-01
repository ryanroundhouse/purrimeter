extends "res://ui/patrol_dialog.gd"
signal equipped
const Portrait = preload("res://ui/skin_portrait.gd")
var game: Session
var kind := 0
var selection := "scout_default"
var tier := 1
var tabs: Array = []
var cards: Dictionary = {}
var previews: Dictionary = {}
var details: VBoxContainer
var card_row: HBoxContainer
var portrait: Control
var equip_button: Button
var tier_picker: OptionButton
var status_label: Label

func open(session: Session) -> void:
	game=session; selection=CatSkins.selected(game.achievements,kind)
	begin_dialog("Cat Skins","Choose a look for your patrol · Skins never change combat",Vector2(1120,800))
	body.add_theme_constant_override("separation",20)
	var tab_row := HBoxContainer.new(); body.add_child(tab_row)
	tab_row.add_theme_constant_override("separation",12); tabs.clear()
	for i in range(3):
		var tab := Button.new(); tab.text=Balance.CATS[i].name
		tab.custom_minimum_size=Vector2(160,44); tab.toggle_mode=true
		tab.pressed.connect(func(): kind=i; selection=CatSkins.selected(game.achievements,kind); refresh_cards())
		tab_row.add_child(tab); tabs.append(tab)
	card_row=HBoxContainer.new(); body.add_child(card_row); card_row.add_theme_constant_override("separation",10)
	var columns := HBoxContainer.new(); body.add_child(columns); columns.add_theme_constant_override("separation",28)
	var showcase := VBoxContainer.new(); columns.add_child(showcase); showcase.custom_minimum_size.x=260
	var stage := PanelContainer.new(); showcase.add_child(stage); stage.add_theme_stylebox_override("panel",surface(Color("3d514e"),8))
	portrait=Portrait.new(); portrait.custom_minimum_size=Vector2(260,230); stage.add_child(portrait)
	tier_picker=OptionButton.new(); showcase.add_child(tier_picker); tier_picker.custom_minimum_size.y=44
	for rank in range(1,7): tier_picker.add_item("Preview tier %d" % rank,rank)
	tier_picker.select(tier-1)
	tier_picker.item_selected.connect(func(index): tier=index+1; portrait.tier=tier; portrait.queue_redraw())
	details=VBoxContainer.new(); columns.add_child(details); details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",12)
	finish_dialog("Back",Callable(),false)
	accept_button.focus_next=NodePath(); accept_button.focus_previous=NodePath()
	refresh_cards(); tabs[kind].grab_focus()

func refresh_cards() -> void:
	for i in range(tabs.size()): tabs[i].button_pressed=i==kind
	for child in card_row.get_children(): card_row.remove_child(child); child.queue_free()
	cards.clear(); previews.clear()
	for row in CatSkins.for_kind(kind):
		var owned := CatSkins.unlocked(game.achievements,row[0])
		var active: bool = CatSkins.selected(game.achievements,kind)==row[0]
		var card := Button.new(); card_row.add_child(card)
		card.custom_minimum_size=Vector2(0,158); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.toggle_mode=true; card.tooltip_text=row[1]+(" · Equipped" if active else (" · Unlocked" if owned else " · Locked"))
		card.pressed.connect(func(): selection=row[0]; refresh_details())
		var contents := VBoxContainer.new(); card.add_child(contents)
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left=6; contents.offset_right=-6; contents.offset_top=6; contents.offset_bottom=-6
		contents.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var icon := Portrait.new(); contents.add_child(icon); icon.custom_minimum_size.y=88
		icon.skin_id=row[0]; icon.locked=not owned; icon.animated=false; previews[row[0]]=icon
		var name_label := label(contents,row[1],16,CREAM); name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var state := label(contents,"Equipped" if active else ("Unlocked" if owned else "Locked"),14,GOLD if active else MUTED)
		state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; state.mouse_filter=Control.MOUSE_FILTER_IGNORE
		cards[row[0]]=card
	refresh_details()

func refresh_details() -> void:
	for child in details.get_children(): details.remove_child(child); child.queue_free()
	for id in cards: cards[id].button_pressed=id==selection
	var row := CatSkins.item(selection)
	var owned := CatSkins.unlocked(game.achievements,selection)
	var active: bool = CatSkins.selected(game.achievements,kind)==selection
	portrait.skin_id=selection; portrait.tier=tier; portrait.locked=not owned; portrait.queue_redraw()
	label(details,row[1],28,CREAM)
	if row[3].is_empty():
		label(details,"Your original look · Always available",18,MINT)
	else:
		var achievement := Achievements.item(row[3])
		label(details,"Unlocked by "+achievement[1] if owned else "Earn "+achievement[1],19,GOLD if owned else CREAM)
		label(details,achievement[2],18,CREAM)
		var progress := ProgressBar.new(); details.add_child(progress); progress.custom_minimum_size.y=10
		progress.show_percentage=false; progress.max_value=achievement[4]
		progress.value=achievement[4] if owned else minf(game.achievements.values.get(achievement[3],0),achievement[4])
		progress.add_theme_stylebox_override("background",surface(INK,5)); progress.add_theme_stylebox_override("fill",surface(MINT,5))
		label(details,game.achievements.progress_text(achievement,game),16,MINT)
	status_label=label(details,"Equipped on every %s in your patrol." % Balance.CATS[kind].name if active else ("Applies to existing and future cats of this type." if owned else "The full look is revealed when you earn it."),16,MUTED)
	equip_button=Button.new(); details.add_child(equip_button)
	equip_button.text="Equipped" if active else ("Equip skin" if owned else "Locked")
	equip_button.disabled=active or not owned; equip_button.custom_minimum_size=Vector2(160,44)
	equip_button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	equip_button.pressed.connect(equip_selection)
	layout_panel.call_deferred()

func equip_selection() -> void:
	if not CatSkins.equip(game.achievements,kind,selection): return
	game.changed.emit(); equipped.emit(); refresh_cards(); cards[selection].grab_focus()
