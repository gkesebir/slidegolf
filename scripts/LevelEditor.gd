extends Control

@export var grid_manager: GridManager
@export var status_label: Label
@export var tool_buttons: Array[Button] # Buttons in palette: Wall, Gem, Hole, PortalIn, PortalOut, BallStart, Grass
@export var save_button: Button
@export var play_test_button: Button
@export var back_button: Button

var grid_width = 7
var grid_height = 7
var player_start = Vector2i(1, 1)
var active_tool = 1 # Default: Wall

var start_marker: Panel

func _ready():
	if not grid_manager:
		grid_manager = $GridManager
		
	# Initialize default grid (borders are walls, inner empty)
	var default_grid = []
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			if x == 0 or x == grid_width - 1 or y == 0 or y == grid_height - 1:
				row.append(1) # Wall border
			else:
				row.append(0) # Empty
		default_grid.append(row)
		
	# Place initial hole
	default_grid[5][5] = 3
	
	grid_manager.grid = default_grid
	grid_manager.grid_width = grid_width
	grid_manager.grid_height = grid_height
	grid_manager.reset_grid()
	
	# Connect palette buttons
	# Array indices mapping:
	# 0 = Wall, 1 = Gem, 2 = Hole, 3 = PortalIn, 4 = PortalOut, 5 = BallStart, 6 = Grass
	if tool_buttons.size() >= 7:
		tool_buttons[0].pressed.connect(func(): _select_tool(1)) # Wall
		tool_buttons[1].pressed.connect(func(): _select_tool(2)) # Gem
		tool_buttons[2].pressed.connect(func(): _select_tool(3)) # Hole
		tool_buttons[3].pressed.connect(func(): _select_tool(4)) # PortalIn
		tool_buttons[4].pressed.connect(func(): _select_tool(5)) # PortalOut
		tool_buttons[5].pressed.connect(func(): _select_tool(100)) # BallStart
		tool_buttons[6].pressed.connect(func(): _select_tool(0)) # Grass/Clear
		
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if play_test_button:
		play_test_button.pressed.connect(_on_play_test_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		
	_select_tool(1) # Select Wall by default
	update_start_marker()
	style_editor_ui()
	validate_and_update_status()

func _input(event):
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# Check if left button is pressed
		var is_pressed = false
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				is_pressed = event.pressed
		elif event is InputEventMouseMotion:
			is_pressed = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
			
		if is_pressed:
			var local_pos = grid_manager.get_local_mouse_position()
			var gx = floor(local_pos.x / grid_manager.cell_size)
			var gy = floor(local_pos.y / grid_manager.cell_size)
			var grid_pos = Vector2i(gx, gy)
			
			# Paint if inside grid and not on the wall boundaries
			if gx > 0 and gx < grid_width - 1 and gy > 0 and gy < grid_height - 1:
				_paint_cell(grid_pos)

func _paint_cell(grid_pos: Vector2i):
	var current_grid = grid_manager.grid
	
	if active_tool == 100:
		# Change player start position (ensure cell itself is empty type 0)
		if current_grid[grid_pos.y][grid_pos.x] == 3:
			return # Cannot spawn player inside the target hole
		player_start = grid_pos
		if current_grid[grid_pos.y][grid_pos.x] != 4 and current_grid[grid_pos.y][grid_pos.x] != 5:
			current_grid[grid_pos.y][grid_pos.x] = 0
	elif active_tool == 3:
		# Placing Hole: remove existing hole
		for y in range(grid_height):
			for x in range(grid_width):
				if current_grid[y][x] == 3:
					current_grid[y][x] = 0
		current_grid[grid_pos.y][grid_pos.x] = 3
	elif active_tool == 4:
		# Placing PortalIn: remove existing PortalIn
		for y in range(grid_height):
			for x in range(grid_width):
				if current_grid[y][x] == 4:
					current_grid[y][x] = 0
		current_grid[grid_pos.y][grid_pos.x] = 4
	elif active_tool == 5:
		# Placing PortalOut: remove existing PortalOut
		for y in range(grid_height):
			for x in range(grid_width):
				if current_grid[y][x] == 5:
					current_grid[y][x] = 0
		current_grid[grid_pos.y][grid_pos.x] = 5
	else:
		# Standard type painting (Wall, Gem, Grass)
		# Enforce player spawn position shouldn't be covered by walls
		if active_tool == 1 and grid_pos == player_start:
			return
		current_grid[grid_pos.y][grid_pos.x] = active_tool
		
	grid_manager.grid = current_grid
	grid_manager.reset_grid()
	update_start_marker()
	validate_and_update_status()

func _select_tool(tool_id: int):
	active_tool = tool_id
	
	# Highlight selected tool button
	# Mapping tool_id to palette index:
	# 1->0, 2->1, 3->2, 4->3, 5->4, 100->5, 0->6
	var active_index = -1
	match tool_id:
		1: active_index = 0
		2: active_index = 1
		3: active_index = 2
		4: active_index = 3
		5: active_index = 4
		100: active_index = 5
		0: active_index = 6
		
	for i in range(tool_buttons.size()):
		var btn = tool_buttons[i]
		if not btn:
			continue
			
		var style = btn.get_theme_stylebox("normal").duplicate()
		if i == active_index:
			# Highlight active
			style.bg_color = Color("e8f5e9")
			style.border_color = Color("2e7d32") # Dark green border
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			btn.add_theme_color_override("font_color", Color("2e7d32"))
		else:
			style.bg_color = Color("ffffff")
			style.border_color = Color("e0e0e0")
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			btn.add_theme_color_override("font_color", Color("37474f"))
		btn.add_theme_stylebox_override("normal", style)

func update_start_marker():
	if not start_marker:
		start_marker = Panel.new()
		start_marker.size = Vector2(grid_manager.cell_size * 0.5, grid_manager.cell_size * 0.5)
		start_marker.pivot_offset = start_marker.size / 2.0
		var style = StyleBoxFlat.new()
		style.bg_color = Color("f5f5f5") # Cream white
		style.border_color = Color("78909c") # Slate border
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = start_marker.size.x / 2.0
		style.corner_radius_top_right = start_marker.size.x / 2.0
		style.corner_radius_bottom_left = start_marker.size.x / 2.0
		style.corner_radius_bottom_right = start_marker.size.x / 2.0
		style.shadow_color = Color(0, 0, 0, 0.15)
		style.shadow_size = 3
		start_marker.add_theme_stylebox_override("panel", style)
		
		# Specular dot
		var dot = ColorRect.new()
		dot.size = Vector2(4, 4)
		dot.position = Vector2(4, 4)
		dot.color = Color(1, 1, 1, 0.6)
		start_marker.add_child(dot)
		
		grid_manager.add_child(start_marker)
		
	var cell_pos = grid_manager.get_cell_world_position(player_start)
	start_marker.position = cell_pos + Vector2(grid_manager.cell_size * 0.25, grid_manager.cell_size * 0.25)

func get_level_dictionary() -> Dictionary:
	var current_grid = grid_manager.grid
	var walls_json = []
	var gems_json = []
	var hole = Vector2i(-1, -1)
	var portal_in = Vector2i(-1, -1)
	var portal_out = Vector2i(-1, -1)
	
	for y in range(grid_height):
		for x in range(grid_width):
			var type = current_grid[y][x]
			if type == 1:
				# Skip outer walls to keep file size compact, only store inner walls
				if x > 0 and x < grid_width - 1 and y > 0 and y < grid_height - 1:
					walls_json.append([x, y])
			elif type == 2:
				gems_json.append([x, y])
			elif type == 3:
				hole = Vector2i(x, y)
			elif type == 4:
				portal_in = Vector2i(x, y)
			elif type == 5:
				portal_out = Vector2i(x, y)
				
	var level_data = {
		"grid_size": [grid_width, grid_height],
		"player_start": [player_start.x, player_start.y],
		"objects": {
			"walls": walls_json,
			"gems": gems_json,
			"hole": [hole.x, hole.y]
		},
		"grid": current_grid,
		"min_moves": -1
	}
	
	if portal_in != Vector2i(-1, -1) and portal_out != Vector2i(-1, -1):
		level_data["objects"]["portal_in"] = [portal_in.x, portal_in.y]
		level_data["objects"]["portal_out"] = [portal_out.x, portal_out.y]
		
	return level_data

func validate_and_update_status():
	if not status_label:
		return
		
	var level_data = get_level_dictionary()
	var moves = LevelSolver.solve_level(level_data)
	
	if moves > 0:
		status_label.text = "Status: Solvable (Par: %d moves)" % moves
		status_label.add_theme_color_override("font_color", Color("2e7d32")) # Pastel Green
	else:
		status_label.text = "Status: Unsolvable"
		status_label.add_theme_color_override("font_color", Color("ef5350")) # Pastel Red

func _on_save_pressed():
	var level_data = get_level_dictionary()
	var moves = LevelSolver.solve_level(level_data)
	level_data["min_moves"] = moves
	
	var path = "res://custom_levels.json"
	var custom_levels = []
	
	# Load existing custom levels
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_str) == OK:
				var data = json.get_data()
				if data is Array:
					custom_levels = data
					
	# Append new custom level
	custom_levels.append(level_data)
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(custom_levels, "\t")
		file.store_string(json_str)
		file.close()
		
		if status_label:
			status_label.text = "Level Saved to res://custom_levels.json successfully!"
			status_label.add_theme_color_override("font_color", Color("2e7d32"))
	else:
		printerr("Failed to save custom level.")

func _on_play_test_pressed():
	var level_data = get_level_dictionary()
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.playtest_level_data = level_data
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func style_editor_ui():
	# Style Action Buttons
	var actions = [
		{"btn": save_button, "border": "2e7d32", "text": "2e7d32", "hover": "f1f8e9"},
		{"btn": play_test_button, "border": "ffb74d", "text": "e65100", "hover": "fff3e0"},
		{"btn": back_button, "border": "ef5350", "text": "c62828", "hover": "ffebee"}
	]
	
	for action in actions:
		var btn = action["btn"]
		if not btn:
			continue
			
		var style = StyleBoxFlat.new()
		style.bg_color = Color("ffffff")
		style.border_color = Color(action["border"])
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.shadow_color = Color(0, 0, 0, 0.05)
		style.shadow_size = 2
		
		var hover = style.duplicate()
		hover.bg_color = Color(action["hover"])
		hover.shadow_size = 4
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_color_override("font_color", Color(action["text"]))

	# Style BottomBar panel
	var bar = get_node_or_null("UI/BottomBar")
	if bar:
		var bar_style = StyleBoxFlat.new()
		bar_style.bg_color = Color("ffffff") # Clean white
		bar_style.border_color = Color("e0e0e0")
		bar_style.border_width_top = 3
		bar_style.corner_radius_top_left = 24
		bar_style.corner_radius_top_right = 24
		bar_style.shadow_color = Color(0, 0, 0, 0.05)
		bar_style.shadow_size = 8
		bar.add_theme_stylebox_override("panel", bar_style)
