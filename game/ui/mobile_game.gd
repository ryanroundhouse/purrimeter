class_name MobileGarden
extends RefCounted
## Phone layout and gestures; combat and purchases stay in the shared Session.
const ICONS = {
	"pause": preload("res://assets/controls/pause.svg"),
	"play": preload("res://assets/controls/play.svg"),
	"menu": preload("res://assets/controls/menu.svg"),
	"auto": preload("res://assets/controls/auto.svg"),
	"close": preload("res://assets/controls/close.svg"),
	"fit": preload("res://assets/controls/fit.svg"),
}
var v: Control
var field := Rect2()
var transform := Transform2D.IDENTITY
var zoom := 1.0
var pan := Vector2.ZERO
var touches := {}
var gesture := false
var origin := Vector2.ZERO
var board_gesture := false
var pending := -1
var panel := ""
var sheet: PanelContainer
var content: VBoxContainer
var scroll: ScrollContainer
var detail: VBoxContainer
var refresh_clock := 0.0
var detail_key := ""

func _init(view: Control) -> void:
	v=view

func layout() -> void:
	var landscape := v.size.x>v.size.y
	# Reserve both wave and placement rows so selecting a cat never shifts the field.
	var edge := minf(v.size.y-48,v.size.x-244) if landscape else minf(v.size.x-24,v.size.y-390)
	edge=maxf(100,edge)
	field=Rect2(Vector2(8,40) if landscape else Vector2((v.size.x-edge)/2,108),Vector2.ONE*edge)
	var scale_factor := edge/704.0*zoom
	pan=pan.clamp(Vector2.ONE*(-edge*(zoom-1)/2),Vector2.ONE*(edge*(zoom-1)/2))
	transform=Transform2D(0,Vector2.ONE*scale_factor,0,field.get_center()+pan-v.BOARD.get_center()*scale_factor)
	if is_instance_valid(sheet):
		sheet.position=Vector2(8,108 if not landscape else 60)
		sheet.size=Vector2(v.size.x-16,v.size.y-sheet.position.y-8)

func draw() -> void:
	layout(); v.buttons.clear(); v.box(Rect2(Vector2.ZERO,v.size),v.INK)
	v.buttons.append({"rect":field,"id":"board","enabled":true})
	v.draw_set_transform_matrix(transform); v.draw_board()
	if v.game.auto_start_remaining>0:
		var number := str(ceili(v.game.auto_start_remaining))
		v.text(number,v.BOARD.get_center()-Vector2(40,75),120,v.GOLD)
	v.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Mask everything outside the field, including zoomed sprites/range circles.
	v.box(Rect2(0,0,v.size.x,field.position.y),v.INK)
	v.box(Rect2(0,field.end.y,v.size.x,v.size.y-field.end.y),v.INK)
	v.box(Rect2(0,field.position.y,field.position.x,field.size.y),v.INK)
	v.box(Rect2(field.end.x,field.position.y,v.size.x-field.end.x,field.size.y),v.INK)
	v.text_fit(GardenLevels.level_name(v.game.garden_level),Vector2(12,4),v.size.x*0.55,20,v.MINT)
	v.text_fit("Level %d · Wave %d%s" % [v.game.garden_level,v.game.level," / %d" % v.game.wave_limit() if v.game.wave_limit()>0 else ""],Vector2(12,29),v.size.x*0.55,14,v.MUTED)
	v.right_text(v.game.coins.label()+" coins",Vector2(v.size.x-12,10),20,v.GOLD)
	var landscape := v.size.x>v.size.y
	var header_y := 56.0 if not landscape else 8.0
	var header_x := 12.0 if not landscape else field.end.x+16
	var header_w := v.size.x-24 if not landscape else v.size.x-header_x-12
	if landscape:
		v.box(Rect2(header_x,0,header_w+12,58),v.INK)
		v.right_text(v.game.coins.label()+"c",Vector2(field.end.x,12),20,v.GOLD)
	var w := (header_w-16)/3
	icon_button("play" if v.game.paused else "pause",Rect2(header_x,header_y,w,44),"pause",not v.read_only)
	v.button("%d×"%v.game.speed,Rect2(header_x+w+8,header_y,w,44),"speed",not v.read_only)
	icon_button("menu",Rect2(header_x+2*(w+8),header_y,w,44),"menu",not v.read_only)
	var x := field.end.x+16 if landscape else 12.0
	var y := 60.0 if landscape else field.end.y+8
	var width := v.size.x-x-12 if landscape else v.size.x-24
	w=(width-16)/3
	for kind in range(3):
		var r := Rect2(x+kind*(w+8),y,w,60)
		v.box(r,v.PANEL if v.placing!=kind else Color("304b40"),6)
		v.cat_sprite(kind,1,0,Rect2(r.position+Vector2((w-36)/2,0),Vector2(36,34)))
		v.text_fit(v.game.recruit_cost(kind).label()+"c",r.position+Vector2(10,36),w-14,16,v.GOLD)
		if v.placing==kind: v.draw_rect(r,v.MINT,false,2)
		v.buttons.append({"rect":r,"id":"cat%d"%kind,"enabled":not v.read_only and not v.game.completed})
	y+=68
	v.button("Level complete" if v.game.completed else ("Resume wave" if v.game.active and v.game.paused else ("Wave in progress" if v.game.active else "Start wave %d"%v.game.level)),Rect2(x,y,width-52,44),"resume" if v.game.active and v.game.paused else "start",not v.read_only and (not v.game.active or v.game.paused),true)
	icon_button("auto",Rect2(x+width-44,y,44,44),"auto_start",not v.read_only,v.game.auto_start)
	y+=52
	if v.placing>=0:
		v.button("Confirm · %sc"%v.game.recruit_cost(v.placing).label(),Rect2(x,y,width-52,44),"mobile_confirm",pending>=0,true)
		icon_button("close",Rect2(x+width-44,y,44,44),"mobile_cancel")
		y+=52
	v.button("Powerups",Rect2(x,y,(width-52)*0.52,44),"mobile_powerups")
	v.button("Rebirth",Rect2(x+(width-52)*0.52+8,y,(width-52)*0.48-8,44),"rebirth",not v.read_only and v.game.can_rebirth())
	icon_button("fit",Rect2(x+width-44,y,44,44),"mobile_fit")
	y+=50
	if v.game.active:
		v.bar(Rect2(x,y,width,5),v.game.level_health_fraction(),v.PINK,v.LINE)
		y+=9
	v.wrapped(("Waiting for garden…" if v.remote_revision<0 else ("Player reconnecting…" if not v.remote_connected else "Read-only garden")) if v.read_only else ("Tap a tile, then Confirm" if v.placing>=0 and pending<0 else v.status),Vector2(x,y),width,16,v.MUTED)
	if pending>=0 and v.placing>=0:
		var rect := transform*Rect2(v.center(pending)-Vector2.ONE*22,Vector2.ONE*44)
		if field.encloses(rect): v.draw_rect(rect,v.GOLD,false,3)

func icon_button(icon: String, rect: Rect2, id: String, enabled: bool = true, lit: bool = false) -> void:
	v.button("",rect,id,enabled,lit)
	var color = v.INK if lit and enabled else (v.CREAM if enabled else v.DISABLED)
	v.draw_texture_rect(ICONS[icon],Rect2(rect.get_center()-Vector2(12,12),Vector2(24,24)),false,color)

func panel_blocks_input(_event: InputEvent) -> bool:
	return is_instance_valid(sheet) and sheet.visible

func blocks_gesture(_point: Vector2) -> bool:
	return false

func dismiss_layer() -> bool:
	if not panel.is_empty(): close_panel(); return true
	return false

func handle(event: InputEvent) -> bool:
	if panel_blocks_input(event): return true
	if event is InputEventScreenTouch:
		var p: Vector2=v.get_global_transform_with_canvas().affine_inverse()*event.position
		if event.pressed:
			touches[event.index]=p
			if touches.size()==1:
				origin=p; gesture=false; board_gesture=field.has_point(p) and not blocks_gesture(p)
			board_gesture=board_gesture and field.has_point(p) and not blocks_gesture(p)
			if touches.size()>1: gesture=true
		else:
			if not touches.has(event.index): return true
			touches.erase(event.index)
			if touches.is_empty() and not gesture and not event.canceled and p.distance_to(origin)<=8: tap(p)
		return true
	if event is InputEventScreenDrag:
		var p: Vector2=v.get_global_transform_with_canvas().affine_inverse()*event.position
		if not touches.has(event.index): return true
		var old: Vector2=touches[event.index]
		if touches.size()==2:
			var other: Vector2=touches[touches.keys()[0] if touches.keys()[1]==event.index else touches.keys()[1]]
			if board_gesture:
				var before := zoom
				zoom=clampf(zoom*p.distance_to(other)/maxf(1,old.distance_to(other)),1,3)
				var midpoint := (old+other)/2
				pan=(pan+field.get_center()-midpoint)*(zoom/before)-(field.get_center()-midpoint)+(p-old)/2
			gesture=true
		elif p.distance_to(origin)>8 or gesture:
			gesture=true
			if board_gesture: pan+=p-old
		touches[event.index]=p; layout(); return true
	if event is InputEventMouseButton:
		if event.device==InputEvent.DEVICE_ID_EMULATION: return true
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT: tap(v.get_local_mouse_position()); return true
	return event is InputEventMouseMotion

func tap(point: Vector2) -> void:
	for b in v.buttons:
		if b.id!="board" and b.rect.has_point(point):
			if b.enabled: act(b.id)
			return
	if not field.has_point(point): return
	var original: Vector2=transform.affine_inverse()*point
	var cell: int=v.cell_at(original)
	if v.placing>=0 and not v.read_only:
		pending=cell; v.hover=cell; v.status=v.game.placement_error(cell,v.placing)
	else:
		v.interact_cell(cell,original)
		if v.selected>=0 or v.selected_enemy>=0: open_panel("inspect")

func act(id: String) -> void:
	match id:
		"mobile_confirm":
			if pending>=0 and v.placing>=0:
				var error: String=v.game.placement_error(pending,v.placing)
				if error.is_empty():
					if v.game.build(v.placing,pending): v.status="Cat recruited."; pending=-1; v.hover=-1
				else: v.status=error
		"mobile_cancel": pending=-1; v.placing=-1; v.hover=-1
		"mobile_powerups": v.selected=-1; v.selected_enemy=-1; open_panel("powerups")
		"mobile_fit": zoom=1; pan=Vector2.ZERO
		_:
			v.action(id)
			if id.begins_with("cat"): pending=-1; v.hover=-1

func close_panel() -> void:
	panel=""
	if is_instance_valid(sheet): sheet.hide(); sheet.queue_free()
	sheet=null

func open_panel(which: String) -> void:
	close_panel(); panel=which
	sheet=PanelContainer.new(); v.add_child(sheet)
	var style := StyleBoxFlat.new(); style.bg_color=v.PANEL; style.set_corner_radius_all(8)
	style.content_margin_left=12; style.content_margin_right=12; style.content_margin_top=12; style.content_margin_bottom=12
	sheet.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); sheet.add_child(box)
	var close := Button.new(); close.text="Back to garden"; close.custom_minimum_size.y=44; close.pressed.connect(close_panel); box.add_child(close)
	scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	content=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",12); scroll.add_child(content)
	if which=="powerups":
		var collection := Button.new(); collection.text="Draft Collection"; collection.custom_minimum_size.y=44; content.add_child(collection)
		collection.pressed.connect(func(): v.action("draft_collection"))
		var tabs := HBoxContainer.new(); content.add_child(tabs)
		for mode in ["available","owned"]:
			var b := Button.new(); b.text=mode.capitalize(); b.custom_minimum_size.y=44; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tabs.add_child(b)
			b.pressed.connect(func(): v.powerup_tab=mode; open_panel("powerups"))
		var choices := OptionButton.new(); choices.custom_minimum_size.y=44; choices.clip_text=true; content.add_child(choices)
		var ids: Array=v.powerup_list()
		for id in ids: choices.add_item(Powerups.definition(id).name)
		if not ids.is_empty():
			if not v.selected_powerup in ids: v.selected_powerup=ids[0]
			choices.select(ids.find(v.selected_powerup))
			choices.item_selected.connect(func(index): v.selected_powerup=ids[index]; detail_key=""; update_details())
		else: v.selected_powerup=""
	detail=VBoxContainer.new(); detail.add_theme_constant_override("separation",12); content.add_child(detail)
	detail_key=""; update_details(); layout()

func label(value: String, color: Color, font_size: int = 18) -> void:
	var l := Label.new(); l.text=value; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.add_theme_font_size_override("font_size",font_size); l.add_theme_color_override("font_color",color); detail.add_child(l)

func action_button(value: String, id: String, enabled: bool = true) -> void:
	var b := Button.new(); b.text=value; b.custom_minimum_size.y=48; b.disabled=not enabled or v.read_only or v.game.completed; detail.add_child(b)
	b.pressed.connect(func(): v.action(id); detail_key=""; update_details())

func update_details() -> void:
	if not is_instance_valid(sheet): return
	var tower: Dictionary=v.game.tower_at(v.selected)
	var enemy: Dictionary=v.inspected_enemy()
	# Rebuild only on relevant changes; preserve scrolling between refreshes.
	var key := JSON.stringify([v.selected,v.selected_enemy,v.selected_powerup,v.game.coins.power,tower,enemy,v.game.powerup_ranks,v.game.kills])
	if key==detail_key: return
	detail_key=key
	for c in detail.get_children(): detail.remove_child(c); c.queue_free()
	if panel=="inspect" and not tower.is_empty():
		add_portrait(tower,{})
		label(Balance.CATS[tower.kind].name+" · Tier %d"%tower.tier,v.CREAM,24)
		label("Health %d%% · Damage %s\nRange %.1f tiles"%[roundi(tower.hp*100),Amount.from_power(v.game.cat_stat(tower,"damage_power")).label(),v.game.cat_stat(tower,"range")],v.MINT)
		action_button("Upgrade · %sc"%v.game.upgrade_cost(tower).label() if tower.tier<6 else "Maximum tier","upgrade",tower.tier<6 and v.game.coins.enough(v.game.upgrade_cost(tower)))
		action_button("Repair · %sc"%v.game.repair_cost(tower).label(),"repair",tower.hp<0.999999 and v.game.coins.enough(v.game.repair_cost(tower)))
		action_button("Sell · +%sc"%v.game.refund(tower).label(),"sell")
	elif panel=="inspect" and not enemy.is_empty():
		var info: Dictionary=Balance.BOSSES[enemy.boss] if enemy.boss>=0 else Balance.FOES[enemy.kind]
		add_portrait({},enemy)
		label(info.name,v.CREAM,24)
		var health := Amount.from_power(enemy.hp_power)
		label("Health %s / %s"%[health.times(enemy.hp).label(),health.label()],v.MINT)
		label("Speed %.2f tiles/s\nTower damage %s HP/s"%[0.0 if enemy.get("stun",0)>0 else v.game.foe_speed(enemy),Amount.of(v.game.foe_dps(enemy)).label()],v.MUTED)
		label("\n".join(v.enemy_effects(enemy)),v.GOLD)
	elif panel=="inspect":
		label("This selection is no longer on the field.",v.MUTED)
	elif v.selected_powerup.is_empty(): label("No powerups here yet. Choose Available to explore your discoveries.",v.MUTED)
	else:
		var id: String=v.selected_powerup
		var d := Powerups.definition(id); var rank: int=v.game.powerup_rank(id)
		label(d.name+" · Rank %d"%rank,v.CREAM,24)
		label(d.description,v.MUTED)
		label("Now: "+Powerups.effect(id,rank),v.MINT)
		if v.game.powerup_complete(id): label("All ranks purchased",v.GOLD)
		else:
			label("Next: "+Powerups.effect(id,rank+1),v.CREAM)
			label(Powerups.requirement_text(v.game,id,rank+1),v.GOLD)
			action_button("Buy · %sc"%Powerups.cost(id,rank).label(),"powerup_buy",v.game.can_buy_powerup(id))

func process(delta: float) -> void:
	refresh_clock+=delta
	if refresh_clock>=0.4: refresh_clock=0; update_details()

func add_portrait(tower: Dictionary, enemy: Dictionary) -> void:
	var portrait := preload("res://ui/mobile_portrait.gd").new()
	portrait.view=v; portrait.tower=tower; portrait.enemy=enemy
	portrait.custom_minimum_size=Vector2(88,88); portrait.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	detail.add_child(portrait)
