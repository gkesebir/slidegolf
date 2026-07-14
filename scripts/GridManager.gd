extends Node2D

class_name GridManager

# Grid configuration
@export var cell_size: float = 140.0
@export var grid_width: int = 7
@export var grid_height: int = 7

# Level grid representation
# 0 = Empty, 1 = Wall, 2 = Diamond, 3 = Hole
var grid: Array = [
	[1, 1, 1, 1, 1, 1, 1],
	[1, 0, 2, 0, 0, 2, 1],
	[1, 0, 1, 1, 0, 1, 1],
	[1, 0, 0, 3, 0, 0, 1],
	[1, 1, 0, 1, 1, 0, 1],
	[1, 2, 0, 0, 2, 0, 1],
	[1, 1, 1, 1, 1, 1, 1]
]

# Track visual nodes
var cell_visuals: Dictionary = {} # Key: Vector2i (grid position) -> Value: Node
var diamond_nodes: Dictionary = {} # Key: Vector2i -> Value: Node
var hole_node: Node = null

func _ready():
	setup_grid()

func setup_grid():
	# Calculate offsets to center the grid on the 1080x1920 viewport
	var total_w = grid_width * cell_size
	var total_h = grid_height * cell_size
	
	# Centered position
	var start_x = (1080.0 - total_w) / 2.0
	var start_y = (1920.0 - total_h) / 2.0
	position = Vector2(start_x, start_y)
	
	# Build the visual grid
	for y in range(grid_height):
		for x in range(grid_width):
			var grid_pos = Vector2i(x, y)
			var type = grid[y][x]
			create_cell_visual(grid_pos, type)

func create_cell_visual(grid_pos: Vector2i, type: int):
	var cell_pos = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
	
	# 1. Base Empty Cell / Background for pathways
	# Even walls have a pathway under them or we can just draw path backgrounds for non-wall cells.
	if type != 1:
		var path_rect = ColorRect.new()
		path_rect.size = Vector2(cell_size - 4, cell_size - 4)
		path_rect.position = cell_pos + Vector2(2, 2)
		path_rect.color = Color("1a1c23") # Sleek dark background
		add_child(path_rect)
		
		# Draw grid lines or small dots
		var border = ReferenceRect.new()
		border.size = path_rect.size
		border.position = path_rect.position
		border.border_color = Color("2e3440")
		border.border_width = 1.0
		add_child(border)
	
	# 2. Wall (1)
	if type == 1:
		var wall_panel = Panel.new()
		wall_panel.size = Vector2(cell_size - 6, cell_size - 6)
		wall_panel.position = cell_pos + Vector2(3, 3)
		
		# Create a beautiful stylebox flat for the wall
		var style = StyleBoxFlat.new()
		style.bg_color = Color("2b303c") # Dark slate
		style.border_color = Color("00e5ff") # Glowing Cyan
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		
		# Add shadow for premium feel
		style.shadow_color = Color("00e5ff", 0.25)
		style.shadow_size = 4
		
		wall_panel.add_theme_stylebox_override("panel", style)
		add_child(wall_panel)
		cell_visuals[grid_pos] = wall_panel
		
	# 3. Diamond (2)
	elif type == 2:
		var diamond = Control.new()
		diamond.size = Vector2(cell_size * 0.4, cell_size * 0.4)
		# Center inside the cell
		diamond.position = cell_pos + Vector2(cell_size * 0.3, cell_size * 0.3)
		
		var inner_panel = Panel.new()
		inner_panel.size = diamond.size
		inner_panel.pivot_offset = diamond.size / 2.0
		inner_panel.rotation = deg_to_rad(45) # Rotate to make a diamond
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color("39ff14") # Bright neon green
		style.border_color = Color("ffffff")
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		
		# Glowing neon shadow
		style.shadow_color = Color("39ff14", 0.5)
		style.shadow_size = 8
		
		inner_panel.add_theme_stylebox_override("panel", style)
		diamond.add_child(inner_panel)
		add_child(diamond)
		
		diamond_nodes[grid_pos] = diamond
		
		# Add a subtle hover/idle float animation to the diamond
		var tween = create_tween().set_loops()
		tween.tween_property(inner_panel, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE)
		tween.tween_property(inner_panel, "scale", Vector2(0.9, 0.9), 0.8).set_trans(Tween.TRANS_SINE)
		
	# 4. Hole (3)
	elif type == 3:
		var hole = Panel.new()
		var h_size = cell_size * 0.6
		hole.size = Vector2(h_size, h_size)
		hole.position = cell_pos + Vector2((cell_size - h_size)/2.0, (cell_size - h_size)/2.0)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color("0d0d1b") # Abyss dark
		style.border_color = Color("ff007f") # Glowing Pink
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
		style.corner_radius_top_left = h_size / 2.0
		style.corner_radius_top_right = h_size / 2.0
		style.corner_radius_bottom_left = h_size / 2.0
		style.corner_radius_bottom_right = h_size / 2.0
		
		style.shadow_color = Color("ff007f", 0.4)
		style.shadow_size = 6
		
		hole.add_theme_stylebox_override("panel", style)
		add_child(hole)
		hole_node = hole

# Get value at cell coordinates
func get_cell_type(grid_pos: Vector2i) -> int:
	if grid_pos.x < 0 or grid_pos.x >= grid_width or grid_pos.y < 0 or grid_pos.y >= grid_height:
		return -1 # Out of bounds is treated as an obstacle
	return grid[grid_pos.y][grid_pos.x]

# Set value at cell coordinates (e.g. collecting a diamond)
func set_cell_type(grid_pos: Vector2i, type: int):
	if grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height:
		grid[grid_pos.y][grid_pos.x] = type

# Get world coordinates for a grid cell center
func get_cell_world_position(grid_pos: Vector2i) -> Vector2:
	var local_pos = Vector2(
		grid_pos.x * cell_size + cell_size / 2.0,
		grid_pos.y * cell_size + cell_size / 2.0
	)
	return global_position + local_pos

# Remove diamond visuals
func remove_diamond_visual(grid_pos: Vector2i):
	if diamond_nodes.has(grid_pos):
		var node = diamond_nodes[grid_pos]
		
		# Animate shrinking out
		var tween = create_tween()
		tween.tween_property(node, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(node.queue_free)
		
		diamond_nodes.erase(grid_pos)
		set_cell_type(grid_pos, 0) # Set cell as empty in grid data

func reset_grid():
	# Clear existing diamond nodes, walls, path visuals
	for child in get_children():
		child.queue_free()
	cell_visuals.clear()
	diamond_nodes.clear()
	hole_node = null
	
	# Reset grid data to initial state
	grid = [
		[1, 1, 1, 1, 1, 1, 1],
		[1, 0, 2, 0, 0, 2, 1],
		[1, 0, 1, 1, 0, 1, 1],
		[1, 0, 0, 3, 0, 0, 1],
		[1, 1, 0, 1, 1, 0, 1],
		[1, 2, 0, 0, 2, 0, 1],
		[1, 1, 1, 1, 1, 1, 1]
	]
	
	setup_grid()

