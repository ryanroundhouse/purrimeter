extends SceneTree
func _initialize():
	for path in OS.get_cmdline_user_args():
		var image=Image.load_from_file(path)
		var transparent=0
		for y in range(0,image.get_height(),8):
			for x in range(0,image.get_width(),8):
				if image.get_pixel(x,y).a<0.01: transparent+=1
		print(path.get_file()," dimensions=",image.get_size()," corner=",image.get_pixel(0,0)," transparent samples=",transparent)
	quit()
