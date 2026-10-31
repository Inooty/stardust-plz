extends CanvasLayer
 
signal finished
 
# Scene tree expected:
#   Dialogue (CanvasLayer, this script)
#   ├─ Control
#   │   ├─ NameBG, DialogueBG, NameLabel
#   │   ├─ VBoxContainer (RichTextLabel, HBoxContainer)
#   │   └─ FinishTriangle (AnimatedSprite2D)
#   ├─ AudioStreamPlayer
#   └─ AnimationPlayer   "popup", "begone", "arrow"
#
# Custom tags: [speed=0.3]...[/speed]  [pause=0.5]
 
const DIALOGUE_BUTTON = preload("res://Scenes/Dialogue/button.tscn")
const NO_CAMERA := Vector2(999.999, 999.999)
const NAME_PADDING := 12.0
const TEXT_PADDING := 12.0
const ARROW_SOUND_PATH := "res://Assets/Dialogue/SFX/finisharrow.wav"
const ZOOM_RESTORE_TIME := 0.4
const ALWAYS_BOTTOM := true   # every dialogue sits at the bottom, locked or not
const RESUME_IDLE := true     # restart paused/replaced idle animations when the dialogue ends
const MAX_ANIM_WAIT := 20.0   # an animation-only line never waits longer than this (seconds)
 
@onready var label: RichTextLabel = $Control/VBoxContainer/RichTextLabel
@onready var button_container: HBoxContainer = $Control/VBoxContainer/HBoxContainer
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var anim: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var name_bg: NinePatchRect = get_node_or_null("Control/NameBG")
@onready var name_label: RichTextLabel = get_node_or_null("Control/NameLabel")
@onready var arrow: AnimatedSprite2D = find_child("FinishTriangle", true, false) as AnimatedSprite2D
 
var arrow_sound: AudioStreamPlayer
 
var dialogue: Array[DE] = []     # set by the Area2D
var sets := {}                   # id -> Array[DE], set by the Area2D
var lock_player := true          # set by the Area2D
var anchor_bottom := false       # set by the Area2D
var bottom_margin := 16.0        # set by the Area2D
var restore_zoom := true         # set by the Area2D
var stop_animations := true      # set by the Area2D: stop line animations (and resume idle) when the dialogue ends
var origin: Node = null          # set by the Area2D (node that node paths in the resources are relative to)
var current_dialogue_item := 0
var next_item := true
var _finished_emitted := false
var _zoom_changed := false
var _zoom_before := Vector2.ONE
var _zoom_target := Vector2.ONE
var _zoom_hold := false
var _played_players: Array[AnimationPlayer] = []   # stopped when the dialogue ends
var _played_sprites: Array[AnimatedSprite2D] = []  # stopped when the dialogue ends
var _suspended_idle := {}                          # AnimationPlayer -> idle animation name, resumed at the end
 
static var _folder_cache: Dictionary = {}
 
 
func _ready() -> void:
	add_to_group("dialogue")
 
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = TEXT_PADDING
	pad.content_margin_right = TEXT_PADDING
	pad.content_margin_top = TEXT_PADDING
	pad.content_margin_bottom = TEXT_PADDING
	label.add_theme_stylebox_override("normal", pad)
 
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
 
	if anchor_bottom or ALWAYS_BOTTOM:
		_anchor_to_bottom()
 
 
func _exit_tree() -> void:
	if not _finished_emitted:
		_finished_emitted = true
		finished.emit()
 
 
func _process(_delta: float) -> void:
	# Hold the zoom every frame so nothing else can reset it mid-dialogue
	if _zoom_hold:
		var zc := get_viewport().get_camera_2d()
		if zc:
			zc.zoom = _zoom_target
 
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
		if not _has_text(i):
			hide()   # no text: no box
		else:
			_show_box()
		_text_resource(i)
	elif i is DialogueJump:
		_jump_to(i.target)
		next_item = true
	else:
		push_error("Dialogue: an empty or DE resource is in the array, remove it. Skipping.")
		current_dialogue_item += 1
		next_item = true
 
 
# Called by a newer dialogue taking over the screen
func dismiss() -> void:
	_stop_line_animations()
	_restore_camera_zoom(true)
	set_process(false)
	remove_from_group("dialogue")
	hide()
	if not _finished_emitted:
		_finished_emitted = true
		finished.emit()
	queue_free()
 
 
func _jump_to(id: StringName) -> void:
	if id != &"" and sets.has(id):
		dialogue.assign(sets[id])
		current_dialogue_item = 0
	else:
		if id != &"":
			push_warning("Dialogue: no set named '%s'" % id)
		current_dialogue_item = dialogue.size()
 
 
func _next_frame() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	while is_inside_tree() and not can_process():
		await tree.process_frame
	return is_inside_tree()
 
 
# True if the line has anything to type out. Blank text, or text made only of
# tags like [pause=1] or [shake][/shake], counts as "no text".
func _has_text(i) -> bool:
	var t: String = i.text
	if t.strip_edges() == "":
		return false
	return _parse_markup(t)["speeds"].size() > 0
 
 
func _show_box() -> void:
	if visible:
		return
	if anim and anim.has_animation("popup"):
		anim.play("popup")
		anim.advance(0)
	show()
 
 
func _finish() -> void:
	set_process(false)
	_hide_arrow()
	_stop_line_animations()
	_restore_camera_zoom()
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
# Camera zoom + per-line animation (set in the DialogueText inspector)
# =====================================================================
func _apply_camera_zoom(i: DialogueText) -> void:
	if i.camerazoom <= 0.0:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		push_warning("Dialogue: no Camera2D found for zoom")
		return
	if not _zoom_changed:
		_zoom_before = cam.zoom
		_zoom_changed = true
	_zoom_target = Vector2.ONE * i.camerazoom
	_zoom_hold = false
	if i.camerazoomtime <= 0.0:
		cam.zoom = _zoom_target
		_zoom_hold = true
	else:
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(cam, "zoom", _zoom_target, i.camerazoomtime)
		tw.tween_callback(func(): _zoom_hold = true)
 
 
func _restore_camera_zoom(force := false) -> void:
	if not _zoom_changed or not (force or restore_zoom):
		return
	_zoom_changed = false
	_zoom_hold = false
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tw := cam.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(cam, "zoom", _zoom_before, ZOOM_RESTORE_TIME)
 
 
func _play_line_animation(i: DialogueText) -> Array:
	# Returns the non-looping players/sprites it started, so callers can wait on them
	var waitable: Array = []
 
	# AnimationPlayer
	if i.animationname != &"":
		var ap := _find_target(i.animationplayer) as AnimationPlayer
		if ap == null:
			push_warning("Dialogue: no AnimationPlayer at path '%s'" % i.animationplayer)
		elif not ap.has_animation(i.animationname):
			push_warning("Dialogue: '%s' has no animation '%s'" % [ap.name, i.animationname])
		else:
			_suspend_idle(ap)
			ap.play(i.animationname)
			if not _played_players.has(ap):
				_played_players.append(ap)
			if ap.get_animation(i.animationname).loop_mode == Animation.LOOP_NONE:
				waitable.append(ap)
				if i.persist_end:
					_persist_anim_end(ap, i)
 
	# AnimatedSprite2D
	if i.spriteanimation != &"":
		var sprite := _find_target(i.spritenode) as AnimatedSprite2D
		if sprite == null:
			push_warning("Dialogue: no AnimatedSprite2D at path '%s'" % i.spritenode)
		elif sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(i.spriteanimation):
			push_warning("Dialogue: '%s' has no sprite animation '%s'" % [sprite.name, i.spriteanimation])
		else:
			_suspend_idle(sprite)
			sprite.play(i.spriteanimation)
			if not _played_sprites.has(sprite):
				_played_sprites.append(sprite)
			if not sprite.sprite_frames.get_animation_loop(i.spriteanimation):
				waitable.append(sprite)
 
	return waitable
 
 
# Remembers a finished animation so the area can restore its last frame after a reload
func _persist_anim_end(ap: AnimationPlayer, i: DialogueText) -> void:
	var key: StringName = i.persist_key(ap)
	var anim_name: StringName = i.animationname
	while is_instance_valid(ap):
		var finished_name: StringName = await ap.animation_finished
		if finished_name == anim_name:
			GameState.set_flag(key)
			return
 
 
# Waits until every given animation has finished. Uses the animation_finished
# signals (an AnimatedSprite2D can report is_playing() == true on its last frame),
# with a time cap so a stuck animation can never keep the player locked forever.
func _wait_line_animations(started: Array) -> void:
	var pending := {}
	for n in started:
		pending[n] = true
		n.animation_finished.connect(func(_a = null): pending.erase(n), CONNECT_ONE_SHOT)
 
	var waited := 0.0
	while not pending.is_empty():
		if waited >= MAX_ANIM_WAIT:
			push_warning("Dialogue: gave up waiting for line animations after %s seconds" % MAX_ANIM_WAIT)
			return
		for n in pending.keys():
			if not is_instance_valid(n) or (n is AnimationPlayer and not n.is_playing()):
				pending.erase(n)
		if not await _next_frame():
			return
		waited += get_process_delta_time()
 
 
# Stops animations started by dialogue lines that are still playing.
# Ones that already finished are left alone so they keep their end pose.
func _stop_line_animations() -> void:
	if not stop_animations:
		# Leave everything as it is (no stopping, and idle stays put so it doesn't fight)
		_played_players.clear()
		_played_sprites.clear()
		_suspended_idle.clear()
		return
	for ap in _played_players:
		if is_instance_valid(ap) and ap.is_playing():
			ap.seek(0.0, true)   # snap back to the first frame of the animation
			ap.stop()
	for sprite in _played_sprites:
		if is_instance_valid(sprite) and sprite.is_playing():
			sprite.stop()
			sprite.frame = 0
			sprite.frame_progress = 0.0
	_played_players.clear()
	_played_sprites.clear()
	_resume_idle()
 
 
# Stops (and resets) idle AnimationPlayers that would fight with a line animation: the
# target itself (if it's a player) and any AnimationPlayer sibling of the target.
# Everything touched is remembered so it can be resumed when the dialogue ends.
func _suspend_idle(node: Node) -> void:
	var candidates: Array = []
	if node is AnimationPlayer:
		candidates.append(node)
	var parent := node.get_parent()
	if parent:
		for c in parent.get_children():
			if c is AnimationPlayer and c != node:
				candidates.append(c)
 
	for ap in candidates:
		# Skip ones we already handled, and ones playing line animations
		if _suspended_idle.has(ap) or _played_players.has(ap):
			continue
		if ap.is_playing() and ap.current_animation != &"":
			_suspended_idle[ap] = ap.current_animation
			if ap != node:
				ap.seek(0.0, true)   # reset to the first frame, then stop
				ap.stop()            # (the target player just gets replaced by play())
 
 
func _resume_idle() -> void:
	if RESUME_IDLE:
		for ap in _suspended_idle:
			if is_instance_valid(ap):
				ap.play(_suspended_idle[ap])   # restarts from the first frame
	_suspended_idle.clear()
 
 
# =====================================================================
# Finish arrow
# =====================================================================
func _show_arrow() -> void:
	if arrow == null:
		return
	arrow.show()
	arrow.play("default")
	if arrow_sound:
		arrow_sound.play()
	if anim and anim.has_animation("arrow"):
		anim.play("arrow")
 
 
func _hide_arrow() -> void:
	if arrow == null:
		return
	arrow.stop()
	arrow.hide()
 
 
# =====================================================================
# Markup parsing
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
					pass
				else:
					is_letter = false
 
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
# Typewriter (Enter / Escape completes the line instantly)
# =====================================================================
func _reveal(text: String, i) -> bool:
	var parsed_markup := _parse_markup(text)
	var speeds: Array[float] = parsed_markup["speeds"]
	var pauses: Dictionary = parsed_markup["pauses"]
 
	label.visible_characters = 0
	label.text = parsed_markup["text"]
	var total: int = label.get_total_character_count()
	var timer := 0.0
	var last_pause_idx := -1
 
	# Wait a frame so the press that advanced to this line doesn't skip it
	if not await _next_frame():
		return false
 
	while label.visible_characters < total:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
			label.visible_characters = total
			break
 
		var idx := label.visible_characters
 
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
 
 
func _find_target(path: NodePath) -> Node:
	if path.is_empty():
		return null
 
	# Paths picked in the inspector are relative to the node that owns the
	# resource (the Dialogue Area), so try that first.
	if origin and is_instance_valid(origin):
		var o := origin.get_node_or_null(path)
		if o:
			return o
 
	var n: Node = null
	if get_tree().current_scene:
		n = get_tree().current_scene.get_node_or_null(path)
	if n == null:
		n = get_node_or_null(path)
	if n == null:
		n = get_tree().root.get_node_or_null(path)
	return n
 
 
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
			await Signal(target, f.waitsignal)
		else:
			push_warning("Dialogue: target has no signal '%s'" % f.waitsignal)
 
 
# Runs the function embedded in a DialogueText, if it's enabled and set to this timing
func _run_text_function(i: DialogueText, timing: int) -> void:
	if not i.use_function or i.function_call == null:
		return
	if i.function_timing != timing:
		return
	if i.function_call.hidebox:
		hide()
	if i.function_blocks:
		await _run_function(i.function_call)
	else:
		_run_function(i.function_call)   # fire and forget
 
 
# =====================================================================
# Choice block
# =====================================================================
func _choice_resource(i: DialogueChoice) -> void:
	_hide_arrow()
	_set_speaker(i.speaker)
	button_container.hide()
	audio.stream = _build_sound(i)
	audio.volume_db = i.textvolume
 
	if not await _reveal(i.text, i):
		return
	button_container.show()
 
	var first_btn: Button = null
	for n in i.choicetext.size():
		var holder: Node = DIALOGUE_BUTTON.instantiate()
		var btn := holder as Button
		if btn == null:
			var found := holder.find_children("*", "Button", true, false)
			if found.is_empty():
				push_error("Dialogue: button.tscn contains no Button node")
				holder.queue_free()
				continue
			btn = found[0]
		btn.text = i.choicetext[n]
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var f: DialogueFunction = i.choicetextcall[n] if n < i.choicetextcall.size() else null
		var jump: StringName = i.choicejump[n] if n < i.choicejump.size() else &""
		var resp: DialogueText = i.choiceresponse[n] if n < i.choiceresponse.size() else null
		btn.pressed.connect(_on_choice_pressed.bind(f, jump, resp), CONNECT_ONE_SHOT)
		button_container.add_child(holder)
		if first_btn == null:
			first_btn = btn
 
	if first_btn:
		first_btn.grab_focus()
 
 
func _on_choice_pressed(f: DialogueFunction, jump: StringName, response: DialogueText = null) -> void:
	button_container.hide()
	for c in button_container.get_children():
		c.queue_free()
 
	if f != null:
		if f.hidebox:
			hide()
		await _run_function(f)
		if not is_inside_tree():
			return
 
	# Optional response line: plays like any DialogueText (animation, zoom, function...)
	if response != null:
		if _has_text(response):
			_show_box()
		else:
			hide()
		if not await _play_text(response):
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
	if await _play_text(i):
		current_dialogue_item += 1
		next_item = true
 
 
# Plays one DialogueText line: animation, zoom, functions, typing, waiting for Enter.
# Returns false if the box was removed meanwhile. Also used for choice responses.
func _play_text(i: DialogueText) -> bool:
	_hide_arrow()
	_set_speaker(i.speaker)
	audio.stream = _build_sound(i)
	audio.volume_db = i.textvolume
 
	var cam := get_viewport().get_camera_2d()
	if cam and not i.camerapos.is_equal_approx(NO_CAMERA):
		var tween := create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(cam, "global_position", i.camerapos, i.cameratranstime)
 
	var zoomed_here: bool = i.camerazoom > 0.0
	_apply_camera_zoom(i)
	var started := _play_line_animation(i)
 
	await _run_text_function(i, DialogueText.FunctionTiming.LINE_START)
	if not is_inside_tree():
		return false
 
	# Empty text = animation-only line: no typing, no waiting for Enter
	if not _has_text(i):
		await _wait_line_animations(started)
		if not is_inside_tree():
			return false
		# No typing or Enter on this line, so run the later timings here
		await _run_text_function(i, DialogueText.FunctionTiming.AFTER_TYPING)
		await _run_text_function(i, DialogueText.FunctionTiming.AFTER_ENTER)
		if not is_inside_tree():
			return false
		if zoomed_here and not i.camerazoomuntilend:
			_restore_camera_zoom(true)
		return true
 
	if not await _reveal(i.text, i):
		return false
 
	await _run_text_function(i, DialogueText.FunctionTiming.AFTER_TYPING)
	if not is_inside_tree():
		return false
 
	_show_arrow()
	while true:
		if not await _next_frame():
			return false
		if Input.is_action_just_pressed("ui_accept"):
			break
	_hide_arrow()
 
	await _run_text_function(i, DialogueText.FunctionTiming.AFTER_ENTER)
	if not is_inside_tree():
		return false
 
	if zoomed_here and not i.camerazoomuntilend:
		_restore_camera_zoom(true)   # this line's zoom ends with the line
 
	return true
 
 
# =====================================================================
# Bottom anchor
# =====================================================================
func _anchor_to_bottom() -> void:
	if not await _next_frame():
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
 
 
func _set_speaker(speaker: String) -> void:
	if name_bg == null or name_label == null:
		return
	var has_name := speaker != ""
	name_bg.visible = has_name
	name_label.visible = has_name
	if not has_name:
		return
 
	# Measure the name straight from the font instead of waiting a frame for the label's
	# layout. If the box opens while a room is still loading, that layout can be stale,
	# which made the name wrap ("Kev" / "in") and the tab too narrow.
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text = speaker
	var font := name_label.get_theme_font("normal_font")
	var font_size := name_label.get_theme_font_size("normal_font_size")
	var w := font.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	name_bg.size.x = w + NAME_PADDING * 2.0
	name_label.position.x = name_bg.position.x + NAME_PADDING
	name_label.size.x = w + 1.0
 
 
func _build_sound(i) -> AudioStream:
	var streams: Array[AudioStream] = []
	if i.textsoundfolder != "":
		streams = _folder_sounds(i.textsoundfolder)
	if streams.is_empty():
		return i.textsound
	if streams.size() == 1:
		return streams[0]
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
 
 
func set_players_move(value: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if "move" in p:
			p.move = value
		else:
			push_warning("%s is in group 'player' but has no 'move' variable" % p.name)
 
