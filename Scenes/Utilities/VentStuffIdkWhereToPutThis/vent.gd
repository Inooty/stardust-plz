extends Area2D

var vent: AudioStream = preload("res://Assets/SFX/% (vent)s.wav")

var trigger := false
var armed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Wait for the initial physics frames before allowing the trigger.
	await get_tree().physics_frame
	await get_tree().physics_frame

	armed = true


func play_sfx(stream: AudioStream) -> void:
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.global_position = global_position

	# Add the player to the scene before playing.
	get_tree().current_scene.add_child(p)

	p.finished.connect(p.queue_free)
	p.play()


func _on_body_entered(body: Node2D) -> void:
	if not armed or trigger:
		return

	if not body.is_in_group("player"):
		return

	# Prevent the sound from playing repeatedly.
	trigger = true
	play_sfx(vent)
