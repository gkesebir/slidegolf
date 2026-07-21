extends RefCounted

class_name LevelGenerator

# level_index (1'den 100'e kadar)
static func generate_level_for_index(level_index: int) -> Dictionary:
	var width = int(clamp(7 + floor((level_index - 1) / 5.0), 7, 20))
	var height = int(clamp(7 + floor((level_index - 1) / 4.0), 7, 25))
	
	var wall_count = int(clamp(7 + floor(level_index / 1.5), 7, 50))
	var gem_count = 0
	var mud_count = int(floor(level_index / 3.0)) if level_index > 10 else 0
	
	var portal_chance = 0.0
	if level_index >= 15:
		portal_chance = min(0.3 + (level_index - 15) * 0.015, 0.9)
	elif level_index >= 5:
		portal_chance = 0.15
		
	var target_min_moves = int(clamp(4 + floor(level_index / 3.0), 4, 25))
	
	return generate_complex_level(width, height, wall_count, gem_count, mud_count, portal_chance, target_min_moves)

static func generate_complex_level(width: int, height: int, wall_count: int, gem_count: int, mud_count: int, portal_chance: float, target_min_moves: int) -> Dictionary:
	var attempts = 0
	var max_attempts = 150
	
	while attempts < max_attempts:
		attempts += 1
		
		# Initialize the grid with walls (1)
		var grid = []
		for y in range(height):
			var row = []
			for x in range(width):
				row.append(1)
			grid.append(row)
			
		# Carve inner space (0)
		# To create complex shapes, we randomly carve out blocks, or just carve the center and leave some borders as Void (9)
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				grid[y][x] = 0
				
		# Add Voids (9) to make non-square shapes (L-shapes, missing corners)
		if width > 8 and height > 8:
			var corners = [[1, 1], [1, height-2], [width-2, 1], [width-2, height-2]]
			corners.shuffle()
			var void_corners = randi() % 3 # 0 to 2 corners voided
			for i in range(void_corners):
				var cx = corners[i][0]
				var cy = corners[i][1]
				var void_w = 2 + randi() % 3
				var void_h = 2 + randi() % 3
				for vy in range(void_h):
					for vx in range(void_w):
						var nx = cx + (vx if cx == 1 else -vx)
						var ny = cy + (vy if cy == 1 else -vy)
						if nx >= 1 and nx < width - 1 and ny >= 1 and ny < height - 1:
							grid[ny][nx] = 9 # Void
			
		var available_positions: Array[Vector2i] = []
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				if grid[y][x] == 0:
					available_positions.append(Vector2i(x, y))
					
		available_positions.shuffle()
		
		var generate_portal = (randf() < portal_chance)
		var required_cells = 1 + 1 + wall_count + gem_count + mud_count + (2 if generate_portal else 0)
		if available_positions.size() < required_cells:
			continue
			
		var player_start = available_positions.pop_back()
		var hole = available_positions.pop_back()
		
		var portal_in: Vector2i = Vector2i(-1, -1)
		var portal_out: Vector2i = Vector2i(-1, -1)
		if generate_portal:
			portal_in = available_positions.pop_back()
			portal_out = available_positions.pop_back()
			grid[portal_in.y][portal_in.x] = 4
			grid[portal_out.y][portal_out.x] = 5
			
		var walls: Array[Vector2i] = []
		for i in range(wall_count):
			var pos = available_positions.pop_back()
			walls.append(pos)
			grid[pos.y][pos.x] = 1
			
		var gems: Array[Vector2i] = []
		for i in range(gem_count):
			var pos = available_positions.pop_back()
			gems.append(pos)
			grid[pos.y][pos.x] = 2
			
		var muds: Array[Vector2i] = []
		for i in range(mud_count):
			var pos = available_positions.pop_back()
			muds.append(pos)
			grid[pos.y][pos.x] = 10
			
		grid[hole.y][hole.x] = 3
		
		var walls_json = []
		for w in walls:
			walls_json.append([w.x, w.y])
		var gems_json = []
		for g in gems:
			gems_json.append([g.x, g.y])
			
		var level_data = {
			"grid_size": [width, height],
			"player_start": [player_start.x, player_start.y],
			"objects": {
				"walls": walls_json,
				"gems": gems_json,
				"hole": [hole.x, hole.y]
			},
			"grid": grid,
			"min_moves": -1
		}
		
		if generate_portal:
			level_data["objects"]["portal_in"] = [portal_in.x, portal_in.y]
			level_data["objects"]["portal_out"] = [portal_out.x, portal_out.y]
			
		# Enforce difficulty scaling: verify min_moves is close to target_min_moves
		var moves = LevelSolver.solve_level(level_data)
		if moves > 0 and moves >= target_min_moves - 3:
			level_data["min_moves"] = moves
			return level_data
			
	return {}
