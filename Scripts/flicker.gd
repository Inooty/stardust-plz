extends Node2D

@export var min_interval: float = 10.5
@export var max_interval: float = 30.5

@export var flicker_speed: float = 0.05
@export var flicker_duration: float = 0.2

@export var play_sfx: bool = false
var sfx: AudioStream = preload("res://Assets/SFX/% (flicker)s.wav")


func _ready() -> void:
	while true:
		visible = true

		await get_tree().create_timer(
			randf_range(min_interval, max_interval)
		).timeout

		await flicker()


func flicker() -> void:
	var elapsed := 0.0

	while elapsed < flicker_duration:
		visible = not visible

		if play_sfx:
			play_flicker_sfx()

		await get_tree().create_timer(flicker_speed).timeout
		elapsed += flicker_speed

	visible = true


func play_flicker_sfx() -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = sfx
	player.global_position = global_position
	get_tree().current_scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
