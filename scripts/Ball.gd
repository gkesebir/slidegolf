extends Node2D

class_name Ball

# Visual Configuration
@export var radius: float = 30.0
@export var ball_color: Color = Color("ffffff")
@export var glow_color: Color = Color("00e5ff")

# Node References
var grid_manager: GridManager
var game_manager: GameManager

# Movement state
var grid_position: Vector2i = Vector2i(1, 1)
var is_moving: bool = false

# Swipe Input tracking
var swipe_start_pos: Vector2 = Vector2.ZERO
var min_swipe_distance: float = 50.0

# Phase 3 state tracking
var crossed_fragile_tiles: Array[Vector2i] = []

# Phase 4 Physics & Skins Profiles
const BALL_PROFILES = {
	"standard": {
		"name": "Standart Top",
		"speed_factor": 1.0,
		"color": Color("ffffff"),
		"glow_color": Color("00e5ff")
	},
	"iron": {
		"name": "Demir Top",
		"speed_factor": 1.6, # Slower acceleration / slide
		"color": Color("90a4ae"),
		"glow_color": Color("cfd8dc")
	},
	"super": {
		"name": "Süper Top",
		"speed_factor": 0.6, # Ultra fast slide
		"color": Color("ff007f"),
		"glow_color": Color("ff007f")
	}
}

var speed_factor: float = 1.0

func _ready():
	queue_redraw()

func initialize(start_grid_pos: Vector2i, grid_mgr: GridManager, game_mgr: GameManager):
	grid_position = start_grid_pos
	grid_manager = grid_mgr
	game_manager = game_mgr
	
	crossed_fragile_tiles.clear()
	
	# Apply currently equipped ball profile from SaveManager
	apply_ball_profile(SaveManager.equipped_ball)
	
	# Instantly snap to start pos
	global_position = grid_manager.get_cell_world_position(grid_position)
	
	# Verify button state at start
	update_button_trigger_states()

func apply_ball_profile(profile_id: String):
	var profile = BALL_PROFILES.get(profile_id, BALL_PROFILES["standard"])
	speed_factor = profile["speed_factor"]
	ball_color = profile["color"]
	glow_color = profile["glow_color"]
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, radius + 4, Color(glow_color.r, glow_color.g, glow_color.b, 0.3))
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, glow_color, 2.5, true)

func _input(event):
	if is_moving:
		return
		
	# Block input if UI screens are visible
	if game_manager:
		if game_manager.victory_screen and game_manager.victory_screen.visible:
			return
		if game_manager.get_node_or_null("UI/ShopScreen") and game_manager.get_node_or_null("UI/ShopScreen").visible:
			return
		
	if event is InputEventMouseButton:
		if event.pressed:
			swipe_start_pos = event.position
		else:
			var swipe_end_pos = event.position
			var diff = swipe_end_pos - swipe_start_pos
			if diff.length() >= min_swipe_distance:
				handle_swipe(diff)
				
	elif event is InputEventScreenTouch:
		if event.pressed:
			swipe_start_pos = event.position
		else:
			var swipe_end_pos = event.position
			var diff = swipe_end_pos - swipe_start_pos
			if diff.length() >= min_swipe_distance:
				handle_swipe(diff)

func handle_swipe(swipe_vector: Vector2):
	var swipe_dir = Vector2i.ZERO
	
	if abs(swipe_vector.x) > abs(swipe_vector.y):
		if swipe_vector.x > 0:
			swipe_dir = Vector2i(1, 0) # Right
		else:
			swipe_dir = Vector2i(-1, 0) # Left
	else:
		if swipe_vector.y > 0:
			swipe_dir = Vector2i(0, 1) # Down
		else:
			swipe_dir = Vector2i(0, -1) # Up
			
	if swipe_dir != Vector2i.ZERO:
		slide_to(swipe_dir)

func slide_to(dir: Vector2i):
	if is_moving:
		return
		
	var path_steps: Array = []
	var current = grid_position
	var reached_hole = false
	
	crossed_fragile_tiles.clear()
	
	while true:
		var next_pos = current + dir
		var type = grid_manager.get_cell_type(next_pos)
		
		if type == 1 or type == -1:
			break
			
		if type == 4:
			var portal_out = grid_manager.get_portal_out_position()
			if portal_out != Vector2i(-1, -1):
				path_steps.append({ "pos": next_pos, "teleport": false })
				path_steps.append({ "pos": portal_out, "teleport": true })
				current = portal_out
				continue
				
		if type == 3:
			if not game_manager.is_bonus_mode and game_manager.all_diamonds_collected():
				current = next_pos
				reached_hole = true
				path_steps.append({ "pos": current, "teleport": false })
				break
			else:
				current = next_pos
				path_steps.append({ "pos": current, "teleport": false })
				
		elif type == 8:
			current = next_pos
			path_steps.append({ "pos": current, "teleport": false })
			if not crossed_fragile_tiles.has(current):
				crossed_fragile_tiles.append(current)
				
		else:
			current = next_pos
			path_steps.append({ "pos": current, "teleport": false })
			
	if path_steps.size() > 0:
		is_moving = true
		var tween = create_tween().set_parallel(false)
		
		# Slide duration scaled by ball's speed factor
		var duration = 0.12 * speed_factor
		
		for step in path_steps:
			var pos = step["pos"]
			var is_teleport = step["teleport"]
			
			if is_teleport:
				tween.tween_callback(func(): 
					global_position = grid_manager.get_cell_world_position(pos)
					grid_position = pos
				)
			else:
				var target_world_pos = grid_manager.get_cell_world_position(pos)
				tween.tween_property(self, "global_position", target_world_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				tween.tween_callback(func(): on_reach_cell(pos))
				
		tween.tween_callback(func(): on_slide_finished(current, reached_hole))

func on_reach_cell(cell_pos: Vector2i):
	grid_position = cell_pos
	
	var type = grid_manager.get_cell_type(cell_pos)
	
	if type == 2:
		grid_manager.remove_diamond_visual(cell_pos)
		game_manager.collect_diamond()
		
	elif type == 8:
		grid_manager.crack_fragile_tile(cell_pos)

func on_slide_finished(final_pos: Vector2i, reached_hole: bool):
	grid_position = final_pos
	is_moving = false
	
	update_button_trigger_states()
	
	for tile in crossed_fragile_tiles:
		if grid_position != tile:
			grid_manager.destroy_fragile_tile(tile)
	crossed_fragile_tiles.clear()
	
	if reached_hole and not game_manager.is_bonus_mode:
		game_manager.win_level()

func update_button_trigger_states():
	var current_cell_type = grid_manager.get_cell_type(grid_position)
	if current_cell_type == 6:
		grid_manager.set_gate_state(true)
	else:
		grid_manager.set_gate_state(false)

func _process(_delta):
	if is_moving and grid_manager and game_manager:
		# Calculate current cell based on visual global_position relative to GridManager
		var local_pos = global_position - grid_manager.global_position
		var current_cell = Vector2i(
			floor(local_pos.x / grid_manager.cell_size),
			floor(local_pos.y / grid_manager.cell_size)
		)
		
		# If within bounds and has a diamond, collect it immediately
		if current_cell.x >= 0 and current_cell.x < grid_manager.grid_width:
			if current_cell.y >= 0 and current_cell.y < grid_manager.grid_height:
				if grid_manager.get_cell_type(current_cell) == 2:
					grid_manager.remove_diamond_visual(current_cell)
					game_manager.collect_diamond()
