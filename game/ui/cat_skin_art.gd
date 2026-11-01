class_name CatSkinArt
extends RefCounted
static var textures: Dictionary = {}
static var alpha_maps: Dictionary = {}
static var outlines: Dictionary = {}

static func frame_outline(id: String, tier: int, frame: int) -> Dictionary:
	var key := "%s:%d:%d" % [id,tier,frame]
	if outlines.has(key): return outlines[key]
	if not alpha_maps.has(id):
		var bitmap := BitMap.new(); bitmap.create_from_image_alpha(texture(id).get_image(),0.03)
		alpha_maps[id]=bitmap
	var src := source(id,tier,frame)
	var polygons: Array = alpha_maps[id].opaque_to_polygons(Rect2i(src),0.5)
	var outline := PackedVector2Array()
	var largest := 0.0
	for polygon in polygons:
		var area := 0.0
		for i in range(polygon.size()): area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
		if absf(area)>largest: largest=absf(area); outline=polygon
	var uvs := PackedVector2Array()
	for point in outline: uvs.append((point+src.position)/texture(id).get_size())
	outlines[key]={"points":outline,"uvs":uvs}
	return outlines[key]

static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		var row := CatSkins.item(id)
		textures[id]=load("res://assets/"+row[4]+".png")
	return textures[id]

static func source(id: String, tier: int, frame: int) -> Rect2:
	var row := CatSkins.item(id)
	var bounds: Array
	if row[3].is_empty(): bounds=SpriteBounds.CATS[row[2]][tier-1][frame]
	elif SkinBounds.DATA.has(id): bounds=SkinBounds.DATA[id][tier-1][frame]
	else: bounds=[frame*256,(tier-1)*256,256,256]
	return Rect2(bounds[0],bounds[1],bounds[2],bounds[3])

static func draw(canvas: CanvasItem, id: String, tier: int, frame: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var src := source(id,tier,frame)
	var fit := minf(rect.size.x/310.0,rect.size.y/310.0)
	var target := Rect2(Vector2(rect.get_center().x-src.size.x*fit/2,rect.end.y-src.size.y*fit-rect.size.y*0.04),src.size*fit)
	if CatSkins.item(id)[3].is_empty():
		canvas.draw_texture_rect_region(texture(id),target,src,tint,false,true)
		return
	# Irregular generated atlases can have overlapping bounding rectangles. Draw
	# only this sprite's alpha outline so neighboring staff tips never bleed in.
	var geometry := frame_outline(id,tier,frame)
	canvas.draw_set_transform(target.position,0,Vector2.ONE*fit)
	canvas.draw_polygon(geometry.points,PackedColorArray([tint]),geometry.uvs,texture(id))
	canvas.draw_set_transform(Vector2.ZERO)
