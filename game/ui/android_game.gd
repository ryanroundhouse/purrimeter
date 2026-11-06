class_name AndroidGarden
extends MobileGarden
## Android's field-first controls. Session remains the authority for every purchase.
const SURFACE := Color("18382a")
const PANEL := Color("152e23")
const HUD := Color("162b22")
const RECRUIT_ICON = preload("res://assets/controls/recruit.svg")
const POWER_ICON = preload("res://assets/powerups/quick.svg")
var safe := Rect2()
var overview := Rect2()
var palette := Rect2()
var recruit_open := false
var palette_horizontal := false
var camera_ready := false
var focused_camera := true
var overlay_regions: Array[Rect2] = []
var notice := ""
var notice_left := 0.0
var mouse_down := false
var panel_title: Label
var footer: BoxContainer
var sell_button: Button

func _init(view: Control) -> void:
	super(view)

func safe_bounds() -> Rect2:
	var result := Rect2(Vector2.ZERO,v.size)
	if GamePlatform.android():
		var pixels := Rect2(DisplayServer.get_display_safe_area())
		if pixels.has_area():
			var local := v.get_screen_transform().affine_inverse()*pixels
			result=result.intersection(local)
	return result.grow(-12)

func focus_zoom() -> float:
	return maxf(1.0,v.size.x/minf(v.size.x,v.size.y))

func layout() -> void:
	field=Rect2(Vector2.ZERO,v.size)
	safe=safe_bounds()
	if not camera_ready or focused_camera:
		zoom=focus_zoom(); camera_ready=true
	var edge := minf(field.size.x,field.size.y)*zoom
	var limit := (Vector2.ONE*edge-field.size).max(Vector2.ZERO)/2
	pan=pan.clamp(-limit,limit)
	transform=Transform2D(0,Vector2.ONE*(edge/704.0),0,field.get_center()+pan-v.BOARD.get_center()*(edge/704.0))
	var side := 80.0 if safe.size.y>=330 else 56.0
	overview=Rect2(safe.end.x-side,safe.position.y+64,side,side)
	palette_horizontal=safe.size.y<324
	palette=Rect2(safe.position.x,safe.end.y-136,safe.size.x,72) if palette_horizontal else Rect2(safe.end.x-212,safe.end.y-260,212,196)
	if is_instance_valid(sheet):
		var width := minf(332,safe.size.x*0.49)
		sheet.position=Vector2(safe.end.x-width,safe.position.y+64)
		var height := maxf(120,safe.size.y-64)
		if panel=="inspect": height=minf(height,236)
		elif panel=="powerups": height=minf(height,420)
		elif panel=="patrol": height=minf(height,280)
		sheet.size=Vector2(width,height)

func draw() -> void:
	layout(); v.buttons.clear(); overlay_regions.clear()
	v.box(field,v.INK)
	v.buttons.append({"rect":field,"id":"board","enabled":true})
	v.draw_set_transform_matrix(transform); v.draw_board()
	v.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The parent clips zoomed artwork; board-header text is hidden by the field clip.
	draw_status()
	draw_wave_controls()
	if zoom>1.02 and not recruit_open and panel.is_empty(): draw_overview()
	pill("Fit" if zoom>1.02 else "Focus",Rect2(safe.position.x,safe.end.y-112,120,48),"mobile_fit",true,false,"fit")
	pill("Powerups",Rect2(safe.position.x,safe.end.y-56,152,56),"mobile_powerups",true,false,"power")
	if not v.read_only:
		pill("Close" if recruit_open else "Recruit",Rect2(safe.end.x-132,safe.end.y-56,132,56),"android_recruit",true,true,"close" if recruit_open else "recruit")
	if recruit_open: draw_recruitment()
	if v.placing>=0 and not v.read_only and not recruit_open: draw_placement()
	if v.game.auto_start_remaining>0:
		var number := str(ceili(v.game.auto_start_remaining))
		var width: float=v.font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,72).x
		text(number,field.get_center()-Vector2(width/2,48),72,v.GOLD)
	if notice_left>0 and not notice.is_empty():
		var rect := Rect2(safe.position.x+148,safe.position.y+64,maxf(120,safe.size.x-320),44)
		v.box(rect,PANEL,12); text_fit(notice,rect.position+Vector2(12,10),rect.size.x-24,14,v.CREAM)

func text(value: String, at: Vector2, size: int, color: Color) -> void:
	v.text(value,at,GamePlatform.ui_font_size(size),color)

func text_fit(value: String, at: Vector2, width: float, size: int, color: Color) -> void:
	v.text_fit(value,at,width,GamePlatform.ui_font_size(size),color)

func label(value: String, color: Color, font_size: int = 18) -> void:
	super(value,color,GamePlatform.ui_font_size(font_size))
	GamePlatform.apply_font(detail.get_child(-1),font_size)

func wave_button_width() -> float:
	return maxf(120,v.font.get_string_size("Resume",HORIZONTAL_ALIGNMENT_LEFT,-1,GamePlatform.ui_font_size(15)).x+54)

func draw_status() -> void:
	var width := minf(300,safe.size.x-wave_button_width()-184)
	var rect := Rect2(safe.position,Vector2(width,52))
	v.box(rect,HUD,26); overlay_regions.append(rect)
	text("Level %d"%v.game.level,rect.position+Vector2(14,3),14,v.CREAM)
	var coins: String=v.game.coins.label()+"c"
	var coin_width: float=v.font.get_string_size(coins,HORIZONTAL_ALIGNMENT_LEFT,-1,GamePlatform.ui_font_size(14)).x
	text_fit(coins,Vector2(maxf(rect.position.x+width*0.55,rect.end.x-14-coin_width),rect.position.y+3),width*0.45-14,14,v.GOLD)
	if v.read_only:
		text_fit("Read-only" if v.remote_connected else "Reconnecting",rect.position+Vector2(14,28),width-28,12,v.MUTED)
	elif v.game.active:
		text_fit("Health %d%%"%ceili(v.game.level_health_fraction()*100),rect.position+Vector2(14,28),width*0.6-14,12,v.MUTED)
		v.bar(Rect2(rect.position.x+width*0.62,rect.position.y+37,width*0.38-14,4),v.game.level_health_fraction(),v.PINK,v.LINE)
	else:
		text_fit("Ready to start",rect.position+Vector2(14,28),width-28,12,v.MUTED)

func draw_wave_controls() -> void:
	var width := wave_button_width()
	var x := safe.end.x-width-168
	var y := safe.position.y
	var running: bool=v.game.active or v.game.auto_start_remaining>0
	var id := "resume" if v.game.paused and running else ("pause" if running else "start")
	var caption := "Resume" if id=="resume" else ("Pause" if id=="pause" else "Start")
	pill(caption,Rect2(x,y,width,48),id,not v.read_only,id=="start","pause" if id=="pause" else "play")
	pill("%d×"%v.game.speed,Rect2(x+width+8,y,48,48),"speed",not v.read_only)
	pill("",Rect2(x+width+64,y,48,48),"auto_start",not v.read_only,v.game.auto_start,"auto")
	pill("",Rect2(x+width+120,y,48,48),"menu",not v.read_only,false,"menu")

func pill(caption: String, rect: Rect2, id: String, enabled: bool = true, lit: bool = false, icon: String = "") -> void:
	var color: Color=v.INK if lit else v.CREAM
	if not enabled: color=v.MUTED
	v.box(rect,v.GOLD if lit and enabled else SURFACE,rect.size.y/2)
	var x := rect.position.x+14
	if not icon.is_empty():
		var texture: Texture2D=RECRUIT_ICON if icon=="recruit" else (POWER_ICON if icon=="power" else ICONS[icon])
		var icon_x := rect.get_center().x-10 if caption.is_empty() else x
		v.draw_texture_rect(texture,Rect2(icon_x,rect.get_center().y-10,20,20),false,color)
		x+=28
	if not caption.is_empty():
		if icon.is_empty():
			var text_width: float=v.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,GamePlatform.ui_font_size(15)).x
			x=rect.get_center().x-text_width/2
		text_fit(caption,Vector2(x,rect.get_center().y-GamePlatform.ui_font_size(15)*0.65),rect.end.x-x-10,15,color)
	if v.focus_id==id: v.draw_rect(rect.grow(2),v.GOLD,false,2)
	v.buttons.append({"rect":rect,"id":id,"enabled":enabled})
	overlay_regions.append(rect)

func draw_recruitment() -> void:
	v.box(palette,PANEL,16); overlay_regions.append(palette)
	for kind in range(3):
		var width := (palette.size.x-32)/3 if palette_horizontal else palette.size.x-16
		var offset := Vector2(8+kind*(width+8),8) if palette_horizontal else Vector2(8,8+kind*60)
		var rect := Rect2(palette.position+offset,Vector2(width,56))
		var chosen: bool=v.placing==kind
		v.box(rect,SURFACE if not chosen else Color("395b3e"),10)
		v.cat_sprite(kind,1,0,Rect2(rect.position+Vector2(4,0),Vector2(52,52)))
		text_fit(Balance.CATS[kind].name,rect.position+Vector2(64,3),rect.size.x-72,16,v.CREAM)
		var cost: Amount=v.game.recruit_cost(kind)
		text(cost.label()+"c",rect.position+Vector2(64,30),14,v.GOLD if v.game.coins.enough(cost) else v.PINK)
		v.buttons.append({"rect":rect,"id":"cat%d"%kind,"enabled":not v.read_only})

func draw_placement() -> void:
	var left := safe.position.x+164
	var width := safe.size.x-312
	var rect := Rect2(left,safe.end.y-104,width,104)
	v.box(rect,PANEL,14); overlay_regions.append(rect)
	var error: String=v.game.placement_error(pending,v.placing) if pending>=0 else "Tap a tile to preview"
	text_fit(Balance.CATS[v.placing].name+" · "+("Ready to recruit" if error.is_empty() else error),rect.position+Vector2(12,8),width-24,14,v.CREAM if error.is_empty() else v.MUTED)
	pill("Confirm · %sc"%v.game.recruit_cost(v.placing).label(),Rect2(left+8,rect.end.y-56,width-72,48),"mobile_confirm",pending>=0 and error.is_empty(),true)
	pill("",Rect2(rect.end.x-56,rect.end.y-56,48,48),"mobile_cancel",true,false,"close")
	if pending>=0:
		var tile: Rect2=transform*Rect2(v.center(pending)-Vector2.ONE*22,Vector2.ONE*44)
		if field.intersects(tile): v.draw_rect(tile.intersection(field),v.GOLD,false,2)

func draw_overview() -> void:
	v.box(overview,PANEL,8); overlay_regions.append(overview)
	var inner := overview.grow(-5)
	v.box(inner,Color("30483c"),3)
	var tile := inner.size/16
	for tower in v.game.towers:
		v.box(Rect2(inner.position+Vector2(tower.cell%16,tower.cell/16)*tile+Vector2.ONE,tile-Vector2.ONE*2),Balance.CATS[tower.kind].color)
	for enemy in v.game.enemies:
		var at: Vector2=inner.position+(v.enemy_position(enemy)+Vector2.ONE*0.5)*tile
		v.draw_circle(at,2,v.PINK)
	var camera: Rect2=transform.affine_inverse()*field
	camera=camera.intersection(v.BOARD)
	var window := Rect2(inner.position+(camera.position-v.BOARD.position)/v.BOARD.size*inner.size,camera.size/v.BOARD.size*inner.size)
	v.draw_rect(window,v.CREAM,false,1.5)
	v.buttons.append({"rect":overview,"id":"android_overview","enabled":true})

func blocks_gesture(point: Vector2) -> bool:
	if is_instance_valid(sheet) and sheet.get_rect().has_point(point): return true
	return overlay_regions.any(func(rect): return rect.has_point(point))

func panel_blocks_input(event: InputEvent) -> bool:
	if not is_instance_valid(sheet) or not sheet.visible: return false
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and touches.has(event.index): return false
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and mouse_down: return false
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
		var point: Vector2=v.get_global_transform_with_canvas().affine_inverse()*event.position
		return sheet.get_rect().has_point(point)
	return event is InputEventKey and event.keycode not in [KEY_SPACE,KEY_ESCAPE]

func handle(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and dismiss_layer():
		v.get_viewport().set_input_as_handled(); return true
	if event is InputEventScreenDrag and board_gesture: focused_camera=false
	if event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION:
		if panel_blocks_input(event): return true
		var point := v.get_local_mouse_position()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and field.has_point(point) and not blocks_gesture(point):
			focused_camera=false; zoom=clampf(zoom*(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.12),1,3); layout(); return true
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: mouse_down=true; origin=point; gesture=false; board_gesture=field.has_point(point) and not blocks_gesture(point)
			else:
				if mouse_down and not gesture: tap(point)
				mouse_down=false
			return true
	if event is InputEventMouseMotion and mouse_down:
		if v.get_local_mouse_position().distance_to(origin)>8: gesture=true
		if gesture and board_gesture: focused_camera=false; pan+=event.relative/v.get_window().content_scale_factor; layout()
		return true
	return super(event)

func tap(point: Vector2) -> void:
	if is_instance_valid(sheet) and sheet.get_rect().has_point(point): return
	# Latest controls win; palette and placement controls are drawn above the field.
	for index in range(v.buttons.size()-1,-1,-1):
		var item: Dictionary=v.buttons[index]
		if item.id!="board" and item.rect.has_point(point):
			if item.enabled:
				if item.id=="android_overview":
					var target: Vector2=v.BOARD.position+(point-overview.position)/overview.size*v.BOARD.size
					pan+=(field.get_center()-transform*target); focused_camera=false; layout()
				else: act(item.id)
			return
	if blocks_gesture(point): return
	if not panel.is_empty(): close_panel(); return
	super(point)

func act(id: String) -> void:
	if v.read_only and id not in ["mobile_fit","mobile_powerups","android_overview"]: return
	match id:
		"android_recruit":
			var was_open := recruit_open
			close_panel(); recruit_open=not was_open
		"mobile_fit":
			focused_camera=zoom<=1.02; zoom=focus_zoom() if focused_camera else 1.0; pan=Vector2.ZERO; layout()
		"mobile_confirm":
			super(id)
			if pending<0: notify("Cat recruited")
			else: notify(v.game.placement_error(pending,v.placing))
		"mobile_powerups":
			v.placing=-1; pending=-1; v.hover=-1; super(id)
		_:
			super(id)
			if id.begins_with("cat"):
				recruit_open=false; close_panel()
			elif id=="auto_start": notify("Auto-start on" if v.game.auto_start else "Auto-start off")

func notify(message: String) -> void:
	notice=message; notice_left=3

func dismiss_layer() -> bool:
	if not panel.is_empty(): close_panel(); v.selected=-1; v.selected_enemy=-1; return true
	if recruit_open: recruit_open=false; return true
	if v.placing>=0 or v.selected>=0 or v.selected_enemy>=0:
		pending=-1; v.hover=-1; v.placing=-1; v.selected=-1; v.selected_enemy=-1; return true
	return false

func close_panel() -> void:
	recruit_open=false
	panel_title=null; footer=null; sell_button=null
	super()

func panel_button(caption: String, callback: Callable, parent: Node, enabled: bool = true, primary: bool = false) -> Button:
	var button := Button.new(); button.text=caption; button.clip_text=true
	button.custom_minimum_size=Vector2(48,48); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.disabled=not enabled; button.pressed.connect(callback); parent.add_child(button)
	GamePlatform.apply_font(button,14)
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new(); style.bg_color=v.GOLD if primary and enabled else SURFACE
		style.set_corner_radius_all(12); style.content_margin_left=8; style.content_margin_right=8; style.content_margin_top=6; style.content_margin_bottom=6
		if state=="hover": style.bg_color=style.bg_color.lightened(0.08)
		button.add_theme_stylebox_override(state,style)
	if primary and enabled:
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button.add_theme_color_override(state,v.INK)
	return button

func open_panel(which: String) -> void:
	close_panel(); panel=which; touches.clear(); mouse_down=false
	sheet=PanelContainer.new(); v.add_child(sheet)
	var style := StyleBoxFlat.new(); style.bg_color=PANEL; style.set_corner_radius_all(16)
	style.content_margin_left=12; style.content_margin_right=12; style.content_margin_top=12; style.content_margin_bottom=12
	sheet.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",8); sheet.add_child(column)
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation",8); column.add_child(header)
	if which=="powerups" or which=="patrol":
		var filter := OptionButton.new(); filter.custom_minimum_size.y=48; filter.size_flags_horizontal=Control.SIZE_EXPAND_FILL; filter.clip_text=true
		for caption in ["Available powers","Owned powers","Patrol & rebirth"]: filter.add_item(caption)
		filter.select(2 if which=="patrol" else (1 if v.powerup_tab=="owned" else 0)); header.add_child(filter)
		filter.item_selected.connect(func(index):
			if index==2: open_panel("patrol")
			else: v.powerup_tab="owned" if index==1 else "available"; open_panel("powerups"))
	else:
		panel_title=Label.new(); panel_title.text="Inspect"; GamePlatform.apply_font(panel_title,18)
		panel_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; panel_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; header.add_child(panel_title)
		if not v.game.tower_at(v.selected).is_empty() and not v.read_only:
			sell_button=panel_button("Sell",func(): v.action("sell"); close_panel(),header)
			sell_button.size_flags_horizontal=Control.SIZE_SHRINK_END; sell_button.custom_minimum_size.x=56
			sell_button.add_theme_color_override("font_color",v.PINK)
	var close := panel_button("",dismiss_layer,header); close.icon=ICONS.close; close.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	close.size_flags_horizontal=Control.SIZE_SHRINK_END; close.tooltip_text="Back to garden"
	scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.follow_focus=true; column.add_child(scroll)
	content=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",8); scroll.add_child(content)
	if which=="powerups":
		var choices := OptionButton.new(); choices.custom_minimum_size.y=48; choices.clip_text=true; content.add_child(choices)
		var ids: Array=v.powerup_list()
		for id in ids: choices.add_item(Powerups.definition(id).name)
		if not ids.is_empty():
			if not v.selected_powerup in ids: v.selected_powerup=ids[0]
			choices.select(ids.find(v.selected_powerup))
			choices.item_selected.connect(func(index): v.selected_powerup=ids[index]; detail_key=""; update_details())
		else: v.selected_powerup=""
	detail=VBoxContainer.new(); detail.add_theme_constant_override("separation",6); content.add_child(detail)
	footer=HBoxContainer.new(); footer.add_theme_constant_override("separation",8); column.add_child(footer)
	detail_key=""; update_details(); layout()

func add_portrait(tower: Dictionary, enemy: Dictionary) -> void:
	var portrait := preload("res://ui/mobile_portrait.gd").new()
	portrait.view=v; portrait.tower=tower; portrait.enemy=enemy
	portrait.custom_minimum_size=Vector2(48,48); portrait.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	detail.add_child(portrait)

func action_button(caption: String, id: String, enabled: bool = true) -> void:
	panel_button(caption,func(): v.action(id); detail_key=""; update_details(),footer,enabled and not v.read_only,id in ["upgrade","powerup_buy"])

func update_details() -> void:
	if not is_instance_valid(sheet) or not is_instance_valid(footer): return
	var tower: Dictionary=v.game.tower_at(v.selected)
	var enemy: Dictionary=v.inspected_enemy()
	var key := JSON.stringify([panel,v.selected,v.selected_enemy,v.selected_powerup,v.game.coins.power,tower,enemy,v.game.powerup_ranks,v.game.kills,v.game.can_rebirth()])
	if key==detail_key: return
	detail_key=key
	for holder in [detail,footer]:
		for child in holder.get_children(): holder.remove_child(child); child.queue_free()
	if panel=="inspect" and not tower.is_empty():
		panel_title.text=Balance.CATS[tower.kind].name+" · Tier %d"%tower.tier
		var summary := detail
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",12); summary.add_child(row)
		detail=VBoxContainer.new(); detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var portrait := preload("res://ui/mobile_portrait.gd").new(); portrait.view=v; portrait.tower=tower; portrait.custom_minimum_size=Vector2(56,56); row.add_child(portrait); row.add_child(detail)
		label("Health %d%% · Range %.1f tiles"%[roundi(tower.hp*100),v.game.cat_stat(tower,"range")],v.MINT,15)
		label("Damage "+Amount.from_power(v.game.cat_stat(tower,"damage_power")).label(),v.CREAM,15)
		label("Sell returns %sc"%v.game.refund(tower).label(),v.MUTED,13)
		detail=summary
		action_button("Upgrade\n%sc"%v.game.upgrade_cost(tower).label() if tower.tier<6 else "Maximum tier","upgrade",tower.tier<6 and v.game.coins.enough(v.game.upgrade_cost(tower)))
		action_button("Repair\n%sc"%v.game.repair_cost(tower).label() if tower.hp<0.999999 else "Fully healed","repair",tower.hp<0.999999 and v.game.coins.enough(v.game.repair_cost(tower)))
	elif panel=="inspect" and not enemy.is_empty():
		var info: Dictionary=Balance.BOSSES[enemy.boss] if enemy.boss>=0 else Balance.FOES[enemy.kind]
		panel_title.text=info.name.capitalize()
		add_portrait({},enemy)
		var health := Amount.from_power(enemy.hp_power)
		label("Health %s / %s"%[health.times(enemy.hp).label(),health.label()],v.MINT,15)
		label("Speed %.2f tiles/s\nTower damage %s HP/s"%[0.0 if enemy.get("stun",0)>0 else v.game.foe_speed(enemy),Amount.of(v.game.foe_dps(enemy)).label()],v.CREAM,15)
		label("\n".join(v.enemy_effects(enemy)),v.GOLD,14)
	elif panel=="inspect":
		panel_title.text="Selection ended"; label("This selection is no longer on the field.",v.MUTED,15)
		if is_instance_valid(sell_button): sell_button.disabled=true
	elif panel=="patrol":
		label("%d rebirths · coins +%s%%"%[v.game.rebirths,Amount.of(v.game.bonus_points).label()],v.GOLD,15)
		panel_button("Draft Collection",func(): v.action("draft_collection"),detail)
		panel_button("Rebirth · choose a reward" if v.game.can_rebirth() else "Rebirth · clear level 5",func(): close_panel(); v.action("rebirth"),detail,v.game.can_rebirth() and not v.read_only)
	elif v.selected_powerup.is_empty(): label("No powerups here yet. Choose Available powers to explore your discoveries.",v.MUTED,15)
	else:
		var id: String=v.selected_powerup
		var definition := Powerups.definition(id); var rank: int=v.game.powerup_rank(id)
		label("Rank %d · %s"%[rank,definition.description],v.CREAM,14)
		label("Now: "+Powerups.effect(id,rank),v.MINT,14)
		if v.game.powerup_complete(id): label("All ranks purchased",v.GOLD,14)
		else:
			label("Next: "+Powerups.effect(id,rank+1),v.CREAM,14)
			label(Powerups.requirement_text(v.game,id,rank+1),v.GOLD,14)
			action_button("Buy · %sc"%Powerups.cost(id,rank).label(),"powerup_buy",v.game.can_buy_powerup(id))
	footer.visible=footer.get_child_count()>0
func process(delta: float) -> void:
	notice_left=maxf(0,notice_left-delta)
	super(delta)
