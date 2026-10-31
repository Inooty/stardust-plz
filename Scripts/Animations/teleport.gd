extends Node
 
# Attach to any Node in the room, then in a DialogueFunction set:
#   targetpath = this node
#   funcname   = go
#   funcarg    = []                                  -> uses the values set in the inspector
#                ["res://Scenes/Level2.tscn"]        -> different room
#                ["res://Scenes/Level2.tscn", "Door"] -> different room + spawn marker name
#                ["res://Scenes/Level2.tscn", "Door", 1.0] -> ...and a 1 second fade
#
# waitsignal (optional): "teleported" keeps the dialogue box up (and the player locked)
# until the room has swapped, instead of letting the dialogue finish during the fade.
 
signal teleported   # only fires if the teleport didn't happen (bad path, already changing)
 
@export_file("*.tscn") var scene_path: String
@export var spawn: StringName = &""    # name of the Marker2D in the target room
@export var fade_time := 0.3
 
 
func go(path: String = "", spawn_name: String = "", fade: float = -1.0) -> void:
	var target := path if path != "" else scene_path
	var spawn_id := StringName(spawn_name) if spawn_name != "" else spawn
	var time := fade if fade >= 0.0 else fade_time
 
	if target == "" or not ResourceLoader.exists(target):
		push_warning("SceneTeleport '%s': scene '%s' not found" % [name, target])
		teleported.emit.call_deferred()
		return
 
	await RoomManager.change_room(target, spawn_id, time)
	# Only reached if this node survived (e.g. the change failed or was already running)
	teleported.emit()
