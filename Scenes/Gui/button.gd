@tool
extends Node2D

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

@onready var bg: NinePatchRect = $Button
@onready var label: RichTextLabel = $RichTextLabel

func _ready() -> void:
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	refresh()

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
