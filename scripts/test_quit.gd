extends SceneTree

func _init():
	var f = FileAccess.open("res://validation_results.txt", FileAccess.WRITE)
	if f:
		f.store_line("=== Godot Headless Test Works ===")
		f.close()
		print("Validation complete")
	else:
		push_error("Cannot write file")
	quit()