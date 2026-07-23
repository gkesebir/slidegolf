extends RefCounted
class_name HintSolver

const DIR_UP = Vector2i(0, -1)
const DIR_DOWN = Vector2i(0, 1)
const DIR_LEFT = Vector2i(-1, 0)
const DIR_RIGHT = Vector2i(1, 0)
const DIRS = [DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT]

func get_best_move(grid_manager, start_pos: Vector2i, _collected: int, _total: int) -> Vector2i:
	var gem_positions = []
	var portal_out = grid_manager.get_portal_out_position()
	
	for y in range(grid_manager.grid_height):
		for x in range(grid_manager.grid_width):
			var type = grid_manager.get_cell_type(Vector2i(x, y))
			if type == 2:
				gem_positions.append(Vector2i(x, y))
				
	var total_gems_left = gem_positions.size()
	var initial_mask = (1 << total_gems_left) - 1
	var initially_all_collected = (total_gems_left == 0)
	
	var queue = []
	var visited = {}
	
	for dir in DIRS:
		var state = simulate_slide(grid_manager, start_pos, dir, initial_mask, gem_positions, initially_all_collected, portal_out)
		if state["pos"] != start_pos:
			if state["won"]:
				return dir
			var key = "%d_%d_%d" % [state["pos"].x, state["pos"].y, state["mask"]]
			if not visited.has(key):
				visited[key] = true
				queue.append({ "pos": state["pos"], "mask": state["mask"], "first_dir": dir })
				
	var head = 0
	while head < queue.size():
		if head > 20000: # Safe break for too complex levels
			break
		var curr = queue[head]
		head += 1
		
		for dir in DIRS:
			var all_collected = (curr["mask"] == 0)
			var state = simulate_slide(grid_manager, curr["pos"], dir, curr["mask"], gem_positions, all_collected, portal_out)
			
			if state["pos"] != curr["pos"]:
				if state["won"]:
					return curr["first_dir"]
					
				var key = "%d_%d_%d" % [state["pos"].x, state["pos"].y, state["mask"]]
				if not visited.has(key):
					visited[key] = true
					queue.append({ "pos": state["pos"], "mask": state["mask"], "first_dir": curr["first_dir"] })
					
	# Fallback if no full path to hole is found
	if queue.size() > 0:
		return queue[0]["first_dir"]
	return Vector2i.ZERO

func simulate_slide(grid_manager, start_pos: Vector2i, dir: Vector2i, start_mask: int, gem_positions: Array, all_collected: bool, portal_out: Vector2i) -> Dictionary:
	var current = start_pos
	var mask = start_mask
	var won = false
	
	while true:
		var next_pos = current + dir
		var type = grid_manager.get_cell_type(next_pos)
		
		if type == 1 or type == 9 or type == -1:
			break
			
		if type == 4:
			if portal_out != Vector2i(-1, -1):
				current = portal_out
				continue
				
		if type == 10:
			current = next_pos
			break
			
		current = next_pos
		
		if type == 2:
			var idx = gem_positions.find(current)
			if idx != -1:
				if (mask & (1 << idx)) != 0:
					mask &= ~(1 << idx)
					if mask == 0:
						all_collected = true
						
		if type == 3:
			if all_collected:
				won = true
				break
				
	return { "pos": current, "mask": mask, "won": won }
