@tool
extends Node

## Displays a startup warning regarding the usage of the UserContents folder.
## Remains dormant after the first check to prevent editor crashes.

const CONFIG_PATH: String = "user://startup_warning.cfg"
const SETTING_PATH: String = "godot_rpg_creator/interface/show_startup_warning"
const USER_SAFE_FOLDER: String = "UserContents"

var _dialog: AcceptDialog
var _checkbox: CheckBox
# Flag to prevent the popup from appearing multiple times in the same session (e.g. when opening settings)
var _has_shown: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return

	# If we already showed the warning this session, do nothing.
	if _has_shown:
		return

	# Wait for editor to stabilize
	await get_tree().create_timer(1.5).timeout
	
	# Double check after the timer (in case script reloaded)
	if _has_shown: return

	# Ensure the setting exists
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
	# Mark as shown immediately to prevent loops
	_has_shown = true
	
	# 1. Check Project Settings
	var show_by_settings = ProjectSettings.get_setting(SETTING_PATH)
	if not show_by_settings:
		return
	
	# 2. Check User Preference
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		var dont_show_again = config.get_value("general", "dont_show_again", false)
		if dont_show_again:
			return
	
	_create_ui()


func _create_ui() -> void:
	# Safety cleanup if a dialog was left over
	if _dialog:
		_dialog.queue_free()
		
	_dialog = AcceptDialog.new()
	_dialog.title = "⚠️ IMPORTANT WARNING (ALPHA)"
	_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	_dialog.min_size = Vector2(520, 300)
	
	# Non-exclusive to prevent conflicts with other editor windows
	_dialog.exclusive = false
	_dialog.transient = true 
	
	var vbox = VBoxContainer.new()
	_dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Welcome to Godot RPG Creator!\n\n" + \
	"GOLDEN RULE FOR UPDATES:\n" + \
	"This project is updated frequently, overwriting core files.\n\n" + \
	"Please save ALL your custom files (Scripts, Scenes, Assets)\n" + \
	"inside the designated safe folder:\n\n" + \
	"📂 res://%s/\n\n" % USER_SAFE_FOLDER + \
	"Any file modified outside this folder may be deleted or\n" + \
	"reset in the next update."
	
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
	var config = ConfigFile.new()
	config.set_value("general", "dont_show_again", _checkbox.button_pressed)
	config.save(CONFIG_PATH)
	
	_cleanup_ui()


func _cleanup_ui() -> void:
	# Only delete the dialog, NOT the main node (to avoid crashes)
	if _dialog:
		_dialog.queue_free()
		_dialog = null
