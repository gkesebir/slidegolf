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
	var start_y = 220.0 + (1480.0 - total_h) / 2.0 # 220 top bar, 1480 playable height
	position = Vector2(start_x, start_y)
	
	for y in range(grid_height):
		for x in range(grid_width):
			var grid_pos = Vector2i(x, y)
			var type = grid[y][x]
			create_cell_visual(grid_pos, type)

func create_cell_visual(grid_pos: Vector2i, type: int):
	var cell_pos = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
	
	# Draw base Grass tile for all non-void cells
	if type != 9:
		var tile_size = cell_size - 10
		var tile_pos = cell_pos + Vector2(5, 5)
		
		var grass_panel = Panel.new()
		grass_panel.size = Vector2(tile_size, tile_size)
		grass_panel.position = tile_pos
		
		var style = StyleBoxFlat.new()
		if (grid_pos.x + grid_pos.y) % 2 == 0:
			style.bg_color = Color("99deb9") # Mint green
		else:
			style.bg_color = Color("91d4af") # Slightly darker mint
			
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 16
		grass_panel.add_theme_stylebox_override("panel", style)
		
		# Add 3 tiny grass blades
		var blade_color = Color("7ac29a")
		var blade_positions = [Vector2(20, 30), Vector2(80, 20), Vector2(40, 90)]
		for bp in blade_positions:
			var center = Control.new()
			center.position = bp
			
			var blade1 = ColorRect.new()
			blade1.size = Vector2(4, 12)
			blade1.position = Vector2(-2, -12)
			blade1.color = blade_color
			
			var blade2 = ColorRect.new()
			blade2.size = Vector2(4, 10)
			blade2.position = Vector2(-6, -10)
			blade2.rotation = deg_to_rad(-30)
			blade2.color = blade_color
			
			var blade3 = ColorRect.new()
			blade3.size = Vector2(4, 10)
			blade3.position = Vector2(2, -10)
			blade3.rotation = deg_to_rad(30)
			blade3.color = blade_color
			
			center.add_child(blade1)
			center.add_child(blade2)
			center.add_child(blade3)
			grass_panel.add_child(center)
			
		add_child(grass_panel)
	
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
	
	var wall_panel = Panel.new()
	var tile_size = cell_size - 6
	wall_panel.size = Vector2(tile_size, tile_size)
	wall_panel.position = Vector2(3, 3)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("fad5c4") # Light wood/beige
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	wall_panel.add_theme_stylebox_override("panel", style)
	
	# Wood grain (simple vertical lines)
	var line_color = Color("f3c4af")
	var line_xs = [tile_size * 0.25, tile_size * 0.5, tile_size * 0.75]
	for lx in line_xs:
		var grain = ColorRect.new()
		grain.size = Vector2(4, tile_size * 0.8)
		grain.position = Vector2(lx - 2, tile_size * 0.1)
		grain.color = line_color
		wall_panel.add_child(grain)
		
	wall.add_child(wall_panel)
	
	add_child(wall)
	cell_visuals[grid_pos] = wall

func spawn_diamond_visual(grid_pos: Vector2i, cell_pos: Vector2):
	var diamond = Control.new()
	diamond.z_index = 10 
	diamond.size = Vector2(cell_size * 0.4, cell_size * 0.4)
	diamond.position = cell_pos + Vector2(cell_size * 0.3, cell_size * 0.3)
	
	# Diamond Body
	var inner_panel = Panel.new()
	inner_panel.size = diamond.size
	inner_panel.pivot_offset = diamond.size / 2.0
	inner_panel.rotation = deg_to_rad(45)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("4fc3f7") # Pastel blue
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
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
	
	# Hole Base
	var style = StyleBoxFlat.new()
	style.bg_color = Color("282635") # Dark navy hole cup center
	style.border_color = Color("484a5e") # Soft lighter rim
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
	
	# Flag Pole
	var pole = Panel.new()
	pole.size = Vector2(6, h_size)
	pole.position = Vector2(h_size / 2.0 - 3, -h_size * 0.4)
	var pole_style = StyleBoxFlat.new()
	pole_style.bg_color = Color("fae59e") # Light wood pole
	pole_style.corner_radius_top_left = 3
	pole_style.corner_radius_top_right = 3
	pole_style.corner_radius_bottom_left = 3
	pole_style.corner_radius_bottom_right = 3
	pole.add_theme_stylebox_override("panel", pole_style)
	hole.add_child(pole)
	
	# Triangular flat flag
	var flag_pts = PackedVector2Array([
		Vector2(0, 0),
		Vector2(25, 10),
		Vector2(0, 20)
	])
	
	var flag = Polygon2D.new()
	flag.color = Color("fccc75") # Pastel yellow/orange
	flag.polygon = flag_pts
	flag.position = Vector2(3, 5) # Attach to pole
	pole.add_child(flag)
	
	# Wind effect (Tween) on the flag (Polygon offset)
	var tween = create_tween().set_loops()
	tween.tween_property(flag, "scale:x", 0.7, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flag, "scale:x", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(flag, "rotation", deg_to_rad(5), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(flag, "rotation", deg_to_rad(-5), 0.4).set_delay(0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
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
	var m_size = cell_size - 6
	mud.size = Vector2(m_size, m_size)
	mud.position = cell_pos + Vector2(3, 3)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("cd7f71") # Terracotta / Mud
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	mud.add_theme_stylebox_override("panel", style)
	
	# Add tiny specks
	var speck_color = Color("b1685b")
	var speck_positions = [Vector2(20, 20), Vector2(80, 30), Vector2(40, 70), Vector2(90, 80), Vector2(25, 95)]
	for sp in speck_positions:
		var speck = ColorRect.new()
		speck.size = Vector2(6, 6)
		speck.position = sp
		speck.color = speck_color
		mud.add_child(speck)
	
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
