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

func _ready():
	queue_redraw()

func initialize(start_grid_pos: Vector2i, grid_mgr: GridManager, game_mgr: GameManager):
	grid_position = start_grid_pos
	grid_manager = grid_mgr
	game_manager = game_mgr
	
	crossed_fragile_tiles.clear()
	
	# Instantly snap to start pos
	global_position = grid_manager.get_cell_world_position(grid_position)
	
	# Verify button state at start
	update_button_trigger_states()

func _draw():
	draw_circle(Vector2.ZERO, radius + 4, Color(glow_color.r, glow_color.g, glow_color.b, 0.3))
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, glow_color, 2.5, true)

func _input(event):
	if is_moving:
		return
		
	# Block swipes if victory screen is visible
	if game_manager and game_manager.victory_screen and game_manager.victory_screen.visible:
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
		
	# Structure of path steps: Array of Dict { "pos": Vector2i, "teleport": bool }
	var path_steps: Array = []
	var current = grid_position
	var reached_hole = false
	
	crossed_fragile_tiles.clear()
	
	# Calculate path with Portals, Switches, Cracked Tiles, and Holes
	while true:
		var next_pos = current + dir
		var type = grid_manager.get_cell_type(next_pos)
		
		# Hitting wall or out of bounds
		if type == 1 or type == -1:
			break
			
		# 4. PortalIn
		if type == 4:
			var portal_out = grid_manager.get_portal_out_position()
			if portal_out != Vector2i(-1, -1):
				# Move into PortalIn
				path_steps.append({ "pos": next_pos, "teleport": false })
				# Teleport to PortalOut
				path_steps.append({ "pos": portal_out, "teleport": true })
				current = portal_out
				continue
				
		# 3. Hole
		if type == 3:
			# In Bonus Mode there is no Hole victory condition
			if not game_manager.is_bonus_mode and game_manager.all_diamonds_collected():
				current = next_pos
				reached_hole = true
				path_steps.append({ "pos": current, "teleport": false })
				break
			else:
				# Slide over
				current = next_pos
				path_steps.append({ "pos": current, "teleport": false })
				
		# 8. Fragile Tile
		elif type == 8:
			current = next_pos
			path_steps.append({ "pos": current, "teleport": false })
			if not crossed_fragile_tiles.has(current):
				crossed_fragile_tiles.append(current)
				
		else:
			# Empty, Diamond, Button, or Open Gate
			current = next_pos
			path_steps.append({ "pos": current, "teleport": false })
			
	# Animate the path
	if path_steps.size() > 0:
		is_moving = true
		var tween = create_tween().set_parallel(false)
		
		for step in path_steps:
			var pos = step["pos"]
			var is_teleport = step["teleport"]
			
			if is_teleport:
				# Teleport instantly
				tween.tween_callback(func(): 
					global_position = grid_manager.get_cell_world_position(pos)
					# Reset internal position during teleport step
					grid_position = pos
				)
			else:
				# Slide smoothly
				var target_world_pos = grid_manager.get_cell_world_position(pos)
				tween.tween_property(self, "global_position", target_world_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				tween.tween_callback(func(): on_reach_cell(pos))
				
		tween.tween_callback(func(): on_slide_finished(current, reached_hole))

func on_reach_cell(cell_pos: Vector2i):
	grid_position = cell_pos
	
	var type = grid_manager.get_cell_type(cell_pos)
	
	# Check if this cell is a Diamond (2)
	if type == 2:
		grid_manager.remove_diamond_visual(cell_pos)
		game_manager.collect_diamond()
		
	# Check if this cell is a Fragile Tile (8)
	elif type == 8:
		grid_manager.crack_fragile_tile(cell_pos)

func on_slide_finished(final_pos: Vector2i, reached_hole: bool):
	grid_position = final_pos
	is_moving = false
	
	# Apply button presses
	update_button_trigger_states()
	
	# Destroy fragile tiles that we have left
	for tile in crossed_fragile_tiles:
		if grid_position != tile:
			grid_manager.destroy_fragile_tile(tile)
	crossed_fragile_tiles.clear()
	
	# Check win condition (only in normal mode)
	if reached_hole and not game_manager.is_bonus_mode:
		game_manager.win_level()

func update_button_trigger_states():
	var current_cell_type = grid_manager.get_cell_type(grid_position)
	if current_cell_type == 6: # Standing on Button
		grid_manager.set_gate_state(true)
	else:
		grid_manager.set_gate_state(false)
