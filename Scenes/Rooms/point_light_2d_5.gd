extends PointLight2D

func _ready():
	var modulate_node := get_tree().current_scene.find_child("CanvasModulate", true, false) as CanvasModulate
	if modulate_node == null:
		push_warning("No CanvasModulate found in the scene")
		return
	color = Color(1, 1, 1) - modulate_node.color
	color.a = 1.0
	energy = 1.0
