extends DE
class_name DialogueText

@export var speaker: String
@export_multiline var text: String

@export var textspeed := 30.0                 # letters per second
@export_dir var textsoundfolder: String       # random sound from this folder, wins over textsound
@export var textsound: AudioStream
@export_range(-80.0, 24.0, 0.1) var textvolume := 0.0
@export var textpitchmin := 0.85
@export var textpitchmax := 1.15
@export var spritenode: NodePath        # AnimatedSprite2D in the room, path from the scene root (e.g. "Kevin/AnimatedSprite2D")
@export var spriteanimation: StringName # SpriteFrames animation to play when this line starts


@export var camerapos := Vector2(999.999, 999.999)   # 999.999 = don't move the camera
@export var cameratranstime := 1.0

@export_group("Camera Zoom")
@export var camerazoom := 0.0          # 0 = don't change. 1 = normal, 2 = zoomed in, 0.5 = zoomed out
@export var camerazoomtime := 0.5      # seconds to get there (0 = instant)
@export var camerazoomuntilend := false   # OFF = zoom only during this line. ON = stay zoomed until the dialogue finishes

@export_group("Animation")
@export var animationplayer: NodePath  # AnimationPlayer in the room, path from the scene root (e.g. "AnimationPlayer")
@export var animationname: StringName
