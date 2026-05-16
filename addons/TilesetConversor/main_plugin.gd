@tool
extends EditorPlugin

var autotile_button: Button


func _enter_tree() -> void:
	_create_button()


func _exit_tree() -> void:
	if autotile_button:
		RPGMenuAPI.remove_menu_item(autotile_button)
		autotile_button.queue_free()


func _create_button() -> void:
	autotile_button = Button.new()
	autotile_button.icon = preload("uid://bgafb3d1vhpij")
	autotile_button.name = "AutoTileButton"
	autotile_button.text = "Open Autotile Conversor"
	autotile_button.pressed.connect(_on_autotile_button_pressed, CONNECT_DEFERRED)
	autotile_button.theme = load("res://addons/CustomControls/Resources/Themes/editor_buitton_themes.tres")
	autotile_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	autotile_button.tooltip_text = "[title]Open Autotile Conversor[/title]\nConvert auto-tiles (such as those from RPG Maker) into Godot-compatible auto-tiles"
	
	RPGMenuAPI.add_menu_item(autotile_button)
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(autotile_button)


func _on_autotile_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/atlas_to_autotiles_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
