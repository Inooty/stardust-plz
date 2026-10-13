extends CharacterBody2D

# Speed Controls
@export var smoothspeed: float = 100
@export var maxspeed: float = 900

# Newton, pass me the sauce
@export var pushstrength: float = 2
@export var knockbackdecay: float = 2
@export var minbounce: float = 10
@export var maxbounce: float = 1000
@export  var maxbouncestrength: float = 100

# Mouse Leash (Yes it gets its own section)
@export var mouseleash: float = 300

# Texture Changess
@export var default: Texture2D
@export var grab: Texture2D
@export var ponder: Texture2D

var knockbackvel: Vector2 = Vector2.ZERO
var chasevel: Vector2 = Vector2.ZERO
var vmousepos: Vector2 = Vector2.ZERO
var hold: RigidBody2D

# Controls The Holding Textures
var holding: bool = false
var pondering: bool = false

# Movement Control
var move: bool = false

# Can Move Function Yipeeee
func _canmemove() -> void:
	if move:
		velocity = chasevel + knockbackvel
	else:
		velocity = Vector2.ZERO
		var velbefcol  = velocity

# Texture Control
func _process (_delta: float) -> void:
	if holding ==true:
		$Sprite2D.texture= load("res://Assets/Player/cursor_buku_hold.png")
	elif pondering == true:
		$Sprite2D.texture= load("res://Assets/Player/cursor_buku_ponder.png")
	else:
		$Sprite2D.texture= load("res://Assets/Player/cursor_buku.png")

# On Game Start
func _ready() -> void:
	CameraManager.camera = get_viewport().get_camera_2d()
	CameraManager.player = self
	print("Camera Manager! ", CameraManager.camera)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	vmousepos = get_global_mouse_position()
	
# OS, am I moving the mouse?
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		vmousepos += event.relative

# Even Eviler Physics Processes
func _physics_process(delta: float) -> void:
	
	var tomouse = vmousepos - global_position
	if tomouse.length() > mouseleash:
		vmousepos = global_position + tomouse.normalized() * mouseleash
		tomouse = vmousepos - global_position
	
	var tarvel = tomouse.limit_length(maxspeed)
	
	
	# Lovely Smoothing
	var t = 1 - exp(-smoothspeed * delta)
	chasevel = chasevel.lerp(tarvel, t)
	
	# Knockback
	var decay_t = 1 -exp(-knockbackdecay * delta)
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
