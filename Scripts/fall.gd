extends Area2D

var trigger := false

func _ready()  -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if trigger:
		return
	trigger = true
	print("triggered by", body.name)
	$"../AnimationPlayer".play("trigger")
