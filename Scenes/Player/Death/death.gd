extends Node2D

var screen_pos := Vector2.ZERO

func _ready() -> void:
	var pivot = $CanvasLayer2/Pivot
	pivot.visible = false
	pivot.position = screen_pos
	var cam := get_viewport().get_camera_2d()
	if cam:
		pivot.scale = cam.zoom
	await get_tree().process_frame
	pivot.visible = true
	# $CanvasLayer2/Pivot/AnimationPlayer.play("death")
