@tool
extends Control

# To add other commands follow this:

# - Get next available command code and next available button name in "res://addons/CustomControls/Dialogs/event_commands_dialog.tscn"
# - Add to Enum "res://addons/CustomControls/custom_edit_item_list.tscn"
# - Map in Dictionary "res://addons/CustomControls/code_script.gd"
# - Add Formatting "res://addons/CustomControls/formatter.gd"
# - Create Dialog Scene for this comnmand
# - Create manager function in the Interpreter
# - Optional: Add logic to "_show_dialog_command" function of this script


## Main theme for the editor
@export var main_theme: Theme

## Reference to the code script
@export var code_script: Node

## Triggers code retrieval
@export_tool_button("Get Available Code")
var available_code:
	get:
		return func():
			if code_script:
				print("Available Code = ", code_script.get_available_code())


static var event_commands_dialog: Dictionary

var current_parent
var current_data: Array[RPGEventCommand]
var current_indent: int
var current_index: int
var current_search_index: int
var busy1: bool = false
var busy2: bool = false
var busy3: bool = false
var filter_delay_timer: float = 0.0
var fix_ignore_commands_timer: float = 0.0
var command_codes: Dictionary

@onready var right_menu: PopupMenu = %RightMenu

signal data_changed()



## Called when the node enters the scene tree for the first time
func _ready() -> void:
	%FavoriteButtonContainer.create_command_requested.connect(_on_create_new_command)
	%EventListContainer.get_h_scroll_bar().value_changed.connect(_on_event_list_container_scroll)
	%EventListContainer.get_v_scroll_bar().value_changed.connect(_on_event_list_container_scroll)
	%EventListContainer.get_h_scroll_bar().z_index = 5
	%EventListContainer.get_h_scroll_bar().z_as_relative = false
	%EventListContainer.get_v_scroll_bar().z_as_relative = false
	%EventPageList.items_dropped.connect(_on_event_page_list_items_dropped)
	var btn = get_node_or_null("%CollabsableCommands")
	if btn:
		btn.toggled.connect(_on_collabsable_commands_toggled.bind(btn))
	update_theme()
	visibility_changed.connect(func(): if visible: recharge_code_script())
	tree_entered.connect(recharge_code_script)
	recharge_code_script()
	_fill_favorite_buttons()



## Fills the favorite buttons container
func _fill_favorite_buttons() -> void:
	%FavoriteButtonContainer.fill()



## Recharges the code script data
func recharge_code_script() -> void:
	if code_script:
		command_codes = code_script.command_codes
	_on_favorite_button_container_item_rect_changed()



## Returns the selected items array directly querying the real metadata
func get_selected_items() -> PackedInt32Array:
	return %EventPageList.get_real_selected_items()



## Triggers a redraw when scrolling
func _on_event_list_container_scroll(_value: float) -> void:
	%EventPageList.queue_redraw()



## Sets the current parent node
func set_current_parent(parent: Node) -> void:
	current_parent = parent



## Updates the editor visual theme
func update_theme() -> void:
	if main_theme:
		var node = %EventPageList
		node.odd_line_color = main_theme.get_color("odd_line_color", "EventEditor")
		node.event_line_color = main_theme.get_color("event_line_color", "EventEditor")
		node.text_selected_color = main_theme.get_color("text_selected_color", "EventEditor")
		node.enabled_action_cursor_texture = main_theme.get_stylebox("enabled_action_cursor_texture", "EventEditor")
		node.no_editable_cursor_texture = main_theme.get_stylebox("no_editable_cursor_texture", "EventEditor")
		node.disabled_action_cursor = main_theme.get_stylebox("disabled_action_cursor", "EventEditor")
		var color_list = main_theme.get_color_list("Parameters")
		var color_theme = {}
		for id in color_list:
			color_theme[id] = main_theme.get_color(id, "Parameters").to_html()
		node.color_theme = color_theme



## Updates current data to the item list
func update_data() -> void:
	%EventPageList.set_data(current_data)
	if not busy2:
		%EventPageList.select_real_index(current_index)



## Sets the initial data for the editor
func set_data(_data) -> void:
	update_theme()
	current_data = _data
	%EventPageList.set_data(current_data)



## Checks if the event code at index is editable
func can_edit_event(index: int) -> bool:
	if current_data.size() > index:
		return current_data[index].code in %EventPageList.EDITABLE_CODES
	else:
		return false



## Checks if the event code at index is marked as no editable
func is_not_editable_event(index: int) -> bool:
	return current_data[index].code in %EventPageList.NO_EDITABLE_CODES



## Checks if any selected item is parent of the specified command
func item_has_parent_selected(indexes: PackedInt32Array, command: RPGEventCommand, index: int) -> bool:
	var parent_code: int
	var indent = command.indent
	match command.code:
		3: parent_code = 2
	for i in range(indexes.size() - 1, -1, -1):
		if indexes[i] > index: continue
		var other: RPGEventCommand = current_data[i]
		if other.parent_code == parent_code and other.indent == indent:
			return true
	return false



## Event triggered when a line is activated
func _on_event_page_list_item_activated(visual_index: int, force_edit: bool = false) -> void:
	if busy2:
		return
	var item_list = %EventPageList
	var meta = item_list.get_item_metadata(visual_index) if visual_index >= 0 and visual_index < item_list.get_item_count() else null
	if meta == null:
		return
	var mapped_index = meta
	var indexes = get_selected_items()
	if indexes.size() > 0:
		for i in indexes:
			if can_edit_event(i) or is_not_editable_event(i):
				mapped_index = i
				break
	current_index = mapped_index
	item_list.select_real_index(mapped_index, true)
	var list = current_data
	if (not can_edit_event(mapped_index) or not item_list.item_has_parent_selected(list[mapped_index])):
		if not is_not_editable_event(mapped_index):
			return
	if Input.is_key_pressed(KEY_SPACE) or force_edit:
		if can_edit_event(mapped_index):
			edit_event(mapped_index, current_data[mapped_index])
		return
	if !current_parent:
		current_parent = get_tree().get_nodes_in_group("main_database")[0]
	if !event_commands_dialog.has(current_parent):
		var path: String = "res://addons/CustomControls/Dialogs/event_commands_dialog.tscn"
		event_commands_dialog[current_parent] = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		event_commands_dialog[current_parent].request_command_created.connect(_on_create_new_command)
		event_commands_dialog[current_parent].request_update_favorite_buttons.connect(_fill_favorite_buttons)
	else:
		RPGDialogFunctions.show_dialog(event_commands_dialog[current_parent])
	if current_data.size() > mapped_index:
		current_indent = current_data[mapped_index].indent
	else:
		current_indent = 0



## Gets a list of commands starting from a given index
func get_command_list_from(index: int, command: RPGEventCommand) -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand]
	commands.append(command)
	var indexes = %EventPageList.get_selection_from_command(command, index, current_data)
	for id in indexes:
		commands.append(current_data[id])
	return commands



## Opens the edit dialog for an specific event command
func edit_event(index: int, command: RPGEventCommand) -> void:
	if command.code == 0:
		return
	if is_not_editable_event(index):
		return
	current_parent = RPGDialogFunctions.current_opened_dialogs[0]
	var info: Dictionary
	for key in command_codes:
		if command_codes[key].command_code == command.code:
			info = command_codes[key]
			break
	var data = {
		"commands": get_command_list_from(index, command),
		"command_code": info.get("command_code", 0),
		"dialog": info.get("dialog", "")
	}
	_show_dialog_command(current_parent, data, true)



## Creates a new command
func _on_create_new_command(button_code: int, from_dialog: Window = null) -> void:
	if not %EventPageList.is_anything_selected():
		current_index = %EventPageList.data.size() - 1
		current_search_index = current_index
		%EventPageList.select_real_index(current_index)
		%EventListContainer.scroll_vertical = %EventListContainer.get_v_scroll_bar().max_value
	var code_info = command_codes.get(button_code, {"command_code": button_code, "dialog": ""})
	_show_dialog_command(from_dialog, code_info)



## Inserts a new command into the data array
func _insert_command(command: RPGEventCommand, index: int = -1) -> void:
	if index == -1: index = current_index
	if _is_parent_disabled(command, index):
		command.ignore_command = true
	current_data.insert(index, command)
	call_deferred("_fix_command_ignore", [command])



## Creates multiple commands from a list
func _create_command(command_list: Array[RPGEventCommand]) -> void:
	for command: RPGEventCommand in command_list:
		_insert_command(command)
	update_data()



## Edits an existing command list
func _edit_command(command_list: Array[RPGEventCommand]) -> void:
	var indexes = get_selected_items()
	var bak_index = current_index
	_on_event_page_list_delete_pressed(indexes, false, true)
	current_index = bak_index
	_create_command(command_list)



## Returns a default initialized command for the given code
func _get_default_command(command_code: int) -> Array[RPGEventCommand]:
	var default_command: Array[RPGEventCommand] = []
	var command = RPGEventCommand.new()
	command.code = command_code
	command.indent = current_indent
	default_command.append(command)
	return default_command



## Shows the appropriate dialog depending on the command selected
func _show_dialog_command(parent: Window, data: Dictionary, edit_mode: bool = false) -> void:
	var command_code = data.command_code
	var cancel_dialog = false
	match command_code:
		24:
			_create_command_start_loop()
		28:
			if !edit_mode:
				_show_select_common_event_dialog(parent)
			else:
				var id = 2 if !data.commands else data.commands[0].parameters.get("id", 2)
				_show_select_common_event_dialog(parent, id, true)
		29:
			if !edit_mode:
				_show_select_set_label_dialog(parent)
			else:
				var text = "" if !data.commands else data.commands[0].parameters.get("text", "")
				_show_select_set_label_dialog(parent, text, true)
		57:
			if !edit_mode:
				_show_movement_route_dialog(parent, RPGMovementRoute.new(), false)
			else:
				var movement_route = RPGMovementRoute.new()
				movement_route.target = data.commands[0].parameters.get("target", 0)
				movement_route.repeat = data.commands[0].parameters.get("loop", true)
				movement_route.skippable = data.commands[0].parameters.get("skippable", false)
				movement_route.wait = data.commands[0].parameters.get("wait", false)
				for i in range(1, data.commands.size(), 1):
					movement_route.list.append(data.commands[i].parameters.get("movement_command", RPGMovementCommand.new()))
				_show_movement_route_dialog(parent, movement_route, true)
		26, 27, 85, 86, 91, 94, 95, 99, 100, 101, 102, 200, 201:
			_create_simple_command(command_code)
		_:
			if command_code == 0:
				return
			var path = "res://addons/CustomControls/Dialogs/CommandEvents/%s.tscn" % data.dialog
			if data.dialog == "select_sound_dialog":
				path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
			if !ResourceLoader.exists(path):
				printerr("⚠️ The dialog to manage this control does not exist (path: %s, button_code: %s)" % [path, data.command_code])
				return
			var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
			var parameters = data.get("commands", _get_default_command(command_code))
			if command_code == 2:
				var current_dialog_config = get_current_dialog_config(data)
				var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
				if edited_scene and edited_scene is RPGMap:
					dialog.set_events(edited_scene.events.get_events())
				dialog.set_main_config(current_dialog_config)
			elif command_code == 10:
				dialog.set_scroll_mode_dialog()
			elif command_code == 30:
				dialog.fill_labels(current_data)
				dialog.force_emit = true
				dialog.title = TranslationManager.tr("Jump To Label")
			elif command_code == 31:
				dialog.title = TranslationManager.tr("Comment")
			elif command_code == 34:
				dialog.set_instant_text_mode_dialog()
			elif command_code == 37:
				dialog.title = TranslationManager.tr("Change HP")
				dialog.parameter_code = command_code
			elif command_code == 38:
				dialog.title = TranslationManager.tr("Change MP")
				dialog.parameter_code = command_code
			elif command_code == 39:
				dialog.title = TranslationManager.tr("Change TP")
				dialog.parameter_code = command_code
			elif command_code == 42:
				dialog.title = TranslationManager.tr("Change Experience")
				dialog.setup_experience_mode()
				dialog.parameter_code = command_code
			elif command_code == 43:
				dialog.title = TranslationManager.tr("Change Level")
				dialog.parameter_code = command_code
			elif command_code == 44:
				dialog.title = TranslationManager.tr("Change Parameter")
				dialog.parameter_code = command_code
				dialog.show_parameter_control()
			elif command_code == 53:
				var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
				if edited_scene and edited_scene is RPGMap:
					dialog.current_map_id = edited_scene.internal_id
				var p = parameters[0].parameters
				if !p.has("target"):
					parameters[0].parameters.target = data.get("target", 0)
				if parameters[0].parameters.target == 0:
					dialog.title = TranslationManager.tr("Transfer Player")
				elif parameters[0].parameters.target == 1:
					dialog.title = TranslationManager.tr("Transfer Vehicle")
				elif parameters[0].parameters.target == 2:
					dialog.title = TranslationManager.tr("Transfer Event")
					if edited_scene and edited_scene is RPGMap:
						dialog.set_events(edited_scene.events.get_events())
						var current_event: RPGEvent = edited_scene.current_event
						if current_event:
							dialog.title += ": %s: %s" % [current_event.id, current_event.name]
			elif command_code == 63:
				dialog.title = TranslationManager.tr("Fade Out")
				dialog.parameter_code = 63
			elif command_code == 64:
				dialog.title = TranslationManager.tr("Fade In")
				dialog.parameter_code = 64
			elif command_code == 65:
				dialog.title = TranslationManager.tr("Tint Screen Color")
				dialog.parameter_code = 65
			elif command_code == 66:
				dialog.title = TranslationManager.tr("Flash Color")
				dialog.parameter_code = 66
			elif command_code == 72 or command_code == 73:
				var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
				if edited_scene and edited_scene is RPGMap:
					dialog.current_event = edited_scene.current_event
					dialog.set_targets(edited_scene.events.get_events())
			elif command_code == 83:
				dialog.title = tr("Play BGM Audio")
				dialog.enable_random_pitch(false)
				dialog.enable_fade_in(true)
				dialog.parameter_code = 83
			elif command_code == 84:
				dialog.title = tr("Stop BGM")
				dialog.parameter_code = 84
				dialog.show_local_container(false)
				dialog.set_parameter_name("Fade Out", "[title]Fade Out Duration[/title]Sound fade-out duration")
				dialog.set_min_value(0)
			elif command_code == 87:
				dialog.title = tr("Play BGS Audio")
				dialog.parameter_code = 87
				dialog.enable_random_pitch(false)
				dialog.enable_fade_in(true)
			elif command_code == 88:
				dialog.title = tr("Stop BGS")
				dialog.parameter_code = 88
				dialog.show_local_container(false)
				dialog.set_parameter_name("Fade Out", "[title]Fade Out Duration[/title]Sound fade-out duration")
				dialog.set_min_value(0)
			elif command_code == 89:
				dialog.title = tr("Play ME Audio")
				dialog.enable_random_pitch(false)
				dialog.enable_fade_in(false)
				dialog.parameter_code = 89
			elif command_code == 90:
				dialog.title = tr("Play SE Audio")
				dialog.enable_random_pitch(true)
				dialog.enable_fade_in(false)
				dialog.parameter_code = 90
			elif command_code == 93:
				dialog.title = tr("Stop Video")
				dialog.parameter_code = 93
				dialog.show_local_container(false)
				dialog.set_parameter_name("Fade Out", "[title]Fade Out Duration[/title]Video fade-out duration")
				dialog.set_min_value(0)
			elif command_code == 103:
				dialog.set_info(tr("Change map name Display"), tr("Display Name:"))
				dialog.title = tr("Change map name Display")
				dialog.parameter_code = 103
			elif command_code == 104:
				dialog.set_info(tr("Select Battle Background"), tr("Background:"), 104, PackedStringArray(["images", "battle_background_scenes"]))
			elif command_code == 105:
				dialog.set_info(tr("Select Map Parallax"), tr("Parallax:"), 105, PackedStringArray(["images", "MapParallaxScene"]))
			elif command_code == 110:
				dialog.title = tr("Select Battle BGM")
				dialog.parameter_code = 110
				dialog.enable_random_pitch(false)
			elif command_code == 111:
				dialog.title = tr("Select Victory ME")
				dialog.parameter_code = 111
				dialog.enable_random_pitch(false)
			elif command_code == 112:
				dialog.title = tr("Select Defeat ME")
				dialog.parameter_code = 112
				dialog.enable_random_pitch(false)
			elif command_code == 113:
				dialog.set_info(tr("Change Save Access"), tr("Save Access:"))
				dialog.title = tr("Change Save Access")
				dialog.parameter_code = 113
			elif command_code == 114:
				dialog.set_info(tr("Change Menu Access"), tr("Menu Access:"))
				dialog.title = tr("Change Menu Access")
				dialog.parameter_code = 114
			elif command_code == 115:
				dialog.title = "Change Encounter Rate"
				dialog.parameter_code = 115
				dialog.default_value = 100
				dialog.set_suffix(" %")
				dialog.set_min_max_values(0, 1000, 0.1)
			elif command_code == 116:
				dialog.set_info(tr("Change Formation Access"), tr("Formation Access:"))
				dialog.title = tr("Change Formation Access")
				dialog.parameter_code = 116
			elif command_code == 117:
				dialog.title = "Change Game Speed"
				dialog.parameter_code = 117
				dialog.default_value = 1
				dialog.set_min_max_values(0.1, 3.5, 0.01)
			elif command_code == 118:
				dialog.parameter_code = 118
				dialog.dialog_type = 1
				dialog.enable_actor()
			elif command_code == 119:
				dialog.parameter_code = 119
				dialog.dialog_type = 0
				dialog.enable_vehicle()
			elif command_code == 121:
				dialog.title = tr("Select Vehicle BGM")
				dialog.parameter_code = 121
				dialog.enable_random_pitch(false)
			elif command_code == 210:
				dialog.set_info(tr("Toggle Auto-Save"), tr("Auto-Save:"))
				dialog.title = tr("Toggle Auto-Save")
				dialog.parameter_code = 210
			elif command_code == 211:
				dialog.select(true)
				dialog.set_info(tr("Change Post-Battle Summary"), tr("Post-Battle Summary:"))
				dialog.title = tr("Post-Battle Summary")
				dialog.parameter_code = 211
			dialog.set_parameters(parameters)
			if !edit_mode:
				dialog.command_changed.connect(
					func(x):
						if parent:
							parent.hide()
				)
				dialog.command_changed.connect(_create_command)
			elif command_code in %EventPageList.EDITABLE_CODES:
				dialog.command_changed.connect(_edit_command)



## Retrieves any required configuration inside a dialog from command info
func get_current_dialog_config(data: Dictionary) -> Dictionary:
	if !"commands" in data:
		return {}
	var dialog_config = {}
	var main_dialog_command: RPGEventCommand = data.commands[0]
	for i: int in range(0, current_data.size(), 1):
		if current_data[i] == main_dialog_command:
			break
		if current_data[i].indent <= main_dialog_command.indent and current_data[i].code == 1:
			dialog_config = current_data[i].parameters
	return dialog_config



## Spawns the required loop commands
func _create_command_start_loop() -> void:
	var dialog = RPGDialogFunctions.get_current_dialog()
	if dialog and dialog.is_in_group("event_command_dialog"): dialog.hide()
	var command = RPGEventCommand.new()
	command.code = 25
	command.indent = current_indent
	_insert_command(command)
	command = RPGEventCommand.new()
	command.code = 0
	command.indent = current_indent + 1
	_insert_command(command)
	command = RPGEventCommand.new()
	command.code = 24
	command.indent = current_indent
	_insert_command(command)
	update_data()



## Opens the common event select dialog
func _show_select_common_event_dialog(parent: Window, id: int = 1, edit_mode: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	dialog.destroy_on_hide = true
	var real_id = RPGSYSTEM.uid_to_id("common_events", id)
	dialog.setup(RPGSYSTEM.database.common_events, id, "Common Events", null)
	if !edit_mode:
		dialog.selected.connect(func(x, y): parent.hide())
		dialog.selected.connect(_create_command_select_common_dialog)
	else:
		dialog.selected.connect(_edit_command_select_common_dialog)



## Inserts a new command pointing to a common event
func _create_command_select_common_dialog(id: int, target) -> void:
	var command = RPGEventCommand.new()
	command.code = 28
	command.indent = current_indent
	var real_id = RPGSYSTEM.id_to_uid("common_events", id)
	command.parameters.id = id
	_insert_command(command)
	update_data()



## Edits a command pointing to a common event
func _edit_command_select_common_dialog(id: int, target) -> void:
	var indexes = get_selected_items()
	var bak_index = current_index
	_on_event_page_list_delete_pressed(indexes, false, true)
	current_index = bak_index
	_create_command_select_common_dialog(id, null)



## Shows the set label text dialog
func _show_select_set_label_dialog(parent: Window, text: String = "", edit_mode: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_text(text)
	dialog.force_emit = true
	dialog.title = TranslationManager.tr("Label")
	if !edit_mode:
		dialog.text_selected.connect(func(x): parent.hide())
		dialog.text_selected.connect(_create_command_set_label_dialog)
	else:
		dialog.text_selected.connect(_edit_command_set_label_dialog)



## Inserts the set label command
func _create_command_set_label_dialog(text: String) -> void:
	var command = RPGEventCommand.new()
	command.code = 29
	command.indent = current_indent
	command.parameters.text = text.strip_edges()
	_insert_command(command)
	update_data()



## Edits the set label command
func _edit_command_set_label_dialog(text: String) -> void:
	var indexes = get_selected_items()
	var bak_index = current_index
	_on_event_page_list_delete_pressed(indexes, false, true)
	current_index = bak_index
	_create_command_set_label_dialog(text)



## Shows movement route parameters dialog
func _show_movement_route_dialog(parent: Window, movement_route: RPGMovementRoute, edit_mode: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/movement_route_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var current_page: RPGEventPage = RPGEventPage.new()
	current_page.movement_route = movement_route.clone(true)
	dialog.set_current_page(current_page)
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene is RPGMap:
		dialog.current_event = edited_scene.current_event
		dialog.set_targets(edited_scene.events.get_events())
	if !edit_mode:
		dialog.apply.connect(
			func(x):
				if parent:
					parent.hide()
		)
		dialog.apply.connect(_create_movement_route_dialog)
	else:
		dialog.apply.connect(_edit_movement_route_dialog)



## Inserts all elements for a movement route
func _create_movement_route_dialog(movement_route: RPGMovementRoute) -> void:
	for i in range(movement_route.list.size() - 1, -1, -1):
		var command = RPGEventCommand.new()
		command.code = 58
		command.indent = current_indent
		command.parameters.movement_command = movement_route.list[i]
		_insert_command(command)
	var command = RPGEventCommand.new()
	command.code = 57
	command.indent = current_indent
	command.parameters.target = movement_route.target
	command.parameters.loop = movement_route.repeat
	command.parameters.skippable = movement_route.skippable
	command.parameters.wait = movement_route.wait
	_insert_command(command)
	update_data()



## Edits all elements corresponding to a movement route
func _edit_movement_route_dialog(movement_route: RPGMovementRoute) -> void:
	var indexes = get_selected_items()
	var bak_index = current_index
	_on_event_page_list_delete_pressed(indexes, false, true)
	current_index = bak_index
	_create_movement_route_dialog(movement_route)



## Creates simple command directly into the event line
func _create_simple_command(code: int) -> void:
	var dialog = RPGDialogFunctions.get_current_dialog()
	if dialog and dialog.is_in_group("event_command_dialog"): dialog.hide()
	var command = RPGEventCommand.new()
	command.code = code
	command.indent = current_indent
	_insert_command(command)
	update_data()



## Open Blacksmith Shop system function
func _create_command_open_blacksmith_shop() -> void:
	var dialog = RPGDialogFunctions.get_current_dialog()
	if dialog and dialog.is_in_group("event_command_dialog"): dialog.hide()
	var command = RPGEventCommand.new()
	command.code = 200
	command.indent = current_indent
	_insert_command(command)
	update_data()



## Detects if an item ends a parent command
func is_end_command(index: int) -> bool:
	var list = current_data
	var is_end: bool = false
	if index < list.size() - 1:
		if list[index + 1].code in [5, 6, 7, 22, 23, 25]:
			is_end = true
	return is_end



## Compiles the fully expanded hierarchical block based on selected indices for reliable copy/cut mapping
func _get_full_expanded_selection(indexes: PackedInt32Array) -> Array[int]:
	var full_indexes: Array[int] = []
	for idx in indexes:
		if not full_indexes.has(idx):
			full_indexes.append(idx)
		var children = %EventPageList.get_selection_from_command(current_data[idx], idx, current_data)
		for child in children:
			if not full_indexes.has(child):
				full_indexes.append(child)
	full_indexes.sort()
	return full_indexes



## Copies the selected itemlist to editor clipboard securely traversing the structural block logic
func _on_event_page_list_copy_requested(indexes: PackedInt32Array) -> void:

	var list = current_data

	if indexes.is_empty() or list.is_empty(): return

	var valid_indexes = PackedInt32Array()
	for idx in indexes:
		if list[idx].code != 0:
			valid_indexes.append(idx)
			
	if valid_indexes.is_empty(): return
	if list[valid_indexes[0]].code in %EventPageList.SUB_CODES: return

	var copy_event_commands: Array[RPGEventCommand] = []
	var full_indexes = _get_full_expanded_selection(valid_indexes)

	if full_indexes.size() == 0: return

	for index in full_indexes:
		if index >= list.size() - 1 and list[index].code == 0: continue
		copy_event_commands.append(list[index].clone(true))

	if copy_event_commands.size() == 0: return

	StaticEditorVars.CLIPBOARD["event_page_commands"] = copy_event_commands


## Cuts the selected itemlist securely traversing the structural block and copies to editor clipboard
func _on_event_page_list_cut_requested(indexes: PackedInt32Array) -> void:

	var list = current_data

	if indexes.is_empty() or list.is_empty(): return

	var valid_indexes = PackedInt32Array()
	for idx in indexes:
		if list[idx].code != 0:
			valid_indexes.append(idx)
			
	if valid_indexes.is_empty(): return
	if list[valid_indexes[0]].code in %EventPageList.SUB_CODES: return

	var copy_event_commands: Array[RPGEventCommand] = []
	var remove_event_commands: Array[RPGEventCommand] = []
	var full_indexes = _get_full_expanded_selection(valid_indexes)

	if full_indexes.size() == 0: return

	for index in full_indexes:
		if index >= list.size() - 1 and list[index].code == 0: continue
		copy_event_commands.append(list[index].clone(true))
		remove_event_commands.append(list[index])

	if copy_event_commands.size() == 0: return

	if remove_event_commands.size() > 0: data_changed.emit()

	for item in remove_event_commands:
		list.erase(item)

	_cleanup_zeros()

	StaticEditorVars.CLIPBOARD["event_page_commands"] = copy_event_commands
	current_index = max(0, min(current_index, list.size() - 1))
	update_data()


## Evaluates delete logic and securely clears out targeted blocks including all active sub-children elements
func _on_event_page_list_delete_pressed(indexes: PackedInt32Array, need_scan_indexes: bool = true, remove_all_indexes: bool = false) -> void:

	var event_list = %EventPageList
	var list = current_data

	if indexes.is_empty() or list.is_empty(): return

	var valid_indexes = PackedInt32Array()
	for idx in indexes:
		if list[idx].code != 0:
			valid_indexes.append(idx)
			
	if valid_indexes.is_empty(): return
	if need_scan_indexes and list[valid_indexes[0]].code in %EventPageList.SUB_CODES: return

	var remove_comands = []
	var bak_index = current_index
	current_index = -1

	if remove_all_indexes:
		for i in valid_indexes:
			if can_edit_event(i) or is_not_editable_event(i):
				if current_index == -1:
					current_index = i
			if i >= list.size() - 1 and list[i].code == 0: continue
			remove_comands.append(list[i])
	else:
		if need_scan_indexes:
			var full_indexes = _get_full_expanded_selection(valid_indexes)
			for i in full_indexes:
				if i >= list.size() - 1 and list[i].code == 0: continue
				if current_index == -1 and (can_edit_event(i) or is_not_editable_event(i)):
					current_index = i
				remove_comands.append(list[i])
		else:
			for i in valid_indexes:
				if i >= list.size() - 1 and list[i].code == 0: continue
				if i > 0 and i < list.size() - 1:
					if (%EventPageList.is_code_editable(list[i - 1].code) or %EventPageList.is_code_editable(list[i + 1].code)):
						remove_comands.append(list[i])
				else:
					remove_comands.append(list[i])

	if remove_comands:
		for command in remove_comands:
			list.erase(command)

		_cleanup_zeros()

		if list.size() == 0 or list[-1].code != 0:
			list.append(RPGEventCommand.new())

		current_index = max(0, min(current_index, list.size() - 1))
		update_data()
		data_changed.emit()
	else:
		current_index = bak_index


## Handles marking commands as ignored in compilation
func _on_event_page_ignore_commands(indexes: PackedInt32Array) -> void:
	var list = current_data
	if indexes.size() == 1 and list[indexes[0]].code == 0: return
	var event_commands: Array[RPGEventCommand]
	var event_list = %EventPageList
	var base_indent = list[indexes[0]].indent
	var previous_states: Dictionary = {}
	for index in indexes:
		if index < list.size():
			previous_states[index] = list[index].ignore_command
	for index in indexes:
		if index >= list.size() - 1 or index < 0:
			continue
		if base_indent > list[index].indent:
			break
		if can_edit_event(index) or event_list.item_has_parent_selected(list[index]) or is_not_editable_event(index):
			event_commands.append(list[index])
	if event_commands.size() > 0:
		for command: RPGEventCommand in event_commands:
			command.ignore_command = !command.ignore_command
		_validate_activated_commands(indexes)
		_ensure_children_ignore_state(indexes, previous_states)
		busy2 = true
		update_data()
		event_list.deselect_all()
		var index = indexes[0]
		for i in range(index, index + indexes.size(), 1):
			event_list.select_real_index(i, false)
		busy2 = false
		event_list.start_reselect()



## Ensures child commands reflect ignore state from parents
func _ensure_children_ignore_state(parent_indexes: PackedInt32Array, previous_states: Dictionary) -> void:
	var list = current_data
	for i in range(parent_indexes.size() - 1, -1, -1):
		var parent_index = parent_indexes[i]
		if parent_index >= list.size():
			continue
		var parent_command = list[parent_index]
		var parent_indent = parent_command.indent
		var previous_state = previous_states.get(parent_index, false)
		var current_state = parent_command.ignore_command
		if current_state == true:
			_deactivate_all_children(parent_index, parent_indent)
		elif previous_state == true and current_state == false:
			_activate_all_children(parent_index, parent_indent)



## Applies ignore property to all descendants
func _deactivate_all_children(parent_index: int, parent_indent: int) -> void:
	var list = current_data
	for child_index in range(parent_index + 1, list.size()):
		var child_command = list[child_index]
		if child_command.indent <= parent_indent:
			break
		child_command.ignore_command = true



## Removes ignore property from all active descendant bounds
func _activate_all_children(parent_index: int, parent_indent: int) -> void:
	var list = current_data
	var parent_command = list[parent_index]
	var closing_index = -1
	var event_list = %EventPageList
	for child_index in range(parent_index + 1, list.size()):
		var child_command = list[child_index]
		if child_command.indent <= parent_indent:
			if child_command.indent == parent_indent:
				var parent_code = event_list.find_parent_code_for_child(child_command.code)
				if parent_code == parent_command.code:
					child_command.ignore_command = false
					closing_index = child_index
			break
		if _are_all_ancestors_active(child_index, child_command.indent):
			child_command.ignore_command = false



## Verifies command is not restricted by disabled ancestor branches
func _are_all_ancestors_active(child_index: int, child_indent: int) -> bool:
	var list = current_data
	for i in range(child_index - 1, -1, -1):
		var command = list[i]
		if command.indent < child_indent:
			if command.ignore_command == true:
				return false
			child_indent = command.indent
			if child_indent == 0:
				return true
	return true



## Enforces disabled commands check on activated items
func _validate_activated_commands(indexes: PackedInt32Array) -> void:
	var list = current_data
	for index in indexes:
		if index >= list.size():
			continue
		var command = list[index]
		if command.ignore_command == false:
			if not _are_all_ancestors_active(index, command.indent):
				command.ignore_command = true



## Quick check for direct disabled parent presence
func _is_parent_disabled(command: RPGEventCommand, command_index: int) -> bool:
	var list = current_data
	if command.indent == 0:
		return false
	var parent_indent = command.indent - 1
	for i in range(command_index - 1, -1, -1):
		var other_command = list[i]
		if other_command.indent == parent_indent:
			return other_command.ignore_command
		elif other_command.indent < parent_indent:
			return false
	return false



## Validates command correct activation internally
func _fix_command_ignore(commands: Array) -> void:
	var command: RPGEventCommand = commands[0]
	if command.ignore_command and not _is_parent_disabled(command, current_data.find(command)):
		command.ignore_command = false



## Fallback to restore potentially buggy command ignorances
func _fix_ignore_commands() -> void:
	return
	var list = current_data
	var event_list = %EventPageList
	for i in range(list.size() - 1, -1, -1):
		var command = list[i]
		if command.ignore_command and not _is_parent_disabled(command, i):
			command.ignore_command = false
		if command.ignore_command:
			var parent_index = event_list.get_item_parent(i, command.indent)
			if parent_index != 0:
				command.ignore_command = list[parent_index].ignore_command



## Receives content from system clipboard and inserts internally
func _on_event_page_list_paste_requested(index: int) -> void:
	var selected_items = get_selected_items()
	if selected_items.is_empty(): return
	index = selected_items[0]
	var list = current_data
	if list.is_empty() or index >= list.size(): return
	if list[index].code in %EventPageList.SUB_CODES: return
	if !can_edit_event(index) and !is_not_editable_event(index):
		return
	var event_list = %EventPageList
	var indexes = []
	if StaticEditorVars.CLIPBOARD.has("event_page_commands"):
		var indent_displacement = (StaticEditorVars.CLIPBOARD["event_page_commands"][0].indent - current_indent)
		for i in StaticEditorVars.CLIPBOARD["event_page_commands"].size():
			var command: RPGEventCommand = StaticEditorVars.CLIPBOARD["event_page_commands"][i].clone()
			command.indent -= indent_displacement
			var real_index = index + i
			if real_index < list.size():
				_insert_command(command, real_index)
				indexes.append(real_index)
			else:
				_insert_command(command, list.size() - 1)
				indexes.append(list.size() - 1)
		data_changed.emit()
	else:
		return
	busy2 = true
	update_data()
	event_list.deselect_all()
	for i in range(index, index + indexes.size(), 1):
		event_list.select_real_index(i, false)
	busy2 = false



## Registers multi item selection process
func _on_event_page_list_multi_selected(visual_index: int, selected: bool) -> void:
	if busy2: return
	var item_list = %EventPageList
	var real_index = item_list.get_item_metadata(visual_index) if visual_index >= 0 and visual_index < item_list.get_item_count() else null
	if real_index == null: return
	if selected:
		current_indent = current_data[real_index].indent
	current_index = real_index
	current_search_index = real_index



## Ensures internal node retrieves focus state on hover
func _on_event_page_list_mouse_entered() -> void:
	if get_viewport().gui_get_focus_owner() != %EventPageList:
		%EventPageList.grab_focus()



## Detects search field cursor transitions and input
func _on_filter_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if %Filter.text.length() > 0:
					if event.position.x >= %Filter.size.x - 22:
						%Filter.text = ""
	elif event is InputEventMouseMotion:
		if event.position.x >= %Filter.size.x - 22:
			%Filter.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			%Filter.mouse_default_cursor_shape = Control.CURSOR_IBEAM



## Initiates item filtering procedure
func update_filter_commands() -> void:

	var filter = %Filter.text.to_lower()

	if filter.length() == 0:
		%EventPageList.deselect_all()
		%EventListContainer.scroll_vertical = 0
		return

	var check_index = current_search_index

	if check_index >= 0 and check_index < %EventPageList.data.size():
		var formatted_data = %EventPageList.data[check_index].formatted_data
		for phrases in formatted_data.phrases:
			var full_text = ""
			for text_data in phrases.texts:
				var text = text_data.text.to_lower()
				full_text += text
				if text.find(filter) != -1:
					current_index = check_index
					_expand_parents_of(check_index)
					%EventPageList.select_real_index(check_index, true)
					return
			if full_text.find(filter) != -1:
				current_index = check_index
				_expand_parents_of(check_index)
				%EventPageList.select_real_index(check_index, true)
				return

	_on_find_next_command_pressed(true, check_index, true)


## Fallback handling for manual inputs missing target
func _input(event: InputEvent) -> void:

	if not is_visible_in_tree():
		return

	if event is InputEventKey and event.is_pressed():
		if event.is_action_pressed("FindPrevious", true):
			get_viewport().set_input_as_handled()
			_on_find_previous_command_pressed()
		elif event.is_action_pressed("FindNext", true):
			get_viewport().set_input_as_handled()
			_on_find_next_command_pressed()



## Searches internally previous event instance
func _on_find_previous_command_pressed(reverse_enabled: bool = true, p_current_index: int = -2, from_filter: bool = false) -> void:

	var filter = %Filter.text.to_lower()

	if filter.length() > 0:
		var check_index = current_search_index if p_current_index == -2 else p_current_index
		for i in range(check_index - 1, -1, -1):
			var formatted_data = %EventPageList.data[i].formatted_data
			for phrases in formatted_data.phrases:
				var full_text = ""
				for text_data in phrases.texts:
					var text = text_data.text.to_lower()
					full_text += text
					if text.find(filter) != -1:
						current_index = i
						_expand_parents_of(i)
						%EventPageList.select_real_index(i, true)
						return
				if full_text.find(filter) != -1:
					current_index = i
					_expand_parents_of(i)
					%EventPageList.select_real_index(i, true)
					return

	if reverse_enabled:
		_on_find_previous_command_pressed(false, %EventPageList.data.size(), from_filter)
	elif from_filter:
		%EventPageList.deselect_all()
		%EventListContainer.scroll_vertical = 0


## Searches internally forward for event instance
func _on_find_next_command_pressed(reverse_enabled: bool = true, p_current_index: int = -2, from_filter: bool = false) -> void:

	var filter = %Filter.text.to_lower()

	if filter.length() > 0:
		var check_index = current_search_index if p_current_index == -2 else p_current_index
		for i in range(check_index + 1, %EventPageList.data.size(), 1):
			var formatted_data = %EventPageList.data[i].formatted_data
			for phrases in formatted_data.phrases:
				var full_text = ""
				for text_data in phrases.texts:
					var text = text_data.text.to_lower()
					full_text += text
					if text.find(filter) != -1:
						current_index = i
						_expand_parents_of(i)
						%EventPageList.select_real_index(i, true)
						return
				if full_text.find(filter) != -1:
					current_index = i
					_expand_parents_of(i)
					%EventPageList.select_real_index(i, true)
					return

	if reverse_enabled:
		_on_find_next_command_pressed(false, -1, from_filter)
	elif from_filter:
		%EventPageList.deselect_all()
		%EventListContainer.scroll_vertical = 0


## Expands all collapsed ancestors of a given index to make it visible
func _expand_parents_of(index: int) -> void:

	var changed = false

	for i in range(index - 1, -1, -1):
		var cmd = current_data[i]
		var selection = %EventPageList._get_block_selection(i, current_data)
		if index in selection:
			if not cmd.is_expanded:
				cmd.is_expanded = true
				changed = true

	if changed:
		update_data()


## Collapses all expandable commands
func _collapse_all_commands() -> void:
	for cmd in current_data:
		var selection = %EventPageList._get_block_selection(current_data.find(cmd), current_data)
		if selection.size() > 0:
			cmd.is_expanded = false
	update_data()
	data_changed.emit()



## Expands all expandable commands
func _expand_all_commands() -> void:
	for cmd in current_data:
		var selection = %EventPageList._get_block_selection(current_data.find(cmd), current_data)
		if selection.size() > 0:
			cmd.is_expanded = true
	update_data()
	data_changed.emit()



## Empty function to be filled later for adding a separator
func _on_add_separator_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/command_separator_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var _parameters: Array[RPGEventCommand] = [RPGEventCommand.new(9999, current_indent)]

	dialog.parameters = _parameters
	
	dialog.set_data()
	
	dialog.command_changed.connect(_create_command)



## Multiples active elements copying and pushing inline
func _on_event_page_list_duplicate_requested(indexes: PackedInt32Array) -> void:
	var list = current_data
	var event_list = %EventPageList
	if indexes.is_empty() or list.is_empty(): return
	if list[indexes[0]].code in %EventPageList.SUB_CODES: return
	var duplicate_event_commands: Array[RPGEventCommand] = []
	var full_indexes = _get_full_expanded_selection(indexes)
	for i in range(full_indexes.size() - 1, -1, -1):
		var index = full_indexes[i]
		if can_edit_event(index) or event_list.item_has_parent_selected(list[index]) or is_not_editable_event(index):
			duplicate_event_commands.append(list[index].clone(true))
	if not duplicate_event_commands.size() > 0:
		return
	var insert_position = indexes[-1] + 1
	for command in duplicate_event_commands:
		list.insert(insert_position, command)
	busy2 = true
	update_data()
	event_list.deselect_all()
	for i in range(insert_position, insert_position + full_indexes.size(), 1):
		event_list.select_real_index(i, false)
	busy2 = false



## Presents the context menu on correct offset
func _on_event_page_list_right_click(visual_index: int, indexes: PackedInt32Array) -> void:
	var mouse_pos = DisplayServer.mouse_get_position()
	var screen_size = DisplayServer.screen_get_size()
	var menu_size = right_menu.size
	var list = current_data
	var p = Vector2i(mouse_pos.x - menu_size.x * 0.5, mouse_pos.y)
	p.x = max(10, min(p.x, screen_size.x - menu_size.x - 10))
	if p.y + menu_size.y > screen_size.y - 10:
		p.y = mouse_pos.y - menu_size.y
		p.y = max(10, p.y)
	else:
		p.y = max(10, p.y)
	var is_invalid_code: bool = indexes.is_empty() or list.is_empty() or not list[indexes[0]].code in %EventPageList.EDITABLE_CODES
	var is_sub_code: bool = not indexes.is_empty() and not list.is_empty() and list[indexes[0]].code in %EventPageList.SUB_CODES
	var has_collapsed = false
	var has_expandable = false
	for i in range(list.size()):
		var cmd = list[i]
		var selection = %EventPageList._get_block_selection(i, list)
		if selection.size() > 0:
			if cmd.is_expanded:
				has_expandable = true
			else:
				has_collapsed = true
	if right_menu.item_count > 16:
		right_menu.set_item_disabled(16, not has_expandable)
	if right_menu.item_count > 17:
		right_menu.set_item_disabled(17, not has_collapsed)
	right_menu.set_item_disabled(0, is_invalid_code)
	right_menu.set_item_disabled(1, is_invalid_code or list[indexes[0]].code == 0)
	right_menu.set_item_disabled(3, is_sub_code)
	right_menu.set_item_disabled(4, is_sub_code)
	right_menu.set_item_disabled(5, is_sub_code)
	right_menu.set_item_disabled(6, is_sub_code or not StaticEditorVars.CLIPBOARD.has("event_page_commands"))
	right_menu.set_item_disabled(7, is_sub_code)
	right_menu.set_item_disabled(9, indexes.size() == 1 and list[indexes[0]].code == 0)
	right_menu.set_item_disabled(11, indexes.size() == 1 and (list[indexes[0]].code == 0 or list[indexes[0]].code in %EventPageList.SUB_CODES))
	right_menu.set_item_disabled(12, list.is_empty() or (list.size() == 1 and list[0].code == 0))
	right_menu.set_meta("items", indexes)
	right_menu.position = p
	right_menu.show()



## Connects context options indexes with specific command logic operations
func _on_right_menu_index_pressed(index: int) -> void:
	var items = right_menu.get_meta("items")
	right_menu.remove_meta("items")
	match index:
		0:
			var v_idx = %EventPageList.get_visual_index(items[0])
			if v_idx != -1: _on_event_page_list_item_activated(v_idx)
		1:
			var v_idx = %EventPageList.get_visual_index(items[0])
			if v_idx != -1: _on_event_page_list_item_activated(v_idx, true)
		3:
			_on_event_page_list_copy_requested(items)
		4:
			_on_event_page_list_cut_requested(items)
		5:
			_on_event_page_list_duplicate_requested(items)
		6:
			_on_event_page_list_paste_requested(items[0])
		7:
			_on_event_page_list_delete_pressed(items)
		9:
			_on_event_page_ignore_commands(items)
		11:
			var full_indexes = _get_full_expanded_selection(items)
			var preview_cmds: Array[RPGEventCommand] = []
			for idx in full_indexes:
				preview_cmds.append(current_data[idx])
			RPGDialogFunctions.preview_commands_in_action(preview_cmds)
		12:
			RPGDialogFunctions.preview_commands_in_action(%EventPageList.get_command_list())
		14:
			_copy_selected_commands_as_json(items)
		16:
			_collapse_all_commands()
		17:
			_expand_all_commands()
		19:
			_on_add_separator_pressed()



## Serializes the currently selected commands into a formatted JSON string and copies it to the system clipboard
func _copy_selected_commands_as_json(indexes: PackedInt32Array) -> void:
	var list = current_data
	if not indexes.is_empty() and not list.is_empty() and list[indexes[0]].code in %EventPageList.SUB_CODES: return
	var export_data: Array = []
	var full_indexes = _get_full_expanded_selection(indexes)
	for index in full_indexes:
		var command = current_data[index]
		var cmd_dict: Dictionary = {
			"code": command.code,
			"parameters": command.parameters
		}
		export_data.append(cmd_dict)
	var json_string: String = JSON.stringify(export_data, "\t")
	DisplayServer.clipboard_set(json_string)



## Recursively appends commands dependencies to form visual groups arrays
func _get_expanded_commands(indexes: PackedInt32Array) -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = []
	var list = current_data
	var full_indexes = _get_full_expanded_selection(indexes)
	for i in full_indexes:
		if i < 0 or i >= list.size(): continue
		var cmd = list[i]
		if not cmd in commands:
			commands.append(cmd)
	commands.sort_custom(func(a, b): return list.find(a) < list.find(b))
	return commands



## Verifies logical blocks validity and resolves position index exchange
func _on_event_page_list_change_position_requested(from: int, to: int, indexes: PackedInt32Array) -> void:
	var list = current_data
	if not indexes.is_empty() and not list.is_empty() and list[indexes[0]].code in %EventPageList.SUB_CODES: return
	var moving_commands = _get_expanded_commands(indexes)
	if moving_commands.is_empty():
		return
	var is_up = to < from
	var base_indent = moving_commands[0].indent
	var first_idx = list.find(moving_commands[0])
	var last_idx = list.find(moving_commands[-1])
	var swap_target_idx = -1
	if is_up:
		for i in range(first_idx - 1, -1, -1):
			if list[i].indent < base_indent:
				return
			if list[i].indent == base_indent and list[i].code != 0 and list[i].code not in %EventPageList.SUB_CODES:
				var sibling_block = _get_expanded_commands(PackedInt32Array([i]))
				swap_target_idx = list.find(sibling_block[0])
				break
	else:
		for i in range(last_idx + 1, list.size()):
			if list[i].indent < base_indent:
				return
			if list[i].indent == base_indent and list[i].code != 0 and list[i].code not in %EventPageList.SUB_CODES:
				var sibling_block = _get_expanded_commands(PackedInt32Array([i]))
				swap_target_idx = list.find(sibling_block[-1]) + 1
				break
	if swap_target_idx != -1:
		_move_data_block(moving_commands, swap_target_idx, base_indent)



## Ensures proper items injection over manual dropping offset
func _on_event_page_list_items_dropped(to_index: int, _new_indent: int, indexes: PackedInt32Array) -> void:
	var list = current_data
	var moving_commands = _get_expanded_commands(indexes)
	if moving_commands.is_empty() or to_index < 0:
		return
	var safe_to_index = min(to_index, list.size() - 1)
	var target_cmd = list[safe_to_index]
	if target_cmd in moving_commands:
		return
	if target_cmd.code in %EventPageList.SUB_CODES:
		return
	_move_data_block(moving_commands, safe_to_index, target_cmd.indent)



## Swaps raw memory blocks respecting logical tree layout
func _move_data_block(moving_commands: Array[RPGEventCommand], target_index: int, target_indent: int) -> void:
	var list = current_data
	var base_indent = moving_commands[0].indent
	var indent_displacement = target_indent - base_indent
	var pre_cut_target_cmd = list[target_index] if target_index < list.size() else null
	for cmd in moving_commands:
		list.erase(cmd)
	var real_insert_pos = list.find(pre_cut_target_cmd) if pre_cut_target_cmd != null else list.size()
	if real_insert_pos == -1:
		real_insert_pos = list.size()
	for i in range(moving_commands.size()):
		var cmd = moving_commands[i]
		cmd.indent = max(0, cmd.indent + indent_displacement)
		list.insert(real_insert_pos + i, cmd)
	_cleanup_zeros()
	busy2 = true
	update_data()
	%EventPageList.deselect_all()
	for cmd in moving_commands:
		var idx = current_data.find(cmd)
		if idx != -1:
			%EventPageList.select_real_index(idx, false)
	busy2 = false
	data_changed.emit()



## Removes orphan zero tags preserving a safe empty end
func _cleanup_zeros() -> void:
	var list = current_data
	for i in range(list.size() - 1, 0, -1):
		if list[i].code == 0 and list[i - 1].code == 0:
			list.remove_at(i)
	if list.is_empty() or list[-1].code != 0:
		var zero_cmd = RPGEventCommand.new()
		zero_cmd.code = 0
		zero_cmd.indent = 0
		list.append(zero_cmd)



## Recursively detects child arrays for drag events
func _get_expanded_movement_block(indexes: PackedInt32Array) -> PackedInt32Array:
	if indexes.is_empty(): 
		return PackedInt32Array()
	var first_cmd = current_data[indexes[0]]
	if first_cmd.code == 0 or first_cmd.code in %EventPageList.SUB_CODES:
		return PackedInt32Array()
	var expanded: Array[int] = []
	var list = current_data
	var sorted_indexes = Array(indexes)
	sorted_indexes.sort()
	for idx in sorted_indexes:
		if idx < 0 or idx >= list.size(): 
			continue
		if list[idx].code == 0 or list[idx].code in %EventPageList.SUB_CODES:
			continue
		if not idx in expanded:
			expanded.append(idx)
			var start_indent = list[idx].indent
			for i in range(idx + 1, list.size()):
				if list[i].indent > start_indent:
					if not i in expanded: 
						expanded.append(i)
				elif list[i].indent == start_indent:
					var parent_code = %EventPageList.find_parent_code_for_child(list[i].code)
					if parent_code != -1 and parent_code == list[idx].code:
						if not i in expanded: 
							expanded.append(i)
						continue
					break
				else:
					break
	expanded.sort()
	return PackedInt32Array(expanded)



## Analyzes drop location relative to list conditions and dependencies
func _resolve_drop_target(target_index: int, moving_block: PackedInt32Array) -> Dictionary:
	var list = current_data
	var insert_pos = clamp(target_index, 0, list.size())
	if insert_pos in moving_block:
		return {"valid": false}
	var prev_cmd: RPGEventCommand = null
	var next_cmd: RPGEventCommand = null
	for i in range(insert_pos - 1, -1, -1):
		if not i in moving_block:
			prev_cmd = list[i]
			break
	for i in range(insert_pos, list.size()):
		if not i in moving_block:
			next_cmd = list[i]
			break
	if prev_cmd == null:
		return {"valid": true, "insert_pos": 0, "indent": 0}
	if next_cmd != null:
		var expected_parent = %EventPageList.find_parent_code_for_child(next_cmd.code)
		if expected_parent != -1 and expected_parent == prev_cmd.code and prev_cmd.indent == next_cmd.indent:
			return {"valid": false}
	var param_struct = %EventPageList.get_param_struct()
	var new_indent = prev_cmd.indent
	if param_struct.has(prev_cmd.code):
		new_indent = prev_cmd.indent + 1
	elif prev_cmd.code == 0:
		if next_cmd != null:
			new_indent = next_cmd.indent
		else:
			new_indent = max(0, prev_cmd.indent - 1)
	return {"valid": true, "insert_pos": insert_pos, "indent": new_indent}



## Frame by frame handler for general visual polling elements and states
func _process(delta: float) -> void:

	if filter_delay_timer > 0.0:
		filter_delay_timer -= delta
		if filter_delay_timer <= 0:
			update_filter_commands()

	if fix_ignore_commands_timer > 0.0:
		fix_ignore_commands_timer -= delta
		if fix_ignore_commands_timer <= 0:
			_fix_ignore_commands()



## Restarts filter typing evaluation timeout
func _on_filter_text_changed(new_text: String) -> void:
	filter_delay_timer = 0.15



## Fast logic to verify component offset bounds validity
func _is_current_sub_code() -> bool:
	var itemlist = %EventPageList
	var indexes = get_selected_items()
	var index = -1
	if indexes.size() > 0:
		index = indexes[0]
	else:
		var items = itemlist.get_item_count()
		if items > 0:
			index = itemlist.get_item_metadata(items - 1)
	if index != -1 and index != null:
		if not itemlist.item_has_parent_selected(current_data[index]):
			return true
	itemlist.select_real_index(index, true)
	return false



## Modifies collapsable command structure logic parameter to toggle
func _on_collabsable_commands_toggled(toggled_on: bool, btn: BaseButton) -> void:
	if not btn: return
	var command = btn.get_meta("command_expanded").command
	command.is_expanded = not toggled_on
	update_data()
	data_changed.emit()
	var real_index = current_data.find(command)
	if real_index != -1:
		%EventPageList.select_real_index(real_index, true)



## Fixes panel layout issues dynamically updating custom dimensions bounds
func _on_favorite_button_container_item_rect_changed() -> void:
	if busy3: return
	busy3 = true
	%FavoriteButtonScrollContainer.custom_minimum_size.y = 0
	%FavoriteButtonScrollContainer.size.y = 0
	if not is_inside_tree(): return
	await get_tree().process_frame
	%FavoriteButtonScrollContainer.size.y = 0
	if not is_inside_tree(): return
	await get_tree().process_frame
	var new_height = min(120, %FavoriteButtonContainer.size.y + 16)
	%FavoriteButtonScrollContainer.custom_minimum_size.y = new_height
	%FavoriteButtonScrollContainer.size.y = new_height
	if not is_inside_tree(): return
	await get_tree().process_frame
	set_deferred("busy3", false)
