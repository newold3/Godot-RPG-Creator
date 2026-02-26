@tool
extends EditorPlugin

var _loader_instance: ResourceFormatLoader
var _export_plugin: EditorExportPlugin

func _enter_tree() -> void:
	# 1. Register the ZipLoader (ONLY for Editor usage)
	# In Runtime, the AssetManager autoload handles this registration.
	if Engine.is_editor_hint():
		var loader_script = load("res://addons/0ZipAssetLoader/zip_media_loader.gd")
		if loader_script:
			_loader_instance = loader_script.new()
			# Priority True is vital to intercept calls before Godot checks the disk
			ResourceLoader.add_resource_format_loader(_loader_instance, true)
			print("🔌 [Plugin] ZipMediaLoader hooked into Editor.")

	# 2. Register the Auto-Export Plugin
	# This ensures assets are copied when you click "Export Project"
	var export_script = load("res://addons/0ZipAssetLoader/asset_auto_export.gd")
	if export_script:
		_export_plugin = export_script.new()
		add_export_plugin(_export_plugin)
		print("🔌 [Plugin] AssetAutoExport registered.")


func _exit_tree() -> void:
	# Clean up Loader
	if _loader_instance:
		ResourceLoader.remove_resource_format_loader(_loader_instance)
		_loader_instance = null
	
	# Clean up Exporter
	if _export_plugin:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
		
	print("🔌 [Plugin] Systems deactivated.")
