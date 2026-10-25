extends Area2D

const REGROW_DELAY := 10.0

var trigger := false
var armed := false
var falling_sfx: AudioStream = preload("res://Assets/SFX/crumble.wav")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().physics_frame
	await get_tree().physics_frame
	armed = true

func play_sfx(stream: AudioStream) -> void:
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.global_position = global_position
	get_parent().add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _on_body_entered(body: Node2D) -> void:
	if not armed or trigger:
		return
	if not body.is_in_group("player"):
		return
	trigger = true
	print("triggered by ", body.name)
	play_sfx(falling_sfx)
	$"../AnimationPlayer".play("trigger")
	await get_tree().create_timer(REGROW_DELAY).timeout
	$"../AnimationPlayer".play("regrow")
	await $"../AnimationPlayer".animation_finished
	trigger = false
