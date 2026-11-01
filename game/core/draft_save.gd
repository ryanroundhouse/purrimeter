class_name DraftSave
extends RefCounted
## Complete validation before mutation; old gardens acquire no draft rewards.
static func valid_ranks(ranks) -> bool:
	if not ranks is Dictionary or ranks.size()>RebirthDraft.ITEMS.size()+1: return false
	for id in ranks:
		var d := RebirthDraft.definition(str(id))
		if d.is_empty() or not PowerupSave.number(ranks[id],1,1e9 if id==RebirthDraft.FALLBACK else d.cap,true): return false
	return true

static func valid(data: Dictionary) -> bool:
	if data.version<4: return true
	if not valid_ranks(data.get("draft_ranks")) or not PowerupSave.number(data.get("draft_seed"),1,2147483646,true): return false
	if not PowerupSave.number(data.get("draft_streak"),0,5,true) or not data.get("draft_rescue_used") is bool: return false
	var pending = data.get("pending_draft")
	if not pending is Dictionary: return false
	if not pending.is_empty():
		if pending.size()!=3 or not PowerupSave.number(pending.get("depth"),5,data.best,true) or pending.get("rebirth")!=data.rebirths: return false
		if data.rebirths<1 or data.active or data.level!=1 or data.run_best!=0 or data.auto_start_remaining!=0 or data.draft_streak!=0 or data.draft_rescue_used: return false
		if not pending.get("offers") is Array or pending.offers.is_empty() or pending.offers.size()>3: return false
		var g := Session.new()
		g.best=int(data.best); g.rebirths=int(data.rebirths); g.draft_ranks=data.draft_ranks; g.powerup_ranks=data.powerups
		var eligible := RebirthDraft.pool(g)
		if eligible.is_empty():
			if pending.offers!=[RebirthDraft.FALLBACK]: return false
		else:
			if pending.offers.size()!=mini(3,eligible.size()): return false
			var seen := {}
			for id in pending.offers:
				if not id is String or id not in eligible or seen.has(id): return false
				seen[id]=true
	for t in data.towers:
		if not PowerupSave.number(t.get("focus_credit",0),0,5,true): return false
	for e in data.enemies:
		if not PowerupSave.number(e.get("spotter_left",0),0,3) or not PowerupSave.number(e.get("triad_until",0),0,data.elapsed+3.00001): return false
		if not e.get("burn_relayed",false) is bool: return false
		var marks = e.get("triad_marks",[-1,-1,-1])
		if not marks is Array or marks.size()!=3: return false
		for at in marks:
			if not PowerupSave.number(at,-1,data.elapsed) or (at<0 and at!=-1): return false
	return true

static func apply(g, data: Dictionary) -> void:
	g.draft_ranks={}; g.pending_draft={}; g.draft_streak=0; g.draft_rescue_used=false
	if data.version>=4:
		for id in data.draft_ranks: g.draft_ranks[id]=int(data.draft_ranks[id])
		g.draft_seed=int(data.draft_seed); g.draft_streak=int(data.draft_streak); g.draft_rescue_used=data.draft_rescue_used
		g.pending_draft=data.pending_draft.duplicate(true)
		if not g.pending_draft.is_empty():
			g.pending_draft.depth=int(g.pending_draft.depth); g.pending_draft.rebirth=int(g.pending_draft.rebirth)
	else:
		# Old versions never owned these effects, even if unrecognized keys exist.
		for t in g.towers: t.erase("focus_credit")
		for e in g.enemies:
			for key in ["spotter_left","triad_until","triad_marks","burn_relayed"]: e.erase(key)
