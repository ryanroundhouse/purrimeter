extends "res://ui/patrol_dialog.gd"
## A native, keyboard-accessible collection inside the established garden dialog.
var game: Session
var filter_name := "All"
var selection := "first"
var list: VBoxContainer
var details: VBoxContainer
var filters: Dictionary = {}
var entries: Dictionary = {}

func open(session: Session) -> void:
	game=session
	begin_dialog("Achievements", "%d / 30 earned · Yours to keep across every garden" % game.achievements.earned.size(),Vector2(1050,770))
	body.add_theme_constant_override("separation",16)
	var tabs := HBoxContainer.new(); body.add_child(tabs)
	tabs.add_theme_constant_override("separation",12)
	filters.clear()
	for name in ["All","In Progress","Earned"]:
		var tab := Button.new(); tab.text=name; tab.custom_minimum_size=Vector2(150,44)
		tab.toggle_mode=true; tab.button_pressed=name==filter_name
		tab.pressed.connect(func(): filter_name=name; refresh_list())
		tabs.add_child(tab); filters[name]=tab
	var columns := HBoxContainer.new(); body.add_child(columns)
	columns.add_theme_constant_override("separation",28)
	var list_scroll := ScrollContainer.new(); columns.add_child(list_scroll)
	list_scroll.custom_minimum_size=Vector2(350,380)
	list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; list_scroll.follow_focus=true
	list=VBoxContainer.new(); list_scroll.add_child(list)
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",6)
	details=VBoxContainer.new(); columns.add_child(details)
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",16)
	finish_dialog("Back",Callable(),false)
	# Keep native focus traversal through filters, entries and Back.
	accept_button.focus_next=NodePath(); accept_button.focus_previous=NodePath()
	refresh_list()
	filters[filter_name].grab_focus()

func refresh_list() -> void:
	for name in filters: filters[name].button_pressed=name==filter_name
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	entries.clear()
	var group := ""
	for row in Achievements.ITEMS:
		var earned: bool = game.achievements.earned.has(row[0])
		if filter_name=="Earned" and not earned: continue
		if filter_name=="In Progress" and earned: continue
		if group!=row[5]:
			group=row[5]; label(list,group,16,MINT)
		var entry := Button.new(); entry.text=row[1]+("  ·  Earned" if earned else "")
		entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
		entry.add_theme_font_size_override("font_size",17)
		entry.custom_minimum_size.y=48; entry.toggle_mode=true
		entry.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		entry.tooltip_text=row[2]
		entry.pressed.connect(func(): selection=row[0]; refresh_details())
		list.add_child(entry); entries[row[0]]=entry
	if not entries.has(selection): selection=str(entries.keys()[0]) if not entries.is_empty() else ""
	refresh_details()

func refresh_details() -> void:
	for child in details.get_children(): details.remove_child(child); child.queue_free()
	for id in entries: entries[id].button_pressed=id==selection
	if selection.is_empty():
		label(details,"Your first badge is waiting" if filter_name=="Earned" else "The collection is complete",26,CREAM)
		label(details,"Choose All to explore the challenges." if filter_name=="Earned" else "You have earned all 30 achievements. Your garden has quite a story.")
		return
	var row := Achievements.item(selection)
	var earned: bool = game.achievements.earned.has(selection)
	var icon := TextureRect.new(); details.add_child(icon)
	var path: String = "res://assets/powerups/"+row[6]+".svg"
	icon.texture=load(path) if ResourceLoader.exists(path) else load("res://assets/powerups/training.svg")
	icon.custom_minimum_size=Vector2(64,64); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	icon.modulate=GOLD if earned else MINT
	label(details,row[1],28,CREAM)
	label(details,row[2],19,CREAM)
	var progress := ProgressBar.new(); details.add_child(progress)
	progress.custom_minimum_size.y=10; progress.show_percentage=false; progress.max_value=row[4]
	progress.value=row[4] if earned else minf(game.achievements.values.get(row[3],0),row[4])
	progress.add_theme_stylebox_override("background",surface(INK,5))
	progress.add_theme_stylebox_override("fill",surface(GOLD if earned else MINT,5))
	label(details,game.achievements.progress_text(row,game),18,GOLD if earned else MINT)
	if row[5]=="Tactics" and not earned:
		label(details,"Powerups, training and tactical pause are allowed. Restrictions apply to the whole attempt.",16,MUTED)
	elif not earned and row[3] in ["crew","dream","toys","school"]:
		label(details,"Build this collection in one garden. Best progress is remembered; separate gardens cannot be combined.",16,MUTED)
	layout_panel.call_deferred()
