extends SceneTree

func _init():
	print("VALIDATION_START")
	var err_count = 0

	var dir = DirAccess.open("res://scripts/")
	if dir == null:
		print("DIR_NULL")
		quit(1)
		return

	var files = []
	dir.list_dir_begin()
	var fn = dir.get_next()
	while fn != "":
		files.append(fn)
		fn = dir.get_next()
	dir.list_dir_end()
	files.sort()

	for f in files:
		if not f.ends_with(".gd"):
			continue
		if f == "validate_project.gd" or f == "validate_simple.gd" or f == "test_quit.gd":
			print("SKIP: " + f)
			continue

		var path = "res://scripts/" + f
		var parser = GDScript.new()
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			print("FILE_OPEN_ERROR: " + f)
			err_count += 1
			continue
		var source = file.get_as_text()
		file.close()
		var e = parser.parse(source)
		if e != OK:
			print("PARSE_ERROR: " + f)
			err_count += 1
		else:
			print("OK: " + f)

	print("DONE: %d errors" % err_count)

	var rf = FileAccess.open("res://validation_results.txt", FileAccess.WRITE)
	if rf:
		rf.store_string("Total errors: %d\n" % err_count)
		rf.close()

	quit(err_count)