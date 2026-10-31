extends Control
 
const MENU_SIZE := Vector2(280, 160)   # screen pixels (the script cancels out camera zoom)
const GAP := 24.0                      # space between the checkpoint and the menu
const PADDING := 8              # space between the box edge and the buttons
const FONT_SIZE := 18
const HOVER_COLOR := Color(1.0, 0.92, 0.2)   # yellow: hovered + selected slot
const DISABLED_COLOR := Color(0.5, 0.5, 0.5)
const FADE_TIME := 1          # fade in / fade out duration
const FADE_DELAY := 2           # seconds outside the menu before it fades away
const INSIDE_MARGIN := 4.0             # extra forgiveness around the stay zone (screen pixels)
const STAY_WIDTH := 170          # width of the zone that keeps the menu open (screen pixels, centered, can't exceed MENU_SIZE.x)
 
# Optional: drag your shader material here. If empty, an unshaded material is used,
# which makes the menu ignore Light2D (but NOT the CanvasModulate tint).
@export var ui_material: Material
 
var save_position := Vector2.ZERO      # world position, set by the checkpoint
var checkpoint_name := "Unknown"       # set by the checkpoint
var hitbox: CollisionShape2D           # the player's hitbox, set by the checkpoint (falls back to the player's origin point)
var player_inside := false             # true while the player's hitbox overlaps the menu; read by the checkpoint
var keep_open := false                 # set by the checkpoint every frame: true while the player is next to it
var closing := false
 
var _player: Node2D
var _alpha := 0.0
var _outside_time := 0.0
var _menu_shape := RectangleShape2D.new()   # reused every frame for the hitbox overlap test
var _slots: Array[Button] = []
var _group := ButtonGroup.new()
var _selected := -1                    # index into _slots, -1 = nothing selected
var _buttons: Array[Button] = []       # every clickable button, for the per-frame hover check
var _hovered: Button = null            # the button the mouse is over right now
var _base_color := Color.WHITE         # normal text color
 
@onready var bg: NinePatchRect = $DialogueBG
@onready var box: VBoxContainer = $DialogueBG/VBoxContainer
@onready var slot1: Button = $DialogueBG/VBoxContainer/Slot1
@onready var slot2: Button = $DialogueBG/VBoxContainer/Slot2
@onready var slot3: Button = $DialogueBG/VBoxContainer/Slot3
@onready var save_btn: Button = $DialogueBG/VBoxContainer/Save
@onready var load_btn: Button = $DialogueBG/VBoxContainer/Load
 
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
 
	bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bg.position = Vector2.ZERO
	bg.size = MENU_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
 
	if box.has_node("Close"):
		box.get_node("Close").queue_free()
 
	# Put Save and Load side by side in one row. The row keeps its height even while
	# the buttons are hidden, so the slots don't jump around when you select one.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size.y = FONT_SIZE + 16
	box.add_child(row)
	save_btn.reparent(row, false)
	load_btn.reparent(row, false)
 
	box.call_deferred("set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PADDING)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)   # no gaps between rows, so the mouse never hits a dead zone
	_base_color = slot1.get_theme_color("font_color")  # normal text color, restored when a button stops being hovered
 
	# Slot buttons: toggles, only one selected at a time, click again to deselect
	_slots = [slot1, slot2, slot3]
	_group.allow_unpress = true
	for i in _slots.size():
		var b := _slots[i]
		_style_button(b)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL   # rows fill the box edge to edge
		b.custom_minimum_size.y = FONT_SIZE + 12
		b.toggle_mode = true
		b.button_group = _group
		b.text = _label_for(i + 1)
	_group.pressed.connect(_on_slot_group_pressed)
 
	# Save / Load buttons
	for b in [save_btn, load_btn]:
		_style_button(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_color_override("font_disabled_color", DISABLED_COLOR)
	save_btn.text = "Save"
	load_btn.text = "Load"
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)
	_buttons = [slot1, slot2, slot3, save_btn, load_btn]
 
	_apply_material()
	_refresh_buttons()
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_update_transform()
 
func _style_button(b: Button) -> void:
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS   # react on mouse-down, not on release
	# Selected slots stay yellow. Hover is NOT left to Godot's own hover state (see _update_hover),
	# so its hover/focus colors are set to the normal color.
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, HOVER_COLOR)
	for c in ["font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, _base_color)
 
func _apply_material() -> void:
	var mat: Material = ui_material
	if mat == null:
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		mat = m
	bg.material = mat
	for c in bg.find_children("*", "CanvasItem", true, false):
		(c as CanvasItem).use_parent_material = true
 
func close() -> void:
	closing = true
 
# --- Slot selection -------------------------------------------------------------
 
func _on_slot_group_pressed(_button: BaseButton) -> void:
	_selected = _slots.find(_group.get_pressed_button())   # -1 when nothing is selected
	_refresh_buttons()
 
func _refresh_buttons() -> void:
	var has_selection := _selected >= 0
	save_btn.visible = has_selection
	load_btn.visible = has_selection
	if has_selection:
		var existing = SaveManager.read_slot(SaveManager.current_campaign, _selected + 1)
		load_btn.disabled = existing == null     # nothing to load from an empty slot
 
# --- Save / Load ----------------------------------------------------------------
 
func _on_save_pressed() -> void:
	if closing or _selected < 0:
		return
	var slot := _selected + 1
	SaveManager.save_game(slot, save_position, checkpoint_name)
	_slots[_selected].text = _label_for(slot)
	_refresh_buttons()                           # Load becomes available after the first save
 
	save_btn.text = "Saved!"
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(save_btn):
		save_btn.text = "Save"
 
func _on_load_pressed() -> void:
	if closing or _selected < 0:
		return
	closing = true
	SaveManager.load_game(SaveManager.current_campaign, _selected + 1)
 
func _label_for(slot: int) -> String:
	var s := SaveManager.read_slot(SaveManager.current_campaign, slot)
	if s == null:
		return "Slot %d - Empty" % slot
	var place: String = s.checkpoint_name if s.checkpoint_name != "" else "Unknown"
	return "Slot %d - %s" % [slot, place]
 
# --- Fade / placement -----------------------------------------------------------
 
func _process(delta: float) -> void:
	_update_transform()
	_update_hover()
	_update_outside(delta)
 
	var target := 1.0
	if closing or _outside_time > FADE_DELAY:
		target = 0.0
	_alpha = move_toward(_alpha, target, delta / FADE_TIME)
	modulate.a = _alpha
	if target == 0.0 and _alpha <= 0.0:
		queue_free()
 
# Hover is worked out every frame from the mouse position, instead of waiting for Godot's
# mouse-motion events. The menu lives in the world, so when the camera or player moves it
# slides under a still cursor, and the built-in hover state goes stale until the mouse moves.
func _update_hover() -> void:
	var now: Button = null
	if not closing and _alpha > 0.05:
		for b in _buttons:
			if b.is_visible_in_tree() and not b.disabled \
					and Rect2(Vector2.ZERO, b.size).has_point(b.get_local_mouse_position()):
				now = b
				break
	if now == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.add_theme_color_override("font_color", _base_color)
	if now != null:
		now.add_theme_color_override("font_color", HOVER_COLOR)
	_hovered = now
 
func _update_transform() -> void:
	# Fixed spot in the world above the checkpoint. Only the camera ZOOM is read, never its
	# position, so the menu moves with the world and can't lag behind it.
	var zoom := get_viewport().get_canvas_transform().get_scale()
	var parent_scale := Vector2.ONE
	if get_parent() is CanvasItem:
		parent_scale = (get_parent() as CanvasItem).get_global_transform().get_scale()
	scale = Vector2.ONE / (zoom * parent_scale)
	global_position = save_position + Vector2(-MENU_SIZE.x / 2.0, -MENU_SIZE.y - GAP) / zoom
 
func _update_outside(delta: float) -> void:
	if _player == null:
		return
	var zoom := get_viewport().get_canvas_transform().get_scale()
	# The stay zone is narrower than the visible menu: same height, centered horizontally
	var stay_w := minf(STAY_WIDTH, MENU_SIZE.x)
	var zone_pos := global_position + Vector2((MENU_SIZE.x - stay_w) / 2.0, 0.0) / zoom
	var rect := Rect2(zone_pos, Vector2(stay_w, MENU_SIZE.y) / zoom).grow(INSIDE_MARGIN / zoom.x)
	player_inside = _hitbox_overlaps(rect)
	if player_inside or keep_open:
		_outside_time = 0.0
	else:
		_outside_time += delta
 
# True if the player's actual hitbox overlaps the (world-space) menu rect.
# Falls back to the player's origin point if no hitbox was given.
func _hitbox_overlaps(rect: Rect2) -> bool:
	if not is_instance_valid(hitbox) or hitbox.shape == null or hitbox.disabled:
		return rect.has_point(_player.global_position)
	_menu_shape.size = rect.size
	return hitbox.shape.collide(hitbox.global_transform, _menu_shape, Transform2D(0.0, rect.get_center()))
 
