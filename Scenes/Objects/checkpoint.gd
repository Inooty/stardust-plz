extends CharacterBody2D

const SAVE_MENU := preload("res://Scenes/Gui/savemenu.tscn")

@export var checkpoint_name := "In The Caves"   # shown in the save slots
@export var pickrange: float = 20

var player: CharacterBody2D
var menu: Node

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)
	$"../../AnimationPlayer".play("hover")

func _process(_delta: float) -> void:
	if player == null:
		return
	var over_menu: bool = is_instance_valid(menu) and menu.cursor_inside
	player.pondering = _player_in_range() or over_menu

func _player_in_range() -> bool:
	return player != null and global_position.distance_to(player.global_position) < pickrange

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var is_open: bool = is_instance_valid(menu) and not menu.closing
	if _player_in_range():
		if is_open:
			menu.close()
		else:
			if is_instance_valid(menu):
				menu.queue_free()
			_open_menu()
	elif is_open:
		menu.close()

func _open_menu() -> void:
	menu = SAVE_MENU.instantiate()
	menu.save_position = global_position
	menu.checkpoint_name = checkpoint_name
	# Parent it to the checkpoint's root (not the hovering sprite) so the hover animation can't shake it
	get_parent().get_parent().add_child(menu)
