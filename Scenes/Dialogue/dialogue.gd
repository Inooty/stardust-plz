extends CanvasLayer

signal finished

# =====================================================================
# Scene tree expected:
#   Dialogue (CanvasLayer, this script)
#   ├─ Control
#   │   ├─ NameBG        (NinePatchRect)   name tab background
#   │   ├─ DialogueBG    (NinePatchRect)   main box background
#   │   ├─ NameLabel     (RichTextLabel)   fit_content ON, autowrap OFF
#   │   ├─ VBoxContainer
#   │   │   ├─ RichTextLabel               dialogue text (BBCode ON)
#   │   │   └─ HBoxContainer               choice buttons
#   │   └─ FinishTriangle (AnimatedSprite2D, "default" animation)
#   ├─ AudioStreamPlayer
#   └─ AnimationPlayer                     "popup" and "begone"
#
# Custom tags (stripped before display):
#   [speed=0.3]...[/speed]   multiplier of textspeed (1 = normal, "30%" also ok)
#   [pause=0.5]              wait before the next letter
# Everything else is normal BBCode: [shake], [wave], [bgcolor], [color]...
#
# Resources understood in the dialogue array:
#   DialogueText, DialogueChoice, DialogueFunction, DialogueJump
# =====================================================================

const DIALOGUE_BUTTON = preload("res://Scenes/Dialogue/button.tscn")
const NO_CAMERA := Vector2(999.999, 999.999)
const NAME_PADDING := 12.0
const TEXT_PADDING := 12.0
const ARROW_SOUND_PATH := "res://Assets/Dialogue/SFX/finisharrow.wav"

@onready var label: RichTextLabel = $Control/VBoxContainer/RichTextLabel
@onready var button_container: HBoxContainer = $Control/VBoxContainer/HBoxContainer
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var anim: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var name_bg: NinePatchRect = get_node_or_null("Control/NameBG")
@onready var name_label: RichTextLabel = get_node_or_null("Control/NameLabel")
@onready var arrow: AnimatedSprite2D = find_child("FinishTriangle", true, false) as AnimatedSprite2D

var arrow_sound: AudioStreamPlayer

var dialogue: Array[DE] = []     # set by the Area2D before add_child()
var sets := {}                   # id -> Array[DE], set by the Area2D (for jumps)
var lock_player := true          # set by the Area2D
var anchor_bottom := false       # set by the Area2D
var bottom_margin := 16.0        # set by the Area2D
var current_dialogue_item := 0
var next_item := true
var _finished_emitted := false

# Folder listings are cached so each folder is only scanned once per run
static var _folder_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("dialogue")   # lets other scripts check if a dialogue is open

	# Padding inside the dialogue text label
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = TEXT_PADDING
	pad.content_margin_right = TEXT_PADDING
	pad.content_margin_top = TEXT_PADDING
	pad.content_margin_bottom = TEXT_PADDING
	label.add_theme_stylebox_override("normal", pad)

	# Sound for the finish arrow (created here, no scene node needed)
	if ResourceLoader.exists(ARROW_SOUND_PATH):
		arrow_sound = AudioStreamPlayer.new()
		arrow_sound.stream = load(ARROW_SOUND_PATH)
		add_child(arrow_sound)

	hide()
	button_container.hide()
	if name_bg:
		name_bg.hide()
	if name_label:
		name_label.hide()
	if arrow:
		arrow.stop()
		arrow.hide()

	if anchor_bottom:
		_anchor_to_bottom()


# If the box is removed early (e.g. a room change), still tell anyone waiting on it
func _exit_tree() -> void:
	if not _finished_emitted:
		_finished_emitted = true
		finished.emit()


func _process(_delta: float) -> void:
	# Finished the whole array
	if current_dialogue_item >= dialogue.size():
		_finish()
		return

	if not next_item:
		return
	next_item = false

	var i = dialogue[current_dialogue_item]
	if i is DialogueFunction:
		if i.hidebox:
			hide()
		else:
			_show_box()
		_function_resource(i)
	elif i is DialogueChoice:
		_show_box()
		_choice_resource(i)
	elif i is DialogueText:
		_show_box()
		_text_resource(i)
	elif i is DialogueJump:
		_jump_to(i.target)
		next_item = true
	else:
		push_error("Dialogue: an empty or DE resource is in the array, remove it. Skipping.")
		current_dialogue_item += 1
		next_item = true


# =====================================================================
# Jump to another named set (empty or unknown id ends the dialogue)
# =====================================================================
func _jump_to(id: StringName) -> void:
	if id != &"" and sets.has(id):
		dialogue.assign(sets[id])
		current_dialogue_item = 0
	else:
		if id != &"":
			push_warning("Dialogue: no set named '%s'" % id)
		current_dialogue_item = dialogue.size()


# =====================================================================
# Safe frame wait: works even if we get removed from the tree meanwhile.
# Returns false if the box is gone, so the caller should stop.
# =====================================================================
func _next_frame() -> bool:
	await (Engine.get_main_loop() as SceneTree).process_frame
	return is_inside_tree()


# =====================================================================
# Show / hide with animations
# =====================================================================
# Shows the box and plays popup, but only if it was hidden before
func _show_box() -> void:
	if visible:
		return
	if anim and anim.has_animation("popup"):
		anim.play("popup")
		anim.advance(0)   # apply the first keyframe right now, before anything is drawn
	show()


# Plays begone (if the box is showing), then unlocks the player and frees the box
func _finish() -> void:
	set_process(false)   # stop _process from re-entering while the animation runs
	_hide_arrow()
	if visible and anim and anim.has_animation("begone"):
		anim.play("begone")
		await anim.animation_finished
		if not is_inside_tree():
			return
	if lock_player:
		set_players_move(true)
	if not _finished_emitted:
		_finished_emitted = true
		finished.emit()
	queue_free()


# =====================================================================
# Finish arrow (the little triangle shown when the text is complete)
# =====================================================================
func _show_arrow() -> void:
	if arrow == null:
		return
	arrow.show()
	arrow.play("default")
	if arrow_sound:
		arrow_sound.play()


func _hide_arrow() -> void:
	if arrow == null:
		return
	arrow.stop()
	arrow.hide()


# =====================================================================
# Markup parsing: removes [speed] / [pause] and records them per letter
# Returns { "text": clean bbcode, "speeds": Array[float], "pauses": Dictionary }
#   speeds[n]  = speed multiplier for visible letter n
#   pauses[n]  = seconds to wait before visible letter n
# =====================================================================
func _parse_markup(src: String) -> Dictionary:
	var out := ""
	var speeds: Array[float] = []
	var pauses := {}
	var speed := 1.0
	var pending_pause := 0.0
	var p := 0
	var n := src.length()

	while p < n:
		var chunk := src[p]
		var step := 1
		var is_letter := true

		if chunk == "[":
			var close := src.find("]", p)
			if close != -1:
				var tag := src.substr(p + 1, close - p - 1)
				chunk = "[" + tag + "]"
				step = close - p + 1
				if tag.begins_with("speed="):
					speed = _parse_speed(tag.substr(6))
					chunk = ""
					is_letter = false
				elif tag == "/speed":
					speed = 1.0
					chunk = ""
					is_letter = false
				elif tag.begins_with("pause="):
					pending_pause += tag.substr(6).to_float()
					chunk = ""
					is_letter = false
				elif tag == "lb" or tag == "rb":
					pass   # these render as one visible character
				else:
					is_letter = false   # normal BBCode tag, passes through

		out += chunk
		if is_letter:
			if pending_pause > 0.0:
				pauses[speeds.size()] = pending_pause
				pending_pause = 0.0
			speeds.append(speed)
		p += step

	return {"text": out, "speeds": speeds, "pauses": pauses}


func _parse_speed(s: String) -> float:
	s = s.strip_edges()
	if s.ends_with("%"):
		return maxf(s.trim_suffix("%").to_float() / 100.0, 0.001)
	return maxf(s.to_float(), 0.001)


# =====================================================================
# Typewriter: types `text` using the speed/sound settings of resource `i`
# (works for both DialogueText and DialogueChoice).
# Returns false if the box was removed meanwhile.
# =====================================================================
func _reveal(text: String, i) -> bool:
	var parsed_markup := _parse_markup(text)
	var speeds: Array[float] = parsed_markup["speeds"]
	var pauses: Dictionary = parsed_markup["pauses"]

	label.visible_characters = 0
	label.text = parsed_markup["text"]
	var total: int = label.get_total_character_count()   # ignores BBCode automatically
	var timer := 0.0
	var last_pause_idx := -1

	while label.visible_characters < total:
		if Input.is_action_just_pressed("ui_cancel"):
			label.visible_characters = total
			break

		var idx := label.visible_characters

		# Start of a pause: make the timer negative so it has to climb back past zero
		if pauses.has(idx) and last_pause_idx != idx:
			last_pause_idx = idx
			timer = -float(pauses[idx])

		var mult: float = speeds[idx] if idx < speeds.size() else 1.0
		var interval: float = 1.0 / (float(i.textspeed) * mult)

		timer += get_process_delta_time()
		var plain := label.get_parsed_text()
		var is_space := idx < plain.length() and plain[idx] == " "

		if timer >= interval or (is_space and timer >= 0.0):
			label.visible_characters += 1
			if not is_space and audio.stream:
				audio.pitch_scale = randf_range(i.textpitchmin, i.textpitchmax)
				audio.play()
			timer = 0.0
		if not await _next_frame():
			return false
	return true


# =====================================================================
# Function block
# =====================================================================
func _function_resource(i: DialogueFunction) -> void:
	await _run_function(i)
	if not is_inside_tree():
		return
	current_dialogue_item += 1
	next_item = true


# Resolve a NodePath stored in a resource
func _find_target(path: NodePath) -> Node:
	if path.is_empty():
		return null
	var n: Node = null
	if get_tree().current_scene:
		n = get_tree().current_scene.get_node_or_null(path)
	if n == null:
		n = get_node_or_null(path)
	if n == null:
		n = get_tree().root.get_node_or_null(path)
	return n


# Call a function, optionally wait for a signal
func _run_function(f: DialogueFunction) -> void:
	var target := _find_target(f.targetpath)
	if target == null:
		push_warning("Dialogue: could not find target node at path '%s'" % f.targetpath)
		return
	if not target.has_method(f.funcname):
		push_warning("Dialogue: target has no method '%s'" % f.funcname)
		return

	if f.funcarg.is_empty():
		target.call(f.funcname)
	else:
		target.callv(f.funcname, f.funcarg)

	if f.waitsignal != "":
		if target.has_signal(f.waitsignal):
			await Signal(target, f.waitsignal)   # works with any number of signal args
		else:
			push_warning("Dialogue: target has no signal '%s'" % f.waitsignal)


# =====================================================================
# Choice block
# =====================================================================
func _choice_resource(i: DialogueChoice) -> void:
	_hide_arrow()
	_set_speaker(i.speaker)
	button_container.hide()
	audio.stream = _build_sound(i)
	audio.volume_db = i.textvolume

	# Type the question first, then reveal the buttons
	if not await _reveal(i.text, i):
		return
	button_container.show()

	var first_btn: Button = null
	for n in i.choicetext.size():
		var holder: Node = DIALOGUE_BUTTON.instantiate()
		var btn := holder as Button
		if btn == null:
			# Root isn't the Button (e.g. a Control/MarginContainer), so look inside it
			var found := holder.find_children("*", "Button", true, false)
			if found.is_empty():
				push_error("Dialogue: button.tscn contains no Button node")
				holder.queue_free()
				continue
			btn = found[0]
		btn.text = i.choicetext[n]
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())   # removes the focus outline
		var f: DialogueFunction = i.choicetextcall[n] if n < i.choicetextcall.size() else null
		var jump: StringName = i.choicejump[n] if n < i.choicejump.size() else &""
		btn.pressed.connect(_on_choice_pressed.bind(f, jump), CONNECT_ONE_SHOT)
		button_container.add_child(holder)
		if first_btn == null:
			first_btn = btn

	if first_btn:
		first_btn.grab_focus()


func _on_choice_pressed(f: DialogueFunction, jump: StringName) -> void:
	button_container.hide()
	for c in button_container.get_children():
		c.queue_free()

	if f != null:
		if f.hidebox:
			hide()
		await _run_function(f)
		if not is_inside_tree():
			return

	if jump != &"":
		_jump_to(jump)
	else:
		current_dialogue_item += 1
	next_item = true


# =====================================================================
# Text block
# =====================================================================
func _text_resource(i: DialogueText) -> void:
	_hide_arrow()
	_set_speaker(i.speaker)
	audio.stream = _build_sound(i)
	audio.volume_db = i.textvolume

	# Camera move
	var cam := get_viewport().get_camera_2d()
	if cam and not i.camerapos.is_equal_approx(NO_CAMERA):
		var tween := create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(cam, "global_position", i.camerapos, i.cameratranstime)

	if not await _reveal(i.text, i):
		return

	# Text finished: show the arrow and wait for "next"
	_show_arrow()
	while true:
		$AnimationPlayer.play("arrow")
		if not await _next_frame():
			return
		if Input.is_action_just_pressed("ui_accept"):
			break
	_hide_arrow()

	current_dialogue_item += 1
	next_item = true


# =====================================================================
# Bottom anchor (used when the player is NOT locked)
# =====================================================================
func _anchor_to_bottom() -> void:
	if not await _next_frame():   # let the layout settle
		return
	var box: Control = get_node_or_null("Control/DialogueBG")
	if box == null:
		box = get_node_or_null("Control/BoxBG")
	if box == null:
		box = $Control
	var r := box.get_global_rect()
	var vp_size := get_viewport().get_visible_rect().size
	offset = Vector2(
		vp_size.x / 2.0 - (r.position.x + r.size.x / 2.0),
		vp_size.y - bottom_margin - (r.position.y + r.size.y)
	)


# =====================================================================
# Speaker name tab
# =====================================================================
func _set_speaker(speaker: String) -> void:
	if name_bg == null or name_label == null:
		return
	var has_name := speaker != ""
	name_bg.visible = has_name
	name_label.visible = has_name
	if not has_name:
		return

	name_label.text = speaker
	if not await _next_frame():          # let the label measure its text
		return
	var w := name_label.get_content_width()
	name_bg.size.x = w + NAME_PADDING * 2.0
	name_label.position.x = name_bg.position.x + NAME_PADDING
	name_label.size.x = w + 1.0             # a pixel of slack so the last letter isn't clipped


# =====================================================================
# Text sounds: folder (random) wins, otherwise the single textsound
# Untyped parameter so it works for DialogueText and DialogueChoice.
# =====================================================================
func _build_sound(i) -> AudioStream:
	var streams: Array[AudioStream] = []
	if i.textsoundfolder != "":
		streams = _folder_sounds(i.textsoundfolder)
	if streams.is_empty():
		return i.textsound
	if streams.size() == 1:
		return streams[0]
	# Randomizer picks a different sound each play and keeps polyphony working
	var r := AudioStreamRandomizer.new()
	for st in streams:
		r.add_stream(-1, st)
	return r


func _folder_sounds(folder: String) -> Array[AudioStream]:
	if _folder_cache.has(folder):
		return _folder_cache[folder]

	var result: Array[AudioStream] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		push_warning("Dialogue: can't open sound folder '%s'" % folder)
	else:
		var seen := {}
		for f in dir.get_files():
			# Exported games list 'name.wav.import' / 'name.wav.remap', not the raw file
			var fname := f.trim_suffix(".import").trim_suffix(".remap")
			if seen.has(fname):
				continue
			if fname.get_extension().to_lower() in ["wav", "ogg", "mp3"]:
				seen[fname] = true
				var st = load(folder.path_join(fname))
				if st is AudioStream:
					result.append(st)
		if result.is_empty():
			push_warning("Dialogue: no audio files found in '%s'" % folder)

	_folder_cache[folder] = result
	return result


# =====================================================================
# Freeze / unfreeze every character in the "player" group
# =====================================================================
func set_players_move(value: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "move" in p:
			p.move = value
		else:
			push_warning("%s is in group 'player' but has no 'move' variable" % p.name)
