extends SceneTree
# core/ and tests/ scripts are indented with tabs only. A line that starts with a space (or an
# editor rewriting some lines to tabs) is a GDScript parse error that can crash the app.
var failures = 0

func _initialize() -> void:
	for folder in ["res://core", "res://tests"]:
		for name in DirAccess.get_files_at(folder):
			if not name.ends_with(".gd"): continue
			var number = 0
			for line in FileAccess.get_file_as_string(folder + "/" + name).split("\n"):
				number += 1
				if line.begins_with(" "):
					failures += 1
					push_error("%s/%s:%d starts with a space" % [folder, name, number])
					break
	print("Indentation: %d failures" % failures)
	quit(1 if failures else 0)
