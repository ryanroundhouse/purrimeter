class_name TerrainArt
extends RefCounted
## World-aligned material sampling keeps every shared edge continuous.
## Cache four low-resolution frames; simulation and saved styles never animate.
const PIXELS := 22
var frames: Array[Texture2D] = []
var layout: Array = []
var material: Image

func texture(terrain: GardenTerrain, time: float) -> Texture2D:
	var rows := terrain.snapshot()
	if rows.is_empty(): return null
	if frames.is_empty() or rows!=layout:
		layout=rows; frames.clear()
		if material==null: material=(load("res://assets/terrain/materials.png") as Texture2D).get_image()
		for frame in range(4): frames.append(ImageTexture.create_from_image(paint(terrain,frame)))
	return frames[posmod(int(time*3.0),4)]

static func kind_at(terrain: GardenTerrain, x: int, y: int) -> int:
	if x<0 or x>=16 or y<0 or y>=16: return -1
	return terrain.cells.get(y*16+x,{}).get("kind",-1)

func paint(terrain: GardenTerrain, frame: int) -> Image:
	var result := Image.create(16*PIXELS,16*PIXELS,false,Image.FORMAT_RGBA8)
	var half := material.get_width()/2
	for cell in terrain.cells:
		var tile: Dictionary = terrain.cells[cell]
		var tx: int = cell%16; var ty: int = cell/16
		var stone: bool = tile.kind==GardenTerrain.ROCK
		var sides := [kind_at(terrain,tx-1,ty),kind_at(terrain,tx,ty-1),kind_at(terrain,tx+1,ty),kind_at(terrain,tx,ty+1)]
		for y in range(PIXELS):
			for x in range(PIXELS):
				var wx := tx*PIXELS+x; var wy := ty*PIXELS+y
				# Chamfer exposed convex corners only. Diagonal neighbors keep contact.
				var sx := -1 if x<PIXELS/2 else 1; var sy := -1 if y<PIXELS/2 else 1
				var corner_x := mini(x,PIXELS-1-x); var corner_y := mini(y,PIXELS-1-y)
				var diagonal := kind_at(terrain,tx+sx,ty+sy)
				if corner_x+corner_y<5 and kind_at(terrain,tx+sx,ty)<0 and kind_at(terrain,tx,ty+sy)<0 and diagonal<0: continue
				var edges := [x,y,PIXELS-1-x,PIXELS-1-y]
				var outside := false
				# A stepped silhouette softens exposed banks without changing joined borders.
				for side in range(4):
					if sides[side]>=0: continue
					var along := wy if side in [0,2] else wx
					var inset := posmod(along/3+along/7+tile.style,3)
					if diagonal>=0 and corner_x<3 and corner_y<3: inset=0
					edges[side]-=inset
					if edges[side]<0: outside=true
				if outside: continue
				var scale := 6 if stone else 4
				var source_x := (wx*scale)%half+(half if tile.style==1 else 0)
				var source_y := (wy*scale)%half+(0 if stone else half)
				var color := material.get_pixel(source_x,source_y)
				if tile.style==2: color=color*Color(0.86,1.10,0.94) if stone else color*Color(0.83,1.16,1.15)
				for side in range(4):
					if sides[side]==tile.kind or edges[side]>2: continue
					var depth: int = edges[side]
					if stone:
						if depth==0: color=Color("263a36")
						elif side in [0,1]: color=color.lightened(0.20 if depth==1 else 0.07)
						else: color=color.darkened(0.36 if depth==1 else 0.17)
					else:
						var rocky: bool = sides[side]==GardenTerrain.ROCK
						if depth==0: color=Color("68736b") if rocky else Color("65815a")
						elif depth==1: color=Color("414f49") if rocky else Color("3e6149")
						else: color=color.darkened(0.25)
				# Sparse highlights travel across water, with no tile-boundary reset.
				if not stone and x>3 and x<PIXELS-4 and y>3 and y<PIXELS-4 and posmod(wy-frame,11)==0 and posmod(wx+wy/11*7,19)<4:
					color=color.lightened(0.15)
				result.set_pixel(wx,wy,color)
	return result

static func overview_color(kind: int) -> Color:
	return Color("8b9990") if kind==GardenTerrain.ROCK else Color("4c96b0")
