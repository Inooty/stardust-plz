extends Node

# scene_path -> { node_path (String) -> state Dictionary }
var rooms := {}
var suppress_capture := false   # set when loading a save, so the old room doesn't overwrite it


# RigidBody2Ds, anything in "persist" (deleted if it was gone), and anything in
# "persist_state" (state only, never deleted)
func _tracked(scene: Node) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for n in scene.find_children("*", "Node2D", true, true):
		if n is RigidBody2D or n.is_in_group("persist") or n.is_in_group("persist_state"):
			out.append(n)
	return out


func capture() -> void:
	if suppress_capture:
		suppress_capture = false
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == "":
		return

	var record := {}
	for n in _tracked(scene):
		if n.is_queued_for_deletion():
			continue
		var d := {
			"pos": n.global_position,
			"rot": n.global_rotation,
			"scale": n.scale,
			"visible": n.visible,
		}
		if n.has_method("save_state"):
			d["custom"] = n.save_state()
		record[str(scene.get_path_to(n))] = d
	rooms[scene.scene_file_path] = record


func restore() -> void:
	var scene := get_tree().current_scene
	if scene == null or not rooms.has(scene.scene_file_path):
		return
	var record: Dictionary = rooms[scene.scene_file_path]

	for n in _tracked(scene):
		var key := str(scene.get_path_to(n))
		if not record.has(key):
			if not n.is_in_group("persist_state"):
				n.queue_free()   # it was gone when we left
			continue
		var d: Dictionary = record[key]
		if not n.is_in_group("persist_state"):
			n.global_position = d["pos"]
			n.global_rotation = d["rot"]
			n.scale = d["scale"]
			n.visible = d["visible"]
			if n is RigidBody2D:
				var body := n as RigidBody2D
				body.linear_velocity = Vector2.ZERO
				body.angular_velocity = 0.0
				PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(d["rot"], d["pos"]))
		if d.has("custom") and n.has_method("load_state"):
			n.load_state(d["custom"])


func reset() -> void:
	rooms.clear()
