extends Node

class_name GameManager

# Node references
@export var grid_manager: GridManager
@export var ball: Ball

# UI Nodes
@export var diamond_label: Label
@export var victory_screen: Control
@export var restart_button: Button

# Game state
var total_diamonds: int = 0
var diamonds_collected: int = 0

func _ready():
	# If references aren't assigned, try to find them in the scene tree
	if not grid_manager:
		grid_manager = get_node_or_null("../GridManager")
	if not ball:
		ball = get_node_or_null("../Ball")
		
	# Wait for GridManager to be ready so it builds the grid
	if grid_manager and not grid_manager.is_node_ready():
		await grid_manager.ready
		
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
		
	style_ui()
	initialize_game()

func initialize_game():
	if not grid_manager or not ball:
		printerr("GameManager: GridManager or Ball is not assigned!")
		return
		
	total_diamonds = count_diamonds_in_grid()
	diamonds_collected = 0
	update_ui()
	
	if victory_screen:
		victory_screen.hide()
		
	# Set up the ball at starting position (1,1)
	ball.initialize(Vector2i(1, 1), grid_manager, self)

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
		diamond_label.text = "DIAMONDS: %d / %d" % [diamonds_collected, total_diamonds]

func win_level():
	print("Level Cleared!")
	if victory_screen:
		victory_screen.show()
		# Add a nice scale animation to the inner panel
		var panel = victory_screen.get_node_or_null("Panel")
		if panel:
			panel.scale = Vector2.ZERO
			panel.pivot_offset = panel.size / 2.0
			var tween = create_tween()
			tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_restart_button_pressed():
	# Reset grid and re-init game
	grid_manager.reset_grid()
	initialize_game()

func style_ui():
	# Style the Victory Panel
	var panel = victory_screen.get_node_or_null("Panel") if victory_screen else null
	if panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color("12141c")
		panel_style.border_color = Color("ff007f") # Glowing Pink
		panel_style.border_width_left = 4
		panel_style.border_width_right = 4
		panel_style.border_width_top = 4
		panel_style.border_width_bottom = 4
		panel_style.corner_radius_top_left = 24
		panel_style.corner_radius_top_right = 24
		panel_style.corner_radius_bottom_left = 24
		panel_style.corner_radius_bottom_right = 24
		panel_style.shadow_color = Color("ff007f", 0.3)
		panel_style.shadow_size = 15
		panel.add_theme_stylebox_override("panel", panel_style)
		
	# Style the Restart Button
	if restart_button:
		# Normal style
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color("1c1e26")
		btn_normal.border_color = Color("00e5ff") # Neon Cyan
		btn_normal.border_width_left = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_bottom = 2
		btn_normal.corner_radius_top_left = 12
		btn_normal.corner_radius_top_right = 12
		btn_normal.corner_radius_bottom_left = 12
		btn_normal.corner_radius_bottom_right = 12
		btn_normal.shadow_color = Color("00e5ff", 0.25)
		btn_normal.shadow_size = 6
		
		# Hover style
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color("252936")
		btn_hover.shadow_size = 10
		
		# Pressed style
		var btn_pressed = btn_normal.duplicate()
		btn_pressed.bg_color = Color("0f1014")
		btn_pressed.shadow_size = 2
		
		restart_button.add_theme_stylebox_override("normal", btn_normal)
		restart_button.add_theme_stylebox_override("hover", btn_hover)
		restart_button.add_theme_stylebox_override("pressed", btn_pressed)
		
		# Add white text and clean look
		restart_button.add_theme_color_override("font_color", Color("00e5ff"))
		restart_button.add_theme_color_override("font_hover_color", Color("ffffff"))
		restart_button.add_theme_color_override("font_pressed_color", Color("00b2cc"))

