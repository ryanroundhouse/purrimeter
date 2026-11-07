extends SceneTree
var failures := 0
var capture_dir := ""
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
func run() -> void:
	if "--multiplayer-test" not in OS.get_cmdline_user_args(): quit(1); return
	var args := OS.get_cmdline_user_args(); var at := args.find("--terrain-capture")
	if at>=0 and at+1<args.size(): capture_dir=args[at+1]; DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size=Vector2i(844,390) if GamePlatform.responsive() else Vector2i(1280,900)
	var app=load("res://app.tscn").instantiate(); root.add_child(app)
	await process_frame; await process_frame
	app.show_game(false); var view=app.local_view
	view.game=Session.fresh(42); view.connect_game(); view.game.paused=true; view.game.coins=Amount.of(1000)
	if view.mobile is AndroidGarden: view.mobile.focused_camera=false; view.mobile.zoom=1; view.mobile.layout()
	var terrain_cell: int=view.game.terrain.cells.keys()[0]
	view.action("cat0"); view.interact_cell(terrain_cell)
	check(view.placing==0 and view.game.towers.is_empty() and view.status.contains("block recruitment"),"terrain rejects recruitment and retains selected cat")
	if view.compact():
		view.mobile.pending=terrain_cell; view.mobile.act("mobile_confirm")
		check(view.placing==0 and view.game.towers.is_empty(),"mobile confirmation revalidates obstacle placement")
	view.focus_id="board"; view.hover=terrain_cell; view.keyboard_cell=terrain_cell
	await capture("blocked-placement")
	view.placing=-1; view.interact_cell(terrain_cell)
	check(view.selected==-1 and view.selected_enemy==-1 and view.status.contains("cannot be destroyed"),"terrain selection explains without inspector")
	if view.mobile is AndroidGarden: check(view.mobile.notice.contains("cannot be destroyed"),"Android terrain selection shows notice")
	view.terrain_notice_until=0; view.focus_id=""; view.hover=-1; view.status="Rocks and streams shape this garden. Recruit cats on open ground."
	for cell in [113,130,145,173,90]:
		if view.game.placement_error(cell,0).is_empty(): view.game.build(cell%3,cell)
	view.fanfare.ids.clear(); view.fanfare.skin_ids.clear(); view.game.achievements.pending.clear()
	await capture("garden")
	var original: Array=view.game.terrain.snapshot()
	var other=LiveField.decode(LiveField.capture(view.game,1,1))
	check(other!=null and other.terrain.snapshot()==original,"remote display receives identical terrain")
	var art=TerrainArt.new(); var tex=art.texture(view.game.terrain,0)
	check(tex!=null and tex.get_size()==Vector2(352,352),"terrain renders at exact pixel grid")
	var before=tex.get_image(); var after=art.texture(view.game.terrain,0.4).get_image()
	var rock_unchanged := true; var water_changed := false
	for cell in view.game.terrain.cells:
		for y in range(22):
			for x in range(22):
				var px: int=cell%16*22+x; var py: int=cell/16*22+y
				if view.game.terrain.cells[cell].kind==GardenTerrain.ROCK: rock_unchanged=rock_unchanged and before.get_pixel(px,py)==after.get_pixel(px,py)
				else: water_changed=water_changed or before.get_pixel(px,py)!=after.get_pixel(px,py)
	check(rock_unchanged and water_changed,"only water highlights animate")
	# A joined edge and a diagonal contact must never acquire a transparent seam.
	var joins=GardenTerrain.decode([{"cell":34,"kind":0,"style":0},{"cell":35,"kind":0,"style":0},{"cell":52,"kind":0,"style":0},{"cell":36,"kind":1,"style":1}])
	var pixels=art.texture(joins,0).get_image()
	check(pixels.get_pixel(65,55).a==1 and pixels.get_pixel(66,55).a==1,"edge neighbors connect without transparent seam")
	check(pixels.get_pixel(87,65).a==1 and pixels.get_pixel(88,66).a==1,"diagonal neighbors meet at occupied corners")
	check(pixels.get_pixel(88,55)!=pixels.get_pixel(99,55),"rock-water join has a shoreline")
	view.game=Session.new(); view.game.terrain=joins; view.connect_game(); view.route_on=false; view.status="Connection checks: edges, diagonal contacts, rocky shoreline."
	await capture("joins")
	view.new_garden()
	check(not view.game.terrain.cells.is_empty(),"New Garden creates obstacles")
	for seed_value in [7,19]:
		view.game=Session.fresh(seed_value); view.connect_game(); view.game.paused=true; view.route_on=true
		await capture("variety-%d"%seed_value)
	app.queue_free(); await process_frame
	print("Terrain UI: %d failure(s)"%failures); quit(1 if failures else 0)
