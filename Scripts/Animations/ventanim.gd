extends Area2D

var vent: AudioStream = preload("res://Assets/SFX/% (vent)s.wav")
var triggered := false
@export var once_id: StringName = &"vent_jump"   # unique per trigger
@export var gone_nodes: Array[NodePath]          # nodes that stay gone after the cutscene (Kevin, his dialogue area)


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Cutscene already played in an earlier visit: skip it and leave the room as it ended
	if once_id != &"" and GameState.has_flag(once_id):
		triggered = true
		set_deferred("monitoring", false)
		_apply_end_state()


# Puts the room in the state the cutscene left it in
func _apply_end_state() -> void:
	for path in gone_nodes:
		var n := get_node_or_null(path)
		if n == null:
			push_warning("ventanim: gone node '%s' not found" % path)
			continue
		if n is Node2D:
			(n as Node2D).scale = Vector2.ZERO
		if n is CanvasItem:
			(n as CanvasItem).hide()
		for c in n.find_children("*", "CollisionObject2D", true, false):
			c.set_deferred("monitoring", false)
			c.set_deferred("monitorable", false)
		if n is CollisionObject2D:
			n.set_deferred("monitoring", false)
			n.set_deferred("monitorable", false)
		n.process_mode = Node.PROCESS_MODE_DISABLED


func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return

	if not body.is_in_group("player"):
		return

	triggered = true
	set_deferred("monitoring", false)

	# Remember it so it never replays after a death or room change
	GameState.once(once_id)

	var anim: AnimationPlayer = get_node_or_null("../../../AnimationPlayer")

	if anim:
		anim.play("jumpinthecaac")
		await anim.animation_finished

	play_vent_sfx()


func play_vent_sfx() -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = vent
	player.global_position = global_position

	get_tree().current_scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
