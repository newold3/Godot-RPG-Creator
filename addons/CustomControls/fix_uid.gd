@tool
extends Node

@export_dir var current_path :
	set(value):
		if value:
			if value != "<null>":
				_run(value)

@export var es: Resource
var files: Array[String]

const START_DIR = "res://"
const EXTENSIONS = [ "tres", "res", "tscn", "atlastex" ]

func _run(path: String) -> void:
	files = []
	
	add_files(path)
	
	print("fixing uid from < %s > file/s" % files.size())
	await get_tree().process_frame
	
	for i in files.size():
		var file = files[i]
		print("fix file %s / %s (%s)" % [i+1, files.size(), file])
		var res = load(file)
		ResourceSaver.save(res)
		await get_tree().process_frame
	
	print("all files re-saved in folder: ", path)


func add_files(dir: String):
	if dir.begins_with("res://."):
		return
		
	for file in DirAccess.get_files_at(dir):
		if file.get_extension().to_lower() in EXTENSIONS:
			files.append(dir.path_join(file))
	
	for dr in DirAccess.get_directories_at(dir):
		add_files(dir.path_join(dr))
