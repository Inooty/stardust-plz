extends Node2D

@export var maxhealth := 1
@onready var body: CharacterBody2D = get_parent()
var health: float
var dead := false

func _ready():
	health = maxhealth

func damage(attack):
	if dead:
		return
	health -= attack
	if health <= 0:
		dead = true
		body.die()
