extends Node
 
signal music_stopped   # emitted when stop_music() finishes (usable as a DialogueFunction waitsignal)
 
@export var song: AudioStream
@export_range(-40.0, 6.0) var volume_db := 0.0
@export var fade_time := 1.0
@export var bus := "Master"
 
static var current_song: AudioStream
static var player: AudioStreamPlayer
static var fade_tween: Tween
 
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
		_fade_to(volume_db, fade_time)
		return
 
	current_song = song
	player.stream = song
	player.volume_db = -40.0
	player.play()
	_fade_to(volume_db, fade_time)
 
	if player.stream is AudioStreamWAV:
		var wav := player.stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = wav.get_length() * wav.mix_rate
 
 
# Call this from a DialogueFunction: fades the music out and stops it.
# time < 0 uses this node's fade_time, 0 stops instantly.
func stop_music(time: float = -1.0) -> void:
	if time < 0.0:
		time = fade_time
 
	if player == null or not is_instance_valid(player) or not player.playing:
		music_stopped.emit.call_deferred()   # deferred so a waiting dialogue doesn't miss it
		return
 
	var stopping := current_song
	if time > 0.0:
		_fade_to(-40.0, time)
		await get_tree().create_timer(time).timeout   # keeps ticking while paused
 
	# Only stop if a different song didn't start in the meantime
	if is_instance_valid(player) and current_song == stopping:
		player.stop()
		current_song = null
	music_stopped.emit()
 
 
# One shared fade, so a fade-in and a fade-out never fight each other.
# The tween lives on the player node, so it survives room changes and pauses.
static func _fade_to(db: float, time: float) -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = player.create_tween()
	fade_tween.tween_property(player, "volume_db", db, time)
 
