extends Node2D

class_name GridManager

# Grid configuration
@export var cell_size: float = 140.0
@export var grid_width: int = 7
@export var grid_height: int = 7

# Level grid representation
# 0 = Empty, 1 = Wall, 2 = Diamond, 3 = Hole
# 4 = PortalIn, 5 = PortalOut, 6 = Button, 7 = Gate, 8 = Fragile Tile
var grid: Array = [
	[1, 1, 1, 1, 1, 1, 1],
	[1, 0, 2, 0, 4, 2, 1], # PortalIn at (4, 1)
	[1, 0, 1, 7, 0, 1, 1], # Gate at (3, 2)
	[1, 5, 0, 3, 0, 6, 1], # PortalOut at (1, 3), Hole at (3, 3), Button at (5, 3)
	[1, 1, 0, 1, 1, 0, 1],
	[1, 2, 8, 0, 2, 0, 1], # Fragile tile at (2, 5)
	[1, 1, 1, 1, 1, 1, 1]
]

# Track visual nodes
var cell_visuals: Dictionary = {} # Key: Vector2i -> Value: Node
var diamond_nodes: Dictionary = {} # Key: Vector2i -> Value: Node
var hole_node: Node = null

# Phase 3 object visual tracking
var gate_visuals: Dictionary = {} # Key: Vector2i -> Value: Panel
var fragile_visuals: Dictionary = {} # Key: Vector2i -> Value: Panel
var button_visuals: Dictionary = {} # Key: Vector2i -> Value: Panel

# State variables
var is_gate_open: bool = false

func _ready():
	setup_grid()

func setup_grid():
	var total_w = grid_width * cell_size
	var total_h = grid_height * cell_size
	
	var start_x = (1080.0 - total_w) / 2.0
	var start_y = (1920.0 - total_h) / 2.0
	position = Vector2(start_x, start_y)
	
	for y in range(grid_height):
		for x in range(grid_width):
			var grid_pos = Vector2i(x, y)
			var type = grid[y][x]
			create_cell_visual(grid_pos, type)

func create_cell_visual(grid_pos: Vector2i, type: int):
	var cell_pos = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
	
	# Draw checkerboard background for all non-void cells
	if type != 9:
		var bg_rect = ColorRect.new()
		bg_rect.size = Vector2(cell_size, cell_size)
		bg_rect.position = cell_pos
		if (grid_pos.x + grid_pos.y) % 2 == 0:
			bg_rect.color = Color("a1d59b") # Light pastel green
		else:
			bg_rect.color = Color("87c380") # Darker pastel green
		add_child(bg_rect)
	else:
		# Distinct void cell styling (depressed empty tile)
		var void_bg = ColorRect.new()
		void_bg.size = Vector2(cell_size, cell_size)
		void_bg.position = cell_pos
		void_bg.color = Color("b0bec5") # dark grayish blue edge
		add_child(void_bg)
		
		var void_inner = ColorRect.new()
		void_inner.size = Vector2(cell_size - 6, cell_size - 6)
		void_inner.position = cell_pos + Vector2(3, 3)
		void_inner.color = Color("cfd8dc") # lighter gray inside
		add_child(void_inner)
		
		# Cross mark inside void
		var cross1 = ColorRect.new()
		cross1.size = Vector2(cell_size * 0.4, 4)
		cross1.position = cell_pos + Vector2(cell_size * 0.3, cell_size * 0.5 - 2)
		cross1.pivot_offset = Vector2(cell_size * 0.2, 2)
		cross1.rotation = deg_to_rad(45)
		cross1.color = Color(0, 0, 0, 0.1)
		add_child(cross1)
		
		var cross2 = cross1.duplicate()
		cross2.rotation = deg_to_rad(-45)
		add_child(cross2)
	
	# 1. Wall (1)
	if type == 1:
		spawn_wall_visual(grid_pos)
		
	# 2. Diamond (2)
	elif type == 2:
		spawn_diamond_visual(grid_pos, cell_pos)
		
	# 3. Hole (3)
	elif type == 3:
		spawn_hole_visual(grid_pos, cell_pos)
		
	# 4. PortalIn (4)
	elif type == 4:
		spawn_portal_visual(grid_pos, cell_pos, Color("29b6f6"), "PortalIn")
		
	# 5. PortalOut (5)
	elif type == 5:
		spawn_portal_visual(grid_pos, cell_pos, Color("ffb74d"), "PortalOut")
		
	# 6. Button (6)
	elif type == 6:
		spawn_button_visual(grid_pos, cell_pos)
		
	# 7. Gate (7)
	elif type == 7:
		spawn_gate_visual(grid_pos, cell_pos)
		
	# 8. Fragile Tile (8)
	elif type == 8:
		spawn_fragile_visual(grid_pos, cell_pos)
		
	# 10. Mud (10)
	elif type == 10:
		spawn_mud_visual(grid_pos, cell_pos)

# --- Spawning Helpers ---

func spawn_wall_visual(grid_pos: Vector2i):
	var cell_pos = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
	
	# Wall Container Node
	var wall = Control.new()
	wall.size = Vector2(cell_size, cell_size)
	wall.position = cell_pos
	
	# Drop Shadow under the block
	var shadow = Panel.new()
	shadow.size = Vector2(cell_size - 8, cell_size - 8)
	shadow.position = Vector2(4, 12)
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.12)
	shadow_style.corner_radius_top_left = 12
	shadow_style.corner_radius_top_right = 12
	shadow_style.corner_radius_bottom_left = 12
	shadow_style.corner_radius_bottom_right = 12
	shadow.add_theme_stylebox_override("panel", shadow_style)
	wall.add_child(shadow)
	
	# 3D Depth (Bottom face)
	var depth_panel = Panel.new()
	depth_panel.size = Vector2(cell_size - 6, cell_size - 6)
	depth_panel.position = Vector2(3, 3)
	var depth_style = StyleBoxFlat.new()
	depth_style.bg_color = Color("5d4037") # Dark pastel brown
	depth_style.corner_radius_top_left = 12
	depth_style.corner_radius_top_right = 12
	depth_style.corner_radius_bottom_left = 12
	depth_style.corner_radius_bottom_right = 12
	depth_panel.add_theme_stylebox_override("panel", depth_style)
	wall.add_child(depth_panel)
	
	# Top Face
	var top_panel = Panel.new()
	top_panel.size = Vector2(cell_size - 6, cell_size - 16)
	top_panel.position = Vector2(3, 3)
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color("795548") # Light pastel brown
	top_style.border_color = Color("8d6e63")
	top_style.border_width_left = 2
	top_style.border_width_right = 2
	top_style.border_width_top = 2
	top_style.border_width_bottom = 2
	top_style.corner_radius_top_left = 12
	top_style.corner_radius_top_right = 12
	top_style.corner_radius_bottom_left = 10
	top_style.corner_radius_bottom_right = 10
	top_panel.add_theme_stylebox_override("panel", top_style)
	wall.add_child(top_panel)
	
	add_child(wall)
	cell_visuals[grid_pos] = wall

func spawn_diamond_visual(grid_pos: Vector2i, cell_pos: Vector2):
	var diamond = Control.new()
	diamond.z_index = 10 # Elmaslarin zemin tarafindan gizlenmesini onle
	diamond.size = Vector2(cell_size * 0.4, cell_size * 0.4)
	diamond.position = cell_pos + Vector2(cell_size * 0.3, cell_size * 0.3)
	
	# Drop Shadow under the diamond
	var shadow = Panel.new()
	shadow.size = diamond.size
	shadow.position = Vector2(4, 10)
	shadow.pivot_offset = diamond.size / 2.0
	shadow.rotation = deg_to_rad(45)
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.12)
	shadow_style.corner_radius_top_left = 4
	shadow_style.corner_radius_top_right = 4
	shadow_style.corner_radius_bottom_left = 4
	shadow_style.corner_radius_bottom_right = 4
	shadow.add_theme_stylebox_override("panel", shadow_style)
	diamond.add_child(shadow)
	
	# Diamond Body
	var inner_panel = Panel.new()
	inner_panel.size = diamond.size
	inner_panel.pivot_offset = diamond.size / 2.0
	inner_panel.rotation = deg_to_rad(45)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("4fc3f7") # Light pastel blue
	style.border_color = Color("ffffff")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color("4fc3f7", 0.3)
	style.shadow_size = 6
	
	inner_panel.add_theme_stylebox_override("panel", style)
	diamond.add_child(inner_panel)
	add_child(diamond)
	diamond_nodes[grid_pos] = diamond
	
	var tween = create_tween().set_loops()
	tween.tween_property(inner_panel, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(inner_panel, "scale", Vector2(0.9, 0.9), 0.8).set_trans(Tween.TRANS_SINE)

func spawn_hole_visual(grid_pos: Vector2i, cell_pos: Vector2):
	var hole = Panel.new()
	var h_size = cell_size * 0.6
	hole.size = Vector2(h_size, h_size)
	hole.position = cell_pos + Vector2((cell_size - h_size)/2.0, (cell_size - h_size)/2.0)
	
	# Drop Shadow under the hole cup
	var shadow = Panel.new()
	shadow.size = hole.size
	shadow.position = Vector2(2, 6)
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.15)
	shadow_style.corner_radius_top_left = h_size / 2.0
	shadow_style.corner_radius_top_right = h_size / 2.0
	shadow_style.corner_radius_bottom_left = h_size / 2.0
	shadow_style.corner_radius_bottom_right = h_size / 2.0
	shadow.add_theme_stylebox_override("panel", shadow_style)
	add_child(shadow)
	
	# Hole Cup Rim & Center
	var style = StyleBoxFlat.new()
	style.bg_color = Color("1a1a24") # Dark hole cup center
	style.border_color = Color("78909c") # Sleek metallic gray rim
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = h_size / 2.0
	style.corner_radius_top_right = h_size / 2.0
	style.corner_radius_bottom_left = h_size / 2.0
	style.corner_radius_bottom_right = h_size / 2.0
	hole.add_theme_stylebox_override("panel", style)
	add_child(hole)
	
	# Flagpole shadow (shifted slightly right/down)
	var stick_shadow = ColorRect.new()
	stick_shadow.size = Vector2(4, h_size * 0.7)
	stick_shadow.position = Vector2(h_size / 2.0 + 2, h_size * 0.22)
	stick_shadow.color = Color(0, 0, 0, 0.15)
	hole.add_child(stick_shadow)
	
	# Triangular flag shadow (shifted slightly right/down)
	var flag_pts = PackedVector2Array([
		Vector2(0, 0),
		Vector2(18, 9),
		Vector2(0, 18)
	])
	
	var flag_shadow = Polygon2D.new()
	flag_shadow.color = Color(0, 0, 0, 0.15)
	flag_shadow.polygon = flag_pts
	flag_shadow.position = Vector2(h_size / 2.0 + 4, h_size * 0.15 + 4)
	hole.add_child(flag_shadow)
	
	# Actual flagpole stick
	var stick = ColorRect.new()
	stick.size = Vector2(4, h_size * 0.7)
	stick.position = Vector2(h_size / 2.0 - 2, h_size * 0.15)
	stick.color = Color("ffffff")
	hole.add_child(stick)
	
	# Actual red triangular flag
	var flag = Polygon2D.new()
	flag.color = Color("ef5350")
	flag.polygon = flag_pts
	flag.position = Vector2(h_size / 2.0, h_size * 0.15)
	hole.add_child(flag)
	
	hole_node = hole

func spawn_portal_visual(grid_pos: Vector2i, cell_pos: Vector2, water_color: Color, _name: String):
	var well = Control.new()
	var p_size = cell_size * 0.65
	well.size = Vector2(p_size, p_size)
	well.position = cell_pos + Vector2((cell_size - p_size)/2.0, (cell_size - p_size)/2.0)
	
	# Drop Shadow under the well
	var shadow = Panel.new()
	shadow.size = well.size
	shadow.position = Vector2(2, 6)
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.15)
	shadow_style.corner_radius_top_left = p_size / 2.0
	shadow_style.corner_radius_top_right = p_size / 2.0
	shadow_style.corner_radius_bottom_left = p_size / 2.0
	shadow_style.corner_radius_bottom_right = p_size / 2.0
	shadow.add_theme_stylebox_override("panel", shadow_style)
	well.add_child(shadow)
	
	# Stone Well Rim
	var rim = Panel.new()
	rim.size = well.size
	var rim_style = StyleBoxFlat.new()
	rim_style.bg_color = Color("78909c") # Dark slate/stone gray
	rim_style.border_color = Color("b0bec5") # Light stone gray border
	rim_style.border_width_left = 6
	rim_style.border_width_right = 6
	rim_style.border_width_top = 6
	rim_style.border_width_bottom = 6
	rim_style.corner_radius_top_left = p_size / 2.0
	rim_style.corner_radius_top_right = p_size / 2.0
	rim_style.corner_radius_bottom_left = p_size / 2.0
	rim_style.corner_radius_bottom_right = p_size / 2.0
	rim.add_theme_stylebox_override("panel", rim_style)
	well.add_child(rim)
	
	# Water inside the well
	var water = Panel.new()
	var w_size = p_size - 12
	water.size = Vector2(w_size, w_size)
	water.position = Vector2(6, 6)
	var water_style = StyleBoxFlat.new()
	water_style.bg_color = water_color
	water_style.corner_radius_top_left = w_size / 2.0
	water_style.corner_radius_top_right = w_size / 2.0
	water_style.corner_radius_bottom_left = w_size / 2.0
	water_style.corner_radius_bottom_right = w_size / 2.0
	water.add_theme_stylebox_override("panel", water_style)
	well.add_child(water)
	
	# Water reflection overlay
	var reflection = Panel.new()
	var r_size = w_size * 0.7
	reflection.size = Vector2(r_size, r_size)
	reflection.position = Vector2((w_size - r_size)/2.0, (w_size - r_size)/2.0)
	reflection.pivot_offset = reflection.size / 2.0
	var refl_style = StyleBoxFlat.new()
	refl_style.bg_color = Color(1, 1, 1, 0.15)
	refl_style.corner_radius_top_left = r_size / 2.0
	refl_style.corner_radius_top_right = r_size / 2.0
	refl_style.corner_radius_bottom_left = r_size / 2.0
	refl_style.corner_radius_bottom_right = r_size / 2.0
	reflection.add_theme_stylebox_override("panel", refl_style)
	water.add_child(reflection)
	
	add_child(well)
	cell_visuals[grid_pos] = well
	
	# Animate the water reflection (gentle rotation & scale pulse)
	var tween = create_tween().set_loops()
	tween.tween_property(reflection, "scale", Vector2(1.15, 1.15), 1.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(reflection, "scale", Vector2(0.9, 0.9), 1.8).set_trans(Tween.TRANS_SINE)

func spawn_button_visual(grid_pos: Vector2i, cell_pos: Vector2):
	var button = Panel.new()
	var b_size = cell_size * 0.5
	button.size = Vector2(b_size, b_size)
	button.position = cell_pos + Vector2((cell_size - b_size)/2.0, (cell_size - b_size)/2.0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("ffd600") # Glowing yellow
	style.border_color = Color("ffffff")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color("ffd600", 0.3)
	style.shadow_size = 4
	
	button.add_theme_stylebox_override("panel", style)
	add_child(button)
	button_visuals[grid_pos] = button

func spawn_gate_visual(grid_pos: Vector2i, cell_pos: Vector2):
	var gate = Panel.new()
	gate.size = Vector2(cell_size - 8, cell_size - 8)
	gate.position = cell_pos + Vector2(4, 4)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("1e141c")
	style.border_color = Color("ff1744") # Neon red
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color("ff1744", 0.3)
	style.shadow_size = 6
	
	gate.add_theme_stylebox_override("panel", style)
	add_child(gate)
	gate_visuals[grid_pos] = gate

func spawn_fragile_visual(grid_pos: Vector2i, cell_pos: Vector2):
	var fragile = Panel.new()
	fragile.size = Vector2(cell_size - 10, cell_size - 10)
	fragile.position = cell_pos + Vector2(5, 5)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("3e424c") # Slate gray cracked
	style.border_color = Color("ff9100") # Neon orange cracks indicator
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	fragile.add_theme_stylebox_override("panel", style)
	add_child(fragile)
	fragile_visuals[grid_pos] = fragile

# --- State Mechanics ---

# Find first matching portal coordinate
func get_portal_out_position() -> Vector2i:
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x] == 5: # PortalOut
				return Vector2i(x, y)
	return Vector2i(-1, -1)

# Toggle gate visually and logically
func set_gate_state(is_open: bool):
	is_gate_open = is_open
	for pos in gate_visuals.keys():
		var gate = gate_visuals[pos]
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		
		if is_open:
			# Fade out the gate
			style.bg_color = Color("1a1c23", 0.1)
			style.border_color = Color("ff1744", 0.15)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.shadow_size = 0
		else:
			# Close the gate
			style.bg_color = Color("1e141c")
			style.border_color = Color("ff1744")
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.shadow_color = Color("ff1744", 0.3)
			style.shadow_size = 6
			
		gate.add_theme_stylebox_override("panel", style)

# Crack visual feedback
func crack_fragile_tile(grid_pos: Vector2i):
	if fragile_visuals.has(grid_pos):
		var fragile = fragile_visuals[grid_pos]
		var style = StyleBoxFlat.new()
		style.bg_color = Color("4f2b1d") # Warning dark red/brown
		style.border_color = Color("ff3d00") # Glowing hot red/orange
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.shadow_color = Color("ff3d00", 0.4)
		style.shadow_size = 6
		fragile.add_theme_stylebox_override("panel", style)

# Destroy tile and place solid Wall (1)
func destroy_fragile_tile(grid_pos: Vector2i):
	if fragile_visuals.has(grid_pos):
		var fragile = fragile_visuals[grid_pos]
		
		# Animate breaking out
		var tween = create_tween()
		tween.tween_property(fragile, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(fragile.queue_free)
		fragile_visuals.erase(grid_pos)
		
		# Convert logically to Wall (1)
		grid[grid_pos.y][grid_pos.x] = 1
		
		# Spawn wall visual
		spawn_wall_visual(grid_pos)

# Spawn Diamond (useful for Bonus Mode respawns)
func spawn_diamond_at(grid_pos: Vector2i):
	grid[grid_pos.y][grid_pos.x] = 2
	var cell_pos = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
	spawn_diamond_visual(grid_pos, cell_pos)

func find_random_empty_cell() -> Vector2i:
	var empty_cells: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x] == 0:
				empty_cells.append(Vector2i(x, y))
	if empty_cells.size() > 0:
		randomize()
		return empty_cells[randi() % empty_cells.size()]
	return Vector2i(-1, -1)

# Get cell type (takes gate state into account)
func get_cell_type(grid_pos: Vector2i) -> int:
	if grid_pos.x < 0 or grid_pos.x >= grid_width or grid_pos.y < 0 or grid_pos.y >= grid_height:
		return -1
		
	var type = grid[grid_pos.y][grid_pos.x]
	
	# If it's a gate and gates are currently open, treat it as empty path (0)
	if type == 7 and is_gate_open:
		return 0
		
	return type

# Set cell type
func set_cell_type(grid_pos: Vector2i, type: int):
	if grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height:
		grid[grid_pos.y][grid_pos.x] = type

func spawn_mud_visual(grid_pos: Vector2i, cell_pos: Vector2):
	var mud = Panel.new()
	var m_size = cell_size - 4
	mud.size = Vector2(m_size, m_size)
	mud.position = cell_pos + Vector2(2, 2)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("d7ccc8") # Mud light brown (Golf Peaks pastel theme)
	style.border_color = Color("bcaaa4") # Mud border
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	mud.add_theme_stylebox_override("panel", style)
	
	# Add some little mud ripples or details
	var ripple = ColorRect.new()
	ripple.size = Vector2(cell_size * 0.4, 4)
	ripple.position = Vector2(cell_size * 0.3, cell_size * 0.3)
	ripple.color = Color("8d6e63", 0.3)
	mud.add_child(ripple)
	
	var ripple2 = ColorRect.new()
	ripple2.size = Vector2(cell_size * 0.3, 4)
	ripple2.position = Vector2(cell_size * 0.4, cell_size * 0.6)
	ripple2.color = Color("8d6e63", 0.3)
	mud.add_child(ripple2)
	
	add_child(mud)
	cell_visuals[grid_pos] = mud

# Get cell center world coordinates
func get_cell_world_position(grid_pos: Vector2i) -> Vector2:
	var local_pos = Vector2(
		grid_pos.x * cell_size + cell_size / 2.0,
		grid_pos.y * cell_size + cell_size / 2.0
	)
	return global_position + local_pos

# Remove diamond visual
func remove_diamond_visual(grid_pos: Vector2i):
	if diamond_nodes.has(grid_pos):
		var node = diamond_nodes[grid_pos]
		var tween = create_tween()
		tween.tween_property(node, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(node.queue_free)
		diamond_nodes.erase(grid_pos)
		set_cell_type(grid_pos, 0)

# Complete level reset
func reset_grid():
	for child in get_children():
		child.queue_free()
		
	cell_visuals.clear()
	diamond_nodes.clear()
	hole_node = null
	gate_visuals.clear()
	fragile_visuals.clear()
	button_visuals.clear()
	is_gate_open = false
	
	setup_grid()
