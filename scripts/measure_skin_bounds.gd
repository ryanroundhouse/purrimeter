extends SceneTree
## Read alpha components without modifying image pixels. Run with --path game.
func _initialize() -> void:
	var measured := {}
	for row in CatSkins.ITEMS:
		if row[3].is_empty(): continue
		var path: String = "res://assets/"+row[4]+".png"
		if not FileAccess.file_exists(path): continue
		var im := Image.load_from_file(path)
		im.convert(Image.FORMAT_RGBA8)
		var pixels := im.get_data()
		var w := im.get_width()
		var h := im.get_height()
		var visited := PackedByteArray(); visited.resize(w*h)
		var parts := []
		var transparent := 0
		for n in range(w*h):
			if pixels[n*4+3]<16: transparent+=1; continue
			if visited[n]: continue
			var queue := PackedInt32Array([n]); visited[n]=1
			var head := 0
			var left := n%w; var right := left; var top := n/w; var bottom := top
			while head<queue.size():
				var at := queue[head]; head+=1
				var x := at%w; var y := at/w
				left=mini(left,x); right=maxi(right,x); top=mini(top,y); bottom=maxi(bottom,y)
				for next in [at-1 if x>0 else -1,at+1 if x<w-1 else -1,at-w if y>0 else -1,at+w if y<h-1 else -1]:
					if next<0 or visited[next] or pixels[next*4+3]<16: continue
					visited[next]=1; queue.append(next)
			if queue.size()>12: parts.append({"rect":Rect2i(left,top,right-left+1,bottom-top+1),"pixels":queue.size()})
		var large := parts.filter(func(p): return p.pixels>1500)
		if large.size()!=24 or transparent<10000:
			push_error("Expected 24 separate sprites and transparent gutters: "+row[0]+" got "+str(large.size())); quit(1); return
		var frames := []
		for y in range(6): frames.append([[],[],[],[]])
		for part in large:
			var rect: Rect2i=part.rect
			var center := rect.get_center()
			var col := clampi(int(float(center.x)/w*4),0,3)
			var tier := clampi(int(float(center.y)/h*6),0,5)
			if not frames[tier][col].is_empty(): push_error("Overlapping frame assignment: "+row[0]); quit(1); return
			# Include nearby detached highlights, then retain a two-pixel alpha gutter.
			for small in parts:
				if small.pixels>1500: continue
				if rect.grow(5).intersects(small.rect): rect=rect.merge(small.rect)
			rect=rect.grow(2).intersection(Rect2i(0,0,w,h))
			frames[tier][col]=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
		measured[row[0]]=frames
		print(row[0],": 24 frames; ",transparent," transparent pixels")
	var file := FileAccess.open("res://ui/skin_bounds.gd",FileAccess.WRITE)
	file.store_string("class_name SkinBounds\nextends RefCounted\n# Measured alpha bounds; generated source PNGs remain unchanged.\nconst DATA := "+JSON.stringify(measured)+"\n")
	quit()
