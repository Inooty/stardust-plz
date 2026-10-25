extends CharacterBody2D

# Speed Controls
@export var smoothspeed: float = 100
@export var maxspeed: float = 900

# Newton, pass me the sauce
@export var pushstrength: float = 2
@export var knockbackdecay: float = 2
@export var minbounce: float = 10
@export var maxbounce: float = 1000
@export var maxbouncestrength: float = 100

# Mouse Leash (Yes it gets its own section)
@export var mouseleash: float = 300

# Texture Changess
@export var default: Texture2D
@export var grab: Texture2D
@export var ponder: Texture2D

# Death Stuff
const BURST_AT := 1.0
const BURST_LENGTH := 1.0
var blackscreen: PackedScene = preload("res://Scenes/Player/Death/death.tscn")
var death1: AudioStream = preload("res://Assets/SFX/death1.wav")
var death2: AudioStream = preload("res://Assets/SFX/death2.wav")

var knockbackvel: Vector2 = Vector2.ZERO
var chasevel: Vector2 = Vector2.ZERO
var vmousepos: Vector2 = Vector2.ZERO
var hold: RigidBody2D

# Controls The Holding Textures
var holding: bool = false
var pondering: bool = false

# Movement Control
var move: bool = true
var dying: bool = false

# Texture Control
func _process(_delta: float) -> void:
	if holding == true:
		$Buku.texture = load("res://Assets/Player/cursor_buku_hold.png")
	elif pondering == true:
		$Buku.texture = load("res://Assets/Player/cursor_buku_ponder.png")
	else:
		$Buku.texture = load("res://Assets/Player/cursor_buku.png")

# On Game Start
func _ready() -> void:
	$CanvasLayer/Death.hide()
	add_to_group("player")
	CameraManager.camera = get_viewport().get_camera_2d()
	CameraManager.player = self
	print("Camera Manager! ", CameraManager.camera)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	vmousepos = get_global_mouse_position()

func play_sfx(stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	get_tree().root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# Death.
func die() -> void:
	if dying:
		return
	dying = true
	move = false
	play_sfx(death1)
	$Buku.hide()
	var black = blackscreen.instantiate()
	get_tree().current_scene.add_child(black)
	for shape in [$HitBoxMain, $HitboxSecondary, $HitBoxThirdiary]:
		shape.set_deferred("disabled", true)

	var parts: Array = [$CanvasLayer/ParticlesBit1, $CanvasLayer/ParticlesBit2,
			$CanvasLayer/ParticlesBit3]
	for n in [$CanvasLayer/Death] + parts:
		n.global_position = global_position
		n.reset_physics_interpolation()

	$CanvasLayer/Death.show()
	$CanvasLayer/Death.play("death")

	await get_tree().create_timer(BURST_AT).timeout
	play_sfx(death2)
	$CanvasLayer/Death.hide()
	for p in parts:
		p.restart()

	await get_tree().create_timer(BURST_LENGTH).timeout
	get_tree().reload_current_scene()

# OS, am I moving the mouse?
func _input(event: InputEvent) -> void:
	if not move:
		return
	if event is InputEventMouseMotion:
		vmousepos += event.relative

# Even Eviler Physics Processes
func _physics_process(delta: float) -> void:

	var tomouse = vmousepos - global_position
	if tomouse.length() > mouseleash:
		vmousepos = global_position + tomouse.normalized() * mouseleash
		tomouse = vmousepos - global_position
	var tarvel = tomouse.limit_length(maxspeed)

	# Evil Breaks
	if not move:
		velocity = Vector2.ZERO
		chasevel = Vector2.ZERO
		knockbackvel = Vector2.ZERO
		vmousepos = global_position
		return

	# Lovely Smoothing
	var t = 1 - exp(-smoothspeed * delta)
	chasevel = chasevel.lerp(tarvel, t)

	# Knockback
	var decay_t = 1 - exp(-knockbackdecay * delta)
	knockbackvel = knockbackvel.lerp(Vector2.ZERO, decay_t)

	# Velocity Dictionary Definition
	velocity = chasevel + knockbackvel
	var velbefcol = velocity

	move_and_slide()

	# Newtons Third Law :0
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var impspeed = velbefcol.length()

		if collider is RigidBody2D:
			var pushdir = -collision.get_normal()
			var impulse = pushdir * impspeed * pushstrength
			collider.apply_central_impulse(impulse)

		# Bouncy
		var bouncefact = clamp(inverse_lerp(minbounce, maxbounce, impspeed), 0.0, 1.0)
		var bounceamount = bouncefact * maxbouncestrength
		if bounceamount > 0.0:
			knockbackvel += collision.get_normal() * bounceamount
			chasevel = chasevel.slide(collision.get_normal())
