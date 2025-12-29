@tool
extends EditorPlugin


const MAIN_PANEL = preload("res://addons/ImageToLpcPaletteConversor/Scenes/main_panel.tscn")
const PALETTE_ICON = preload("res://addons/ImageToLpcPaletteConversor/Images/palette.png")

var main_panel_instance

func _enter_tree() -> void:
	main_panel_instance = MAIN_PANEL.instantiate()
	EditorInterface.get_editor_main_screen().add_child(main_panel_instance)
	main_panel_instance.enable_plugin_mode()
	_make_visible(false)


func _exit_tree() -> void:
	if main_panel_instance:
		main_panel_instance.queue_free()


func _has_main_screen():
	return true


func _make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible


func _get_plugin_name():
	return "Image To LPC Palette Conversor"


func _get_plugin_icon():
	return PALETTE_ICON
