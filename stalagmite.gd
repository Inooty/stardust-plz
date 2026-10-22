extends Area2D

@export var damage := 1

func _ready():
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)

func _on_hit(thing):
	var node = thing
	while node:
		var health = node.get_node_or_null("Health")
		if health:
			health.damage(damage)
			return
	node = node.get_parent()
