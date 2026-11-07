extends SceneTree
var failures := 0
var app: Control
var capture_dir := ""
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+message)
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame; await process_frame; await create_timer(0.15).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
func run() -> void:
	if "--multiplayer-test" not in OS.get_cmdline_user_args(): quit(1); return
	var args := OS.get_cmdline_user_args(); var at := args.find("--skin-capture")
	if at>=0 and at+1<args.size(): capture_dir=args[at+1]
	app=load("res://app.tscn").instantiate(); root.add_child(app)
	await process_frame; await process_frame
	await capture("main-menu")
	app.open_skins(); await process_frame; await process_frame
	var p=app.skins_panel
	check(p.visible and p.cards.size()==5 and p.tabs.size()==4,"main menu opens five Scout skins and four cat tabs")
	check(p.panel.get_rect().end.x<=root.get_visible_rect().size.x and p.panel.get_rect().end.y<=root.get_visible_rect().size.y,"skin panel fits logical viewport")
	await capture("skins-default")
	p.cards["scout_golden"].pressed.emit(); await process_frame
	check(p.portrait.locked and p.equip_button.disabled and p.previews["scout_golden"].locked,"locked card and detail remain silhouetted and unequippable")
	for tier in range(6):
		p.tier_picker.select(tier)
		p.tier_picker.item_selected.emit(tier)
		check(p.portrait.locked and p.portrait.tier==tier+1,"tier preview cannot reveal locked artwork")
	p.equip_selection()
	check(app.local_view.game.skin_id(0)=="scout_default","locked equip cannot bypass button")
	await capture("skins-locked")
	var escape := InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	Input.parse_input_event(escape); await process_frame
	check(not p.visible and app.screen=="menu","Escape closes skin collection and preserves main menu")
	app.show_game(false); app.local_view.game.paused=false; app.open_skins(); await process_frame
	check(app.local_view.game.paused and not app.local_view.gameplay_enabled,"skins freeze local combat and controls")
	app.layout_game(); check(not app.local_view.gameplay_enabled,"relayout cannot enable combat behind skins")
	p.close(); check(not app.local_view.game.paused and app.local_view.gameplay_enabled,"closing restores running state")
	app.open_pause(); await capture("pause-menu"); app.open_skins(); p.close()
	check(app.pause_open and app.local_view.game.paused and not app.local_view.gameplay_enabled,"collection returns to paused Escape menu")
	app.close_pause()
	var g: Session=app.local_view.game
	g.coins=Amount.of(10000); g.build(0,119); g.upgrade(119)
	g.achievements.award("first",false)
	app.open_skins(); p.cards["scout_ginger"].pressed.emit(); await process_frame
	check(not p.portrait.locked and not p.equip_button.disabled and g.skin_id(0)=="scout_default","browsing unlocked skin does not equip")
	await capture("skins-unlocked")
	p.equip_button.pressed.emit(); await process_frame
	check(g.skin_id(0)=="scout_ginger" and p.equip_button.text=="Equipped","explicit Equip applies skin immediately")
	check(g.towers[0].tier==2,"skin selection preserves existing tower tier")
	p.tabs[1].pressed.emit(); p.cards["gunner_smoky"].pressed.emit(); p.equip_button.pressed.emit()
	check(g.skin_id(0)=="scout_ginger" and g.skin_id(1)=="gunner_smoky" and g.skin_id(2)=="sage_default","independent selections for all cat types")
	p.close(); app.local_view.selected=119; await capture("gameplay-equipped")
	var book=g.achievements; app.local_view.new_garden()
	check(app.local_view.game.achievements==book and app.local_view.game.skin_id(0)=="scout_ginger","New Garden retains selected skins")
	g=app.local_view.game
	app.local_view.set_process(false)
	app.local_view.queue_redraw()
	var f=app.local_view.fanfare
	f.ids.clear(); f.skin_ids.clear(); book.pending=["first"]; book.summary.clear()
	f.advance(.1,true)
	check(f.thumbnail=="scout_ginger" and f.caption.contains("Ginger Scout"),"achievement fanfare names unlocked skin and shows thumbnail")
	var elapsed: float=f.clock; f.advance(.1,false); f.advance(.1,true)
	check(is_equal_approx(f.clock,elapsed+.1),"hidden skin fanfare resumes its clock")
	f.clock=1; f.queue_redraw(); await capture("skin-fanfare")
	for i in range(32): f.advance(.1,true)
	check(book.seen_skins.has("scout_ginger"),"completed celebration durably acknowledges skin")
	var old_book := Achievements.new(); old_book.earned={"first":true,"upgrade":true}
	f.book=old_book; f.ids.clear(); f.skin_ids.clear(); f.advance(.1,true)
	check(f.skin_ids.size()==2 and f.heading.contains("2 cat skins"),"existing achievements reveal all retrospective skins in one summary")
	f.clock=1; f.queue_redraw(); await capture("skin-summary")
	for i in range(32): f.advance(.1,true)
	check(CatSkins.unseen_rewards(old_book).is_empty(),"retroactive summary is acknowledged once")
	for row in Achievements.ITEMS: book.award(row[0],true)
	for kind in range(3):
		app.open_skins(); p.tabs[kind].pressed.emit()
		check(p.cards[CatSkins.selected(book,kind)].tooltip_text.ends_with("Equipped"),"equipped card remains identified for type %d" % kind)
		for row in CatSkins.for_kind(kind):
			p.cards[row[0]].pressed.emit(); await process_frame
			check(not p.portrait.locked and p.details.position.x+p.details.size.x<=p.body.size.x+1,"unlocked detail fits: "+row[1])
		check(p.cards[CatSkins.selected(book,kind)].get_child(0).get_child(2).text=="Equipped","equipped label remains visible for type %d" % kind)
		await capture("skins-all-"+str(kind)); p.close()
	# Owner selection is rendered even when the viewer has never earned it.
	CatSkins.equip(book,2,"sage_aurora")
	var remote_view=preload("res://ui/main.gd").new(); remote_view.read_only=true; root.add_child(remote_view)
	check(remote_view.receive_field(LiveField.capture(g,1,1)) and remote_view.game.skin_id(2)=="sage_aurora","spectator renderer uses owner's skin")
	check(not CatSkins.unlocked(remote_view.game.achievements,"sage_aurora"),"spectator renderer does not unlock viewer collection")
	remote_view.queue_free()
	print("Skin UI checks: %d failure(s)" % failures)
	app.queue_free(); await process_frame; quit(1 if failures else 0)
