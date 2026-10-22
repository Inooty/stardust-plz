extends Node2D

@export var maxhealth := 1
var health : float

func _ready():
	health = maxhealth

func damage(attack):
	health -= attack
	if health <= 0:
		get_parent().queue_free()
