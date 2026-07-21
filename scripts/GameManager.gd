extends Node

class_name GameManager

# Node references
@export var grid_manager: GridManager
@export var ball: Ball

# UI Nodes
@export var diamond_label: Label
@export var move_label: Label
@export var victory_screen: Control
@export var restart_button: Button

# Debug UI Nodes
@export var debug_status_label: Label
@export var generate_levels_button: Button
@export var editor_button: Button

# Phase 5 Audio UI
@export var mute_button: CheckButton

# State variables
var total_diamonds: int = 0
var diamonds_collected: int = 0
var current_level_path: String = ""
var current_level_index: int = 1
var level_cleared: bool = false
var current_moves: int = 0
var target_moves: int = 0
var game_over: bool = false

# Ad System State
var last_ad_time_msec: int = 0
var levels_cleared_since_ad: int = 0

func _ready():
	last_ad_time_msec = Time.get_ticks_msec()
	
	# Cleanup removed UI nodes
	for path in ["../UI/TopBar/DiamondLabel", "../UI/TopBar/TimerLabel", "../UI/TopBar/ShopButton", "../UI/ShopScreen", "../UI/DebugPanel/PlayBonusButton"]:
		var node = get_node_or_null(path)
		if node:
			node.queue_free()
			
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
		
	# Phase 5 Mute button connection
	if mute_button:
		mute_button.toggled.connect(_on_mute_toggled)
		
	setup_zoom_camera()
	style_ui()
	initialize_game()

func _process(delta):
	pass

func initialize_game():
	if not grid_manager or not ball:
		printerr("GameManager: GridManager or Ball is not assigned!")
		return
		
	game_over = false
	level_cleared = false
	
	if restart_button:
		restart_button.text = "TEKRAR OYNA"
		
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
		current_moves = 0
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
	
	grid_manager.grid = level_data["grid"].duplicate(true)
	grid_manager.grid_width = level_data["grid_size"][0]
	grid_manager.grid_height = level_data["grid_size"][1]
	
	grid_manager.reset_grid()
	
	current_moves = 0
	target_moves = level_data.get("min_moves", 0)
	if target_moves <= 0:
		target_moves = 9 # Varsayilan (Fall-back) eger cozulmemisse veya min_moves yoksa
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
	
	grid_manager.grid = level_data["grid"].duplicate(true)
	grid_manager.grid_width = level_data["grid_size"][0]
	grid_manager.grid_height = level_data["grid_size"][1]
	
	grid_manager.reset_grid()
	
	current_moves = 0
	target_moves = level_data.get("min_moves", 0)
	if target_moves <= 0:
		target_moves = 9
	update_ui()
	
	var start_arr = level_data["player_start"]
	ball.initialize(Vector2i(start_arr[0], start_arr[1]), grid_manager, self)
	
	if victory_screen:
		victory_screen.hide()

func count_diamonds_in_grid() -> int:
	var count = 0
	for y in range(grid_manager.grid_height):
		for x in range(grid_manager.grid_width):
			if grid_manager.get_cell_type(Vector2i(x, y)) == 2:
				count += 1
	return count

func collect_diamond():
	diamonds_collected += 1
	update_ui()

func all_diamonds_collected() -> bool:
	return diamonds_collected == total_diamonds

func update_ui():
	if diamond_label:
		var level_str = ""
		if current_level_index > 0:
			level_str = "SEVİYE %d | " % current_level_index
			
		diamond_label.text = "%s💎 %d / %d" % [level_str, diamonds_collected, total_diamonds]
			
	if move_label:
		move_label.text = "%d/%d" % [current_moves, target_moves]
			
		if current_moves <= target_moves:
			move_label.add_theme_color_override("font_color", Color("2e7d32")) # Yesil
		else:
			var diff = current_moves - target_moves
			if diff == 1:
				move_label.add_theme_color_override("font_color", Color("f57c00")) # Turuncu
			elif diff == 2:
				move_label.add_theme_color_override("font_color", Color("e65100")) # Koyu Turuncu
			else:
				move_label.add_theme_color_override("font_color", Color("c62828")) # Kirmizi

func increment_move():
	if not game_over and not level_cleared:
		current_moves += 1
		update_ui()

func win_level():
	print("Level Cleared!")
	level_cleared = true
	AudioController.play_victory()
	
	# Akilli Odul Sistemi (Smart Reward)
	var reward = diamonds_collected
	if current_moves > target_moves:
		var diff = current_moves - target_moves
		if diff <= 2:
			reward = max(1, int(reward / 2))
		else:
			reward = min(1, reward)
			
	SaveManager.add_gems(reward)
	update_ui()
	
	levels_cleared_since_ad += 1
	
	if restart_button:
		var next_index = current_level_index + 1
		if next_index > 100:
			next_index = 1
		restart_button.text = "SONRAKİ BÖLÜM (Seviye %d)" % next_index
	
	check_and_show_ad()

func show_victory_screen():
	if victory_screen:
		victory_screen.show()
		
		var title_label = victory_screen.get_node_or_null("Panel/VictoryLabel")
		if title_label:
			title_label.text = "BÖLÜM GEÇİLDİ!"
			title_label.add_theme_color_override("font_color", Color("ff007f"))
			
		var info_label = victory_screen.get_node_or_null("Panel/InfoLabel")
		if info_label:
			info_label.text = "Tebrikler!\nHamle: %d/%d" % [current_moves, target_moves]
			
		var panel = victory_screen.get_node_or_null("Panel")
		if panel:
			var old_cc = panel.get_node_or_null("CoinContainer")
			if old_cc:
				old_cc.queue_free()
				
			panel.scale = Vector2.ZERO
			panel.pivot_offset = panel.size / 2.0
			var tween = create_tween()
			tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func check_and_show_ad():
	var current_time = Time.get_ticks_msec()
	var time_diff_sec = (current_time - last_ad_time_msec) / 1000.0
	
	if time_diff_sec >= 120.0 or levels_cleared_since_ad >= 3:
		var ad_screen = get_node_or_null("../UI/AdScreen")
		if ad_screen:
			ad_screen.show()
			ad_screen.start_ad_timer()
			last_ad_time_msec = Time.get_ticks_msec()
			levels_cleared_since_ad = 0
		else:
			show_victory_screen()
	else:
		show_victory_screen()

func _on_restart_button_pressed():
	if level_cleared:
		# Load next sequential level
		var next_index = current_level_index + 1
		if next_index > 100:
			next_index = 1
		var next_path = "res://levels/level_%d.json" % next_index
		load_level_from_json(next_path)
	elif current_level_path != "":
		load_level_from_json(current_level_path)
	else:
		initialize_game()

func _on_mute_toggled(button_pressed: bool):
	AudioController.toggle_mute(button_pressed)
	if mute_button:
		mute_button.text = "SES KAPALI" if button_pressed else "SES"

# --- Debug and Solver ---

func _on_generate_levels_pressed():
	generate_and_save_100_levels()

func _on_editor_button_pressed():
	get_tree().change_scene_to_file("res://scenes/LevelEditor.tscn")

func generate_and_save_100_levels():
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
	var max_attempts = 10000 # Increased because complex levels are harder to generate
	
	while count < 100 and attempts < max_attempts:
		attempts += 1
		var level = LevelGenerator.generate_level_for_index(count + 1)
		if level.is_empty():
			continue
			
		var moves = level["min_moves"] # It's already calculated in the generator
		count += 1
		
		var path = "res://levels/level_%d.json" % count
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			var json_str = JSON.stringify(level, "\t")
			file.store_string(json_str)
			file.close()
			
		if debug_status_label:
			debug_status_label.text = "Generated: %d/100 (Par: %d)" % [count, moves]
			
		if count % 2 == 0:
			await get_tree().process_frame
				
	if generate_levels_button:
		generate_levels_button.disabled = false
		
	if debug_status_label:
		if count == 100:
			debug_status_label.text = "Success! 100 levels saved."
			load_level_from_json("res://levels/level_1.json")
		else:
			debug_status_label.text = "Failed to generate 100 levels (attempts: %d)." % attempts

# --- Procedural UI Styling ---

func style_ui():
	# Override TopBar labels for minimalist look
	if diamond_label:
		diamond_label.add_theme_color_override("font_color", Color("37474f")) # Dark slate gray

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

func setup_zoom_camera():
	var bg = get_node_or_null("../Background")
	if bg and bg is ColorRect:
		bg.size = Vector2(10000, 10000)
		bg.position = Vector2(-4000, -4000)
		
	var cam = Camera2D.new()
	cam.name = "MainCamera"
	cam.position = Vector2(540, 960)
	get_node("/root/Main").add_child(cam)
	
	var ui = get_node_or_null("../UI")
	if not ui: return
	
	var zoom_in_btn = Button.new()
	zoom_in_btn.text = "🔍+"
	zoom_in_btn.add_theme_font_size_override("font_size", 40)
	zoom_in_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom_in_btn.position = Vector2(1080 - 130, 1920 - 260)
	zoom_in_btn.size = Vector2(100, 100)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.corner_radius_top_left = 50
	style.corner_radius_top_right = 50
	style.corner_radius_bottom_left = 50
	style.corner_radius_bottom_right = 50
	zoom_in_btn.add_theme_stylebox_override("normal", style)
	zoom_in_btn.add_theme_stylebox_override("hover", style)
	zoom_in_btn.add_theme_stylebox_override("pressed", style)
	
	zoom_in_btn.pressed.connect(func():
		var current = cam.zoom
		cam.zoom = Vector2(current.x + 0.1, current.y + 0.1)
	)
	ui.add_child(zoom_in_btn)
	
	var zoom_out_btn = Button.new()
	zoom_out_btn.text = "🔍-"
	zoom_out_btn.add_theme_font_size_override("font_size", 40)
	zoom_out_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	zoom_out_btn.position = Vector2(1080 - 130, 1920 - 140)
	zoom_out_btn.size = Vector2(100, 100)
	zoom_out_btn.add_theme_stylebox_override("normal", style)
	zoom_out_btn.add_theme_stylebox_override("hover", style)
	zoom_out_btn.add_theme_stylebox_override("pressed", style)
	
	zoom_out_btn.pressed.connect(func():
		var current = cam.zoom
		if current.x > 0.3:
			cam.zoom = Vector2(current.x - 0.1, current.y - 0.1)
	)
	ui.add_child(zoom_out_btn)
