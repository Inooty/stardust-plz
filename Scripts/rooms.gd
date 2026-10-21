extends CanvasLayer

signal room_changed(path: String)

var transitioning := false
var _fade: ColorRect


func _ready() -> void:
	layer = 200   # above the dialogue box (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0.0
	add_child(_fade)


# path:  the room scene, e.g. "res://Scenes/Levels/cave.tscn"
# spawn: name of a Marker2D in the NEW room where the player appears
#        (empty = the player stays wherever it is saved in that scene)
func change_room(path: String, spawn: StringName = &"", fade_time := 0.3) -> void:
	if transitioning:
		return
	if not ResourceLoader.exists(path):
		push_error("RoomManager: room '%s' does not exist" % path)
		return

	transitioning = true
	_set_players_move(false)
	await _fade_to(1.0, fade_time)

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("RoomManager: could not load '%s' (error %d)" % [path, err])
		await _fade_to(0.0, fade_time)
		_set_players_move(true)
		transitioning = false
		return

	# The scene swap happens at the end of the frame, so wait for it
	await get_tree().process_frame
	await get_tree().process_frame

	_set_players_move(false)   # the new player starts frozen too
	_place_player(spawn)
	await get_tree().process_frame
	_snap_camera()

	await _fade_to(0.0, fade_time)
	_set_players_move(true)
	transitioning = false
	room_changed.emit(path)


func _fade_to(alpha: float, time: float) -> void:
	if time <= 0.0:
		_fade.modulate.a = alpha
		return
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", alpha, time)
	await t.finished


func _place_player(spawn: StringName) -> void:
	if spawn == &"":
		return
	var marker := get_tree().current_scene.find_child(String(spawn), true, false) as Node2D
	if marker == null:
		push_warning("RoomManager: no spawn marker named '%s' in the new room" % spawn)
		return
	for p in get_tree().get_nodes_in_group("player"):
		p.global_position = marker.global_position


# Stops the camera from smoothly gliding across the new room
func _snap_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam.reset_smoothing()


func _set_players_move(value: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "move" in p:
			p.move = value
