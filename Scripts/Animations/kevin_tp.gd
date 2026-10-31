extends Area2D
 
# Plays an animation when the player walks into this area.
 
@onready var animation_player: AnimationPlayer = $"../../AnimationPlayer"
@export var animation_name: StringName = &"kevinteleport"
@export var once := true                               # OFF = plays again every time the player enters
 
var triggered := false
 
 
func _ready() -> void:
	body_entered.connect(_on_body_entered)
 
 
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if once and triggered:
		return
	if animation_player == null:
		push_warning("%s: no animation_player assigned" % name)
		return
	if not animation_player.has_animation(animation_name):
		push_warning("%s: animation '%s' not found" % [name, animation_name])
		return
 
	triggered = true
	animation_player.play(animation_name)
 
