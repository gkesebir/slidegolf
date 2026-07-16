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
		"color": Color("f5f5f5"),
		"glow_color": Color("cfd8dc")
	},
	"iron": {
		"name": "Demir Top",
		"speed_factor": 1.6, # Slower acceleration / slide
		"color": Color("455a64"),
		"glow_color": Color("78909c")
	},
	"super": {
		"name": "Süper Top",
		"speed_factor": 0.6, # Ultra fast slide
		"color": Color("ff4081"),
		"glow_color": Color("ff80ab")
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
	# 1. Drop shadow shifted down-right
	draw_circle(Vector2(4, 8), radius, Color(0, 0, 0, 0.15))
	
	# 2. Outer rim glow
	draw_circle(Vector2.ZERO, radius + 2, Color(glow_color.r, glow_color.g, glow_color.b, 0.25))
	
	# 3. Main ball body
	draw_circle(Vector2.ZERO, radius, ball_color)
	
	# 4. Minimalist specular reflection highlight
	draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.25, Color(1, 1, 1, 0.4))

func _input(event):
	if is_moving:
		return
		
	# Block input if UI screens are visible
	if game_manager:
		if game_manager.victory_screen and game_manager.victory_screen.visible:
			print("Ball debug: Input blocked by victory screen.")
			return
		if game_manager.get_node_or_null("UI/ShopScreen") and game_manager.get_node_or_null("UI/ShopScreen").visible:
			print("Ball debug: Input blocked by shop screen.")
			return
		
	if event is InputEventMouseButton:
		if event.pressed:
			swipe_start_pos = event.position
			print("Ball debug: Mouse button pressed at ", swipe_start_pos)
		else:
			var swipe_end_pos = event.position
			var diff = swipe_end_pos - swipe_start_pos
			print("Ball debug: Mouse button released. Diff length: ", diff.length(), " (min required: ", min_swipe_distance, ")")
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
		print("Ball debug: Swipe valid. Calling slide_to with dir: ", swipe_dir)
		slide_to(swipe_dir)
	else:
		print("Ball debug: Swipe direction evaluated to ZERO.")

func slide_to(dir: Vector2i):
	if is_moving:
		return
		
	var path_steps: Array = []
	var current = grid_position
	var reached_hole = false
	
	crossed_fragile_tiles.clear()
	
	print("Ball debug: slide_to starting from ", current, " towards ", dir)
	
	while true:
		var next_pos = current + dir
		var type = grid_manager.get_cell_type(next_pos)
		
		print("Ball debug: Checking cell ", next_pos, " | type = ", type)
		
		if type == 1:
			AudioController.play_hit()
		if type == 1 or type == 9 or type == -1:
			print("Ball debug: Hit wall, void, or out of bounds. Stopping scan.")
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
				
		elif type == 10:
			# Mud: stops slide instantly on entering mud tile
			current = next_pos
			path_steps.append({ "pos": current, "teleport": false })
			break
			
		else:
			current = next_pos
			path_steps.append({ "pos": current, "teleport": false })
			
	if path_steps.size() > 0:
		is_moving = true
		
		# Hamle sayisini artir
		if is_instance_valid(game_manager) and game_manager.has_method("increment_move"):
			game_manager.increment_move()
			
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
