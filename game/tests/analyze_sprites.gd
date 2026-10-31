extends SceneTree
func _initialize():
	for name in ["tuxedo","chunky","siamese"]:
		var image=Image.load_from_file("res://assets/"+name+".png")
		image.convert(Image.FORMAT_RGBA8)
		var data=image.get_data(); var w=image.get_width(); var h=image.get_height()
		var seen=PackedByteArray(); seen.resize(w*h)
		var components=[]
		for start in range(w*h):
			if seen[start] or data[start*4+3]<32: continue
			var stack: Array[int]=[start]; seen[start]=1
			var x0=w; var y0=h; var x1=0; var y1=0; var count=0
			while not stack.is_empty():
				var at=stack.pop_back(); var x=at%w; var y=at/w
				x0=mini(x0,x); x1=maxi(x1,x); y0=mini(y0,y); y1=maxi(y1,y); count+=1
				for n in [at-1,at+1,at-w,at+w]:
					if n<0 or n>=w*h or (absi(n%w-x)>1): continue
					if not seen[n] and data[n*4+3]>=32: seen[n]=1; stack.append(n)
			if count>1500: components.append({"x":x0,"y":y0,"w":x1-x0+1,"h":y1-y0+1,"pixels":count})
		components.sort_custom(func(a,b): return a.y+a.h/2<b.y+b.h/2)
		print(name, " ", JSON.stringify(components))
	quit()
