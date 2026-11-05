extends DE
class_name DialogueChoice

@export_multiline var text: String

@export var speaker: String
@export var choicetext: Array[String]
@export var choicetextcall: Array[DialogueFunction]
@export var choicejump: Array[StringName]

@export var choiceresponse: Array[DialogueText]

@export_group("Typing")
@export var textspeed := 30.0
@export_dir var textsoundfolder: String
@export var textsound: AudioStream
@export_range(-80.0, 24.0, 0.1) var textvolume := 0.0
@export var textpitchmin := 0.85
@export var textpitchmax := 1.15

@export_group("Animation")
@export var animationplayer: NodePath   # AnimationPlayer path (relative to the Dialogue Area)
@export var animationname: StringName   # plays when the question starts typing
@export var spritenode: NodePath        # AnimatedSprite2D path (relative to the Dialogue Area)
@export var spriteanimation: StringName # plays when the question starts typing
