extends RefCounted

class_name LevelGenerator

# Generates a random level grid
# returns a Dictionary containing grid size, start position, objects and the matrix grid.
static func generate_level(width: int, height: int, wall_count: int, gem_count: int) -> Dictionary:
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
	
	# Check if we have enough empty space
	var required_cells = 1 + 1 + wall_count + gem_count # Start + Hole + Walls + Gems
	if available_positions.size() < required_cells:
		printerr("LevelGenerator: Grid size too small for requested object counts!")
		return {}
		
	# Pop positions from the shuffled list
	var player_start = available_positions.pop_back()
	var hole = available_positions.pop_back()
	
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
	
	# Format coordinates for JSON output (as arrays [x, y])
	var walls_json = []
	for w in walls:
		walls_json.append([w.x, w.y])
		
	var gems_json = []
	for g in gems:
		gems_json.append([g.x, g.y])
		
	return {
		"grid_size": [width, height],
		"player_start": [player_start.x, player_start.y],
		"objects": {
			"walls": walls_json,
			"gems": gems_json,
			"hole": [hole.x, hole.y]
		},
		"grid": grid,
		"min_moves": -1 # To be filled by Solver
	}
