extends Node

class_name GameManager

# Node references
@export var grid_manager: GridManager
@export var ball: Ball

# UI Nodes
@export var diamond_label: Label
@export var victory_screen: Control
@export var restart_button: Button

# Debug UI Nodes
@export var debug_status_label: Label
@export var generate_levels_button: Button
@export var editor_button: Button

# Phase 3 UI Nodes
@export var timer_label: Label
@export var play_bonus_mode_button: Button

# Phase 4 Shop UI Nodes
@export var shop_button: Button
@export var shop_screen: Control
@export var shop_close_button: Button
@export var shop_gems_label: Label
@export var shop_status_label: Label
@export var shop_item_buttons: Array[NodePath] # Array paths: 0 = standard, 1 = iron, 2 = super
var shop_buttons: Array[Button] = []

# Game state
var total_diamonds: int = 0
var diamonds_collected: int = 0
var current_level_path: String = ""
var current_level_index: int = 1
var level_cleared: bool = false

# Phase 3 Bonus Mode state
var is_bonus_mode: bool = false
var bonus_time_left: float = 30.0
var game_over: bool = false

# Phase 4 Shop pricing
const BALL_PRICES = {
	"standard": 0,
	"iron": 20,
	"super": 50
}

func _ready():
	if not grid_manager:
		grid_manager = get_node_or_null("../GridManager")
	if not ball:
		ball = get_node_or_null("../Ball")
		
	if grid_manager and not grid_manager.is_node_ready():
		await grid_manager.ready
		
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
		
	if generate_levels_button:
		generate_levels_button.pressed.connect(_on_generate_levels_pressed)
		
	if editor_button:
		editor_button.pressed.connect(_on_editor_button_pressed)
		
	if play_bonus_mode_button:
		play_bonus_mode_button.pressed.connect(_on_play_bonus_mode_pressed)
		
	# Phase 4 Shop UI Connections
	if shop_button:
		shop_button.pressed.connect(_on_shop_button_pressed)
	if shop_close_button:
		shop_close_button.pressed.connect(_on_shop_close_button_pressed)
		
	# Resolve shop buttons from NodePaths
	shop_buttons.clear()
	for path in shop_item_buttons:
		var node = get_node_or_null(path)
		if node is Button:
			shop_buttons.append(node)
			
	if shop_buttons.size() >= 3:
		shop_buttons[0].pressed.connect(func(): _on_shop_item_clicked("standard"))
		shop_buttons[1].pressed.connect(func(): _on_shop_item_clicked("iron"))
		shop_buttons[2].pressed.connect(func(): _on_shop_item_clicked("super"))
		
	style_ui()
	initialize_game()

func _process(delta):
	# Update countdown timer in Bonus Mode
	if is_bonus_mode and not game_over:
		bonus_time_left -= delta
		if bonus_time_left <= 0.0:
			bonus_time_left = 0.0
			end_bonus_level()
		update_timer_label()

func initialize_game():
	if not grid_manager or not ball:
		printerr("GameManager: GridManager or Ball is not assigned!")
		return
		
	is_bonus_mode = false
	game_over = false
	level_cleared = false
	
	if restart_button:
		restart_button.text = "PLAY AGAIN"
		
	if timer_label:
		timer_label.hide()
		
	if shop_screen:
		shop_screen.hide()
		
	if not SaveManager.playtest_level_data.is_empty():
		var level_data = SaveManager.playtest_level_data.duplicate()
		SaveManager.playtest_level_data.clear()
		load_level_from_dict(level_data)
		return

	var level1_path = "res://levels/level_1.json"
	if FileAccess.file_exists(level1_path):
		load_level_from_json(level1_path)
	else:
		current_level_path = ""
		total_diamonds = count_diamonds_in_grid()
		diamonds_collected = 0
		update_ui()
		
		if victory_screen:
			victory_screen.hide()
			
		ball.initialize(Vector2i(1, 1), grid_manager, self)

func load_level_from_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
		
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_str)
	if error != OK:
		printerr("JSON Parse Error: ", json.get_error_message())
		return false
		
	var level_data = json.get_data()
	current_level_path = path
	level_cleared = false
	
	# Extract level index from filename, e.g. level_12.json -> 12
	var level_name = path.get_file().get_basename()
	if level_name.begins_with("level_"):
		current_level_index = level_name.replace("level_", "").to_int()
	
	grid_manager.grid = level_data["grid"]
	grid_manager.grid_width = level_data["grid_size"][0]
	grid_manager.grid_height = level_data["grid_size"][1]
	
	grid_manager.reset_grid()
	
	total_diamonds = count_diamonds_in_grid()
	diamonds_collected = 0
	update_ui()
	
	var start_arr = level_data["player_start"]
	ball.initialize(Vector2i(start_arr[0], start_arr[1]), grid_manager, self)
	
	if victory_screen:
		victory_screen.hide()
		
	return true

func load_level_from_dict(level_data: Dictionary):
	current_level_path = ""
	level_cleared = false
	current_level_index = -1
	
	grid_manager.grid = level_data["grid"]
	grid_manager.grid_width = level_data["grid_size"][0]
	grid_manager.grid_height = level_data["grid_size"][1]
	
	grid_manager.reset_grid()
	
	total_diamonds = count_diamonds_in_grid()
	diamonds_collected = 0
	update_ui()
	
	var start_arr = level_data["player_start"]
	ball.initialize(Vector2i(start_arr[0], start_arr[1]), grid_manager, self)
	
	if victory_screen:
		victory_screen.hide()

func start_bonus_mode():
	is_bonus_mode = true
	game_over = false
	level_cleared = false
	bonus_time_left = 30.0
	diamonds_collected = 0
	
	if restart_button:
		restart_button.text = "PLAY AGAIN"
		
	grid_manager.reset_grid()
	total_diamonds = count_diamonds_in_grid()
	
	if timer_label:
		timer_label.show()
		update_timer_label()
		
	update_ui()
	
	if victory_screen:
		victory_screen.hide()
		
	ball.initialize(Vector2i(1, 1), grid_manager, self)

func end_bonus_level():
	game_over = true
	
	# Add collected gems to the persistent wallet
	SaveManager.add_gems(diamonds_collected)
	update_ui()
	
	if restart_button:
		restart_button.text = "PLAY AGAIN"
		
	if victory_screen:
		victory_screen.show()
		
		var title_label = victory_screen.get_node_or_null("Panel/VictoryLabel")
		if title_label:
			title_label.text = "TIME'S UP!"
			title_label.add_theme_color_override("font_color", Color("ff9100"))
			
		var info_label = victory_screen.get_node_or_null("Panel/InfoLabel")
		if info_label:
			info_label.text = "Gems Collected: %d\nTotal Wallet: %d" % [diamonds_collected, SaveManager.gems_wallet]
			
		var panel = victory_screen.get_node_or_null("Panel")
		if panel:
			panel.scale = Vector2.ZERO
			panel.pivot_offset = panel.size / 2.0
			var tween = create_tween()
			tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func count_diamonds_in_grid() -> int:
	var count = 0
	for y in range(grid_manager.grid_height):
		for x in range(grid_manager.grid_width):
			if grid_manager.get_cell_type(Vector2i(x, y)) == 2:
				count += 1
	return count

func collect_diamond():
	diamonds_collected += 1
	
	if is_bonus_mode:
		bonus_time_left += 1.5
		update_timer_label()
		
		var new_pos = grid_manager.find_random_empty_cell()
		if new_pos != Vector2i(-1, -1):
			grid_manager.spawn_diamond_at(new_pos)
			total_diamonds = count_diamonds_in_grid()
	
	update_ui()

func all_diamonds_collected() -> bool:
	return diamonds_collected == total_diamonds

func update_ui():
	if diamond_label:
		if is_bonus_mode:
			diamond_label.text = "TIME-ATTACK | GEMS: %d | WALLET: %d" % [diamonds_collected, SaveManager.gems_wallet]
		elif current_level_path != "":
			var level_num = current_level_path.get_file().get_basename().replace("level_", "")
			diamond_label.text = "LEVEL %s | GEMS: %d / %d | WALLET: %d" % [level_num, diamonds_collected, total_diamonds, SaveManager.gems_wallet]
		else:
			diamond_label.text = "GEMS: %d / %d | WALLET: %d" % [diamonds_collected, total_diamonds, SaveManager.gems_wallet]

func update_timer_label():
	if timer_label:
		timer_label.text = "TIME: %.1fs" % bonus_time_left

func win_level():
	print("Level Cleared!")
	level_cleared = true
	
	# Add collected gems to the persistent wallet
	SaveManager.add_gems(diamonds_collected)
	update_ui()
	
	if restart_button:
		var next_index = current_level_index + 1
		if next_index > 50:
			next_index = 1
		restart_button.text = "NEXT LEVEL (Level %d)" % next_index
	
	if victory_screen:
		victory_screen.show()
		
		var title_label = victory_screen.get_node_or_null("Panel/VictoryLabel")
		if title_label:
			title_label.text = "LEVEL CLEARED!"
			title_label.add_theme_color_override("font_color", Color("ff007f"))
			
		var info_label = victory_screen.get_node_or_null("Panel/InfoLabel")
		if info_label:
			info_label.text = "Gems Collected: %d\nTotal Wallet: %d" % [diamonds_collected, SaveManager.gems_wallet]
			
		var panel = victory_screen.get_node_or_null("Panel")
		if panel:
			panel.scale = Vector2.ZERO
			panel.pivot_offset = panel.size / 2.0
			var tween = create_tween()
			tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_restart_button_pressed():
	if is_bonus_mode:
		start_bonus_mode()
	elif level_cleared:
		# Load next sequential level
		var next_index = current_level_index + 1
		if next_index > 50:
			next_index = 1
		var next_path = "res://levels/level_%d.json" % next_index
		load_level_from_json(next_path)
	elif current_level_path != "":
		load_level_from_json(current_level_path)
	else:
		initialize_game()

func _on_play_bonus_mode_pressed():
	start_bonus_mode()

# --- Shop UI Logic ---

func _on_shop_button_pressed():
	if shop_screen:
		shop_screen.show()
		refresh_shop_ui()
		
		var panel = shop_screen.get_node_or_null("Panel")
		if panel:
			panel.scale = Vector2.ZERO
			panel.pivot_offset = panel.size / 2.0
			var tween = create_tween()
			tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_shop_close_button_pressed():
	if shop_screen:
		shop_screen.hide()

func _on_shop_item_clicked(ball_id: String):
	var is_unlocked = SaveManager.unlocked_balls.has(ball_id)
	
	if is_unlocked:
		# Equip
		SaveManager.equip_ball(ball_id)
		if ball:
			ball.apply_ball_profile(ball_id)
		show_shop_status("Equipped: " + Ball.BALL_PROFILES[ball_id]["name"], Color("00e5ff"))
	else:
		# Buy
		var price = BALL_PRICES.get(ball_id, 999)
		if SaveManager.gems_wallet >= price:
			if SaveManager.deduct_gems(price):
				SaveManager.unlock_ball(ball_id)
				SaveManager.equip_ball(ball_id)
				if ball:
					ball.apply_ball_profile(ball_id)
				show_shop_status("Unlocked & Equipped: " + Ball.BALL_PROFILES[ball_id]["name"], Color("39ff14"))
		else:
			show_shop_status("Not enough gems! Need " + str(price) + " gems.", Color("ff1744"))
			
	refresh_shop_ui()
	update_ui()

func refresh_shop_ui():
	if shop_gems_label:
		shop_gems_label.text = "GEMS: %d" % SaveManager.gems_wallet
		
	# Refresh button texts
	if shop_buttons.size() >= 3:
		update_item_button_state(shop_buttons[0], "standard")
		update_item_button_state(shop_buttons[1], "iron")
		update_item_button_state(shop_buttons[2], "super")

func update_item_button_state(btn: Button, ball_id: String):
	if not btn:
		return
	
	var is_unlocked = SaveManager.unlocked_balls.has(ball_id)
	var is_equipped = SaveManager.equipped_ball == ball_id
	
	if is_equipped:
		btn.text = "EQUIPPED"
		btn.disabled = true
		var style = btn.get_theme_stylebox("normal").duplicate()
		style.bg_color = Color("cfd8dc") # Pastel gray disabled
		style.border_color = Color("90a4ae")
		style.shadow_size = 0
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color("78909c"))
	elif is_unlocked:
		btn.text = "EQUIP"
		btn.disabled = false
		var style = btn.get_theme_stylebox("normal").duplicate()
		style.bg_color = Color("ffffff")
		style.border_color = Color("29b6f6") # Pastel blue
		style.shadow_color = Color("29b6f6", 0.1)
		style.shadow_size = 3
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color("0288d1"))
	else:
		var price = BALL_PRICES.get(ball_id, 0)
		btn.text = "BUY: %d GEMS" % price
		btn.disabled = false
		var style = btn.get_theme_stylebox("normal").duplicate()
		style.bg_color = Color("ffffff")
		style.border_color = Color("ffb74d") # Pastel orange
		style.shadow_color = Color("ffb74d", 0.1)
		style.shadow_size = 3
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color("f57c00"))

func show_shop_status(msg: String, color: Color):
	if shop_status_label:
		shop_status_label.text = msg
		shop_status_label.add_theme_color_override("font_color", color)
		
		# Fade animation
		shop_status_label.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(shop_status_label, "modulate:a", 0.0, 3.0).set_delay(1.0)

# --- Debug and Solver ---

func _on_generate_levels_pressed():
	generate_and_save_50_levels()

func _on_editor_button_pressed():
	get_tree().change_scene_to_file("res://scenes/LevelEditor.tscn")

func generate_and_save_50_levels():
	if generate_levels_button:
		generate_levels_button.disabled = true
		
	if debug_status_label:
		debug_status_label.text = "Generating levels..."
		
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("res://levels"):
		var err = dir.make_dir("res://levels")
		if err != OK:
			printerr("Failed to create levels folder: ", err)
			
	var count = 0
	var attempts = 0
	var max_attempts = 1500
	
	while count < 50 and attempts < max_attempts:
		attempts += 1
		var level = LevelGenerator.generate_level(7, 7, 7, 3)
		if level.is_empty():
			continue
			
		var moves = LevelSolver.solve_level(level)
		if moves > 0:
			level["min_moves"] = moves
			count += 1
			
			var path = "res://levels/level_%d.json" % count
			var file = FileAccess.open(path, FileAccess.WRITE)
			if file:
				var json_str = JSON.stringify(level, "\t")
				file.store_string(json_str)
				file.close()
				
			if debug_status_label:
				debug_status_label.text = "Generated: %d/50 (Par: %d)" % [count, moves]
				
			if count % 2 == 0:
				await get_tree().process_frame
				
	if generate_levels_button:
		generate_levels_button.disabled = false
		
	if debug_status_label:
		if count == 50:
			debug_status_label.text = "Success! 50 levels saved."
			load_level_from_json("res://levels/level_1.json")
		else:
			debug_status_label.text = "Failed to generate 50 levels (attempts: %d)." % attempts

# --- Procedural UI Styling ---

func style_ui():
	# Override TopBar labels for minimalist look
	if diamond_label:
		diamond_label.add_theme_color_override("font_color", Color("37474f")) # Dark slate gray
	if timer_label:
		timer_label.add_theme_color_override("font_color", Color("c62828")) # Pastel red

	# 1. Victory Panel
	var panel = victory_screen.get_node_or_null("Panel") if victory_screen else null
	if panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color("ffffff") # Minimalist white
		panel_style.border_color = Color("81c784") # Pastel Green
		panel_style.border_width_left = 4
		panel_style.border_width_right = 4
		panel_style.border_width_top = 4
		panel_style.border_width_bottom = 4
		panel_style.corner_radius_top_left = 24
		panel_style.corner_radius_top_right = 24
		panel_style.corner_radius_bottom_left = 24
		panel_style.corner_radius_bottom_right = 24
		panel_style.shadow_color = Color(0, 0, 0, 0.08)
		panel_style.shadow_size = 12
		panel.add_theme_stylebox_override("panel", panel_style)
		
		# Override Victory text labels
		var title_label = panel.get_node_or_null("VictoryLabel")
		if title_label:
			title_label.add_theme_color_override("font_color", Color("2e7d32")) # Dark Green
		var info_label = panel.get_node_or_null("InfoLabel")
		if info_label:
			info_label.add_theme_color_override("font_color", Color("546e7a")) # Slate Gray
		
	# 2. Restart Button
	if restart_button:
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color("ffffff")
		btn_normal.border_color = Color("81c784") # Pastel Green
		btn_normal.border_width_left = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_bottom = 2
		btn_normal.corner_radius_top_left = 12
		btn_normal.corner_radius_top_right = 12
		btn_normal.corner_radius_bottom_left = 12
		btn_normal.corner_radius_bottom_right = 12
		btn_normal.shadow_color = Color(0, 0, 0, 0.05)
		btn_normal.shadow_size = 2
		
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color("f1f8e9")
		btn_hover.shadow_size = 4
		
		var btn_pressed = btn_normal.duplicate()
		btn_pressed.bg_color = Color("e8f5e9")
		btn_pressed.shadow_size = 1
		
		restart_button.add_theme_stylebox_override("normal", btn_normal)
		restart_button.add_theme_stylebox_override("hover", btn_hover)
		restart_button.add_theme_stylebox_override("pressed", btn_pressed)
		
		restart_button.add_theme_color_override("font_color", Color("2e7d32"))
		restart_button.add_theme_color_override("font_hover_color", Color("1b5e20"))
		restart_button.add_theme_color_override("font_pressed_color", Color("1b5e20"))
		
	# 3. Generate Levels Button
	if generate_levels_button:
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color("ffffff")
		btn_normal.border_color = Color("ba68c8") # Pastel Purple
		btn_normal.border_width_left = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_bottom = 2
		btn_normal.corner_radius_top_left = 12
		btn_normal.corner_radius_top_right = 12
		btn_normal.corner_radius_bottom_left = 12
		btn_normal.corner_radius_bottom_right = 12
		btn_normal.shadow_color = Color(0, 0, 0, 0.05)
		btn_normal.shadow_size = 2
		
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color("f3e5f5")
		btn_hover.shadow_size = 4
		
		var btn_pressed = btn_normal.duplicate()
		btn_pressed.bg_color = Color("e1bee7")
		btn_pressed.shadow_size = 1
		
		generate_levels_button.add_theme_stylebox_override("normal", btn_normal)
		generate_levels_button.add_theme_stylebox_override("hover", btn_hover)
		generate_levels_button.add_theme_stylebox_override("pressed", btn_pressed)
		
		generate_levels_button.add_theme_color_override("font_color", Color("6a1b9a"))
		generate_levels_button.add_theme_color_override("font_hover_color", Color("4a148c"))
		generate_levels_button.add_theme_color_override("font_pressed_color", Color("4a148c"))

	# 3b. Editor Button
	if editor_button:
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color("ffffff")
		btn_normal.border_color = Color("4fc3f7") # Pastel Light Blue
		btn_normal.border_width_left = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_bottom = 2
		btn_normal.corner_radius_top_left = 12
		btn_normal.corner_radius_top_right = 12
		btn_normal.corner_radius_bottom_left = 12
		btn_normal.corner_radius_bottom_right = 12
		btn_normal.shadow_color = Color(0, 0, 0, 0.05)
		btn_normal.shadow_size = 2
		
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color("e1f5fe")
		btn_hover.shadow_size = 4
		
		var btn_pressed = btn_normal.duplicate()
		btn_pressed.bg_color = Color("b3e5fc")
		btn_pressed.shadow_size = 1
		
		editor_button.add_theme_stylebox_override("normal", btn_normal)
		editor_button.add_theme_stylebox_override("hover", btn_hover)
		editor_button.add_theme_stylebox_override("pressed", btn_pressed)
		
		editor_button.add_theme_color_override("font_color", Color("0288d1"))
		editor_button.add_theme_color_override("font_hover_color", Color("01579b"))
		editor_button.add_theme_color_override("font_pressed_color", Color("01579b"))

	# 4. Play Bonus Mode Button
	if play_bonus_mode_button:
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color("ffffff")
		btn_normal.border_color = Color("ffb74d") # Pastel Orange
		btn_normal.border_width_left = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_bottom = 2
		btn_normal.corner_radius_top_left = 12
		btn_normal.corner_radius_top_right = 12
		btn_normal.corner_radius_bottom_left = 12
		btn_normal.corner_radius_bottom_right = 12
		btn_normal.shadow_color = Color(0, 0, 0, 0.05)
		btn_normal.shadow_size = 2
		
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color("fff3e0")
		btn_hover.shadow_size = 4
		
		var btn_pressed = btn_normal.duplicate()
		btn_pressed.bg_color = Color("ffe0b2")
		btn_pressed.shadow_size = 1
		
		play_bonus_mode_button.add_theme_stylebox_override("normal", btn_normal)
		play_bonus_mode_button.add_theme_stylebox_override("hover", btn_hover)
		play_bonus_mode_button.add_theme_stylebox_override("pressed", btn_pressed)
		
		play_bonus_mode_button.add_theme_color_override("font_color", Color("e65100"))
		play_bonus_mode_button.add_theme_color_override("font_hover_color", Color("bf360c"))
		play_bonus_mode_button.add_theme_color_override("font_pressed_color", Color("bf360c"))

	# 5. Shop Button
	if shop_button:
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color("ffffff")
		btn_normal.border_color = Color("ffd54f") # Pastel Yellow
		btn_normal.border_width_left = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_bottom = 2
		btn_normal.corner_radius_top_left = 12
		btn_normal.corner_radius_top_right = 12
		btn_normal.corner_radius_bottom_left = 12
		btn_normal.corner_radius_bottom_right = 12
		btn_normal.shadow_color = Color(0, 0, 0, 0.05)
		btn_normal.shadow_size = 2
		
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color("fffde7")
		btn_hover.shadow_size = 4
		
		var btn_pressed = btn_normal.duplicate()
		btn_pressed.bg_color = Color("fff9c4")
		btn_pressed.shadow_size = 1
		
		shop_button.add_theme_stylebox_override("normal", btn_normal)
		shop_button.add_theme_stylebox_override("hover", btn_hover)
		shop_button.add_theme_stylebox_override("pressed", btn_pressed)
		
		shop_button.add_theme_color_override("font_color", Color("f57f17"))
		shop_button.add_theme_color_override("font_hover_color", Color("e65100"))
		shop_button.add_theme_color_override("font_pressed_color", Color("e65100"))

	# 6. Shop Panel Overlay
	var shop_panel = shop_screen.get_node_or_null("Panel") if shop_screen else null
	if shop_panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color("ffffff") # White shop panel background
		panel_style.border_color = Color("ffd54f") # Pastel Yellow
		panel_style.border_width_left = 4
		panel_style.border_width_right = 4
		panel_style.border_width_top = 4
		panel_style.border_width_bottom = 4
		panel_style.corner_radius_top_left = 24
		panel_style.corner_radius_top_right = 24
		panel_style.corner_radius_bottom_left = 24
		panel_style.corner_radius_bottom_right = 24
		panel_style.shadow_color = Color(0, 0, 0, 0.08)
		panel_style.shadow_size = 12
		shop_panel.add_theme_stylebox_override("panel", panel_style)
		
		# Override Shop text colors
		var title_lbl = shop_panel.get_node_or_null("TitleLabel")
		if title_lbl:
			title_lbl.add_theme_color_override("font_color", Color("f57f17")) # Orange/yellow
		
		# Style individual item containers in the Shop
		var items = ["ItemStandard", "ItemIron", "ItemSuper"]
		for item_name in items:
			var item_node = shop_panel.get_node_or_null(item_name)
			if item_node:
				var item_style = StyleBoxFlat.new()
				item_style.bg_color = Color("fafafa") # Soft light card background
				item_style.border_color = Color("e0e0e0")
				item_style.border_width_left = 1
				item_style.border_width_right = 1
				item_style.border_width_top = 1
				item_style.border_width_bottom = 1
				item_style.corner_radius_top_left = 14
				item_style.corner_radius_top_right = 14
				item_style.corner_radius_bottom_left = 14
				item_style.corner_radius_bottom_right = 14
				item_node.add_theme_stylebox_override("panel", item_style)
				
				# Style texts inside the card
				var name_lbl = item_node.get_node_or_null("NameLabel")
				if name_lbl:
					name_lbl.add_theme_color_override("font_color", Color("37474f")) # Dark slate gray
				var desc_lbl = item_node.get_node_or_null("DescLabel")
				if desc_lbl:
					desc_lbl.add_theme_color_override("font_color", Color("78909c")) # Light slate gray
		
	# 7. Shop Close Button
	if shop_close_button:
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color("ffffff")
		btn_normal.border_color = Color("ef5350") # Pastel Red
		btn_normal.border_width_left = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_bottom = 2
		btn_normal.corner_radius_top_left = 8
		btn_normal.corner_radius_top_right = 8
		btn_normal.corner_radius_bottom_left = 8
		btn_normal.corner_radius_bottom_right = 8
		
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color("ffebee")
		btn_hover.shadow_size = 2
		
		var btn_pressed = btn_normal.duplicate()
		btn_pressed.bg_color = Color("ffcdd2")
		
		shop_close_button.add_theme_stylebox_override("normal", btn_normal)
		shop_close_button.add_theme_stylebox_override("hover", btn_hover)
		shop_close_button.add_theme_stylebox_override("pressed", btn_pressed)
		
		shop_close_button.add_theme_color_override("font_color", Color("ef5350"))
		shop_close_button.add_theme_color_override("font_hover_color", Color("c62828"))

	# 8. Style Item Action Buttons initially
	for i in range(shop_buttons.size()):
		var btn = shop_buttons[i]
		if btn:
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color("ffffff")
			btn_style.border_width_left = 2
			btn_style.border_width_right = 2
			btn_style.border_width_top = 2
			btn_style.border_width_bottom = 2
			btn_style.corner_radius_top_left = 10
			btn_style.corner_radius_top_right = 10
			btn_style.corner_radius_bottom_left = 10
			btn_style.corner_radius_bottom_right = 10
			btn.add_theme_stylebox_override("normal", btn_style)
			
			var btn_hov = btn_style.duplicate()
			btn_hov.bg_color = Color("f5f5f5")
			btn.add_theme_stylebox_override("hover", btn_hov)
			
			var btn_pr = btn_style.duplicate()
			btn_pr.bg_color = Color("e0e0e0")
			btn.add_theme_stylebox_override("pressed", btn_pr)
