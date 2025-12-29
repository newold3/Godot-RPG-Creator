@tool
extends EditorPlugin

var export_plugin

func _enter_tree():
	export_plugin = preload("res://addons/rpg_database_export/export_plugin.gd").new()
	add_export_plugin(export_plugin)
	print("RPG Database Export Plugin activado")

func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null
