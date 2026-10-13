class_name Anchor
extends Marker2D

@export var id: int = 1
@export var zoomover: bool = false
@export var zoom: Vector2 = Vector2(3, 3)

func _enter_tree() -> void:
	CameraManager.register_anchor(self)

func _exit_tree() -> void:
	CameraManager.unregister_anchor(self)
