class_name Stardust
extends CharacterBody2D

@export var pickrange: float = 20
@export var followspeed: float = 20

var player: CharacterBody2D
var offset = 15
var held: bool = false


func _ready() -> void:
	player  = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
			add_collision_exception_with(player)
			player.add_collision_exception_with(self)
	$AnimationPlayer.play("Float")

func _process(delta: float) -> void:
	if  player == null:
		return
		
	var dist = global_position.distance_to(player.global_position)
		
	if dist <pickrange and not held:
		player.pondering = true
	else:
		player.pondering = false
	if Input.is_action_just_pressed("use") and dist < pickrange:
		held = true
		player.holding = true
		player.pondering = false
	if Input.is_action_just_released("use"):
		held = false
		player.holding = false
	if held:
		var t = 1.0 - exp(-followspeed * delta)
		var direction = (player.global_position + Vector2(offset, 0)) - global_position
		velocity = velocity.lerp(direction * followspeed, t)
		move_and_slide()
