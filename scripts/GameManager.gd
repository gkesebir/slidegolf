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
var settings_screen: Control

# Ad System State
var last_ad_time_msec: int = 0
var levels_cleared_since_ad: int = 0

func _ready():
	last_ad_time_msec = Time.get_ticks_msec()
	
	# Cleanup old UI elements that are no longer used
	var to_remove = [
		"../UI/TopBar/DiamondLabel", 
		"../UI/TopBar/TimerLabel", 
		"../UI/TopBar/ShopButton", 
		"../UI/ShopScreen", 
		"../UI/DebugPanel"
	]
	for path in to_remove:
		var node = get_node_or_null(path)
		if node:
			node.queue_free()
	
	# Re-create diamond label dynamically
	var ui_topbar = get_node_or_null("../UI/TopBar")
	if ui_topbar:
		diamond_label = Label.new()
		diamond_label.name = "DiamondLabel"
		diamond_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		diamond_label.position = Vector2(160, 110 - 30) # Moved right to make room for hamburger
		diamond_label.add_theme_font_size_override("font_size", 42)
		diamond_label.add_theme_color_override("font_color", Color("37474f"))
		ui_topbar.add_child(diamond_label)
		
	# Settings Button dynamically
	if ui_topbar:
		var settings_btn = Button.new()
		settings_btn.text = "⚙️"
		settings_btn.add_theme_font_size_override("font_size", 50)
		settings_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		settings_btn.position = Vector2(1080 - 120, 110 - 40)
		settings_btn.size = Vector2(80, 80)
		
		var s_style = StyleBoxFlat.new()
		s_style.bg_color = Color("ffffff")
		s_style.border_width_left = 2
		s_style.border_width_top = 2
		s_style.border_width_right = 2
		s_style.border_width_bottom = 2
		s_style.corner_radius_top_left = 20
		s_style.corner_radius_top_right = 20
		s_style.corner_radius_bottom_left = 20
		s_style.corner_radius_bottom_right = 20
		settings_btn.add_theme_stylebox_override("normal", s_style)
		settings_btn.add_theme_color_override("font_color", Color("37474f"))
		settings_btn.pressed.connect(_open_settings)
		ui_topbar.add_child(settings_btn)
		
		# Hamburger Button dynamically
		var hamburger_btn = Button.new()
		hamburger_btn.text = "☰"
		hamburger_btn.add_theme_font_size_override("font_size", 50)
		hamburger_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		hamburger_btn.position = Vector2(40, 110 - 40)
		hamburger_btn.size = Vector2(80, 80)
		hamburger_btn.add_theme_stylebox_override("normal", s_style)
		hamburger_btn.add_theme_color_override("font_color", Color("37474f"))
		hamburger_btn.pressed.connect(_open_level_selection)
		ui_topbar.add_child(hamburger_btn)

	_build_settings_screen()
	_build_level_selection_screen()
	
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
	
	grid_manager.grid = level_data["grid"].duplicate(true)
	grid_manager.grid_width = level_data["grid_size"][0]
	grid_manager.grid_height = level_data["grid_size"][1]
	
	grid_manager.reset_grid()
	
	current_moves = 0
	total_diamonds = count_diamonds_in_grid()
	diamonds_collected = 0
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
	total_diamonds = count_diamonds_in_grid()
	diamonds_collected = 0
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
	return diamonds_collected >= total_diamonds

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
	
	check_and_show_ad()

func show_victory_screen():
	if victory_screen:
		victory_screen.show()
		
		var title_label = victory_screen.get_node_or_null("Panel/VictoryLabel")
		if title_label:
			title_label.text = "BÖLÜM GEÇİLDİ!"
			title_label.add_theme_color_override("font_color", Color("00e676"))
			
		var info_label = victory_screen.get_node_or_null("Panel/InfoLabel")
		if info_label:
			info_label.text = "Tebrikler!\nHamle: %d / %d" % [current_moves, target_moves]
			
		var panel = victory_screen.get_node_or_null("Panel")
		if panel:
			panel.scale = Vector2.ZERO
			panel.pivot_offset = panel.size / 2.0
			var tween = create_tween()
			tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
		if restart_button:
			if current_moves <= target_moves + 2:
				restart_button.text = "SONRAKİ BÖLÜM"
				restart_button.add_theme_color_override("font_color", Color("00b0ff"))
			else:
				restart_button.text = "TEKRAR DENE"
				restart_button.add_theme_color_override("font_color", Color("ff1744"))

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

func show_popup(msg: String, title: String = "BİLGİ"):
	var ui = get_node_or_null("../UI")
	if not ui: return
	
	var popup = Panel.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.size = Vector2(800, 500)
	popup.position = (ui.size - popup.size) / 2.0
	popup.z_index = 1000
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95, 1)
	style.corner_radius_top_left = 30
	style.corner_radius_top_right = 30
	style.corner_radius_bottom_left = 30
	style.corner_radius_bottom_right = 30
	style.border_width_left = 6
	style.border_width_top = 6
	style.border_width_right = 6
	style.border_width_bottom = 6
	style.border_color = Color("cfd8dc")
	popup.add_theme_stylebox_override("panel", style)
	
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_lbl.position.y = 40
	title_lbl.add_theme_font_size_override("font_size", 50)
	title_lbl.add_theme_color_override("font_color", Color("37474f"))
	popup.add_child(title_lbl)
	
	var msg_lbl = RichTextLabel.new()
	msg_lbl.text = "[center]" + msg + "[/center]"
	msg_lbl.bbcode_enabled = true
	msg_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	msg_lbl.size = Vector2(700, 300)
	msg_lbl.position = (popup.size - msg_lbl.size) / 2.0
	msg_lbl.add_theme_font_size_override("normal_font_size", 32)
	msg_lbl.add_theme_color_override("default_color", Color("546e7a"))
	popup.add_child(msg_lbl)
	
	var btn = Button.new()
	btn.text = "KAPAT"
	btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	btn.size = Vector2(300, 80)
	btn.position = Vector2((popup.size.x - 300) / 2.0, popup.size.y - 100)
	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", Color("4caf50"))
	
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color("ffffff")
	b_style.corner_radius_top_left = 15
	b_style.corner_radius_top_right = 15
	b_style.corner_radius_bottom_left = 15
	b_style.corner_radius_bottom_right = 15
	b_style.border_width_left = 3
	b_style.border_width_top = 3
	b_style.border_width_right = 3
	b_style.border_width_bottom = 3
	b_style.border_color = Color("4caf50")
	btn.add_theme_stylebox_override("normal", b_style)
	
	btn.pressed.connect(func(): popup.queue_free())
	popup.add_child(btn)
	
	ui.add_child(popup)
	
	popup.scale = Vector2.ZERO
	popup.pivot_offset = popup.size / 2.0
	var tween = create_tween()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Settings Screen ---

func _build_settings_screen():
	var ui = get_node_or_null("../UI")
	if not ui: return
	
	settings_screen = Control.new()
	settings_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_screen.hide()
	settings_screen.z_index = 500
	ui.add_child(settings_screen)
	
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_screen.add_child(dimmer)
	
	var panel = Panel.new()
	panel.size = Vector2(800, 1000)
	panel.position = (Vector2(1080, 1920) - panel.size) / 2.0
	var style = StyleBoxFlat.new()
	style.bg_color = Color("f5f5f5")
	style.corner_radius_top_left = 40
	style.corner_radius_top_right = 40
	style.corner_radius_bottom_left = 40
	style.corner_radius_bottom_right = 40
	panel.add_theme_stylebox_override("panel", style)
	settings_screen.add_child(panel)
	
	var title = Label.new()
	title.text = "AYARLAR"
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 50
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color("37474f"))
	panel.add_child(title)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.size = Vector2(600, 600)
	vbox.position = (panel.size - vbox.size) / 2.0 + Vector2(0, 50)
	vbox.add_theme_constant_override("separation", 30)
	panel.add_child(vbox)
	
	var btn_font = 36
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("ffffff")
	btn_style.corner_radius_top_left = 15
	btn_style.corner_radius_top_right = 15
	btn_style.corner_radius_bottom_left = 15
	btn_style.corner_radius_bottom_right = 15
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color("cfd8dc")
	
	# Sound Toggle
	var sound_btn = Button.new()
	sound_btn.text = "SES: AÇIK"
	sound_btn.custom_minimum_size = Vector2(0, 80)
	sound_btn.add_theme_font_size_override("font_size", btn_font)
	sound_btn.add_theme_stylebox_override("normal", btn_style)
	sound_btn.add_theme_color_override("font_color", Color("424242"))
	sound_btn.pressed.connect(func():
		var muted = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
		AudioController.toggle_mute(not muted)
		sound_btn.text = "SES: KAPALI" if not muted else "SES: AÇIK"
	)
	vbox.add_child(sound_btn)
	
	# Vibration Toggle (Dummy setting)
	var vib_btn = Button.new()
	vib_btn.text = "TİTREŞİM: AÇIK"
	vib_btn.custom_minimum_size = Vector2(0, 80)
	vib_btn.add_theme_font_size_override("font_size", btn_font)
	vib_btn.add_theme_stylebox_override("normal", btn_style)
	vib_btn.add_theme_color_override("font_color", Color("424242"))
	vib_btn.pressed.connect(func():
		var current = SaveManager.get("vibration_enabled") if "vibration_enabled" in SaveManager else true
		var new_val = not current
		SaveManager.set("vibration_enabled", new_val)
		vib_btn.text = "TİTREŞİM: AÇIK" if new_val else "TİTREŞİM: KAPALI"
	)
	vbox.add_child(vib_btn)
	
	# Privacy Policy
	var privacy_btn = Button.new()
	privacy_btn.text = "GİZLİLİK POLİTİKASI"
	privacy_btn.custom_minimum_size = Vector2(0, 80)
	privacy_btn.add_theme_font_size_override("font_size", btn_font)
	privacy_btn.add_theme_stylebox_override("normal", btn_style)
	privacy_btn.add_theme_color_override("font_color", Color("00838f"))
	privacy_btn.pressed.connect(func(): show_popup("Uygulamamız oyun içerisinde veya haricinde sizden hiçbir kişisel veri toplamaz.\n\nSadece oyunda kullanılan Google reklam altyapısı (AdMob vb.) standart analitik veri ve reklam eşleştirme için anonim veriler kullanabilir.", "GİZLİLİK POLİTİKASI"))
	vbox.add_child(privacy_btn)
	
	# Terms of Use
	var terms_btn = Button.new()
	terms_btn.text = "KULLANIM KOŞULLARI"
	terms_btn.custom_minimum_size = Vector2(0, 80)
	terms_btn.add_theme_font_size_override("font_size", btn_font)
	terms_btn.add_theme_stylebox_override("normal", btn_style)
	terms_btn.add_theme_color_override("font_color", Color("00838f"))
	terms_btn.pressed.connect(func(): show_popup("Bu oyunu indirip oynayarak temel lisans şartlarını kabul etmiş sayılırsınız.\n\nOyun tamamen eğlence amaçlıdır, hiçbir sorumluluk kabul edilmez.", "KULLANIM KOŞULLARI"))
	vbox.add_child(terms_btn)
	
	# Editor
	var editor_b = Button.new()
	editor_b.text = "SEVİYE EDİTÖRÜ"
	editor_b.custom_minimum_size = Vector2(0, 80)
	editor_b.add_theme_font_size_override("font_size", btn_font)
	editor_b.add_theme_stylebox_override("normal", btn_style)
	editor_b.add_theme_color_override("font_color", Color("d84315"))
	editor_b.pressed.connect(_on_editor_button_pressed)
	vbox.add_child(editor_b)
	
	# Generate
	var gen_b = Button.new()
	gen_b.text = "100 SEVİYE ÜRET"
	gen_b.custom_minimum_size = Vector2(0, 80)
	gen_b.add_theme_font_size_override("font_size", btn_font)
	gen_b.add_theme_stylebox_override("normal", btn_style)
	gen_b.add_theme_color_override("font_color", Color("d84315"))
	gen_b.pressed.connect(_on_generate_levels_pressed)
	vbox.add_child(gen_b)
	
	var close_btn = Button.new()
	close_btn.text = "KAPAT"
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	close_btn.offset_left = 100
	close_btn.offset_right = -100
	close_btn.offset_top = -120
	close_btn.offset_bottom = -40
	close_btn.add_theme_font_size_override("font_size", 40)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_color_override("font_color", Color("c62828"))
	close_btn.pressed.connect(func(): settings_screen.hide())
	panel.add_child(close_btn)



var level_selection_screen: Control

func _build_level_selection_screen():
	level_selection_screen = Control.new()
	level_selection_screen.name = "LevelSelectionScreen"
	level_selection_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_selection_screen.z_index = 1000
	level_selection_screen.hide()
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_selection_screen.add_child(bg)
	
	var title = Label.new()
	title.text = "SEVİYE SEÇİMİ"
	title.add_theme_font_size_override("font_size", 60)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position.y = 80
	level_selection_screen.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "✖"
	close_btn.add_theme_font_size_override("font_size", 50)
	close_btn.size = Vector2(100, 100)
	close_btn.position = Vector2(1080 - 130, 60)
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color("e53935")
	c_style.corner_radius_top_left = 50
	c_style.corner_radius_top_right = 50
	c_style.corner_radius_bottom_left = 50
	c_style.corner_radius_bottom_right = 50
	close_btn.add_theme_stylebox_override("normal", c_style)
	close_btn.pressed.connect(func(): level_selection_screen.hide())
	level_selection_screen.add_child(close_btn)
	
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 220
	scroll.offset_bottom = -100
	scroll.offset_left = 40
	scroll.offset_right = -40
	level_selection_screen.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)
	
	for i in range(1, 101):
		var btn = Button.new()
		btn.text = str(i)
		btn.add_theme_font_size_override("font_size", 40)
		btn.custom_minimum_size = Vector2(180, 180)
		
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color("37474f")
		b_style.corner_radius_top_left = 20
		b_style.corner_radius_top_right = 20
		b_style.corner_radius_bottom_left = 20
		b_style.corner_radius_bottom_right = 20
		btn.add_theme_stylebox_override("normal", b_style)
		
		btn.pressed.connect(func(): 
			level_selection_screen.hide()
			start_specific_level(i)
		)
		grid.add_child(btn)
		
	var ui = get_node_or_null("../UI")
	if ui:
		ui.add_child(level_selection_screen)
	else:
		add_child(level_selection_screen)

func _open_level_selection():
	if level_selection_screen:
		level_selection_screen.show()

func start_specific_level(idx: int):
	current_level_index = idx
	var path = "res://levels/level_%d.json" % idx
	if FileAccess.file_exists(path):
		load_level_from_json(path)
	else:
		var level_data = LevelGenerator.generate_level_for_index(idx)
		load_level_from_dict(level_data)

func _open_settings():
	if settings_screen:
		settings_screen.show()
		var panel = settings_screen.get_node_or_null("Panel")
		if panel:
			panel.scale = Vector2.ZERO
			panel.pivot_offset = panel.size / 2.0
			var tween = create_tween()
			tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
