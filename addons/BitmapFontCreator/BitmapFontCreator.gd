@tool
extends EditorPlugin

var bitmap_font_button: Button



## Initializes the plugin and creates the menu button
func _enter_tree() -> void:
	_create_button()



## Cleans up the plugin when disabled or removed
func _exit_tree() -> void:
	if bitmap_font_button:
		RPGMenuAPI.remove_menu_item(bitmap_font_button)
		bitmap_font_button.queue_free()



## Creates and configures the Bitmap Font Creator button
func _create_button() -> void:
	bitmap_font_button = Button.new()
	bitmap_font_button.icon = preload("uid://bhxg5lxu1rqv")
	bitmap_font_button.name = "BitmapFontButton"
	bitmap_font_button.text = "Open Bitmap Font Creator"
	bitmap_font_button.pressed.connect(_on_bitmap_font_button_pressed, CONNECT_DEFERRED)
	bitmap_font_button.theme = load("res://addons/CustomControls/Resources/Themes/editor_buitton_themes.tres")
	bitmap_font_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bitmap_font_button.tooltip_text = "[title]Open Bitmap Font Creator[/title]\nCreate and edit custom bitmap fonts for your game"
	
	RPGMenuAPI.add_menu_item(bitmap_font_button)
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(bitmap_font_button)



## Handles the button press to open the main dialog
func _on_bitmap_font_button_pressed() -> void:
	var path = "res://addons/BitmapFontCreator/bitmap_font_creator_dialog.tscn"
	
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
