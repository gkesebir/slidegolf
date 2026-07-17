extends Control

@export var grid_manager: GridManager
@export var status_label: Label
@export var tool_buttons: Array[Button] # Grass, Wall, Void, Mud, Gem, Hole, PortalIn, PortalOut, Start
@export var save_button: Button
@export var play_test_button: Button
@export var back_button: Button
@export var new_level_button: Button

# Grid Row/Col controls
@export var row_plus_button: Button
@export var row_minus_button: Button
@export var col_plus_button: Button
@export var col_minus_button: Button
@export var row_label: Label
@export var col_label: Label

# Zoom controls
@export var zoom_in_button: Button
@export var zoom_out_button: Button

# Hamburger & Sidebar
@export var hamburger_button: Button
@export var sidebar_panel: Panel
@export var sidebar_close_button: Button
@export var audit_button: Button
@export var level_list_container: VBoxContainer

var grid_width = 7
var grid_height = 7
var player_start = Vector2i(1, 1)
var active_tool = 1 # Default: Wall

# Drag states for click-to-move / drag-and-drop
var is_dragging_start = false
var is_dragging_hole = false

var zoom_level = 1.0
var camera: Camera2D
var start_marker: Panel
var is_sidebar_open = false

var loaded_level_path: String = ""
var loaded_custom_index: int = -1

# Struct to map button texts for localization styling
var level_buttons_data: Array = [] # Stores array of {"btn": Button, "dict": Dictionary, "path": String} for auditing

func _ready():
	# Retrieve or find camera
	camera = get_node_or_null("Camera2D")
	if not camera:
		camera = Camera2D.new()
		camera.position = Vector2(540, 960)
		add_child(camera)
	camera.make_current()
	
	if not grid_manager:
		grid_manager = get_node_or_null("GridManager")
		
	# Setup initial default grid
	_initialize_default_grid()
	
	# Connect palette buttons
	# Index mapping:
	# 0 = Grass (0), 1 = Wall (1), 2 = Void (9), 3 = Mud (10)
	# 4 = Gem (2), 5 = Hole (3), 6 = PortalIn (4), 7 = PortalOut (5), 8 = Start (100)
	if tool_buttons.size() >= 9:
		tool_buttons[0].pressed.connect(func(): _select_tool(0)) # Grass
		tool_buttons[1].pressed.connect(func(): _select_tool(1)) # Wall
		tool_buttons[2].pressed.connect(func(): _select_tool(9)) # Void
		tool_buttons[3].pressed.connect(func(): _select_tool(10)) # Mud
		tool_buttons[4].pressed.connect(func(): _select_tool(2)) # Gem
		tool_buttons[5].pressed.connect(func(): _select_tool(3)) # Hole
		tool_buttons[6].pressed.connect(func(): _select_tool(4)) # PortalIn
		tool_buttons[7].pressed.connect(func(): _select_tool(5)) # PortalOut
		tool_buttons[8].pressed.connect(func(): _select_tool(100)) # Start
		
	# Action buttons
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if play_test_button:
		play_test_button.pressed.connect(_on_play_test_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if new_level_button:
		new_level_button.pressed.connect(_on_new_level_pressed)
		
	# Grid controls
	if row_plus_button:
		row_plus_button.pressed.connect(func(): _adjust_rows(1))
	if row_minus_button:
		row_minus_button.pressed.connect(func(): _adjust_rows(-1))
	if col_plus_button:
		col_plus_button.pressed.connect(func(): _adjust_cols(1))
	if col_minus_button:
		col_minus_button.pressed.connect(func(): _adjust_cols(-1))
		
	# Zoom controls
	if zoom_in_button:
		zoom_in_button.pressed.connect(func(): _adjust_zoom(0.1))
	if zoom_out_button:
		zoom_out_button.pressed.connect(func(): _adjust_zoom(-0.1))
		
	# Sidebar controls
	if hamburger_button:
		hamburger_button.pressed.connect(_toggle_sidebar)
	if sidebar_close_button:
		sidebar_close_button.pressed.connect(_toggle_sidebar)
	if audit_button:
		audit_button.pressed.connect(_on_audit_pressed)
		
	# Initial sidebar position
	if sidebar_panel:
		sidebar_panel.position.x = -500
		
	_select_tool(1) # Default: Wall
	update_start_marker()
	style_editor_ui()
	_update_grid_labels()
	build_level_list()
	validate_and_update_status()

func _initialize_default_grid():
	var default_grid = []
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			if x == 0 or x == grid_width - 1 or y == 0 or y == grid_height - 1:
				row.append(1) # Boundary walls
			else:
				row.append(0) # Empty grass
		default_grid.append(row)
		
	# Spawn default hole at 5,5 if space allows, otherwise bottom-right corner
	var hx = min(5, grid_width - 2)
	var hy = min(5, grid_height - 2)
	default_grid[hy][hx] = 3
	
	player_start = Vector2i(1, 1)
	
	if is_instance_valid(grid_manager):
		grid_manager.grid = default_grid
		grid_manager.grid_width = grid_width
		grid_manager.grid_height = grid_height
		grid_manager.reset_grid()

func _input(event):
	# Camera zoom using mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(0.05)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(-0.05)
			get_viewport().set_input_as_handled()
			
	# Tıklama ile boyama / yerleştirme (Sürükleme IPTAL)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(grid_manager):
			var local_pos = grid_manager.get_local_mouse_position()
			var gx = floor(local_pos.x / grid_manager.cell_size)
			var gy = floor(local_pos.y / grid_manager.cell_size)
			var grid_pos = Vector2i(gx, gy)
			
			# İç sınırlara tıklandığından emin ol
			if gx > 0 and gx < grid_width - 1 and gy > 0 and gy < grid_height - 1:
				_paint_cell(grid_pos)

func _paint_cell(grid_pos: Vector2i):
	if not is_instance_valid(grid_manager):
		return
	var current_grid = grid_manager.grid
	
	if active_tool == 100:
		# Top (Başlangıç) yerleştirme
		var type = current_grid[grid_pos.y][grid_pos.x]
		# Duvar (1), Boşluk (9) veya Delik (3) üzerine yerleştirilemez
		if type == 1 or type == 9 or type == 3:
			return
		player_start = grid_pos
		# Çim, çamur veya elmas olan yerin zeminini sıfırlamıyoruz!
	elif active_tool == 3:
		# Delik
		# Sadece 1 tane delik olabilir, eskisini temizle
		for y in range(grid_height):
			for x in range(grid_width):
				if current_grid[y][x] == 3:
					current_grid[y][x] = 0
		current_grid[grid_pos.y][grid_pos.x] = 3
	elif active_tool == 4:
		# PortalIn
		for y in range(grid_height):
			for x in range(grid_width):
				if current_grid[y][x] == 4:
					current_grid[y][x] = 0
		current_grid[grid_pos.y][grid_pos.x] = 4
	elif active_tool == 5:
		# PortalOut
		for y in range(grid_height):
			for x in range(grid_width):
				if current_grid[y][x] == 5:
					current_grid[y][x] = 0
		current_grid[grid_pos.y][grid_pos.x] = 5
	else:
		# Wall (1), Gem (2), Void (9), Mud (10), Grass (0)
		if (active_tool == 1 or active_tool == 9) and grid_pos == player_start:
			return # Topun olduğu yere duvar veya boşluk konulamaz
		current_grid[grid_pos.y][grid_pos.x] = active_tool
		
	if is_instance_valid(grid_manager):
		grid_manager.grid = current_grid
		grid_manager.reset_grid()
	update_start_marker()
	validate_and_update_status()

func _select_tool(tool_id: int):
	active_tool = tool_id
	
	# Highlight selected tool in palette
	# Mapping tool_id to palette index:
	# 0->0, 1->1, 9->2, 10->3, 2->4, 3->5, 4->6, 5->7, 100->8
	var active_index = -1
	match tool_id:
		0: active_index = 0
		1: active_index = 1
		9: active_index = 2
		10: active_index = 3
		2: active_index = 4
		3: active_index = 5
		4: active_index = 6
		5: active_index = 7
		100: active_index = 8
		
	for i in range(tool_buttons.size()):
		var btn = tool_buttons[i]
		if not btn:
			continue
			
		var style = btn.get_theme_stylebox("normal").duplicate()
		if i == active_index:
			style.bg_color = Color("e8f5e9") # Active highlight pastel green
			style.border_color = Color("2e7d32")
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
	if not is_instance_valid(grid_manager):
		return
		
	if not is_instance_valid(start_marker) or start_marker.is_queued_for_deletion():
		start_marker = Panel.new()
		start_marker.z_index = 100 # Top her zaman en üstte görünsün
		start_marker.size = Vector2(grid_manager.cell_size * 0.5, grid_manager.cell_size * 0.5)
		start_marker.pivot_offset = start_marker.size / 2.0
		var style = StyleBoxFlat.new()
		style.bg_color = Color("f5f5f5") # Ball white
		style.border_color = Color("78909c")
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
		
		var dot = ColorRect.new()
		dot.size = Vector2(4, 4)
		dot.position = Vector2(4, 4)
		dot.color = Color(1, 1, 1, 0.6)
		start_marker.add_child(dot)
		grid_manager.add_child(start_marker)
		
	var cell_pos = grid_manager.get_cell_world_position(player_start)
	start_marker.position = cell_pos + Vector2(grid_manager.cell_size * 0.25, grid_manager.cell_size * 0.25)

func _adjust_rows(delta: int):
	var new_h = clamp(grid_height + delta, 5, 12)
	if new_h != grid_height:
		_resize_grid(grid_width, new_h)

func _adjust_cols(delta: int):
	var new_w = clamp(grid_width + delta, 5, 12)
	if new_w != grid_width:
		_resize_grid(new_w, grid_height)

func _resize_grid(new_width: int, new_height: int):
	if not is_instance_valid(grid_manager):
		return
		
	var old_grid = grid_manager.grid
	var old_w = grid_manager.grid_width
	var old_h = grid_manager.grid_height
	
	var new_grid = []
	for y in range(new_height):
		var row = []
		for x in range(new_width):
			if x == 0 or x == new_width - 1 or y == 0 or y == new_height - 1:
				row.append(1)
			else:
				if x < old_w - 1 and y < old_h - 1:
					row.append(old_grid[y][x])
				else:
					row.append(0)
		new_grid.append(row)
		
	# Clamp player spawn and target hole to safe inner coordinates
	player_start.x = clamp(player_start.x, 1, new_width - 2)
	player_start.y = clamp(player_start.y, 1, new_height - 2)
	
	# Locate hole position and clamp
	var found_hole = false
	var h_pos = Vector2i(new_width - 2, new_height - 2)
	for y in range(new_height):
		for x in range(new_width):
			if new_grid[y][x] == 3:
				found_hole = true
				h_pos = Vector2i(x, y)
				break
				
	if not found_hole:
		# Place target hole
		new_grid[h_pos.y][h_pos.x] = 3
		
	grid_width = new_width
	grid_height = new_height
	
	grid_manager.grid = new_grid
	grid_manager.grid_width = grid_width
	grid_manager.grid_height = grid_height
	grid_manager.reset_grid()
	
	update_start_marker()
	_update_grid_labels()
	validate_and_update_status()

func _update_grid_labels():
	if row_label:
		row_label.text = "Satır: %d" % grid_height
	if col_label:
		col_label.text = "Sütun: %d" % grid_width

func _adjust_zoom(delta: float):
	zoom_level = clamp(zoom_level + delta, 0.5, 2.0)
	if camera:
		camera.zoom = Vector2(zoom_level, zoom_level)

func _toggle_sidebar():
	is_sidebar_open = !is_sidebar_open
	if sidebar_panel:
		var tween = create_tween()
		var target_x = 0 if is_sidebar_open else -500
		tween.tween_property(sidebar_panel, "position:x", target_x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func build_level_list():
	if not level_list_container:
		return
		
	# Clear list
	for child in level_list_container.get_children():
		child.queue_free()
		
	level_buttons_data.clear()
	
	# Style base list panels
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color("ffffff")
	btn_normal.border_color = Color("e0e0e0")
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 8
	btn_normal.corner_radius_top_right = 8
	btn_normal.corner_radius_bottom_left = 8
	btn_normal.corner_radius_bottom_right = 8
	btn_normal.shadow_color = Color(0, 0, 0, 0.03)
	btn_normal.shadow_size = 2
	
	# 1. Built-in levels (Level 1-50)
	for i in range(1, 51):
		var path = "res://levels/level_%d.json" % i
		if FileAccess.file_exists(path):
			_add_list_element("Seviye %d" % i, path, {}, -1, btn_normal)
			
	# 2. Custom levels
	var custom_path = "res://custom_levels.json"
	if FileAccess.file_exists(custom_path):
		var file = FileAccess.open(custom_path, FileAccess.READ)
		if file:
			var json_str = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_str) == OK:
				var data = json.get_data()
				if data is Array:
					for idx in range(data.size()):
						var level_dict = data[idx]
						_add_list_element("Özel %d" % (idx + 1), "", level_dict, idx, btn_normal)

func _add_list_element(label_text: String, file_path: String, direct_dict: Dictionary, custom_idx: int, base_style: StyleBoxFlat):
	var btn = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 70)
	btn.add_theme_stylebox_override("normal", base_style)
	btn.add_theme_color_override("font_color", Color("37474f"))
	btn.add_theme_font_size_override("font_size", 22)
	
	# Load action
	btn.pressed.connect(func():
		_load_level_data(file_path, direct_dict, custom_idx)
		_toggle_sidebar()
	)
	
	level_list_container.add_child(btn)
	level_buttons_data.append({"btn": btn, "path": file_path, "dict": direct_dict})

func _load_level_data(file_path: String, direct_dict: Dictionary, custom_idx: int):
	var level_data: Dictionary = {}
	
	loaded_level_path = file_path
	loaded_custom_index = custom_idx
	
	if not file_path.is_empty():
		# Load from file
		if FileAccess.file_exists(file_path):
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var json_str = file.get_as_text()
				file.close()
				var json = JSON.new()
				if json.parse(json_str) == OK:
					var data = json.get_data()
					if data is Dictionary:
						level_data = data
	else:
		level_data = direct_dict
		
	if level_data.is_empty():
		return
		
	# Set attributes
	var g_size = level_data["grid_size"]
	grid_width = g_size[0]
	grid_height = g_size[1]
	
	var start_arr = level_data["player_start"]
	player_start = Vector2i(start_arr[0], start_arr[1])
	
	if is_instance_valid(grid_manager):
		grid_manager.grid = level_data["grid"]
		grid_manager.grid_width = grid_width
		grid_manager.grid_height = grid_height
		grid_manager.reset_grid()
		
	update_start_marker()
	_update_grid_labels()
	validate_and_update_status()

func get_level_dictionary() -> Dictionary:
	if not is_instance_valid(grid_manager):
		return {}
		
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
		status_label.text = "Durum: Çözülebilir (Par: %d Hamle)" % moves
		status_label.add_theme_color_override("font_color", Color("2e7d32"))
	else:
		status_label.text = "Durum: Çözülemez (Hatalı)"
		status_label.add_theme_color_override("font_color", Color("ef5350"))

func _on_save_pressed():
	var level_data = get_level_dictionary()
	var moves = LevelSolver.solve_level(level_data)
	level_data["min_moves"] = moves
	
	if not loaded_level_path.is_empty():
		# Var olan gercek oyundaki bolumu ustune yaz
		var file = FileAccess.open(loaded_level_path, FileAccess.WRITE)
		if file:
			var json_str = JSON.stringify(level_data, "\t")
			file.store_string(json_str)
			file.close()
			
			if status_label:
				status_label.text = "Seviye başarıyla güncellendi: %s" % loaded_level_path.get_file()
				status_label.add_theme_color_override("font_color", Color("2e7d32"))
			build_level_list()
		else:
			printerr("Guncelleme basarisiz: ", loaded_level_path)
			
	else:
		# Yeni seviyeyi gercek levels klasorune yeni bir numarayla ekle
		var dir = DirAccess.open("res://levels")
		var max_num = 0
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.begins_with("level_") and file_name.ends_with(".json"):
					var num_str = file_name.replace("level_", "").replace(".json", "")
					if num_str.is_valid_int():
						var num = num_str.to_int()
						if num > max_num:
							max_num = num
				file_name = dir.get_next()
			dir.list_dir_end()
			
		var next_num = max_num + 1
		var new_path = "res://levels/level_%d.json" % next_num
		
		var file = FileAccess.open(new_path, FileAccess.WRITE)
		if file:
			var json_str = JSON.stringify(level_data, "\t")
			file.store_string(json_str)
			file.close()
			
			loaded_level_path = new_path # Artik bu kayitli bir seviye oldu
			
			if status_label:
				status_label.text = "Oyun veritabanına yeni seviye olarak kaydedildi: level_%d.json" % next_num
				status_label.add_theme_color_override("font_color", Color("2e7d32"))
			build_level_list()
		else:
			printerr("Yeni seviye kaydetme basarisiz.")

func _on_play_test_pressed():
	var level_data = get_level_dictionary()
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.playtest_level_data = level_data
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_new_level_pressed():
	# Clear Canvas, reset size to 7x7 and default layout
	grid_width = 7
	grid_height = 7
	loaded_level_path = ""
	loaded_custom_index = -1
	_initialize_default_grid()
	update_start_marker()
	_update_grid_labels()
	validate_and_update_status()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_audit_pressed():
	# Toplu seviye denetimi: Solver ile tüm listedeki seviyeleri tara
	for entry in level_buttons_data:
		var btn = entry["btn"]
		var path = entry["path"]
		var direct_dict = entry["dict"]
		
		var level_data: Dictionary = {}
		if not path.is_empty():
			if FileAccess.file_exists(path):
				var file = FileAccess.open(path, FileAccess.READ)
				if file:
					var json_str = file.get_as_text()
					file.close()
					var json = JSON.new()
					if json.parse(json_str) == OK:
						var data = json.get_data()
						if data is Dictionary:
							level_data = data
		else:
			level_data = direct_dict
			
		if not level_data.is_empty():
			var moves = LevelSolver.solve_level(level_data)
			if moves > 0:
				# Solvable: pastel green text
				btn.add_theme_color_override("font_color", Color("2e7d32"))
				btn.text = btn.text.split(" (")[0] + " (Çözülebilir: %d)" % moves
			else:
				# Unsolvable/Softlocked: red text
				btn.add_theme_color_override("font_color", Color("ef5350"))
				btn.text = btn.text.split(" (")[0] + " (Çözülemez!)"

func style_editor_ui():
	# Style topbar
	var topbar = get_node_or_null("UI/TopBar")
	if topbar:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("ffffff")
		style.border_color = Color("e0e0e0")
		style.border_width_bottom = 3
		style.corner_radius_bottom_left = 24
		style.corner_radius_bottom_right = 24
		style.shadow_color = Color(0, 0, 0, 0.05)
		style.shadow_size = 8
		topbar.add_theme_stylebox_override("panel", style)
		
	# Style sidebar
	if sidebar_panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("ffffff")
		style.border_color = Color("e0e0e0")
		style.border_width_right = 4
		style.shadow_color = Color(0, 0, 0, 0.1)
		style.shadow_size = 12
		sidebar_panel.add_theme_stylebox_override("panel", style)
		
	# Style close button & audit button
	if sidebar_close_button:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("ffebee")
		style.border_color = Color("ef5350")
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 30
		style.corner_radius_top_right = 30
		style.corner_radius_bottom_left = 30
		style.corner_radius_bottom_right = 30
		sidebar_close_button.add_theme_stylebox_override("normal", style)
		sidebar_close_button.add_theme_color_override("font_color", Color("c62828"))
		
	if audit_button:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("ffffff")
		style.border_color = Color("0288d1") # Blue border
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		audit_button.add_theme_stylebox_override("normal", style)
		audit_button.add_theme_color_override("font_color", Color("01579b"))
		
	# Style Action Buttons
	var actions = [
		{"btn": save_button, "border": "2e7d32", "text": "2e7d32", "hover": "f1f8e9"},
		{"btn": play_test_button, "border": "ffb74d", "text": "e65100", "hover": "fff3e0"},
		{"btn": new_level_button, "border": "ab47bc", "text": "6a1b9a", "hover": "f3e5f5"},
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
		bar_style.bg_color = Color("ffffff")
		bar_style.border_color = Color("e0e0e0")
		bar_style.border_width_top = 3
		bar_style.corner_radius_top_left = 24
		bar_style.corner_radius_top_right = 24
		bar_style.shadow_color = Color(0, 0, 0, 0.05)
		bar_style.shadow_size = 8
		bar.add_theme_stylebox_override("panel", bar_style)
		
	# Style Hamburger button and control buttons
	var ct_btns = [hamburger_button, row_plus_button, row_minus_button, col_plus_button, col_minus_button, zoom_in_button, zoom_out_button]
	for btn in ct_btns:
		if not btn:
			continue
		var style = StyleBoxFlat.new()
		style.bg_color = Color("ffffff")
		style.border_color = Color("cfd8dc")
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color("37474f"))
