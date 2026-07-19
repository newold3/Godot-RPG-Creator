@tool
extends EditorPlugin

const UI_SCENE: PackedScene = preload("uid://buffccckugjge")

var main_screen: Control


#region Plugin Lifecycle
## Initializes the plugin and instantiates the main screen scene.
func _enter_tree() -> void:
	if UI_SCENE:
		main_screen = UI_SCENE.instantiate()
		main_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
		get_editor_interface().get_editor_main_screen().add_child(main_screen)
		main_screen.hide()


## Cleans up the main screen scene when the plugin is disabled.
func _exit_tree() -> void:
	if main_screen:
		main_screen.queue_free()
#endregion


#region Editor Screen Properties
## Confirms that the plugin uses the main screen.
func _has_main_screen() -> bool:
	return true


## Toggles the visibility of the main plugin screen.
func _make_visible(visible: bool) -> void:
	if main_screen:
		main_screen.visible = visible


## Returns the display name of the plugin.
func _get_plugin_name() -> String:
	return tr("RPG Dialog Manager")


## Returns the icon used for the plugin tab.
func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon(&"RichTextLabel", &"EditorIcons")
#endregion
