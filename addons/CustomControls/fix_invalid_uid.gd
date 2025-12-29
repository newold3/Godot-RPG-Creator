@tool
extends Node

@export_dir var current_path :
	set(value):
		if value:
			if value != "<null>":
				_run(value)


var files: Array[String]

func _run(path: String) -> void:
	files = []
	
	add_files(path)
	
	for file in files:
		var res = load(file)
		ResourceSaver.save(res)
	
	print("all files re-saved in folder: ", path)


func add_files(dir: String):
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "tscn" or file.get_extension() == "tres":
			files.append(dir.path_join(file))
	
	for dr in DirAccess.get_directories_at(dir):
		add_files(dir.path_join(dr))
