extends Control
var view: Control
var tower := {}
var enemy := {}
var clock := 0.0
func _process(delta: float) -> void: clock+=delta; queue_redraw()
func _draw() -> void:
	if not is_instance_valid(view): return
	var rect := Rect2(Vector2.ZERO,size)
	if not tower.is_empty(): CatSkinArt.draw(self,view.game.skin_id(tower.kind),tower.tier,[0,1,3,1][int(clock*2.5)%4],rect)
	elif not enemy.is_empty():
		if enemy.boss>=0: view.boss_sprite(enemy.boss,int(clock*5)%4,rect,Color.WHITE,self)
		else: view.enemy_sprite(enemy.kind,int(clock*5)%4,rect,Color.WHITE,self)
