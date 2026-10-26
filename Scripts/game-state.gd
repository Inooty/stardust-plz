extends Node

var flags := {}

func has_flag(id: StringName) -> bool:
	return flags.get(String(id), false)

func set_flag(id: StringName, value := true) -> void:
	flags[String(id)] = value

func once(id: StringName) -> bool:
	if id == &"":
		return true
	if has_flag(id):
		return false
	set_flag(id)
	return true

func reset() -> void:
	flags.clear()
