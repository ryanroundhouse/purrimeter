extends Control
## Representative terrain rendered with the same materials as the playing field.
var selected_level := 1
var terrain_texture: Texture2D
static var textures: Dictionary = {}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if not textures.has(selected_level):
		var terrain := miniature(selected_level)
		textures[selected_level]=TerrainArt.new().texture(terrain,0)
	terrain_texture=textures[selected_level]
	queue_redraw()

func _draw() -> void:
	var edge := minf(size.x,size.y)
	var rect := Rect2((size-Vector2.ONE*edge)/2,Vector2.ONE*edge)
	var ground := StyleBoxFlat.new(); ground.bg_color=Color("30483c"); ground.set_corner_radius_all(6)
	draw_style_box(ground,rect)
	if terrain_texture!=null: draw_texture_rect_region(terrain_texture,rect.grow(-3),Rect2(0,0,10*TerrainArt.PIXELS,10*TerrainArt.PIXELS))

static func miniature(selected: int) -> GardenTerrain:
	# A legible ten-tile sample of each profile, not a promise of an exact map seed.
	var terrain := GardenTerrain.new()
	var streams: int=GardenLevels.terrain_profile(selected).streams
	var lanes: Array = [4] if streams==1 else ([2,6] if streams==2 else [1,4,7])
	if streams>0:
		for lane in lanes:
			for y in range(1,9):
				var x: int=lane+(1 if y in [4,5] else 0)
				terrain.cells[y*16+x]={"kind":GardenTerrain.STREAM,"style":2}
				if y in [4,6]: terrain.cells[y*16+lane+(0 if y==4 else 1)]={"kind":GardenTerrain.STREAM,"style":2}
	var rocks: Array = [Vector2i(2,2),Vector2i(7,6)]
	if selected==2: rocks=[Vector2i(1,1),Vector2i(6,1),Vector2i(2,5),Vector2i(6,6)]
	elif selected==3: rocks=[Vector2i(1,2),Vector2i(7,6)]
	elif selected==4: rocks=[Vector2i(4,1),Vector2i(0,6),Vector2i(8,7)]
	elif selected==5: rocks=[Vector2i(2,1),Vector2i(5,7),Vector2i(8,2)]
	for at in rocks:
		for offset in ([Vector2i.ZERO,Vector2i(1,0)] if selected==1 else [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1)]):
			var cell: int=(at.y+offset.y)*16+at.x+offset.x
			if not terrain.cells.has(cell): terrain.cells[cell]={"kind":GardenTerrain.ROCK,"style":0}
	return terrain
