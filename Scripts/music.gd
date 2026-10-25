extends Node
 
@export var song: AudioStream
@export_range(-40.0, 6.0) var volume_db := 0.0
@export var fade_time := 1.0
@export var bus := "Master"
 
static var current_song: AudioStream
static var player: AudioStreamPlayer
 
func _ready() -> void:
	if song == null:
		return
 
	if player == null or not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.bus = bus
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		# The actual AudioStreamPlayer must be in the group, not this script's Node,
		# otherwise fade_out_music() in the player script never finds it.
		player.add_to_group("music")
		get_tree().root.add_child.call_deferred(player)
 
	await get_tree().process_frame
 
	if current_song == song and player.playing:
		create_tween().tween_property(player, "volume_db", volume_db, fade_time)
		return
 
	current_song = song
	player.stream = song
	player.volume_db = -40.0
	player.play()
	create_tween().tween_property(player, "volume_db", volume_db, fade_time)
 
	if player.stream is AudioStreamWAV:
		var wav := player.stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = wav.get_length() * wav.mix_rate
 
