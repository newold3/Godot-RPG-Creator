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


@export var main_theme: Theme

@export var code_script: Node

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


func _ready() -> void:
	%FavoriteButtonContainer.create_command_requested.connect(_on_create_new_command)
	%EventListContainer.get_h_scroll_bar().value_changed.connect(_on_event_list_container_scroll)
	%EventListContainer.get_v_scroll_bar().value_changed.connect(_on_event_list_container_scroll)
	%EventListContainer.get_h_scroll_bar().z_index = 5
	%EventListContainer.get_h_scroll_bar().z_as_relative = false
	%EventListContainer.get_v_scroll_bar().z_as_relative = false
	update_theme()
	
	visibility_changed.connect(func(): if visible: recharge_code_script())
	tree_entered.connect(recharge_code_script)
	recharge_code_script()
	
	_fill_favorite_buttons()


func _fill_favorite_buttons() -> void:
	%FavoriteButtonContainer.fill()


func recharge_code_script() -> void:
	if code_script:
		command_codes = code_script.command_codes
		
	_on_favorite_button_container_item_rect_changed()


func get_selected_items() -> PackedInt32Array:
	return %EventPageList.get_selected_items()


func _on_event_list_container_scroll(_value: float) -> void:
	%EventPageList.queue_redraw()


func set_current_parent(parent: Node) -> void:
	current_parent = parent


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


func update_data() -> void:
	%EventPageList.set_data(current_data)
	#%Tree.build_tree(current_data) # TODO
	if not busy2:
		%EventPageList.set_selected(current_index)


func set_data(_data) -> void:
	update_theme()
	current_data = _data
	%EventPageList.set_data(current_data)
	#%Tree.build_tree(current_data) # TODO


func can_edit_event(index: int) -> bool:
	if current_data.size() > index:
		return current_data[index].code in %EventPageList.EDITABLE_CODES
	else:
		return false


func is_not_editable_event(index: int) -> bool:
	return current_data[index].code in %EventPageList.NO_EDITABLE_CODES


func item_has_parent_selected(indexes: PackedInt32Array, command: RPGEventCommand, index: int) -> bool:
	var parent_code: int
	var indent = command.indent
	
	match command.code:
		3: parent_code = 2
	
	for i in range(indexes.size() -1, -1, -1):
		if indexes[i] > index: continue
		var other : RPGEventCommand = current_data[i]
		if other.parent_code == parent_code and other.indent == indent:
			return true
	
	return false


#region Command Functions

# Edit Event or create a new a event
func _on_event_page_list_item_activated(index: int, force_edit: bool = false) -> void:
	if busy2:
		return
	var indexes = get_selected_items()
	#var editable_commands_count = 0
	if indexes.size() > 0:
		for i in indexes:
			if can_edit_event(i) or is_not_editable_event(i):
				index = i
				break
	
	current_index = index

	%EventPageList.select(index, true)
	%EventPageList.multi_selected.emit(index, true)
	var list = current_data
	
	if (not can_edit_event(index) or
		not %EventPageList.item_has_parent_selected(list[index])
	):
		if not is_not_editable_event(index):
			return
	
	
	if Input.is_key_pressed(KEY_SPACE) or force_edit:
		if can_edit_event(index):
			edit_event(index, current_data[index])
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
	
	if current_data.size() > index:
		current_indent = current_data[index].indent
	else:
		current_indent = 0


func get_command_list_from(index: int, command: RPGEventCommand) -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand]
	commands.append(command)
	
	var indexes = %EventPageList.get_selection_from_command(command, index)
	for id in indexes:
		commands.append(current_data[id])
	
	return commands


func edit_event(index: int, command: RPGEventCommand) -> void:
	if command.code == 0:
		return
	
	if is_not_editable_event(index):
		return

	#if !current_parent:
		#current_parent = get_tree().get_nodes_in_group("main_database")[0]
	
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


func _on_create_new_command(button_code: int, from_dialog: Window = null) -> void:
	if not %EventPageList.is_anything_selected():
		current_index = %EventPageList.get_item_count() - 1
		current_search_index = current_index
		%EventPageList.select(current_index)
		%EventListContainer.scroll_vertical = %EventListContainer.get_v_scroll_bar().max_value
	
	var code_info = command_codes.get(button_code, {"command_code" : button_code, "dialog": ""})
	_show_dialog_command(from_dialog, code_info)


func _insert_command(command: RPGEventCommand, index: int = -1) -> void:
	if index == -1: index = current_index
	if _is_parent_disabled(command, index):
		command.ignore_command = true
	current_data.insert(index, command)
	#fix_ignore_commands_timer = 0.01
	call_deferred("_fix_command_ignore", [command])


func _create_command(command_list: Array[RPGEventCommand]) -> void:
	for command: RPGEventCommand in command_list:
		_insert_command(command)
		
	update_data()


func _edit_command(command_list: Array[RPGEventCommand]) -> void:
	var indexes = %EventPageList.get_selected_items()
	var bak_index = current_index
	_on_event_page_list_delete_pressed(indexes, false, true)
	current_index = bak_index
	
	_create_command(command_list)


func _get_default_command(command_code: int) -> Array[RPGEventCommand]:
	var default_command: Array[RPGEventCommand] = []
	
	var command = RPGEventCommand.new()
	command.code = command_code
	command.indent = current_indent
	default_command.append(command)
	
	return default_command


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


func get_current_dialog_config(data: Dictionary) -> Dictionary:
	if !"commands" in data:
		return {}
	
	var dialog_config = {}
	
	var main_dialog_command: RPGEventCommand = data.commands[0]
	for i:int in range(0, current_data.size(), 1):
		if current_data[i] == main_dialog_command:
			break
		
		if current_data[i].indent <= main_dialog_command.indent and current_data[i].code == 1:
			dialog_config = current_data[i].parameters
	
	return dialog_config


#region Start Loop (Codes 24, 25)
# Code 24 (Parent) parameters {}
# Code 25 (Repeat / End) parameters {}
func _create_command_start_loop() -> void:
	var dialog = RPGDialogFunctions.get_current_dialog()
	if dialog and dialog.is_in_group("event_command_dialog"): dialog.hide()
	
	# Loop Repeat command
	var command = RPGEventCommand.new()
	command.code = 25
	command.indent = current_indent
	_insert_command(command)
	# Next Insert command 0
	command = RPGEventCommand.new()
	command.code = 0
	command.indent = current_indent + 1
	_insert_command(command)
	# Last insert Start Loop Command
	command = RPGEventCommand.new()
	command.code = 24
	command.indent = current_indent
	_insert_command(command)

	update_data()
#endregion


#region Select Common Event Dialog (Code 28)
# Code 28 (Parent) parameters {id}
func _show_select_common_event_dialog(parent: Window, id: int = 1, edit_mode: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	
	dialog.setup(RPGSYSTEM.database.common_events, id, "Common Events", null)
	
	if !edit_mode:
		dialog.selected.connect(func(x, y): parent.hide())
		dialog.selected.connect(_create_command_select_common_dialog)
	else:
		dialog.selected.connect(_edit_command_select_common_dialog)


func _create_command_select_common_dialog(id: int, target) -> void:
	var command = RPGEventCommand.new()
	command.code = 28
	command.indent = current_indent
	command.parameters.id = id
	_insert_command(command)
	update_data()


func _edit_command_select_common_dialog(id: int, target) -> void:
	var indexes = %EventPageList.get_selected_items()
	var bak_index = current_index
	_on_event_page_list_delete_pressed(indexes, false, true)
	current_index = bak_index
	_create_command_select_common_dialog(id, null)
#endregion


#region Set Label Dialog (Code 29)
# Code 29 (Parent) parameters {text}
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


func _create_command_set_label_dialog(text: String) -> void:
	var command = RPGEventCommand.new()
	command.code = 29
	command.indent = current_indent
	command.parameters.text = text.strip_edges()
	_insert_command(command)
	update_data()


func _edit_command_set_label_dialog(text: String) -> void:
	var indexes = %EventPageList.get_selected_items()
	var bak_index = current_index
	_on_event_page_list_delete_pressed(indexes, false, true)
	current_index = bak_index
	_create_command_set_label_dialog(text)
#endregion


#region Movement Route Dialog (Code 57)
# Code 57 (Parent) parameters {}
# Code 58 (movements) parameters {movement_command}

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


func _create_movement_route_dialog(movement_route: RPGMovementRoute) -> void:
	for i in range (movement_route.list.size() - 1, -1, -1):
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


func _edit_movement_route_dialog(movement_route: RPGMovementRoute) -> void:
	var indexes = %EventPageList.get_selected_items()
	var bak_index = current_index
	_on_event_page_list_delete_pressed(indexes, false, true)
	current_index = bak_index
	_create_movement_route_dialog(movement_route)
#endregion


#region Simple Commands (Codes 26, 27, 71, 85, 86, 93, 94, 95, 99, 100, 101, 102)
# Code N (Parent) parameters {}
func _create_simple_command(code: int) -> void:
	var dialog = RPGDialogFunctions.get_current_dialog()
	if dialog and dialog.is_in_group("event_command_dialog"): dialog.hide()
	
	var command = RPGEventCommand.new()
	command.code = code
	command.indent = current_indent
	_insert_command(command)

	update_data()
#endregion


#region Open Blacksmith Shop (Codes 200)
# Code 200 (Parent) parameters {}
func _create_command_open_blacksmith_shop() -> void:
	var dialog = RPGDialogFunctions.get_current_dialog()
	if dialog and dialog.is_in_group("event_command_dialog"): dialog.hide()
	
	var command = RPGEventCommand.new()
	command.code = 200
	command.indent = current_indent
	_insert_command(command)

	update_data()
#endregion

#endregion

#region Copy, Cut, Delete, Paste
func is_end_command(index: int) -> bool:
	var list = current_data
	var is_end: bool = false
	
	if index < list.size() - 1:
		if list[index + 1].code in [5, 6, 7, 22, 23, 25]:
			is_end = true
		
	return is_end


func _on_event_page_list_copy_requested(indexes: PackedInt32Array) -> void:
	var list = current_data
	
	if indexes.size() == 1 and list[indexes[0]].code == 0: return
	
	var copy_event_commands: Array[RPGEventCommand]
	var event_list = %EventPageList
	var base_indent = list[indexes[0]].indent
	for index in indexes:
		if index >= list.size() - 1 or index < 0:
			continue
		if base_indent > list[index].indent:
			break
		if can_edit_event(index) or event_list.item_has_parent_selected(list[index]) or is_not_editable_event(index):
			copy_event_commands.append(list[index].clone(true))
	
	if copy_event_commands.size() == 0:
		return
	
	if copy_event_commands[-1].code == 0:
		copy_event_commands.erase(copy_event_commands[-1])
		
	StaticEditorVars.CLIPBOARD["event_page_commands"] = copy_event_commands


func _on_event_page_list_cut_requested(indexes: PackedInt32Array) -> void:
	var list = current_data
	if indexes.size() == 1 and list[indexes[0]].code == 0: return
	
	var copy_event_commands: Array[RPGEventCommand]
	var remove_event_commands: Array[RPGEventCommand]
	var event_list = %EventPageList
	var base_indent = list[indexes[0]].indent
	for index in indexes:
		if index >= list.size() - 1 or index < 0:
			continue
		if base_indent > list[index].indent:
			break
		if list.size() > index and index >= 0:
			if can_edit_event(index) or event_list.item_has_parent_selected(list[index]) or is_not_editable_event(index):
				copy_event_commands.append(list[index].clone(true))
				remove_event_commands.append(list[index])
	
	if copy_event_commands.size() == 0:
		return
	
	if copy_event_commands[-1].code == 0:
		copy_event_commands.erase(copy_event_commands[-1])
	
	if remove_event_commands[-1].code == 0:
		remove_event_commands.erase(remove_event_commands[-1])
	
	if remove_event_commands.size() > 0: data_changed.emit()
		
	for item in remove_event_commands:
		list.erase(item)

	StaticEditorVars.CLIPBOARD["event_page_commands"] = copy_event_commands
	
	current_index = max(0, min(current_index, list.size() - 1))
	
	update_data()
	


func _on_event_page_list_delete_pressed(indexes: PackedInt32Array, need_scan_indexes: bool = true, remove_all_indexes: bool = false) -> void:
	var event_list = %EventPageList
	var list = current_data
	var remove_comands = []
	var bak_index = current_index
	current_index = -1
	if remove_all_indexes:
		for i in indexes:
			if can_edit_event(i) or is_not_editable_event(i):
				if current_index == -1:
					current_index = i
			remove_comands.append(list[i])
	else:
		if need_scan_indexes:
			for i in indexes:
				if list[i].code == 0: continue
				if can_edit_event(i) or is_not_editable_event(i):
					if current_index == -1:
						current_index = i
					var selection = %EventPageList.get_selection_from_command(list[i], i)
					remove_comands.append(list[i])
					for j in selection:
						remove_comands.append(list[j])
		else:
			for i in indexes:
				if i > 0 and i < list.size() - 1:
					if (
						%EventPageList.is_code_editable(list[i - 1].code) or
						%EventPageList.is_code_editable(list[i + 1].code)
					):
						remove_comands.append(list[i])
				else:
					remove_comands.append(list[i])
				
	if remove_comands:
		for command in remove_comands:
			list.erase(command)
		
		if list.size() == 0 or list[-1].code != 0:
			list.append(RPGEventCommand.new())

		
		current_index = max(0, min(current_index, list.size() - 1))
		
		update_data()
		data_changed.emit()
	else:
		current_index = bak_index



func _on_event_page_ignore_commands(indexes: PackedInt32Array) -> void:
	var list = current_data
	
	if indexes.size() == 1 and list[indexes[0]].code == 0: return
	
	var event_commands: Array[RPGEventCommand]
	var event_list = %EventPageList
	var base_indent = list[indexes[0]].indent
	
	# Guardar estados anteriores antes de cambiar
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
		
		# Validar que los comandos activados tengan todos sus antepasados activos
		_validate_activated_commands(indexes)
		
		# Llamar a la nueva función para asegurar los items
		_ensure_children_ignore_state(indexes, previous_states)
		
		busy2 = true
	
		update_data()

		event_list.deselect_all()
		
		var index = indexes[0]
		for i in range(index, index + indexes.size(), 1):
			event_list.select(i, false)
			
		busy2 = false
		
		event_list.start_reselect()


# Nueva función para sincronizar el estado de ignore_command con los padres
func _ensure_children_ignore_state(parent_indexes: PackedInt32Array, previous_states: Dictionary) -> void:
	var list = current_data
	
	# Recorrer en orden inverso
	for i in range(parent_indexes.size() - 1, -1, -1):
		var parent_index = parent_indexes[i]
		
		if parent_index >= list.size():
			continue
		
		var parent_command = list[parent_index]
		var parent_indent = parent_command.indent
		var previous_state = previous_states.get(parent_index, false)
		var current_state = parent_command.ignore_command
		
		# Si el comando está desactivado, desactivar todos sus hijos recursivamente
		if current_state == true:
			_deactivate_all_children(parent_index, parent_indent)
		
		# Si el comando estaba desactivado y ahora está activado, activar todos sus hijos recursivamente
		elif previous_state == true and current_state == false:
			_activate_all_children(parent_index, parent_indent)


# Desactiva recursivamente todos los hijos de un comando
func _deactivate_all_children(parent_index: int, parent_indent: int) -> void:
	var list = current_data
	
	for child_index in range(parent_index + 1, list.size()):
		var child_command = list[child_index]
		
		# Si el indent es igual o menor, hemos salido del grupo de hijos
		if child_command.indent <= parent_indent:
			break
		
		# Desactivar el hijo
		child_command.ignore_command = true


# Activa recursivamente todos los hijos de un comando
func _activate_all_children(parent_index: int, parent_indent: int) -> void:
	var list = current_data
	var parent_command = list[parent_index]
	var closing_index = -1
	var event_list = %EventPageList
	
	for child_index in range(parent_index + 1, list.size()):
		var child_command = list[child_index]
		
		# Si el indent es igual o menor, hemos salido del grupo de hijos
		if child_command.indent <= parent_indent:
			# Si este comando tiene el mismo indent que el padre, podría ser su cierre
			if child_command.indent == parent_indent:
				# Verificar si es el comando de cierre correspondiente
				var parent_code = event_list.find_parent_code_for_child(child_command.code)
				if parent_code == parent_command.code:
					# Este es el comando de cierre del padre
					child_command.ignore_command = false
					closing_index = child_index
			break
		
		# Activar el hijo solo si TODOS sus antepasados están activos
		if _are_all_ancestors_active(child_index, child_command.indent):
			child_command.ignore_command = false


# Verifica si TODOS los antepasados de un comando están activos
func _are_all_ancestors_active(child_index: int, child_indent: int) -> bool:
	var list = current_data
	
	# Buscar hacia atrás todos los antepasados
	for i in range(child_index - 1, -1, -1):
		var command = list[i]
		
		# Si encontramos un comando con indent menor, es un antepasado
		if command.indent < child_indent:
			# Si el antepasado está desactivado, retornar false
			if command.ignore_command == true:
				return false
			
			# Reducir el indent a buscar para encontrar el siguiente antepasado
			child_indent = command.indent
			
			# Si hemos llegado al indent 0, todos los antepasados están activos
			if child_indent == 0:
				return true
	
	# Si no hay antepasados, está activo
	return true


# Valida que los comandos que se intentan activar tengan todos sus antepasados activos
func _validate_activated_commands(indexes: PackedInt32Array) -> void:
	var list = current_data
	
	for index in indexes:
		if index >= list.size():
			continue
		
		var command = list[index]
		
		# Si el comando está activo (ignore_command == false)
		if command.ignore_command == false:
			# Verificar que todos sus antepasados estén activos
			if not _are_all_ancestors_active(index, command.indent):
				# Si algún antepasado está desactivado, desactivar este comando
				command.ignore_command = true


func _is_parent_disabled(command: RPGEventCommand, command_index: int) -> bool:
	var list = current_data
	
	# Si el comando tiene indent 0, no tiene padre
	if command.indent == 0:
		return false
	
	var parent_indent = command.indent - 1
	
	# Buscar hacia atrás el comando con indent = parent_indent (padre directo)
	for i in range(command_index - 1, -1, -1):
		var other_command = list[i]
		
		# Si encontramos un comando con el indent del padre
		if other_command.indent == parent_indent:
			# Retornar si está desactivado
			return other_command.ignore_command
		
		# Si encontramos un comando con indent menor, no hay padre directo
		elif other_command.indent < parent_indent:
			return false

	return false


func _fix_command_ignore(commands: Array) -> void:
	var command: RPGEventCommand = commands[0]
	if command.ignore_command and not _is_parent_disabled(command, current_data.find(command)):
		command.ignore_command = false


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


func _on_event_page_list_paste_requested(index: int) -> void:
	index = %EventPageList.get_selected_items()[0]
	if !can_edit_event(index) and !is_not_editable_event(index):
		return
	
	var list = current_data
	var event_list = %EventPageList
	var indexes = []
	
	if StaticEditorVars.CLIPBOARD.has("event_page_commands"):
		var indent_displacement = (StaticEditorVars.CLIPBOARD["event_page_commands"][0].indent - current_indent)
		for i in StaticEditorVars.CLIPBOARD["event_page_commands"].size():
			var command: RPGEventCommand = StaticEditorVars.CLIPBOARD["event_page_commands"][i].clone()
			#if command.indent != current_indent:
				#command.indent -= (command.indent - current_indent)
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
		event_list.select(i, false)
		
	busy2 = false
	
	#update_data()
	#
	#list = event_list
	#await get_tree().process_frame
	#await get_tree().process_frame
	#await get_tree().process_frame
	#await get_tree().process_frame
	#list.deselect_all()
	#for i in indexes:
		#list.select(i, false)
#endregion



func _on_event_page_list_multi_selected(index: int, selected: bool) -> void:
	if busy2: return
	var collapsable_button = %CollabsableCommands
	collapsable_button.visible = false
	if selected:
		current_indent = current_data[index].indent
		# TODO
		#var selection: PackedInt32Array = %EventPageList.get_selection_from_command(current_data[index], index)
		#if not selection.is_empty():
			#var rect = %EventPageList.get_item_rect(selection[0] - 1)
			#collapsable_button.position = Vector2(2, rect.position.y + rect.size.y / 2 - collapsable_button.size.y / 2)
			#if current_data[index].is_expanded:
				#collapsable_button.set_pressed_no_signal(false)
			#else:
				#collapsable_button.set_pressed_no_signal(true)
			#collapsable_button.set_meta("command_expanded", {"command": current_data[index], "selection": selection})
			#collapsable_button.visible = true
	current_index = index
	current_search_index = index


func _on_event_page_list_mouse_entered() -> void:
	if get_viewport().gui_get_focus_owner() != %EventPageList:
		%EventPageList.grab_focus()


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


func update_filter_commands() -> void:
	var filter = %Filter.text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.is_action_pressed("FindPrevious"):
			_on_find_previous_command_pressed()
		elif event.is_action_pressed("FindNext"):
			_on_find_next_command_pressed()


func _on_find_previous_command_pressed(reverse_enabled: bool = true, p_current_index: int = -1) -> void:
	var filter = %Filter.text.to_lower()
	if filter.length() > 0:
		var selected_items = get_selected_items()
		var current_index = current_search_index if p_current_index == -1 else p_current_index
		for i in range(current_index - 1, -1, -1):
			var formatted_data = %EventPageList.data[i].formatted_data
			for phrases in formatted_data.phrases:
				var full_text = ""
				for text_data in phrases.texts:
					var text = text_data.text.to_lower()
					full_text += text
					if text.find(filter) != -1:
						select(i, false)
						return
						
				if full_text.find(filter) != -1:
					select(i, false)
					return
	
	if  reverse_enabled:
		_on_find_previous_command_pressed(false, %EventPageList.data.size() - 1)
		


func _on_find_next_command_pressed(reverse_enabled: bool = true, p_current_index: int = -1) -> void:
	var filter = %Filter.text.to_lower()
	if filter.length() > 0:
		var selected_items = get_selected_items()
		var current_index = current_search_index if p_current_index == -1 else p_current_index

		for i in range(current_index + 1, %EventPageList.item_count, 1):
			var formatted_data = %EventPageList.data[i].formatted_data
			
			for phrases in formatted_data.phrases:
				var full_text = ""
				for text_data in phrases.texts:
					var text = text_data.text.to_lower()
					full_text += text
					if text.find(filter) != -1:
						select(i, false)
						return

				if full_text.find(filter) != -1:
					select(i, false)
					return
	
	if reverse_enabled:
		_on_find_next_command_pressed(false, 0)


func select(index: int, initial_delay_on = true) -> void:
	await %EventPageList.set_selected(index, initial_delay_on)
	
	var selected_items = get_selected_items()
		
	var vbar = %EventListContainer.get_v_scroll_bar()
	var item_rect = %EventPageList.get_item_rect(index)
	var max_offset_y =  0 if !selected_items.size() == 0 else selected_items.size() * item_rect.size.y + item_rect.size.y
	var visible_height = %EventListContainer.size.y
	
	var item_global_pos = %EventPageList.get_item_rect(index).position.y
	
	if item_global_pos < vbar.value:
		vbar.value = item_global_pos
	elif (item_global_pos + item_rect.size.y) > (vbar.value + visible_height):
		vbar.value = item_global_pos - visible_height + selected_items.size() * item_rect.size.y + item_rect.size.y


func _on_event_page_list_duplicate_requested(indexes: PackedInt32Array) -> void:
	var list = current_data
	var event_list = %EventPageList
	
	if indexes.size() == 1 and list[indexes[0]].code == 0: return
	
	var duplicate_event_commands: Array[RPGEventCommand] = []
	for i in range(indexes.size() - 1, -1, -1):
		var index = indexes[i]
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
	
	for i in range(insert_position, insert_position + indexes.size(), 1):
		event_list.select(i, false)
		
	busy2 = false


func _on_event_page_list_right_click(index: int, indexes: PackedInt32Array) -> void:
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
	right_menu.set_item_disabled(0, is_invalid_code)
	right_menu.set_item_disabled(1, is_invalid_code or list[indexes[0]].code == 0)
	right_menu.set_item_disabled(6, not StaticEditorVars.CLIPBOARD.has("event_page_commands"))
	right_menu.set_item_disabled(9, indexes.size() == 1 and list[indexes[0]].code == 0)
	right_menu.set_item_disabled(11, indexes.size() == 1 and (list[indexes[0]].code == 0 or list[indexes[0]].code in %EventPageList.SUB_CODES))
	right_menu.set_item_disabled(12, list.is_empty() or (list.size() == 1 and list[0].code == 0))

	right_menu.set_meta("items", indexes)
	right_menu.position = p
	right_menu.show()


func _on_right_menu_index_pressed(index: int) -> void:
	var items = right_menu.get_meta("items")
	right_menu.remove_meta("items")
	match index:
		0: # Create Command
			_on_event_page_list_item_activated(items[0])
		1: # Edit Command
			_on_event_page_list_item_activated(items[0], true)
		3: # Copy Command
			_on_event_page_list_copy_requested(items)
		4: # Cut Command
			_on_event_page_list_cut_requested(items)
		5: # Duplicate Command
			_on_event_page_list_duplicate_requested(items)
		6: # Paste Command
			_on_event_page_list_paste_requested(items[0])
		7: # Delete Command
			_on_event_page_list_delete_pressed(items)
		9: # Ignore Commands Selected
			_on_event_page_ignore_commands(items)
		11: # Preview commands selected in-game
			RPGDialogFunctions.preview_commands_in_action(%EventPageList.get_selected_commands())
		12: # Preview current page in-game
			RPGDialogFunctions.preview_commands_in_action(%EventPageList.get_command_list())


func _on_event_page_list_change_position_requested(from: int, to: int, indexes: PackedInt32Array) -> void:
	#print([from, to, indexes])
	pass


func _process(delta: float) -> void:
	if filter_delay_timer > 0.0:
		filter_delay_timer -= delta
		if filter_delay_timer <= 0:
			_on_find_next_command_pressed()
	
	if fix_ignore_commands_timer > 0.0:
		fix_ignore_commands_timer -= delta
		if fix_ignore_commands_timer <= 0:
			_fix_ignore_commands()


func _on_filter_text_changed(new_text: String) -> void:
	filter_delay_timer = 0.15


func _is_current_sub_code() -> bool:
	var itemlist = %EventPageList
	var indexes = itemlist.get_selected_items()
	var index = -1
	if indexes.size() > 0:
		index = indexes[0]
	else:
		var items = itemlist.get_item_count()
		if items > 0:
			index = items - 1
	
	if index != -1:
		if not itemlist.item_has_parent_selected(current_data[index]):
			return true
	
	itemlist.set_selected(index)
	
	return false


func _on_collabsable_commands_toggled(toggled_on: bool) -> void:
	#TODO
	var itemlist = %EventPageList
	var node = %CollabsableCommands
	var command_data = node.get_meta("command_expanded")
	var command = command_data.command
	var selection = command_data.selection
	command.is_expanded = !toggled_on
	for i in range(0, selection.size()):
		if not command.is_expanded:
			itemlist.set_item_text(selection[i], "")
		
	#"command_expanded", {"command": current_data[index], "selection": selection}


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
