extends Node
 
@export_file("*.tscn") var menu_scene: String = "res://Scenes/Gui/main_menu.tscn"
@export var start_automatically := true
@export var delay := 100
@export var animation_player: AnimationPlayer
@export var animation_name: StringName = &""
@export var fade_time := 1
 
var _going := false
 
 
func _ready() -> void:
	if start_automatically:
		start()
 
 
func start() -> void:
	if animation_player and animation_name != &"" and animation_player.has_animation(animation_name):
		if animation_player.current_animation != animation_name or not animation_player.is_playing():
			animation_player.play(animation_name)
		var finished_name: StringName = &""
		while finished_name != animation_name:
			finished_name = await animation_player.animation_finished
	else:
		await get_tree().create_timer(delay).timeout
 
	go_to_menu()
 
 
func go_to_menu() -> void:
	if _going or not is_inside_tree():
		return
	if menu_scene == "" or not ResourceLoader.exists(menu_scene):
		push_warning("ReturnToMenu '%s': menu_scene is not set or doesn't exist" % name)
		return
	_going = true
 
	var rm = get_node_or_null("/root/RoomManager")
	if rm:
		await rm.change_room(menu_scene, &"", fade_time)
		_going = false
	else:
		get_tree().change_scene_to_file(menu_scene)
 
