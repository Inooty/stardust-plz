extends CharacterBody2D

@export var pickrange: float = 20

var player: CharacterBody2D

func _ready() -> void:
	player  = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
			add_collision_exception_with(player)
			player.add_collision_exception_with(self)
	$"../../AnimationPlayer".play("hover")

func _process(_delta: float) -> void:
	if  player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <pickrange:
		player.pondering = true
	else:
		player.pondering = false
