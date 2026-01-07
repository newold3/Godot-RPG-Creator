@tool
extends Node

## Displays a startup warning regarding the usage of the User_Content folder.
## Uses ProjectSettings to persist the user's preference.

const SETTING_PATH: String = "godot_rpg_creator/interface/show_startup_warning"
const USER_SAFE_FOLDER: String = "UserContents"
const BLOCKING_GROUP: String = "startup_blocking_window"

var _dialog: AcceptDialog
var _checkbox: CheckBox
var _has_shown: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return

	if _has_shown:
		return

	# Wait briefly to ensure the editor interface is fully loaded
	await get_tree().create_timer(1.5).timeout
	
	if not is_instance_valid(self) or not is_inside_tree(): return

	if _has_shown:
		return

	if not ProjectSettings.has_setting(SETTING_PATH):
		ProjectSettings.set_setting(SETTING_PATH, true)
		ProjectSettings.set_initial_value(SETTING_PATH, true)
		ProjectSettings.add_property_info({
			"name": SETTING_PATH,
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Show the safe folder warning at startup"
		})
	
	_check_and_show()


func _check_and_show() -> void:
	_has_shown = true
	
	var show_warning = ProjectSettings.get_setting(SETTING_PATH)
	
	if not show_warning:
		return
	
	_create_ui()


func _create_ui() -> void:
	if _dialog:
		_dialog.queue_free()
		
	_dialog = AcceptDialog.new()
	_dialog.title = "⚠️ IMPORTANT WARNING (ALPHA)"
	_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	_dialog.min_size = Vector2(520, 300)
	
	_dialog.add_to_group(BLOCKING_GROUP)
	
	_dialog.exclusive = false
	_dialog.transient = true 
	
	var vbox = VBoxContainer.new()
	_dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Welcome to Godot RPG Creator!\n\n" + \
	"GOLDEN RULE FOR UPDATES:\n" + \
	"This project is updated frequently via Git, overwriting core files.\n\n" + \
	"Please save ALL your custom files (Scripts, Scenes, Assets)\n" + \
	"inside the designated safe folder:\n\n" + \
	"📂 res://%s/\n\n" % USER_SAFE_FOLDER + \
	"Any file modified outside this folder WILL BE RESET in the next update."
	
	label.custom_minimum_size.x = 480
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)
	
	vbox.add_child(HSeparator.new())
	
	_checkbox = CheckBox.new()
	_checkbox.text = "Do not show this warning again"
	vbox.add_child(_checkbox)
	
	_dialog.confirmed.connect(_on_dialog_confirmed)
	_dialog.canceled.connect(_cleanup_ui) 
	_dialog.close_requested.connect(_cleanup_ui)
	
	add_child(_dialog)
	_dialog.popup_centered()


func _on_dialog_confirmed() -> void:
	if _checkbox.button_pressed:
		ProjectSettings.set_setting(SETTING_PATH, false)
		var err = ProjectSettings.save()
		if err != OK:
			printerr("Error saving project settings: ", err)
		else:
			print("Startup warning disabled in Project Settings.")
	
	_cleanup_ui()


func _cleanup_ui() -> void:
	if _dialog:
		if _dialog.is_in_group(BLOCKING_GROUP):
			_dialog.remove_from_group(BLOCKING_GROUP)
		_dialog.queue_free()
		_dialog = null
