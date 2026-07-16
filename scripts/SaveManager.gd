extends Node

# Singleton to handle player wallet and unlocked items persistently
const SAVE_PATH = "user://save_data.json"

var gems_wallet: int = 0
var unlocked_balls: Array = ["standard"]
var equipped_ball: String = "standard"
var playtest_level_data: Dictionary = {}

func _ready():
	load_game()

func save_game():
	var save_dict = {
		"gems_wallet": gems_wallet,
		"unlocked_balls": unlocked_balls,
		"equipped_ball": equipped_ball
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
		gems_wallet = int(data.get("gems_wallet", 0))
		unlocked_balls = data.get("unlocked_balls", ["standard"])
		equipped_ball = data.get("equipped_ball", "standard")
		print("SaveManager: Game loaded. Gems: ", gems_wallet, ", Equipped: ", equipped_ball)
	else:
		printerr("SaveManager: JSON Parse Error during load: ", json.get_error_message())
		reset_defaults()

func reset_defaults():
	gems_wallet = 0
	unlocked_balls = ["standard"]
	equipped_ball = "standard"
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
