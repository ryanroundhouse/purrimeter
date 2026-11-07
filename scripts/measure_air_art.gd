extends SceneTree
## Measure generated atlases without changing their pixels or alpha.
func _initialize() -> void:
	var data := {}
	for name in ["ranger","moth"]:
		var im := Image.load_from_file("res://assets/"+name+".png")
		var columns := 4 if name=="ranger" else 2
		var rows := 6 if name=="ranger" else 2
		var cell := Vector2i(im.get_width()/columns,im.get_height()/rows)
		var frames := []
		for y in range(rows):
			var row := []
			for x in range(columns):
				var offset := Vector2i(x,y)*cell
				var bitmap := BitMap.new()
				bitmap.create_from_image_alpha(im.get_region(Rect2i(offset,cell)),0.06)
				var bounds := Rect2i()
				for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,cell),1.0):
					if polygon.size()<3: continue
					for point in polygon:
						var pixel := Rect2i(Vector2i(point),Vector2i.ONE)
						bounds=pixel if bounds.size==Vector2i.ZERO else bounds.merge(pixel)
				bounds.position+=offset
				row.append([bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y])
			frames.append(row)
		data[name]=frames
	var file := FileAccess.open("res://ui/air_art.gd",FileAccess.WRITE)
	file.store_string("class_name AirArt\nextends RefCounted\n# Measured alpha bounds. Original generated sprites are unmodified.\nconst RANGER := "+JSON.stringify(data.ranger)+"\nconst MOTH := "+JSON.stringify(data.moth[0]+data.moth[1])+"\n")
	print(data)
	quit()
