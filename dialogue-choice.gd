extends DE
class_name DialogueChoice

@export var speakerimg: Texture
@export var speakerhframes: int = 1
@export var speakerselectframe: int = 0

@export_multiline var text: String

@export var choicetext: Array[String]
@export var choicetextcall: Array[DialogueFunction]
