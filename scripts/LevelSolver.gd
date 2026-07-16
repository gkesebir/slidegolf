extends RefCounted

class_name LevelSolver

# Solves a level using Breadth-First Search (BFS)
# Returns the minimum moves (Par) if solvable, otherwise returns -1
static func solve_level(level_data: Dictionary) -> int:
	var grid = level_data["grid"]
	var grid_size = level_data["grid_size"]
	var width = grid_size[0]
	var height = grid_size[1]
	
	var start_arr = level_data["player_start"]
	var start_pos = Vector2i(start_arr[0], start_arr[1])
	
	var objects = level_data["objects"]
	var hole_arr = objects["hole"]
	var hole_pos = Vector2i(hole_arr[0], hole_arr[1])
	
	var gems_arr = objects["gems"]
	var gem_positions: Array[Vector2i] = []
	for g in gems_arr:
		gem_positions.append(Vector2i(g[0], g[1]))
		
	var gem_count = gem_positions.size()
	var goal_mask = (1 << gem_count) - 1
	
	# BFS Queue stores: [ { "pos": Vector2i, "gems_mask": int }, moves_count ]
	var queue: Array = []
	var visited: Dictionary = {}
	
	# Initial state
	var start_state = {
		"pos": start_pos,
		"gems_mask": 0
	}
	
	queue.append([start_state, 0])
	var start_key = _get_state_key(start_pos, 0)
	visited[start_key] = true
	
	# 4 slider directions
	var directions = [
		Vector2i(0, -1), # Up
		Vector2i(0, 1),  # Down
		Vector2i(-1, 0), # Left
		Vector2i(1, 0)   # Right
	]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var state = current[0]
		var moves = current[1]
		
		var curr_pos = state["pos"]
		var curr_mask = state["gems_mask"]
		
		# If we reached the hole and collected all gems, we solved it!
		if curr_pos == hole_pos and curr_mask == goal_mask:
			return moves
			
		for d in directions:
			# Simulate sliding in direction d
			var pos = curr_pos
			var mask = curr_mask
			var reached_hole = false
			
			var slide_visited = {}
			while true:
				var next_pos = pos + d
				
				# Out of bounds check
				if next_pos.x < 0 or next_pos.x >= width or next_pos.y < 0 or next_pos.y >= height:
					break
				
				# Wall check
				if grid[next_pos.y][next_pos.x] == 1:
					break
					
				# Detect infinite loops in a single slide step (e.g. portal ping-pong)
				var slide_key = str(next_pos.x) + "," + str(next_pos.y)
				if slide_visited.has(slide_key):
					break
				slide_visited[slide_key] = true
					
				# PortalIn check (type 4)
				if grid[next_pos.y][next_pos.x] == 4:
					var portal_out = _find_portal_out_pos(grid, width, height)
					if portal_out != Vector2i(-1, -1):
						# Teleport directly to PortalOut
						pos = portal_out
						
						# Check if PortalOut itself has a gem
						var gem_idx = gem_positions.find(pos)
						if gem_idx != -1:
							mask |= (1 << gem_idx)
						continue
					
				# Valid step: move to next position
				pos = next_pos
				
				# Check if we slid over/into a gem
				var gem_idx = gem_positions.find(pos)
				if gem_idx != -1:
					mask |= (1 << gem_idx)
					
				# Check if we slid into the hole
				if grid[pos.y][pos.x] == 3:
					# If all gems are collected, the ball stops at the hole
					if mask == goal_mask:
						reached_hole = true
						break
					# Otherwise, it slides over it (treat it like a normal road)
			
			# We finished sliding in direction d
			var new_state = {
				"pos": pos,
				"gems_mask": mask
			}
			
			var state_key = _get_state_key(pos, mask)
			if not visited.has(state_key):
				visited[state_key] = true
				queue.append([new_state, moves + 1])
				
	return -1 # Unsolvable

static func _get_state_key(pos: Vector2i, mask: int) -> String:
	return str(pos.x) + "," + str(pos.y) + "|" + str(mask)

static func _find_portal_out_pos(grid: Array, width: int, height: int) -> Vector2i:
	for y in range(height):
		for x in range(width):
			if grid[y][x] == 5: # PortalOut
				return Vector2i(x, y)
	return Vector2i(-1, -1)
