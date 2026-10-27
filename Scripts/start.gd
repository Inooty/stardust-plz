extends Control

func _input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed
	var key: bool = event is InputEventKey and event.pressed
	if clicked or key:
		get_window().mode = Window.MODE_FULLSCREEN
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().change_scene_to_file("res://Scenes/Rooms/enter-caves1.tscn")
