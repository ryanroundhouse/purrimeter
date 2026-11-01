extends Control
var skin_id := "scout_default"
var tier := 1
var locked := false
var animated := true
var clock := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not animated: return
	clock+=minf(delta,0.1); queue_redraw()

func _draw() -> void:
	CatSkinArt.draw(self,skin_id,tier,int(clock*4)%4 if animated else 0,Rect2(Vector2.ZERO,size),Color.BLACK if locked else Color.WHITE)
