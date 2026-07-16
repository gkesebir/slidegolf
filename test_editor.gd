extends SceneTree

func _init():
	print("--- Advanced Level Editor Integration Test Start ---")
	
	# Mock SaveManager if not loaded
	var root = get_root()
	if not root.has_node("SaveManager"):
		var mock_save_mgr = Node.new()
		mock_save_mgr.name = "SaveManager"
		mock_save_mgr.set("playtest_level_data", {})
		root.add_child(mock_save_mgr)
		print("SaveManager mocked successfully!")
		
	# Instantiate LevelEditor
	var editor_scene = load("res://scenes/LevelEditor.tscn")
	if not editor_scene:
		printerr("Failed to load LevelEditor.tscn")
		quit(1)
		return
		
	var editor = editor_scene.instantiate()
	if not editor:
		printerr("Failed to instantiate LevelEditor scene")
		quit(1)
		return
		
	# Add to tree
	root.add_child(editor)
	
	# Manually force _ready calls
	if editor.grid_manager:
		editor.grid_manager._ready()
	editor._ready()
	
	print("LevelEditor successfully instantiated and readied!")
	
	# Check basic elements
	if editor.tool_buttons.size() < 9:
		printerr("Insufficient tool buttons in palette! Found: ", editor.tool_buttons.size())
		quit(1)
		return
		
	# 1. Test Grid Resizing
	print("Resizing grid to 9x9...")
	editor._resize_grid(9, 9)
	# Place a wall at (1, 6) to make the resized grid solvable
	editor.grid_manager.grid[6][1] = 1
	editor.grid_manager.reset_grid()
	var dict = editor.get_level_dictionary()
	if dict["grid_size"] != [9, 9]:
		printerr("Grid resizing failed! Grid size: ", dict["grid_size"])
		quit(1)
		return
	print("Grid successfully resized to 9x9!")
	
	# 2. Test Solvability on empty 9x9 layout with a wall helper
	var moves = LevelSolver.solve_level(dict)
	print("Empty 9x9 level solved in ", moves, " moves.")
	if moves <= 0:
		printerr("Resized level is unsolvable!")
		quit(1)
		return
		
	# 3. Test Mud (type 10) Physics and solving
	print("Placing mud tiles to test slide termination...")
	var grid = editor.grid_manager.grid
	grid[4][4] = 10
	editor.grid_manager.grid = grid
	editor.grid_manager.reset_grid()
	
	var dict_mud = editor.get_level_dictionary()
	var moves_mud = LevelSolver.solve_level(dict_mud)
	print("Mud level solved in ", moves_mud, " moves.")
	if moves_mud <= 0:
		printerr("Level with mud became unsolvable!")
		quit(1)
		return
		
	# 4. Test Void (type 9) Physics and solving
	print("Placing void tiles (blocking)...")
	grid[2][2] = 9
	editor.grid_manager.grid = grid
	editor.grid_manager.reset_grid()
	
	var dict_void = editor.get_level_dictionary()
	var moves_void = LevelSolver.solve_level(dict_void)
	print("Void level solved in ", moves_void, " moves.")
	if moves_void <= 0:
		printerr("Level with void became unsolvable!")
		quit(1)
		return
		
	print("--- Advanced Level Editor Integration Test Success! ---")
	quit(0)
