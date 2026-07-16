extends SceneTree

func _init():
	print("--- Level Editor Integration Test Start ---")
	
	# If SaveManager is not loaded (headless/standalone mode), mock it!
	var root = get_root()
	if not root.has_node("SaveManager"):
		var mock_save_mgr = Node.new()
		mock_save_mgr.name = "SaveManager"
		mock_save_mgr.set("playtest_level_data", {})
		root.add_child(mock_save_mgr)
		print("SaveManager mocked successfully!")
		
	# Instantiate LevelEditor node
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
	
	# Manually force _ready calls since we are running inside SceneTree._init() before the main loop starts
	if editor.grid_manager:
		editor.grid_manager._ready()
	editor._ready()
	
	print("LevelEditor successfully instantiated and readied!")
	
	# Check bindings
	if not editor.grid_manager:
		printerr("grid_manager binding is missing!")
		quit(1)
		return
	if not editor.status_label:
		printerr("status_label binding is missing!")
		quit(1)
		return
	if editor.tool_buttons.size() < 7:
		printerr("tool_buttons binding has insufficient buttons! Count: ", editor.tool_buttons.size())
		quit(1)
		return
		
	# Test getting dictionary
	var dict = editor.get_level_dictionary()
	print("Level Dictionary: ", dict)
	if dict.is_empty():
		printerr("get_level_dictionary() returned empty dictionary!")
		quit(1)
		return
		
	# Test solving
	var moves = LevelSolver.solve_level(dict)
	print("Default editor level solved in ", moves, " moves.")
	if moves <= 0:
		printerr("Default editor level is unsolvable!")
		quit(1)
		return
		
	print("--- Level Editor Integration Test Success! ---")
	quit(0)
