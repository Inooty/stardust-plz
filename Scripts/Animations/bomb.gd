extends Node

const EXPLODE_SFX: AudioStream = preload("res://Assets/SFX/explode.wav")
const CREDITS: PackedScene = preload("res://Scenes/Rooms/credits.tscn")

@export var once_id: StringName = &"bomb_explode"   
@export var gone_nodes: Array[NodePath]             
@export var anim: AnimationPlayer                  
var _running := false


func _ready() -> void:
	if once_id != &"" and GameState.has_flag(once_id):
		_apply_end_state()


func _apply_end_state() -> void:
	for path in gone_nodes:
		var n := get_node_or_null(path)
		if n == null:
			push_warning("bombexplode: gone node '%s' not found" % path)
			continue

		if n is CanvasItem:
			(n as CanvasItem).hide()
		n.process_mode = Node.PROCESS_MODE_DISABLED

func explode(_body: Node2D = null) -> void:
	if _running or (once_id != &"" and GameState.has_flag(once_id)):
		return
	_running = true

	GameState.once(once_id)

	if anim == null:
		push_error("bombexplode: AnimationPlayer not assigned")
		return
	anim.play("bomb")
	play_explode_sfx()
	await get_tree().create_timer(7).timeout
	get_tree().change_scene_to_packed(CREDITS)


func play_explode_sfx() -> void:
	print("IM CALLING YOU")
	var player := AudioStreamPlayer.new()
	player.stream = EXPLODE_SFX
	get_tree().current_scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
