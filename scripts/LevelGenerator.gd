extends RefCounted

class_name LevelGenerator

# Generates a random level grid
# returns a Dictionary containing grid size, start position, objects and the matrix grid.
static func generate_level(width: int, height: int, wall_count: int, gem_count: int) -> Dictionary:
	var attempts = 0
	var max_attempts = 100
	
	while attempts < max_attempts:
		attempts += 1
		
		# Initialize the grid with walls on the border and empty cells inside
		var grid = []
		for y in range(height):
			var row = []
			for x in range(width):
				if x == 0 or x == width - 1 or y == 0 or y == height - 1:
					row.append(1) # Wall
				else:
					row.append(0) # Empty
			grid.append(row)
			
		# Find all available inner positions
		var available_positions: Array[Vector2i] = []
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				available_positions.append(Vector2i(x, y))
				
		# Shuffle positions to pick random unique coordinates
		randomize()
		available_positions.shuffle()
		
		# We decide to generate a portal with 35% probability
		var generate_portal = (randf() < 0.35)
		var portal_cells = 2 if generate_portal else 0
		
		# Check if we have enough empty space
		var required_cells = 1 + 1 + wall_count + gem_count + portal_cells # Start + Hole + Walls + Gems + Portals
		if available_positions.size() < required_cells:
			continue # Try again or adjust size
			
		# Pop positions from the shuffled list
		var player_start = available_positions.pop_back()
		var hole = available_positions.pop_back()
		
		# Place portals if requested
		var portal_in: Vector2i = Vector2i(-1, -1)
		var portal_out: Vector2i = Vector2i(-1, -1)
		if generate_portal:
			portal_in = available_positions.pop_back()
			portal_out = available_positions.pop_back()
			grid[portal_in.y][portal_in.x] = 4
			grid[portal_out.y][portal_out.x] = 5
			
		# Place walls
		var walls: Array[Vector2i] = []
		for i in range(wall_count):
			var wall_pos = available_positions.pop_back()
			walls.append(wall_pos)
			grid[wall_pos.y][wall_pos.x] = 1
			
		# Place gems
		var gems: Array[Vector2i] = []
		for i in range(gem_count):
			var gem_pos = available_positions.pop_back()
			gems.append(gem_pos)
			grid[gem_pos.y][gem_pos.x] = 2
			
		# Place hole
		grid[hole.y][hole.x] = 3
		
		# Format coordinates for JSON output
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
		
		# Add portals to objects definition if they were generated
		if generate_portal:
			level_data["objects"]["portal_in"] = [portal_in.x, portal_in.y]
			level_data["objects"]["portal_out"] = [portal_out.x, portal_out.y]
			
		# Validate the level is solvable using LevelSolver
		var moves = LevelSolver.solve_level(level_data)
		if moves > 0:
			level_data["min_moves"] = moves
			return level_data
			
	# If we exceed max_attempts, return fallback solvable layout
	printerr("LevelGenerator: Failed to generate a solvable level in ", max_attempts, " attempts. Returning fallback layout.")
	var fallback_grid = [
		[1, 1, 1, 1, 1, 1, 1],
		[1, 0, 2, 0, 0, 0, 1],
		[1, 0, 1, 0, 1, 0, 1],
		[1, 2, 0, 0, 0, 2, 1],
		[1, 0, 1, 0, 1, 0, 1],
		[1, 0, 0, 0, 0, 3, 1],
		[1, 1, 1, 1, 1, 1, 1]
	]
	return {
		"grid_size": [7, 7],
		"player_start": [1, 1],
		"objects": {
			"walls": [[2, 2], [4, 2], [2, 4], [4, 4]],
			"gems": [[2, 1], [1, 3], [5, 3]],
			"hole": [5, 5]
		},
		"grid": fallback_grid,
		"min_moves": 4
	}
