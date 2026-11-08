class_name AndroidMenus
extends Control
## Android's selected sidebar menus. App owns navigation and confirmation rules.
var app: Control
var paused := false
var panel: PanelContainer
var body: VBoxContainer
var actions: GridContainer
var scroll: ScrollContainer
var hero := Rect2()
var clock := 0.0
var last_safe := Rect2()
var last_font_size := 0
var title_font: FontVariation
var controls := {}
const ICON_PATHS := {
	"people":"M8 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8M2 21v-3a5 5 0 0 1 10 0v3M16 4a4 4 0 0 1 0 8M17 15a5 5 0 0 1 5 5v1",
	"trophy":"M7 3h10v7a5 5 0 0 1-10 0ZM7 5H3v3a4 4 0 0 0 4 4M17 5h4v3a4 4 0 0 1-4 4M12 15v6M7 21h10",
	"cat":"M4 10 3 3l6 4h6l6-4-1 7a8 8 0 1 1-16 0M8 12h.01M16 12h.01M10 17h4",
	"settings":"M4 6h16M4 12h16M4 18h16M8 3v6M16 9v6M10 15v6",
	"download":"M12 3v12M7 10l5 5 5-5M3 16v5h18v-5",
	"upload":"M12 16V4M7 9l5-5 5 5M3 16v5h18v-5",
	"help":"M9 9a3 3 0 1 1 5 2l-2 2v1M12 17h.01M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0",
	"home":"M3 10 12 3l9 7v11h-6v-7H9v7H3Z",
	"trash":"M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7",
}
static var icons := {}

static func icon(id: String) -> Texture2D:
	if id in ["play","close"]: return MobileGarden.ICONS[id]
	if not icons.has(id):
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="'+ICON_PATHS[id]+'" fill="none" stroke="white" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>')
		icons[id]=ImageTexture.create_from_image(image)
	return icons[id]

static func switch_icon(enabled: bool) -> Texture2D:
	var key := "switch_on" if enabled else "switch_off"
	if not icons.has(key):
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="20" viewBox="0 0 32 20"><rect x="1" y="1" width="30" height="18" rx="9" fill="'+('#ffc46b' if enabled else '#3d514e')+'"/><circle cx="'+('22' if enabled else '10')+'" cy="10" r="6" fill="'+('#131c26' if enabled else '#b0c3bd')+'"/></svg>')
		icons[key]=ImageTexture.create_from_image(image)
	return icons[key]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	title_font=FontVariation.new(); title_font.base_font=ThemeDB.fallback_font; title_font.variation_embolden=1.0
	panel=PanelContainer.new(); add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color=AndroidGarden.PANEL; style.set_corner_radius_all(20)
	for side in ["left","right","top","bottom"]: style.set("content_margin_"+side,16)
	panel.add_theme_stylebox_override("panel",style)
	body=VBoxContainer.new(); body.add_theme_constant_override("separation",8); panel.add_child(body)
	if paused: build_pause()
	else: build_main()
	resized.connect(layout); layout()

func safe_bounds() -> Rect2:
	var bounds := Rect2(Vector2.ZERO,size)
	if GamePlatform.native_mobile():
		bounds=bounds.intersection(GamePlatform.safe_area_in(self))
	return bounds.grow(-12)

func layout() -> void:
	var safe := safe_bounds()
	last_safe=safe; last_font_size=GamePlatform.ui_font_size(14)
	var width := minf(510,maxf(340,safe.size.x*0.46))
	width=minf(width,safe.size.x*0.62)
	var height := minf(safe.size.y,560 if paused else 440)
	panel.position=Vector2(safe.end.x-width,safe.position.y+(safe.size.y-height)/2)
	panel.custom_maximum_size=Vector2(width,height)
	panel.size=Vector2(width,height)
	hero=Rect2(safe.position,Vector2(panel.position.x-safe.position.x-16,safe.size.y))
	actions.columns=1 if width<460 and GamePlatform.ui_font_size(14)>16 else 2
	queue_redraw()

func action(parent: Node, id: String, caption: String, callback: Callable, primary := false, symbol := "", quiet := false) -> Button:
	var button: Button=app.button(caption,callback,primary)
	button.name=id; controls[id]=button
	button.mouse_filter=Control.MOUSE_FILTER_PASS
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	GamePlatform.apply_font(button,15 if primary else 14)
	button.custom_minimum_size=Vector2(48,48)
	button.tooltip_text=caption
	if not symbol.is_empty():
		button.icon=icon(symbol); button.add_theme_constant_override("icon_max_width",20)
		button.add_theme_constant_override("h_separation",8); button.expand_icon=false
		for state in ["normal","hover","pressed","focus"]: button.add_theme_color_override("icon_"+state+"_color",app.INK if primary else app.CREAM)
	for state in ["normal","hover","pressed","disabled"]:
		var style: StyleBoxFlat=app.theme.get_stylebox(state,"Button").duplicate()
		style.set_corner_radius_all(24 if primary else 12)
		style.content_margin_left=10; style.content_margin_right=10; style.content_margin_top=6; style.content_margin_bottom=6
		if quiet: style.bg_color=Color.TRANSPARENT if state=="normal" else AndroidGarden.SURFACE
		elif primary: style.bg_color=app.GOLD.lightened(0.08) if state=="hover" else app.GOLD
		button.add_theme_stylebox_override(state,style)
	var focus: StyleBoxFlat=app.theme.get_stylebox("focus","Button").duplicate()
	focus.set_corner_radius_all(24 if primary else 12); button.add_theme_stylebox_override("focus",focus)
	parent.add_child(button)
	return button

func note(parent: Node, value: String, font_size := 13, color := Color("b0c3bd")) -> Label:
	var label: Label=app.label(value,font_size,color); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label); return label

func scroller() -> VBoxContainer:
	scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.follow_focus=true
	body.add_child(scroll)
	var content := VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",8); scroll.add_child(content)
	return content

func grid(parent: Node) -> GridContainer:
	var result := GridContainer.new(); result.columns=2; result.add_theme_constant_override("h_separation",8); result.add_theme_constant_override("v_separation",8); parent.add_child(result); return result

func updates() -> void:
	if paused: app.close_pause()
	app.show_updates()
	if app.updater.state in ["idle","error","current","newer"]: app.updater.check(app.network.address)

func build_main() -> void:
	var content := scroller()
	if not app.notice.is_empty(): note(content,app.notice,14,app.GOLD)
	action(content,"single","Single player",func(): app.show_game(false),true,"play")
	note(content,"Your garden · %s" % app.local_view.game.progress_label())
	action(content,"multiplayer","Multiplayer",func(): app.notice=""; app.show_browser(); app.network.connect_server(),false,"people")
	note(content,"Up to 3 gardeners · Live fields and chat",12)
	actions=grid(content)
	action(actions,"achievements","Achievements",app.open_achievements,false,"trophy")
	action(actions,"skins","Cat Skins",app.open_skins,false,"cat")
	# Long utility names stay full-width on small phones and enlarged type.
	action(content,"settings","Connection settings",func(): app.show_settings("menu"),false,"settings",true)
	action(content,"updates","Check for updates",updates,false,"download",true)
	app.update_note=note(content,app.updater.message if app.updater!=null else "",12)
	content.add_child(HSeparator.new())
	var reset := action(content,"reset","Reset all progress",app.confirm_reset_progress,false,"trash",true)
	reset.add_theme_color_override("font_color",app.PINK); reset.add_theme_color_override("icon_normal_color",app.PINK)

func build_pause() -> void:
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation",8); body.add_child(header)
	var title: Label=app.label("Garden paused",22); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(title)
	var close := action(header,"close","",app.close_pause,false,"close",true); close.size_flags_horizontal=Control.SIZE_SHRINK_END
	close.tooltip_text="Close menu · stay paused"
	var resume := action(body,"resume","Resume",func(): app.close_pause(); app.local_view.game.paused=false,true,"play")
	var content := scroller(); actions=grid(content)
	var route := action(actions,"route","",app.local_view.action.bind("route")); route.toggle_mode=true
	var sound := action(actions,"sound","",app.local_view.action.bind("sound")); sound.toggle_mode=true
	var refresh := func():
		route.text="Route on" if app.local_view.route_on else "Route off"; route.button_pressed=app.local_view.route_on
		sound.text="Sound off" if app.local_view.audio.muted else "Sound on"; sound.button_pressed=not app.local_view.audio.muted
		for toggle in [route,sound]:
			toggle.icon=switch_icon(toggle.button_pressed); toggle.icon_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			toggle.alignment=HORIZONTAL_ALIGNMENT_LEFT; toggle.add_theme_constant_override("icon_max_width",32)
	refresh.call(); route.pressed.connect(refresh); sound.pressed.connect(refresh)
	action(actions,"achievements","Achievements",app.open_achievements,false,"trophy")
	action(actions,"skins","Cat Skins",app.open_skins,false,"cat")
	action(actions,"export","Export garden",func(): app.close_pause(); app.local_view.action("export"),false,"upload")
	action(actions,"import","Import garden",func(): app.close_pause(); app.local_view.action("import"),false,"download")
	action(actions,"help","How to play",func(): app.close_pause(); app.local_view.action("help"),false,"help")
	action(actions,"updates","Updates",updates,false,"download")
	var fresh := action(actions,"new","New garden",func(): app.close_pause(); app.local_view.action("new"),false,"trash")
	fresh.add_theme_color_override("font_color",app.PINK); fresh.add_theme_color_override("icon_normal_color",app.PINK)
	action(actions,"main","Main menu",func():
		app.close_pause(); app.confirm_main_menu(),false,"home")
	if app.screen=="multiplayer":
		note(content,"Other gardeners can keep playing.",12)
		action(content,"offline","Continue offline",func(): app.close_pause(); app.network.leave_game(); app.show_game(false))
	action(body,"stay_paused","Close menu · stay paused",app.close_pause,false,"",true)
	if not GamePlatform.touch(): resume.grab_focus()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock+=minf(delta,0.1)
	if safe_bounds()!=last_safe or GamePlatform.ui_font_size(14)!=last_font_size: layout()
	if not paused: queue_redraw()

func _draw() -> void:
	if paused:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.05,0.12,0.09,0.23)); return
	# The same garden tile vocabulary as the playing field, without a staged save.
	var edge := 56.0
	for y in range(ceili(size.y/edge)):
		for x in range(ceili(size.x/edge)):
			var at := Vector2(x,y)*edge
			draw_rect(Rect2(at,Vector2.ONE*edge),Color("30483c") if (x+y)%2==0 else Color("2d4439"))
			if (x*13+y*7)%9==0:
				draw_rect(Rect2(at+Vector2(13,35),Vector2(3,7)),Color("48634a")); draw_rect(Rect2(at+Vector2(18,31),Vector2(3,10)),Color("48634a"))
	if hero.size.x<=0: return
	var font_size := mini(GamePlatform.ui_font_size(48),int(hero.size.x/7.3))
	var title := "PURRIMETER"
	var width := title_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(title_font,Vector2(hero.get_center().x-width/2,hero.position.y+hero.size.y*0.23),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,app.CREAM)
	var subtitle := "The Garden Guard"; var sub_size := mini(GamePlatform.ui_font_size(18),int(hero.size.x/10))
	width=ThemeDB.fallback_font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,sub_size).x
	draw_string(ThemeDB.fallback_font,Vector2(hero.get_center().x-width/2,hero.position.y+hero.size.y*0.23+sub_size+8),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,sub_size,app.CREAM)
	var cat_size := minf(hero.size.x*0.45,hero.size.y*0.38)
	for item in [{"kind":0,"at":Vector2(0.25,0.75),"tier":1},{"kind":1,"at":Vector2(0.75,0.71),"tier":2},{"kind":2,"at":Vector2(0.5,0.96),"tier":2}]:
		var at: Vector2=hero.position+hero.size*item.at
		CatSkinArt.draw(self,app.local_view.game.skin_id(item.kind),item.tier,int(clock*3)%4,Rect2(at-Vector2(cat_size/2,cat_size),Vector2.ONE*cat_size))
