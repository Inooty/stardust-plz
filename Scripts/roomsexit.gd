extends Area2D

@export_file("*.tscn") var target_room: String
@export var target_spawn: StringName = &""   # name of the Marker2D in the target room
@export var fade_time := 0.3


func _ready() -> void:
	# Connected in code: do NOT also connect this in the editor's Node tab
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if target_room == "":
		push_warning("RoomExit '%s' has no target_room set" % name)
		return
	RoomManager.change_room(target_room, target_spawn, fade_time)
