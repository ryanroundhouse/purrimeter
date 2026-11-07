class_name PowerupSave
extends RefCounted
## Validate the extension before Session replaces any live state.
static func number(value, low: float, high: float, integral: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and (not integral or float(value)==floor(float(value)))

static func valid(data: Dictionary) -> bool:
	if data.get("version",0)>=3:
		if not data.get("powerups") is Dictionary or not data.get("discovered") is Dictionary: return false
		for id in data.powerups:
			var d := Powerups.definition(str(id))
			if d.is_empty() or id=="training" or not number(data.powerups[id],0,d.cap,true): return false
		for id in data.discovered:
			if Powerups.definition(str(id)).is_empty() or not data.discovered[id] is bool: return false
		if not data.get("cat_milestones") is Array or data.cat_milestones.size() not in [3,4]: return false
		for tier in data.cat_milestones:
			if not number(tier,0,6,true): return false
		if not number(data.get("combat_seed"),1,2147483646,true): return false
		if not data.get("aftershocks") is Array or data.aftershocks.size()>1024: return false
		if not data.get("active",false) and not data.aftershocks.is_empty(): return false
		for echo in data.aftershocks:
			if not echo is Dictionary: return false
			for key in ["x","y"]:
				if not number(echo.get(key),0,15): return false
			if not number(echo.get("radius"),1.35,2.1) or not number(echo.get("delay"),0,0.45) or not number(echo.get("tier"),1,6,true): return false
			if not number(echo.get("power"),-1e100,1e100): return false
	if data.get("towers") is Array:
		for t in data.towers:
			if not t is Dictionary: return false
			if not number(t.get("focus_target",0),0,1e9,true) or not number(t.get("focus_hits",0),0,5,true): return false
	if data.get("enemies") is Array:
		for e in data.enemies:
			if not e is Dictionary: return false
			if not number(e.get("stun",0),0,0.900001) or not number(e.get("control_guard",0),0,4): return false
			if not number(e.get("burn_left",0),0,3) or not number(e.get("burn_power",Amount.ZERO),-1e100,1e100): return false
			if e.get("burn_left",0)>0 and not e.has("burn_power"): return false
			if not number(e.get("frost_hits",0),0,1e12,true): return false
	return true

static func apply(g, data: Dictionary) -> void:
	g.powerup_ranks={}; g.discovered={"training":true}; g.cat_milestones=[0,0,0,0]
	g.combat_seed=1234567; g.aftershocks=[]
	if data.version>=3:
		for id in data.powerups: g.powerup_ranks[id]=int(data.powerups[id])
		for id in data.discovered:
			if data.discovered[id]: g.discovered[id]=true
		for i in range(data.cat_milestones.size()): g.cat_milestones[i]=int(data.cat_milestones[i])
		g.combat_seed=int(data.combat_seed); g.aftershocks=data.aftershocks.duplicate(true)
	# Version 2 retains Session's saved training and lifetime counters verbatim.
	# refresh_powerups seeds only cat achievements supported by surviving towers.
