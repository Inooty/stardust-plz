extends Node

var camera: Camera2D
var player: Node2D

var defzoom: Vector2 = Vector2(2, 2)
var speed: float = 5
var speedzoom: float = 5

var actzones: Array[CameraZone]
var latched: CameraZone = null
var anchors: Dictionary = {}

func register_anchor(a: Anchor) -> void:
	print("registered anchor with id: ", a.id)
	if anchors.has(a.id):
		push_warning("Oh No! Duplicate ID %d!" % a.id)
	anchors[a.id] =a

func unregister_anchor(a: Anchor) -> void:
	print("unregistered anchor with id: ", a.id)
	if anchors.get(a.id) == a:
		anchors.erase(a.id)

func register_zone(z: CameraZone) -> void:
	if z not in actzones:
		actzones.append(z)
	latched = null

func unregister_zone(z: CameraZone) -> void:
	actzones.erase(z)
	if z.sticky and actzones.is_empty():
		latched = z

func _process(delta: float) -> void:
	if camera == null or player ==null:
		return
	var winner: CameraZone = null
	for z in actzones:
		if winner == null or z.campriority > winner.campriority:
			winner = z
	if winner == null:
		winner = latched

	var targetpos: Vector2 = player.global_position
	var targetzoom: Vector2 = defzoom
	var curspeed: float = speed
	var curzoomspeed: float = speedzoom

	if winner != null:
		if winner.camoverride:
			curspeed = winner.camspeed
			curzoomspeed = winner.zoomspeed
		if winner.anchor:
			var anchor: Anchor = anchors.get(winner.anchorid)
			if anchor != null:
				targetpos = anchor.global_position
				if anchor.zoomover:
					targetzoom = anchor.zoom
			else:
				push_warning("No Anchor ID with %d! Register IDs: %s" % [winner.anchorid, str(anchors.keys())])
		if winner.applyzoom:
			targetzoom = winner.zoom

	camera.global_position = camera.global_position.lerp(targetpos, 1.0 - exp(-curspeed * delta))
	camera.zoom = camera.zoom.lerp(targetzoom,  1.0 - exp(-curzoomspeed * delta))
