extends Control
## Non-blocking, real-time celebration. Hiding freezes its duration and queue.
var book: Achievements
var audio: GameSound
var ids: Array = []
var clock := 0.0
var heading := ""
var caption := ""
var allowed := false
var persist := Callable()
var skin_ids: Array = []
var thumbnail := ""

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	position=Vector2(104,88); size=Vector2(552,110)
	z_index=10
	hide()

func advance(delta: float, can_show: bool) -> void:
	if get_parent().has_method("compact") and get_parent().compact():
		position=Vector2(8,104); size=Vector2(get_parent().size.x-16,110)
	else: position=Vector2(104,88); size=Vector2(552,110)
	allowed=can_show
	if not can_show or book==null:
		hide(); return
	if ids.is_empty() and skin_ids.is_empty():
		if book.pending.is_empty() and CatSkins.unseen_rewards(book).is_empty(): hide(); return
		if book.pending.is_empty():
			skin_ids=CatSkins.unseen_rewards(book)
			heading="%d cat skin%s unlocked" % [skin_ids.size(),"" if skin_ids.size()==1 else "s"]
			caption="Your achievements earned new looks. Open Cat Skins."
		elif not book.summary.is_empty():
			ids=book.summary.duplicate()
			heading="%d achievement%s added" % [ids.size(),"" if ids.size()==1 else "s"]
			caption="Your collection is ready in the Achievements menu."
			skin_ids=CatSkins.unseen_rewards(book)
			if not skin_ids.is_empty(): caption="%d cat skin%s unlocked · Open Cat Skins to equip" % [skin_ids.size(),"" if skin_ids.size()==1 else "s"]
		else:
			ids=[book.pending[0]]
			heading=Achievements.item(ids[0])[1]
			caption="Achievement earned · %d / 30" % book.earned.size()
			var skin := CatSkins.reward(ids[0])
			if not skin.is_empty():
				skin_ids=[skin]; caption=CatSkins.item(skin)[1]+" unlocked · Cat Skins"
		thumbnail=skin_ids[0] if skin_ids.size()==1 else ""
		clock=0.0; audio.play("achievement")
	clock+=minf(delta,0.1)
	if clock>=4.0:
		book.acknowledge(ids); ids.clear()
		for skin in skin_ids:
			if skin not in book.seen_skins: book.seen_skins.append(skin)
		skin_ids.clear(); thumbnail=""
		if persist.is_valid(): persist.call()
		hide(); return
	show(); queue_redraw()

func _draw() -> void:
	var enter := 1.0-pow(1.0-clampf(clock/0.35,0,1),3)
	var leave := clampf((4.0-clock)/0.3,0,1)
	modulate.a=minf(enter,leave)
	var offset := Vector2(0,-12*(1-enter))
	var frame := StyleBoxFlat.new(); frame.bg_color=Color("202e3a")
	frame.border_color=Color("ffc46b"); frame.set_border_width_all(2); frame.set_corner_radius_all(8)
	draw_style_box(frame,Rect2(offset,size))
	var gold := Color("ffc46b"); var center := Vector2(46,50)+offset
	if not thumbnail.is_empty(): CatSkinArt.draw(self,thumbnail,1,0,Rect2(Vector2(4,5)+offset,Vector2(80,95)))
	# Geometric garden medal, with one short radial sparkle on arrival.
	if thumbnail.is_empty():
		draw_colored_polygon(PackedVector2Array([center+Vector2(-13,12),center+Vector2(-18,36),center+Vector2(0,27),center+Vector2(18,36),center+Vector2(13,12)]),Color("89dfb5"))
		draw_circle(center,23,gold,false,2.5,true)
	var star := PackedVector2Array()
	for i in range(10):
		var angle := -PI/2+i*PI/5
		star.append(center+Vector2(cos(angle),sin(angle))*(15 if i%2==0 else 7))
	if thumbnail.is_empty(): draw_colored_polygon(star,gold)
	if clock<0.7:
		for i in range(8):
			var dir := Vector2.from_angle(i*PI/4)
			draw_line(center+dir*(27+clock*10),center+dir*(31+clock*14),Color(gold,1-clock/0.7),2,true)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(88,47)+offset,heading,HORIZONTAL_ALIGNMENT_LEFT,size.x-96,18 if size.x<500 else 24,Color("f4edd7"))
	draw_string(font,Vector2(88,76)+offset,caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-96,16,Color("89dfb5"))
