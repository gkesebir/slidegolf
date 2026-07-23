extends Node

# Singleton to handle player wallet and unlocked items persistently
const SAVE_PATH = "user://save_data.json"
const SAVE_VERSION = 2 # Incremented to force reset to 0 for Phase 4/5 testing

var gems_wallet: int = 0
var unlocked_balls: Array = ["standard"]
var equipped_ball: String = "standard"
var save_version: int = SAVE_VERSION
var playtest_level_data: Dictionary = {}

var current_level: int = 1
var level_stars: Dictionary = {}

func _ready():
	load_game()

func save_game():
	var save_dict = {
		"gems_wallet": gems_wallet,
		"unlocked_balls": unlocked_balls,
		"equipped_ball": equipped_ball,
		"current_level": current_level,
		"level_stars": level_stars,
		"save_version": save_version
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(save_dict)
		file.store_string(json_str)
		file.close()
		print("SaveManager: Game saved successfully.")
	else:
		printerr("SaveManager: Failed to save game data.")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: No save file found, loading defaults.")
		reset_defaults()
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		reset_defaults()
		return
		
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_str)
	if error == OK:
		var data = json.get_data()
		var loaded_version = data.get("save_version", 1)
		if loaded_version < SAVE_VERSION:
			print("SaveManager: Outdated save version, resetting to defaults.")
			reset_defaults()
			return
			
		gems_wallet = int(data.get("gems_wallet", 0))
		unlocked_balls = data.get("unlocked_balls", ["standard"])
		equipped_ball = data.get("equipped_ball", "standard")
		current_level = int(data.get("current_level", 1))
		level_stars = data.get("level_stars", {})
		print("SaveManager: Game loaded. Gems: ", gems_wallet, ", Level: ", current_level)
	else:
		printerr("SaveManager: JSON Parse Error during load: ", json.get_error_message())
		reset_defaults()

func reset_defaults():
	gems_wallet = 0
	unlocked_balls = ["standard"]
	equipped_ball = "standard"
	current_level = 1
	level_stars = {}
	save_version = SAVE_VERSION
	save_game()

func update_level_stars(level: int, stars: float):
	var key = str(level)
	if level_stars.has(key):
		if stars > level_stars[key]:
			level_stars[key] = stars
	else:
		level_stars[key] = stars
	save_game()

func update_current_level(level: int):
	current_level = level
	save_game()

func add_gems(amount: int):
	gems_wallet += amount
	save_game()

func deduct_gems(amount: int) -> bool:
	if gems_wallet >= amount:
		gems_wallet -= amount
		save_game()
		return true
	return false

func unlock_ball(ball_id: String):
	if not unlocked_balls.has(ball_id):
		unlocked_balls.append(ball_id)
		save_game()

func equip_ball(ball_id: String):
	equipped_ball = ball_id
	save_game()
