@tool
extends Node2D
 
# One script for the whole button. Attach it to the ROOT node of button.tscn
# (the Node2D with NinePatchRect "Button", RichTextLabel and Area2D under it).
 
@export var text := "Button":
	set(value):
		text = value
		if is_node_ready():
			refresh()
@export var padding := Vector2(12, 6):
	set(value):
		padding = value
		if is_node_ready():
			refresh()
@export var min_size := Vector2(48, 20)
 
@export_group("Action")
@export_file("*.tscn") var target_room: String      # scene this button goes to
@export var quit_game := false                      # ON = quits the game instead of changing scene
@export var target_spawn: StringName = &""          # Marker2D name in the target room (optional)
@export var fade_time := 0.5
@export var click_action: StringName = &"use"
 
@export_group("Look")
@export var hover_color := Color(1.0, 0.88, 0.25)   # text colour while the cursor is on the button
 
@onready var bg: NinePatchRect = $Button
@onready var label: RichTextLabel = $RichTextLabel
@onready var area: Area2D = get_node_or_null("Area2D")
@onready var collision: CollisionShape2D = get_node_or_null("Area2D/CollisionShape2D")
 
var player: Node2D
var hovering := false
var _ponder_set := false
var _busy := false
var _base_modulate := Color.WHITE
 
 
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	refresh()
 
	# Everything below is game logic, it must not run inside the editor
	set_process(not Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	_base_modulate = label.modulate
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
 
 
func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_set_ponder(false)
	_set_highlight(false)
 
 
# =====================================================================
# Layout: frame and click area grow around the text
# =====================================================================
func refresh() -> void:
	if not is_inside_tree():
		return
	label.text = text
	label.size = Vector2.ZERO
	await get_tree().process_frame
	var content := Vector2(label.get_content_width(), label.get_content_height())
	var box := (content + padding * 2.0).max(min_size).ceil()
	bg.size = box
	bg.position = (-box / 2.0).round()
	label.size = content
	label.position = (-content / 2.0).round()
	_fit_area(box)
 
 
# Makes the click area exactly as big as the button, and keeps it centred on it
func _fit_area(box: Vector2) -> void:
	if collision == null:
		return
	# A fresh shape each time: the scene's shape is shared between every copy of the
	# button, so resizing it in place would resize all of them together
	var rect := RectangleShape2D.new()
	rect.size = box
	collision.shape = rect
	var area_offset := area.position if area else Vector2.ZERO
	collision.position = bg.position + box * 0.5 - area_offset
 
 
# =====================================================================
# Hover + click
# =====================================================================
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		hovering = true
 
 
func _on_body_exited(body: Node2D) -> void:
	if body == player:
		hovering = false
		_set_ponder(false)
		_set_highlight(false)
 
 
func _process(_delta: float) -> void:
	if not hovering or _busy or not is_instance_valid(player):
		return
	if "holding" in player and player.holding:
		_set_ponder(false)
		_set_highlight(false)
		return
 
	_set_ponder(true)   # re-applied every frame so nothing else can wipe it
	_set_highlight(true)
 
	if Input.is_action_just_pressed(click_action):
		_activate()
 
 
func _activate() -> void:
	if quit_game:
		get_tree().quit()
		return
	if target_room == "" or not ResourceLoader.exists(target_room):
		push_warning("Button '%s': target_room is not set or doesn't exist" % name)
		return
 
	_busy = true
	_set_ponder(false)
 
	# Uses your RoomManager (fade + spawn marker) if it exists, plain scene change otherwise
	var rm = get_node_or_null("/root/RoomManager")
	if rm:
		await rm.change_room(target_room, target_spawn, fade_time)
		_busy = false   # only reached if this node survived (the change failed)
	else:
		get_tree().change_scene_to_file(target_room)
 
 
func _set_highlight(value: bool) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.modulate = hover_color if value else _base_modulate
 
 
# Only turns the ponder image off if this button was the one that turned it on
func _set_ponder(value: bool) -> void:
	if not is_instance_valid(player) or not ("pondering" in player):
		_ponder_set = false
		return
	if value:
		_ponder_set = true
		player.pondering = true
	elif _ponder_set:
		_ponder_set = false
		player.pondering = false
