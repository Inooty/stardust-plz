extends Area2D

func _ready() -> void:
	pass

func kevin() -> void:
	GameState.set_flag(&"kevin")
	await get_tree().create_timer(1).timeout
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.kevin = true
	player._kevin()
