extends Node

const SAVE_DIR := "user://saves/"
const LAST_FILE := "user://saves/last.cfg"
const SLOT_COUNT := 3

var current_campaign := ""
var last_slot := 0            # slot of the last checkpoint saved or loaded (0 = none yet)
var playtime := 0.0
var pending_position = null   # legacy: RoomManager places the player now, nothing sets this anymore

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_read_last()

func _process(delta: float) -> void:
	if current_campaign != "":
		playtime += delta

func _path(campaign: String, slot: int) -> String:
	return "%s%s_slot%d.tres" % [SAVE_DIR, campaign, slot]

func read_slot(campaign: String, slot: int) -> SaveData:
	if not FileAccess.file_exists(_path(campaign, slot)):
		return null
	return ResourceLoader.load(_path(campaign, slot), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData

func save_game(slot: int, pos: Vector2, place_name: String) -> void:
	var s := SaveData.new()
	s.scene_path = get_tree().current_scene.scene_file_path
	s.position = pos
	s.playtime = playtime
	s.checkpoint_name = place_name
	RoomState.capture()
	s.rooms = RoomState.rooms.duplicate(true)
	s.flags = GameState.flags.duplicate()
	var err := ResourceSaver.save(s, _path(current_campaign, slot))
	if err != OK:
		push_error("Save failed: %s" % error_string(err))
		return
	_set_last(slot)

func load_game(campaign: String, slot: int) -> void:
	var s := read_slot(campaign, slot)
	if s == null:
		return
	current_campaign = campaign
	playtime = s.playtime
	RoomState.rooms = s.rooms.duplicate(true)
	RoomState.suppress_capture = true
	GameState.flags = s.flags.duplicate()
	_set_last(slot)
	RoomManager.change_room(s.scene_path, &"", 0.3, s.position)

# Sends the player to the last checkpoint they saved at.
# Returns false if there is none (caller should fall back to something else).
func respawn() -> bool:
	if last_slot <= 0:
		return false
	var s := read_slot(current_campaign, last_slot)
	if s == null:
		return false
	RoomManager.change_room(s.scene_path, &"", 0.3, s.position)
	return true

# Call from a "Continue" button on the main menu: loads the most recent save
func continue_last() -> bool:
	if current_campaign == "" or last_slot <= 0:
		return false
	load_game(current_campaign, last_slot)
	return true

func _set_last(slot: int) -> void:
	last_slot = slot
	var cfg := ConfigFile.new()
	cfg.set_value("last", "campaign", current_campaign)
	cfg.set_value("last", "slot", slot)
	cfg.save(LAST_FILE)

func _read_last() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LAST_FILE) != OK:
		return
	current_campaign = cfg.get_value("last", "campaign", current_campaign)
	last_slot = cfg.get_value("last", "slot", 0)
