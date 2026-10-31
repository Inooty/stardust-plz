extends CharacterBody2D
 
const SAVE_MENU := preload("res://Scenes/Gui/savemenu.tscn")
 
@export var checkpoint_name := "In The Caves"   # shown in the save slots
@export var pickrange: float = 20               # how close the player's hitbox must get (edge, not center)
 
var player: CharacterBody2D
var menu: Node
 
var _hitbox: CollisionShape2D                   # the player's real collision shape
var _range_shape := CircleShape2D.new()         # reused for the range test
 
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)
		_hitbox = _find_hitbox()
		if _hitbox == null:
			push_warning("Checkpoint: no CollisionShape2D found on the player, using its origin point instead")
	$"../../AnimationPlayer".play("hover")
 
# Prefer a shape directly on the player body, otherwise the first one found anywhere under it
func _find_hitbox() -> CollisionShape2D:
	for c in player.get_children():
		if c is CollisionShape2D:
			return c as CollisionShape2D
	var found := player.find_children("*", "CollisionShape2D", true, false)
	if found.is_empty():
		return null
	return found[0] as CollisionShape2D
 
func _process(_delta: float) -> void:
	if player == null:
		return
	var in_range := _player_in_range()
	var over_menu: bool = is_instance_valid(menu) and menu.player_inside
	if is_instance_valid(menu):
		menu.keep_open = in_range   # standing next to the checkpoint also keeps the menu open
	player.pondering = in_range or over_menu
 
# True when the player's hitbox is within pickrange of the checkpoint
func _player_in_range() -> bool:
	if player == null:
		return false
	if not is_instance_valid(_hitbox) or _hitbox.shape == null or _hitbox.disabled:
		return global_position.distance_to(player.global_position) < pickrange
	_range_shape.radius = pickrange
	return _hitbox.shape.collide(_hitbox.global_transform, _range_shape, Transform2D(0.0, global_position))
 
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
	menu.hitbox = _hitbox
	# Parent it to the checkpoint's root (not the hovering sprite) so the hover animation can't shake it
	get_parent().get_parent().add_child(menu)
