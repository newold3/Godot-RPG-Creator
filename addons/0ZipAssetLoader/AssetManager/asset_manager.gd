@tool
extends Node

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		print("🛠️ [Assets] Editor Mode: Delegating to Plugin.")
		return

	print("🎮 [Assets] Game Mode: Initializing Zip System...")
	var background = preload("uid://denwon4yn06ww").instantiate()
	add_child(background)
	_registrar_loader_runtime()


func _registrar_loader_runtime() -> void:
	var loader = ZipMediaLoader.new()
	ResourceLoader.add_resource_format_loader(loader, true)
	print("✅ [Assets] ZipMediaLoader active in Runtime.")


func file_exists(path: String) -> bool:
	return ZipMediaLoader.file_exists(path)


func exists(path: String) -> bool:
	return file_exists(path)
