extends SceneTree

func _init():
	print("=== Script Validation ===")

	var dir = DirAccess.open("res://scripts/")
	if dir == null:
		print("ERROR: Cannot open scripts dir")
		quit(1)

	var files = []
	dir.list_dir_begin()
	var fn = dir.get_next()
	while fn != "":
		files.append(fn)
		fn = dir.get_next()
	dir.list_dir_end()
	files.sort()

	var total = 0
	var errors = 0

	for f in files:
		if not f.ends_with(".gd"):
			continue
		if f == "validate_project.gd" or f == "validate_simple.gd" or f == "test_quit.gd":
			print("SKIP: " + f)
			continue

		total += 1
		var path = "res://scripts/" + f
		print("Loading: " + f)
		var scr = load(path)
		if scr == null:
			print("  LOAD_ERROR: " + f)
			errors += 1
		else:
			print("  OK: " + f)

	print("=== Done: %d scripts, %d errors ===" % [total, errors])

	var rf = FileAccess.open("res://validation_results.txt", FileAccess.WRITE)
	if rf:
		rf.store_string("Total: %d, Errors: %d\n" % [total, errors])
		rf.close()

	quit(errors)