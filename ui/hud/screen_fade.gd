class_name ScreenFade
## Full-screen fade to/from black (travel through passages, later
## respawns and cutscenes). One shared overlay, created on first use.

const LAYER_NAME := "ScreenFadeLayer"


## Fades to `alpha` (1 = black) over `seconds`. Await it.
static func fade(tree: SceneTree, alpha: float, seconds: float) -> void:
	var rect := _rect(tree)
	var tween := rect.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", alpha, seconds)
	await tween.finished


static func is_black(tree: SceneTree) -> bool:
	return _rect(tree).color.a > 0.99


static func _rect(tree: SceneTree) -> ColorRect:
	var layer := tree.root.get_node_or_null(LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = LAYER_NAME
		layer.layer = 90
		var rect := ColorRect.new()
		rect.name = "Rect"
		rect.color = Color(0, 0, 0, 0)
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(rect)
		tree.root.add_child(layer)
	return layer.get_node("Rect")
