extends SceneTree
var failures := 0
var capture_enabled := false
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(6): await process_frame
func capture_image(name: String) -> void:
	if not capture_enabled: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/purrimeter-draft-"+name+".png")
func run() -> void:
	capture_enabled="--draft-captures" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,900)
	var app=load("res://app.tscn").instantiate(); root.add_child(app)
	await settle(); app.show_game(false); await settle()
	var view=app.local_view; view.testing=true
	view.game.garden_level=5; view.game.achievements.unlocked_level=5; view.game.best=30; view.game.run_best=30; view.game.level=31; view.game.rebirths=5; view.game.powerup_ranks={"embers":1,"focus":1}; view.game.draft_ranks={"supply":1,"spotter":1,"front":1}
	view.action("rebirth"); await settle()
	check(view.confirm.visible and view.game.rebirths==5,"confirmation precedes rebirth commitment")
	await capture_image("confirmation")
	view.confirm.accept_button.pressed.emit(); await settle()
	var panel=view.draft_panel
	check(panel.visible and panel.locked and view.game.rebirths==6,"confirmed rebirth reveals the mandatory draft")
	check(panel.selected_id.is_empty() and panel.accept_button.disabled,"draft has no default selection and cannot accidentally confirm")
	var offered: Array=view.game.pending_draft.offers.duplicate()
	var esc := InputEventKey.new(); esc.keycode=KEY_ESCAPE; esc.pressed=true
	panel._input(esc); view.action("start"); view.action("cat0")
	check(panel.visible and not view.game.active and view.placing==-1,"Escape and gameplay shortcuts cannot bypass the pending draft")
	check(Rect2(Vector2.ZERO,view.size).encloses(panel.panel.get_rect()),"desktop draft stays inside the viewport")
	check(panel.body.size.y<=panel.scroll.size.y+1,"desktop offers and preview fit without scrolling")
	await capture_image("desktop")
	var selected: String=offered[0]
	panel.cards[selected].grab_focus()
	var enter := InputEventKey.new(); enter.keycode=KEY_ENTER; enter.pressed=true
	Input.parse_input_event(enter); await process_frame
	enter.pressed=false; Input.parse_input_event(enter); await settle()
	check(panel.selected_id==selected,"keyboard Enter selects the focused card")
	check(panel.selected_id==selected and not panel.accept_button.disabled and view.game.draft_rank(selected)<RebirthDraft.definition(selected).cap,"selecting a card previews without granting its rank")
	await capture_image("selected")
	var recovery := {"exported":false}
	panel.show_save_error("Save failed. Retry or export a backup.",func(): recovery.exported=true)
	await settle(); panel.backup_button.pressed.emit()
	check(recovery.exported and panel.locked and not panel.accept_button.disabled,"save failure offers backup export without dismissing the unresolved draft")
	var before: int=view.game.draft_rank(selected)
	panel.accept_button.pressed.emit(); await settle()
	check(not panel.visible and view.game.draft_rank(selected)==before+1 and view.game.pending_draft.is_empty() and view.game.paused,"explicit Choose grants one rank and leaves level one waiting")
	await capture_image("garden")
	view.action("draft_collection"); await settle()
	check(panel.visible and not panel.locked and panel.body.get_child(0).get_child_count()==13,"collection shows all twelve improvements and the fallback")
	await capture_image("collection")
	panel.close(); await settle()
	check(not panel.visible,"collection closes normally")
	for dimensions in [Vector2i(390,844),Vector2i(360,740),Vector2i(844,390)]:
		root.size=dimensions; await settle(); app.layout_game(); await settle()
		view.game.garden_level=5; view.game.achievements.unlocked_level=5; view.game.best=30; view.game.run_best=20; view.game.level=21
		view.action("rebirth"); await settle(); await capture_image("confirm-%dx%d"%[dimensions.x,dimensions.y])
		view.confirm.accept_button.pressed.emit(); await settle()
		check(panel.visible and Rect2(Vector2.ZERO,view.size).encloses(panel.panel.get_rect()),"draft fits %dx%d"%[dimensions.x,dimensions.y])
		var overflow := false
		for card in panel.cards.values():
			if card.size.x>panel.scroll.size.x+1: overflow=true
		check(not overflow,"offer text wraps within %dpx viewport"%dimensions.x)
		check(panel.accept_button.size.y>=44,"choice control retains a touch target at %dpx"%dimensions.x)
		await capture_image("%dx%d"%[dimensions.x,dimensions.y])
		var snapshot: Dictionary=JSON.parse_string(JSON.stringify(view.game.snapshot(),"",true,true))
		var pending: Array=view.game.pending_draft.offers.duplicate()
		panel.finish_choice(); view.game.restore(snapshot); await settle()
		check(panel.visible and view.game.pending_draft.offers==pending,"restored pending draft reopens with the same offers at %dpx"%dimensions.x)
		panel.select_card(pending[0]); panel.accept_button.pressed.emit(); await settle()
	view.action("draft_collection"); await settle(); await capture_image("collection-landscape"); panel.close()
	view.game=Session.new(); view.connect_game(); view.game.best=5; view.game.run_best=5
	for id in ["mixed","supply","salvage","guard"]: view.game.draft_ranks[id]=1
	view.commit_draft(); await settle()
	check(panel.cards.size()==1 and panel.cards.has(RebirthDraft.FALLBACK),"empty eligible pool renders the sole fallback")
	await capture_image("fallback")
	panel.select_card(RebirthDraft.FALLBACK); panel.accept_button.pressed.emit(); await settle()
	view.new_garden(); await settle()
	check(view.game.draft_ranks.is_empty() and view.game.pending_draft.is_empty(),"New Garden clears draft ownership and pending choices")
	app.queue_free(); await settle()
	print("DRAFT UI RESULT: %d failures"%failures); quit(1 if failures else 0)
