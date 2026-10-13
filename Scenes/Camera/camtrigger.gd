class_name CameraZone
extends Area2D

@export var anchorid: int = 1
@export var campriority: int = 0
@export var sticky: bool = false

@export var anchor: bool = false
@export var applyzoom: bool = true
@export var zoom: Vector2 = Vector2(4,4)

@export var zoomspeed: float = 5
@export var camspeed: float = 5
@export var camoverride: bool = false
@export var hackatimetestplzworkbro: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		CameraManager.register_zone(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		CameraManager.unregister_zone(self)
