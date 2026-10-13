extends DE
class_name DialogueText

@export var dialimg: Texture
@export var dialimghframes: int = 1
@export var dialimgrestframe: int = 0

@export_multiline var text: String
@export_range(0.1, 30.0, 0.1) var textspeed: float = 1.0

@export var textsound: AudioStream
@export var textvolume: int
@export var textpitchmin: float = 0.85
@export var textpitchmax: float = 1.15

@export var camerapos: Vector2 = Vector2(999.999, 999.999)
@export_range(0.05, 10.0, 0.05) var cameratranstime: float = 1.0
