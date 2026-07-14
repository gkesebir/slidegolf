extends Node2D

class_name Ball

# Visual Configuration
@export var radius: float = 30.0
@export var ball_color: Color = Color("ffffff")
@export var glow_color: Color = Color("00e5ff")

# Node References (can be assigned by GameManager or set on ready)
var grid_manager: GridManager
var game_manager: GameManager

# Movement state
var grid_position: Vector2i = Vector2i(1, 1) # Initial grid position
var is_moving: bool = false

# Swipe Input tracking
var swipe_start_pos: Vector2 = Vector2.ZERO
var min_swipe_distance: float = 50.0

func _ready():
	# Redraw to see the ball
	queue_redraw()

func initialize(start_grid_pos: Vector2i, grid_mgr: GridManager, game_mgr: GameManager):
	grid_position = start_grid_pos
	grid_manager = grid_mgr
	game_manager = game_mgr
	
	# Instantly snap to the initial position
	global_position = grid_manager.get_cell_world_position(grid_position)

func _draw():
	# Draw glow circle
	draw_circle(Vector2.ZERO, radius + 4, Color(glow_color.r, glow_color.g, glow_color.b, 0.3))
	# Draw main white ball
	draw_circle(Vector2.ZERO, radius, ball_color)
	# Draw sharp inner border
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, glow_color, 2.5, true)

func _input(event):
	if is_moving:
		return
		
	# Mouse/Touch support
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
	
	# Determine if swipe is horizontal or vertical
	if abs(swipe_vector.x) > abs(swipe_vector.y):
		# Horizontal swipe
		if swipe_vector.x > 0:
			swipe_dir = Vector2i(1, 0) # Right
		else:
			swipe_dir = Vector2i(-1, 0) # Left
	else:
		# Vertical swipe
		if swipe_vector.y > 0:
			swipe_dir = Vector2i(0, 1) # Down
		else:
			swipe_dir = Vector2i(0, -1) # Up
			
	if swipe_dir != Vector2i.ZERO:
		slide_to(swipe_dir)

func slide_to(dir: Vector2i):
	if is_moving:
		return
		
	var path_cells: Array[Vector2i] = []
	var current = grid_position
	var reached_hole = false
	
	# Calculate path
	while true:
		var next_pos = current + dir
		var type = grid_manager.get_cell_type(next_pos)
		
		# If next cell is wall or out of bounds, stop sliding
		if type == 1 or type == -1:
			break
			
		# If next cell is the hole
		if type == 3:
			if game_manager.all_diamonds_collected():
				current = next_pos
				reached_hole = true
				path_cells.append(current)
				break
			else:
				# Slide over the hole (treat it as empty) and continue
				current = next_pos
				path_cells.append(current)
		else:
			# Regular path or diamond
			current = next_pos
			path_cells.append(current)
			
	# If we have cells to slide to, start movement
	if path_cells.size() > 0:
		is_moving = true
		
		var tween = create_tween().set_parallel(false)
		
		for step_pos in path_cells:
			var target_world_pos = grid_manager.get_cell_world_position(step_pos)
			# Animate sliding to the cell
			tween.tween_property(self, "global_position", target_world_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			# Triggers when the ball reaches the cell
			tween.tween_callback(func(): on_reach_cell(step_pos))
			
		# At the end of the full slide path
		tween.tween_callback(func(): on_slide_finished(current, reached_hole))

func on_reach_cell(cell_pos: Vector2i):
	# Update internal position
	grid_position = cell_pos
	
	# Check if this cell contains a diamond
	if grid_manager.get_cell_type(cell_pos) == 2:
		# Collect diamond
		grid_manager.remove_diamond_visual(cell_pos)
		game_manager.collect_diamond()

func on_slide_finished(final_pos: Vector2i, reached_hole: bool):
	grid_position = final_pos
	is_moving = false
	
	# Check win condition
	if reached_hole:
		game_manager.win_level()
