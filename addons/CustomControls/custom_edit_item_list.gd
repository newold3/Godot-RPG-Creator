@tool
class_name CustomEditItemList
extends ItemList


# To add new commands, include the command ID in the EDITABLE_CODES
# constant and append the command to the get_formatted_command function
# (refer to other added commands as examples).

# For multi-commands (commands that are divided into subcommands and together
# form a single command), they need to be added in the
# "get_selection_from_command" and "item_has_parent_selected" functions


#region Exports
@export var odd_line_color: Color = Color("#e4ecf2") :
	set(value):
		odd_line_color = value
		if %BackControl:
			%BackControl.queue_redraw()


@export var event_line_color: Color = Color(1, 1, 1) :
	set(value):
		event_line_color = value
		if %BackControl:
			%BackControl.queue_redraw()


@export var text_selected_color: Color = Color(1, 1, 1) :
	set(value):
		text_selected_color = value
		if %BackControl:
			%BackControl.queue_redraw()


@export var text_margin_left: int = 4 :
	set(value):
		text_margin_left = value
		if %BackControl:
			%BackControl.queue_redraw()


@export var code_format: Node


@export var enabled_action_cursor_texture: StyleBox
@export var no_editable_cursor_texture: StyleBox
@export var disabled_action_cursor: StyleBox
@export var ignored_command: StyleBox

@export var default_text_offset_y: int = 3

@export var default_text: String = "↪️" # ➩ 🔳 🔴 🟡 🔶🔘
@export var default_no_editable_text: String = "▪️"
@export var no_available_icon = "🚫"
@export var disable_text_color = Color(0.427, 0.427, 0.427)


@export_node_path("Control") var main_container

@export_node_path("ScrollContainer") var scroll_container
#endregion

#region Internal Variables
# Dictionary = {"command": RPGEventCommand, "formatted_data": Dictionary}
# formatted_data = {"test": String, "size": vector2, "bg_color": Color, lines: Array}
# lines = [{"text": String, "text_color": Color, "size": Vector2}, ...]
var data : Array[Dictionary]
var busy: bool = false
var need_reselect_timer: float = 0.0
var last_clicked_track: Array = []
var last_click_without_shift: int

var color_theme: Dictionary = {}

var last_offset_setted: float

var backup_text: String


const  EDITABLE_CODES: Array = [
	0, 1, 2, 4, 8, 9, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 28, 29,
	30, 31, 33, 34, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 52, 53, 54, 55, 57, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 87, 88, 89, 90, 92, 93, 96, 98, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 202, 210, 211, 300, 301, 302, 303, 500, 5000
] # Parent Codes Editables

const NO_EDITABLE_CODES: Array = [
	24, 26, 27, 85, 86, 91, 94, 95, 99, 100, 101, 102, 200, 201
] # Parent Codes No Editables

const SUB_CODES = [
	3, 5, 6, 7, 11, 22, 23, 25, 32, 35, 51, 58, 97, 501, 502, 503, 504
] # Child Codes (No Editables)


#endregion


signal delete_pressed(indexes: PackedInt32Array)
signal copy_requested(indexes: PackedInt32Array)
signal cut_requested(indexes: PackedInt32Array)
signal paste_requested(index: int)
signal duplicate_requested(indexes: PackedInt32Array)
signal right_click(index: int, indexes: PackedInt32Array)
signal change_position_requested(to: int, indexes: PackedInt32Array)


func _ready() -> void:
	%BackControl.draw.connect(_on_back_draw)
	draw.connect(%BackControl.queue_redraw)
	#focus_exited.connect(deselect_all)
	item_selected.connect(_on_item_selected)
	multi_selected.connect(_on_multi_selected)
	gui_input.connect(_on_itemlist_gui_input)
	get_v_scroll_bar().value_changed.connect(_change_back_position)
	
	visibility_changed.connect(_config_code_format)
	tree_entered.connect(_config_code_format)
	_config_code_format()


func get_command_list() -> Array[RPGEventCommand]:
	var list: Array[RPGEventCommand] = []
	for obj: Dictionary in data:
		list.append(obj.command)

	return list


func get_selected_commands() -> Array[RPGEventCommand]:
	var indexes = get_selected_items()
	var list: Array[RPGEventCommand] = []
	for i in range(indexes[0], indexes[-1] + 1, 1):
		var obj : Dictionary = data[i]
		list.append(obj.command)

	return list


func _config_code_format() -> void:
	if code_format:
		var config = {
			"color_theme": color_theme,
			"default_text_offset_y": default_text_offset_y,
			"odd_line_color": odd_line_color,
			"event_line_color": event_line_color,
			"default_text": default_text,
			"default_no_editable_text": default_no_editable_text,
			"last_offset_setted": last_offset_setted,
			"backup_text": backup_text
		}
		code_format.set_config(config)
		queue_redraw()


func is_code_editable(code: int) -> bool:
	return EDITABLE_CODES.has(code)


func _process(delta: float) -> void:
	if need_reselect_timer > 0:
		need_reselect_timer -= delta
		if need_reselect_timer <= 0:
			need_reselect_timer = 0.0
			start_reselect()


func _on_itemlist_gui_input(event: InputEvent) -> void:
	if get_item_count() == 0:
		return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		var index = get_item_at_position(event.position, true)
		if index != -1 and event.is_double_click():
			get_viewport().set_input_as_handled()
			item_activated.emit(index)
			return
		if !event.is_shift_pressed():
			last_click_without_shift = index
		if last_clicked_track.size() == 2:
			last_clicked_track.pop_front()
		last_clicked_track.append(index)
		if event.is_ctrl_pressed():
			if index != -1:
				select(index)
				multi_selected.emit(index, true)
			get_viewport().set_input_as_handled()
		elif index != -1 and last_clicked_track.size() == 2 and event.is_shift_pressed():
			var max_value = max(last_click_without_shift, last_clicked_track[1])
			var min_value = min(last_click_without_shift, last_clicked_track[1])
			var selected_items = range(min_value, max_value)
			selected_items.append(max_value)
			select_right_items(selected_items)
			#deselect_all()
			#for i in selected_items:
				#if i != -1:
					#select(i, false)
			#start_reselect()
			get_viewport().set_input_as_handled()
		elif index != -1:
			deselect_all()
			select(index)
			multi_selected.emit(index, true)
			get_viewport().set_input_as_handled()
		return 
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		var index = get_item_at_position(event.position, true)
		var items = get_selected_items()
		if index != -1 and not index in items and data[index].command.code in EDITABLE_CODES:
			select(index)
			multi_selected.emit(index, true)
			items = [index]
		if not items.is_empty():
			right_click.emit(items[0], items)
		get_viewport().set_input_as_handled()
		return
	
	if is_anything_selected() and event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			delete_pressed.emit(get_selected_items())
		elif event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
		elif event.is_ctrl_pressed():
			if event.keycode == KEY_C:
				copy_requested.emit(get_selected_items())
			elif event.keycode == KEY_X:
				cut_requested.emit(get_selected_items())
			elif event.keycode == KEY_V:
				paste_requested.emit(get_selected_items()[-1])
			elif event.keycode == KEY_D:
				duplicate_requested.emit(get_selected_items())
		elif event.keycode == KEY_UP:
			var indexes = get_selected_items()
			if indexes.size() > 0:
				if event.is_alt_pressed() and indexes[0] > 0:
					var next_index = _get_command_index(indexes[0], indexes[0] - 1)
					if next_index != -1:
						change_position_requested.emit(indexes[0], next_index, indexes)
				else:
					var new_index = max(0, indexes[0] - 1)
					select(new_index)
					multi_selected.emit(new_index, true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			var indexes = get_selected_items()
			if indexes.size() > 0:
				if event.is_alt_pressed() and indexes[-1] < data.size() - 1:
					var next_index = _get_command_index(indexes[0], indexes[-1] + 1)
					if next_index != -1:
						change_position_requested.emit(indexes[0], next_index, indexes)
				else:
					var new_index = min(get_item_count() - 1, indexes[-1] + 1)
					select(new_index)
					multi_selected.emit(new_index, true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			var index = get_selected_items()[-1]
			item_activated.emit(index)


func _get_command_index(from: int, to: int) -> int:
	var current_command = data[from].command
	if current_command.code == 0: return -1
	if not current_command.code in EDITABLE_CODES and not current_command.code in NO_EDITABLE_CODES and from > to:
		return - 1

	var next_index = to
	var other_command = data[next_index].command
	if to < from:
		if not other_command.code in EDITABLE_CODES and not other_command.code in NO_EDITABLE_CODES:
			next_index = get_item_parent(to - 1, other_command.indent + 1)
	else:
		if not other_command.code in EDITABLE_CODES and not other_command.code in NO_EDITABLE_CODES:
			var indexes = get_selection_from_command(other_command, to)
			next_index = indexes[-1] + 1

	return next_index



func select_right_items(items: Array) -> void:
	var current_selection_indexes = []
	var start_indent: int = -1
	for index in items:
		if data[index].command.indent < start_indent:
			break
		if (
			data[index].command.code in EDITABLE_CODES or
			data[index].command.code in NO_EDITABLE_CODES
		):
			current_selection_indexes.append(index)
			var child_indexes = get_selection_from_command(data[index].command, index)
			for child_index in child_indexes:
				current_selection_indexes.append(child_index)
		elif item_has_parent_selected(data[index].command):
			current_selection_indexes.append(index)
		else:
			var child_indexes = get_selection_from_command(data[index].command, index)
			
			for child_index in child_indexes:
				current_selection_indexes.append(child_index)
		
		if start_indent == -1 and index in current_selection_indexes:
			start_indent = data[index].command.indent
	
	if items.size() == 1 and current_selection_indexes.size() == 0:
		current_selection_indexes += items 
	
	deselect_all()
	for index in current_selection_indexes:
		select(index, false)


func set_selected(index, initial_delay_on = true) -> void:
	if not (index >= 0 and get_item_count() > index):
		return
		
	if initial_delay_on:
		for i in 4:
			await RenderingServer.frame_post_draw

	var parent = get_node_or_null(scroll_container)
	if parent and parent is ScrollContainer:
		var current_code = data[index]
		var item_parent = get_item_parent(index, current_code.command.indent)
		if index == get_item_count() - 1 or index == get_item_count() - 2 and index != 0:
			parent.get_v_scroll_bar().value = parent.get_v_scroll_bar().max_value
		elif index == 0:
			parent.get_v_scroll_bar().value = 0
		parent.get_h_scroll_bar().value = 0
		parent.scroll_horizontal = parent.get_h_scroll_bar().value
		parent.scroll_vertical = parent.get_v_scroll_bar().value
		
	select(index)
	ensure_current_is_visible()

	multi_selected.emit(index, true)


func _on_item_selected(_item: int) -> void:
	%BackControl.queue_redraw()
	ensure_current_is_visible()


func get_item_parent(index: int, indent: int) -> int:
	for i in range(index - 1, -1, -1):
		if data[i].command.indent < indent and (
			data[i].command.code in EDITABLE_CODES or
			data[i].command.code in NO_EDITABLE_CODES
		):
			return i
	
	return 0


func start_reselect() -> void:
	var indexes = get_selected_items()
	select_right_items(indexes)
	return
	
	# old method
	#var current_selection_indexes: PackedInt32Array = []
	#deselect_all()
	#if indexes.size() > 0:
		#for index in indexes:
			#if data[index].command.code in EDITABLE_CODES or data[index].command.code in NO_EDITABLE_CODES:
				#select(index, false)
				#var childs = get_selection_from_command(data[index].command, index)
				#for i in childs:
					#select(i, false)
					#current_selection_indexes.append(i)
			#elif data[index].command.indent > 0:
				#var command_parent_index = get_item_parent(index, data[index].command.indent)
				#select(command_parent_index, false)
				#var childs = get_selection_from_command(data[command_parent_index].command, command_parent_index)
				#for i in childs:
					#select(i, false)
					#current_selection_indexes.append(i)
			#else:
				#if last_clicked_track[-1] == index:
					#select(index, false)
				#else:
					#if !index in current_selection_indexes:
						#deselect(index)


func _on_multi_selected(index: int, selected: bool) -> void:
	need_reselect_timer = 0.02


func get_selection_from_command(command: RPGEventCommand, start_index: int) -> PackedInt32Array:
	# Parent ID -> get all child IDs for this command
	var indexes = []
	match command.code:
		2: # Dialog Text
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 3 and next_command.indent == command.indent:
					indexes.append(i)
				else:
					break
		4: # Choices
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 7 and next_command.indent == command.indent:
					indexes.append(i)
					break
				else:
					indexes.append(i)
		10: # Scroll Text Dialog
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 11 and next_command.indent == command.indent:
					indexes.append(i)
				else:
					break
		21: # Conditional Branch
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 23 and next_command.indent == command.indent:
					indexes.append(i)
					break
				else:
					indexes.append(i)
		24: # Start Loop
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 25 and next_command.indent == command.indent:
					indexes.append(i)
					break
				else:
					indexes.append(i)
		31: # Comment
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 32 and next_command.indent == command.indent:
					indexes.append(i)
				else:
					break
		34: # Comment
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 35 and next_command.indent == command.indent:
					indexes.append(i)
				else:
					break
		50: # Change Actor Profile
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 51 and next_command.indent == command.indent:
					indexes.append(i)
				else:
					break
		57: # Movement Route
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 58 and next_command.indent == command.indent:
					indexes.append(i)
				else:
					break
		96: # Show Shop
			for i in range(start_index + 1, data.size(), 1):
				var next_command = data[i].command
				if next_command.code == 97 and next_command.indent == command.indent:
					indexes.append(i)
				else:
					break
		500: # Start Battle
			if data.size() > start_index + 1:
				var next_code = data[start_index + 1].command.code
				if [501, 502, 503].has(next_code):
					for i in range(start_index + 1, data.size(), 1):
						var next_command = data[i].command
						if next_command.code == 504 and next_command.indent == command.indent:
							indexes.append(i)
							break
						else:
							indexes.append(i)

	return PackedInt32Array(indexes)


#func get_param_struct() -> Dictionary:
	#var param_struct: Dictionary = {}
	#param_struct[2] = {"start_code": 2, "end_code": -1, "childs": [3]}
	#param_struct[4] = {"start_code": 4, "end_code": 7, "childs": [5, 6]}
	#param_struct[10] = {"start_code": 10, "end_code": -1, "childs": [11]}
	#param_struct[21] = {"start_code": 21, "end_code": 23, "childs": [22]}
	#param_struct[24] = {"start_code": 24, "end_code": 25, "childs": []}
	#param_struct[31] = {"start_code": 31, "end_code": -1, "childs": [32]}
	#param_struct[34] = {"start_code": 34, "end_code": -1, "childs": [35]}
	#param_struct[50] = {"start_code": 50, "end_code": -1, "childs": [51]}
	#param_struct[57] = {"start_code": 57, "end_code": -1, "childs": [58]}
	#param_struct[96] = {"start_code": 96, "end_code": -1, "childs": [97]}
	#param_struct[500] = {"start_code": 500, "end_code": 504, "childs": [501, 502, 503]}
#
	#return param_struct
#func item_has_parent_selected(command: RPGEventCommand) -> bool:
	#var selected_items = get_selected_items()
	#if command.code in EDITABLE_CODES:
		#return true
#
	#var parent_code: int = -1
	#var indent: int = command.indent
#
	## Child Command ID -> Parent ID
	#match command.code:
		#3:
			#parent_code = 2
		#5, 6, 7: 
			#parent_code = 4
		#11:
			#parent_code = 10
		#22, 23:
			#parent_code = 21
		#25:
			#parent_code = 24
		#32:
			#parent_code = 31
		#35:
			#parent_code = 34
		#51:
			#parent_code = 50
		#58:
			#parent_code = 57
		#97:
			#parent_code = 96
		#501, 502, 503, 504:
			#parent_code = 500
#
	#var index: int
#
	#for i in data.size():
		#if data[i].command == command:
			#index = i
			#break
#
	#for i in range(index - 1, -1, -1):
		#var next_command = data[i].command
		#if next_command.code == parent_code and next_command.indent == indent:
			#if is_selected(i):
				#return true
			#else:
				#return false
#
	#return false



func get_param_struct() -> Dictionary:
	var param_struct: Dictionary = {}
	# Command Text Dialog
	param_struct[2] = {"start_code": 2, "end_code": -1, "childs": [3]}
	# Command Show Choices 
	param_struct[4] = {"start_code": 4, "end_code": 7, "childs": [5, 6]}
	# Comand Scrolling Dialog
	param_struct[10] = {"start_code": 10, "end_code": -1, "childs": [11]}
	# Command Conditional Branch
	param_struct[21] = {"start_code": 21, "end_code": 23, "childs": [22]}
	# Command Start Loop
	param_struct[24] = {"start_code": 24, "end_code": 25, "childs": []}
	# Command Comment
	param_struct[31] = {"start_code": 31, "end_code": -1, "childs": [32]}
	# Command Instant Text
	param_struct[34] = {"start_code": 34, "end_code": -1, "childs": [35]}
	# Command Change Actor Profile
	param_struct[50] = {"start_code": 50, "end_code": -1, "childs": [51]}
	# Command Set Movement Route
	param_struct[57] = {"start_code": 57, "end_code": -1, "childs": [58]}
	# Show Shop
	param_struct[96] = {"start_code": 96, "end_code": -1, "childs": [97]}
	# Start Batlle
	param_struct[500] = {"start_code": 500, "end_code": 504, "childs": [501, 502, 503]}
	
	return param_struct


func find_parent_code_for_child(child_code: int) -> int:
	var param_struct = get_param_struct()
	
	for parent_code in param_struct.keys():
		var parent_data = param_struct[parent_code]
		if child_code in parent_data.childs:
			return parent_code
		# También verificar si está en el rango end_code si existe
		if parent_data.end_code != -1 and child_code >= parent_data.start_code and child_code <= parent_data.end_code:
			return parent_code
	
	return -1


func item_has_parent_selected(command: RPGEventCommand) -> bool:
	var selected_items = get_selected_items()
	if command.code in EDITABLE_CODES:
		return true
	
	var parent_code: int = find_parent_code_for_child(command.code)
	
	# Si no se encontró un código padre, retornar false
	if parent_code == -1:
		return false
	
	var indent: int = command.indent
	var index: int
	
	for i in data.size():
		if data[i].command == command:
			index = i
			break
	
	for i in range(index - 1, -1, -1):
		var next_command = data[i].command
		if next_command.code == parent_code and next_command.indent == indent:
			if is_selected(i):
				return true
			else:
				return false
	
	return false


func get_parent_code_data(index: int) -> Dictionary:
	var command: RPGEventCommand = data[index].command
	var command_data = {"start_index": -1, "end_index": -1, "childs": []}
	if command.indent > 0:
		# Start parent index
		for i in range(index - 1, -1, -1):
			var other_command: RPGEventCommand = data[i].command
			if other_command.indent == command.indent - 1 and other_command.code in EDITABLE_CODES:
				command_data.start_index = i
				break
	
	return command_data


func clear_all():
	data = []
	clear()
	%BackControl.position.y = 0
	%BackControl.queue_redraw()


func set_data(_data) -> void:
	#if !is_inside_tree():
		#await tree_entered
	#await get_tree().process_frame
	clear_all()
	_config_code_format()
	custom_minimum_size = Vector2.ZERO
	size = custom_minimum_size
	var font = get("theme_override_fonts/font")
	if !font:
		font = get_theme_default_font()
	var font_size = get("theme_override_font_sizes/font_size")
	if !font_size:
		font_size = get_theme_default_font_size()
	var total_size: Vector2
	var align = HORIZONTAL_ALIGNMENT_LEFT
	var v_separation = get("theme_override_constants/v_separation")
	if v_separation == null:
		v_separation = 0
	
	for i in _data.size():
		var formatted_data = get_formated_command(_data[i], font, font_size, align, v_separation, i)
		
		total_size.x = max(total_size.x, formatted_data.total_size.x)
		total_size.y += formatted_data.total_size.y + v_separation
		data.append({
			"command": _data[i],
			"formatted_data": formatted_data
		})
		add_item(" ")
		set_item_metadata(i, i)
		set_item_tooltip_enabled(-1, false)

	if main_container:
		var node = get_node(main_container)
		node.custom_minimum_size.x = max(total_size.x, get_parent().size.x)
		node.custom_minimum_size.y = max(total_size.y, get_parent().size.y)
	#custom_minimum_size = total_size
	custom_minimum_size.x = max(total_size.x, get_parent().size.x)
	custom_minimum_size.y = max(total_size.y, get_parent().size.y)
	#if main_container:
		#var node = get_node(main_container)
		#if node != self:
			#custom_minimum_size.x = max(custom_minimum_size.x, node.size.x - 20)
			#custom_minimum_size.y = max(custom_minimum_size.y, node.size.y - 20)
	
	if custom_minimum_size.x > get_parent().size.x:
		custom_minimum_size.x += 20
	if custom_minimum_size.y > get_parent().size.y:
		custom_minimum_size.y += 20
	
	var node = get_node_or_null(scroll_container)
	if node and custom_minimum_size.x > node.size.x:
		custom_minimum_size.x += 20
		
	size = custom_minimum_size
	size += Vector2(40, 40)
	#custom_minimum_size = Vector2.ZERO

	%BackControl.queue_redraw()


func dummy_text(tabs: String, command_name: String) -> Dictionary:
	return {
		"texts": [
			{
				"text": tabs + default_text + " parameter < %s > need format" % command_name,
				"color": "#00FFE8"
			}
		],
		"offset_y": default_text_offset_y
	}


func get_item_data(data: Array, id: int) -> Variant:
	if data.size() > id:
		return data[id]
	else:
		return null


func get_item_data_name(data: Array, id: int) -> String:
	if data.size() > id:
		return data[id].name
	else:
		return "⚠ Invalid Data"


func get_event_name(id: int) -> String:
	var data = ["Player"]
	var node: EditEventEditor = get_tree().get_first_node_in_group("event_editor")
	if node:
		var events = node.events.get_events()
		data.append("This Event")
		for ev: RPGEvent in events:
			data.append("%s: %s" % [ev.id, ev.name])
			
	if !node:
		return "Player"
	else:
		if data.size() > id:
			return data[id]
		else:
			return "⚠ Invalid Data"


func get_actor_name(id: int) -> String:
	var data = RPGSYSTEM.database.actors
	if id > 0 and data.size() > id:
		return "< %s: %s >" % [id, data[id].name]
	
	return "⚠ Invalid Data"


func get_formated_movement_command(command: RPGMovementCommand) -> String:
	if !command:
		return ""
		
	match command.code:
		# Column 1
		1: # Move Down
			return("Move Down")
		4: # Move Left
			return("Move Left")
		7: # Move Right
			return("Move Right")
		10: # Move Up
			return("Move Up")
		13: # Move Bottom Left
			return("Move Southwest")
		16: # Move Bottom Right
			return("Move Souteast")
		19: # Move Top Left
			return("Move Northwest")
		22: # Move Top Right
			return("Move Northeast")
		25: # Random Movement
			return("Random Movement")
		28: # Move To The Player
			return("Move To The Player")
		31: # Move Away From The Player
			return("Move Away From The Player")
		34: # Step Forward
			return("Step Ahead")
		37: # Take A Step Back
			return("Step Backward")
		40: # Jump
			return("Jump to %s" % command.parameters[0])
		43: # Wait
			return("Wait %s Seconds" % command.parameters[0])
		46: # Change Z-Index
			return("Z-Index =  %s" % command.parameters[0])
		# Column 2
		2: # Look Down
			return("Look Down")
		5: # Look Left
			return("look Left")
		8: # Look Right
			return("Look Right")
		11: # Look Up
			return("Look Up")
		14: # Turn 90º Left
			return("Turn 90º Left")
		17: # Turn 90º Right
			return("Turn 90º Right")
		20: # Turn 180º
			return("Turn 180º")
		23: # Turn 90º Random
			return("Turn 90º Random")
		26: # Look Random
			return("Look Random")
		29: # Look Player
			return("Look Player")
		32: # Look Opposite Player
			return("Look Opposite Player")
		35: # Switch ON
			var id = str(command.parameters[0]).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
			var switch_name = id + ": " + RPGSYSTEM.system.switches.get_item_name(command.parameters[0])
			return("Switch ON: %s" % switch_name)
		38: # Switch OFF
			var id = str(command.parameters[0]).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
			var switch_name = id + ": " + RPGSYSTEM.system.switches.get_item_name(command.parameters[0])
			return("Switch OFF: %s" % switch_name)
		41: # Change Speed
			return("Change Speed To %s" % command.parameters[0])
		44: # Change Delay
			return("Delay Beetween Motion %s" % command.parameters[0])
		
		# Column 3
		3: # Walkink Animation ON
			return("Walkink Animation ON")
		6: # Walkink Animation OFF
			return("Walkink Animation OFF")
		9: # Idle Animation ON
			return("Idle Animation ON")
		12: # Idle Animation OFF
			return("Idle Animation OFF")
		15: # Fix Direction ON
			return("Fix Direction ON")
		18: # Fix Direction OFF
			return("Fix Direction OFF")
		21: # Passable ON
			return("Walk Through ON")
		24: # Passable OFF
			return("Walk Through OFF")
		27: # Invisible ON
			return("Invisible ON")
		30: # Invisible OFF
			return("Invisible OFF")
		33: # Change Graphic
			return("Change Graphic To %s" % command.parameters[0])
		36: # Change Opacity
			return("Change Opacity To %s" % command.parameters[0])
		39: # Change Blend Mode
			var blend_modes = ["Mix", "Add", "Subtract", "Multiply", "Premult Alpha"]
			return("Change Blend To %s" % blend_modes[command.parameters[0]])
		42: # Play SE
			return("Play SE %s" % command.parameters[0].get_file())
		45: # Script
			return("Script: %s" % command.parameters[0])
		_: # Bad code
			return ""


func get_trait_name(item: RPGTrait) -> Array:
	var column = []
	
	var left = [
		"Element Rate (damage recevied)", "Debuff Rate", "State Rate", "State Resist",
		"Parameter", "Ex-Parameter", "Sp-Parameter",
		"Attack Element", "Attack State", "Attack Speed", "Attack Times +", "Attack Skill",
		"Add Skill Type", "Seal Skill Type", "Add Skill", "Seal Skill",
		"Equip Weapon", "Equip Armor", "Lock Equip", "Seal Equip", "Slot Type",
		"Action Times +", "Special Flag", "Collapse Effect", "Party Ability", "Skill Special Flag",
		"Element Rate (damage done)", "Add Permanent State"
	]
	column.append(left[item.code - 1])
	
	var database = RPGSYSTEM.database
	
	if [1, 27].has(item.code):
		var list = database.types.element_types
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " * " + str(item.value) + " %")
	elif [2, 5].has(item.code):
		var list = ["Max HP", "Max MP", "Attack", "Defense", "Magic Attack", "Magic Defense", "Agility", "Luck"]
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " * " + str(item.value) + "%")
	elif item.code == 3:
		var list = database.states
		if list.size() > item.data_id:
			column.append(list[item.data_id].name + " * " + str(item.value) + "%")
	elif item.code == 4:
		var list = database.states
		if list.size() > item.data_id:
			column.append(list[item.data_id].name)
	elif item.code == 6:
		var list = ["Hit Rate", "Evasion Rate", "Critical Rate", "Critical Evasion", "Magic Evasion", "Magic Reflection", "Counter Attack", "HP Regeneration", "MP Regeneration", "TP Regeneration"]
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " * " + str(item.value) + "%")
	elif item.code == 7:
		var list = ["Target Rate", "Guard Effect", "Recovery Effect", "Pharmacology", "MP Cost Rate", "TP Charge Rate", "Physical Damage", "Magical Damage", "Floor Damage", "Experience", "Gold"]
		if list.size() > item.data_id:
			column.append(list[item.data_id] + " * " + str(item.value) + "%")
	elif item.code == 8:
		var list = database.types.element_types
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 9:
		var list = database.states
		if list.size() > item.data_id:
			column.append(list[item.data_id].name + " + " + str(item.value) + "%")
		else:
			column.append("⚠ Invalid Data")
	elif [10, 11, 22].has(item.code):
		var str = str(item.value)
		if item.code == 22:
			str += "%"
		column.append(str)
	elif [12, 15, 16].has(item.code):
		var list = database.skills
		if list.size() > item.data_id:
			column.append(list[item.data_id].name)
		else:
			column.append("⚠ Invalid Data")
	elif [13, 14].has(item.code):
		var list = database.types.skill_types
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 17:
		var list = database.types.weapon_types
		if item.data_id == 0:
			column.append("All Weapon Types")
		else:
			if list.size() > item.data_id - 1:
				column.append(list[item.data_id - 1])
			else:
				column.append("⚠ Invalid Data")
	elif item.code == 18:
		var list = database.types.armor_types
		if item.data_id == 0:
			column.append("All Armor Types")
		else:
			if list.size() > item.data_id - 1:
				column.append(list[item.data_id - 1])
			else:
				column.append("⚠ Invalid Data")
	elif [19, 20].has(item.code):
		var list = database.types.equipment_types
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
		
	elif item.code == 21:
		var list = ["Normal", "Dual Wield"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
	elif item.code == 23:
		var list = ["Auto Battle", "Guard", "Substitute", "Preserve TP"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 24:
		var list = ["Normal", "Boss", "Instant", "No Dissapear"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 25:
		var list = ["Encounter Half", "Encounter None", "Cancel Surprise", "Raise Preemptive", "Gold Double", "Drop Item Double"]
		if list.size() > item.data_id:
			column.append(list[item.data_id])
		else:
			column.append("⚠ Invalid Data")
	elif item.code == 26:
		var list = ["MP Cost Down", "Double Cast Chance"]
		var str = ""
		if list.size() > item.data_id:
			str = list[item.data_id]
		else:
			str = "⚠ Invalid Data"
		str += " * " + str(item.value) + " %"
		column.append(str)

	return column



func get_formated_command(command: RPGEventCommand, font: Font, font_size: int, align: HorizontalAlignment, v_separation: int, index: int) -> Dictionary:
	var result: Dictionary
	result["bg_color"] = event_line_color if index % 2 == 0 else odd_line_color
	result["phrases"] = []
	result["offset_y"] = 0
	
	var sep = "      "
	var tabs: String
	for i in command.indent:
		tabs += sep
	
	if command.indent > 0:
		tabs[-1] = ""
		
	if code_format:
		return code_format.get_formatted_code(command, font, font_size, align, v_separation, index)
	
	# fallback
	
	result["phrases"].append({
		"texts": [
			{
				"text": tabs + default_text + command.to_string(),
				"color": color_theme.get("color2", Color.WHITE)
			},
		],
		"offset_y": default_text_offset_y
	})
	
	result["total_size"] = Vector2.ZERO
	for phrase in result["phrases"]:
		for obj in phrase.texts:
			obj["size"] = font.get_string_size(obj["text"], align, -1, font_size)
			result["total_size"].x += obj["size"].x
			if result["total_size"].y == 0:
				result["total_size"].y = obj["size"].y

	return result


func can_edit_event(event: RPGEventCommand) -> bool:
	return event.code in EDITABLE_CODES


func is_not_editable_event(event: RPGEventCommand) -> bool:
	return event.code in NO_EDITABLE_CODES


func _on_back_draw() -> void:
	if busy:
		return
		
	var control: Control = %BackControl
	control.size = size

	var rect: Rect2
	var offset_x: int = 0
	var offset_y: int = 0
	var parent = self
	if main_container:
		parent = get_node(main_container)
		if "get_v_scroll_bar" in parent:
			offset_y = max(0, parent.get_v_scroll_bar().value)
		if "get_h_scroll_bar" in parent:
			offset_x = max(0, parent.get_h_scroll_bar().value)
		parent = self
	
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var align = HORIZONTAL_ALIGNMENT_LEFT
	
	var items_selected = get_selected_items()
	
	var max_page_size = Vector2.ZERO
	if scroll_container:
		var main_scroll_container = get_node(scroll_container)
		if main_scroll_container.scroll_vertical > 0 and not main_scroll_container.get_v_scroll_bar().visible:
			main_scroll_container.scroll_vertical = 0
		if main_scroll_container.scroll_horizontal > 0 and not main_scroll_container.get_h_scroll_bar().visible:
			main_scroll_container.scroll_horizontal = 0
		max_page_size = main_scroll_container.size

	var v_separation = get("theme_override_constants/v_separation")
	if !v_separation:
		v_separation = 2
	
	# Array para almacenar todas las filas (reales y de relleno) con su información
	var all_rows = []
	
	if item_count > 0:
		# Agregar filas reales
		for i in item_count:
			var formatted_data = data[i].formatted_data
			rect = get_item_rect(i)
			if rect.position.y + rect.size.y - offset_y < 0:
				continue
			elif rect.position.y - offset_y > parent.size.y:
				continue
			rect.size.x = parent.size.x
			
			all_rows.append({
				"type": "real",
				"index": i,
				"rect": rect,
				"formatted_data": formatted_data
			})
		
		# Si hay espacio para más filas, agregar filas de relleno
		if all_rows.size() > 0:
			var last_real_rect = all_rows[-1].rect
			var base_height = last_real_rect.size.y
			var fill_y = last_real_rect.position.y + last_real_rect.size.y + v_separation
			var fill_id = item_count
			var max_deep = 1000
			var current_deep = 0
			
			while fill_y - offset_y < parent.size.y + 42 and current_deep < max_deep:
				var fill_rect = Rect2()
				fill_rect.position.x = 0
				fill_rect.position.y = fill_y
				fill_rect.size.x = parent.size.x
				fill_rect.size.y = base_height
				
				if fill_rect.position.y + fill_rect.size.y - offset_y >= 0:
					all_rows.append({
						"type": "fill",
						"index": fill_id,
						"rect": fill_rect
					})
				
				fill_y += v_separation + base_height
				fill_id += 1
				current_deep += 1
	else:
		# Cuando no hay items, llenar con filas de altura base del font
		var sy = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y
		var y = 0
		var i = 0
		var max_deep = 1000
		var current_deep = 0
		
		while y < parent.size.y + v_separation + 42 and current_deep < max_deep:
			rect = Rect2()
			rect.position = Vector2(0, y)
			rect.size = Vector2(parent.size.x, sy)
			
			if rect.position.y + rect.size.y - offset_y >= 0 and rect.position.y - offset_y <= parent.size.y:
				all_rows.append({
					"type": "fill",
					"index": i,
					"rect": rect
				})
			
			y += v_separation + sy
			i += 1
			current_deep += 1
	
	# Aplicar +6 solo a la última fila visible
	if all_rows.size() > 0:
		all_rows[-1].rect.size.y += 6
	
	# Dibujar todas las filas
	for row in all_rows:
		rect = row.rect
		
		if row.type == "real":
			var i = row.index
			var formatted_data = row.formatted_data
			var x = rect.position.x + text_margin_left
			var y = font.get_ascent() + rect.position.y
			
			if items_selected.has(i):
				if enabled_action_cursor_texture:
					if can_edit_event(data[i].command) or item_has_parent_selected(data[i].command) or is_not_editable_event(data[i].command):
						control.draw_style_box(enabled_action_cursor_texture, rect)
					else:
						control.draw_rect(rect, formatted_data.bg_color)
						var rect2 = rect
						rect2.size.y -= 6 if row == all_rows[-1] else 0  # Solo restar 6 si es la última fila
						rect2.size.x = size.x - 42
						if main_container:
							var scrolling_panel = get_node(main_container)
							if scrolling_panel.get_v_scroll_bar().visible:
								rect2.size.x = max(scrolling_panel.size.x, rect2.size.x) - scrolling_panel.get_v_scroll_bar().size.x - 4
							if scrolling_panel.get_h_scroll_bar().visible:
								rect2.size.x = max(rect2.size.x, scrolling_panel.get_h_scroll_bar().max_value - 2)
						control.draw_style_box(no_editable_cursor_texture, rect)
				else:
					control.draw_rect(rect, formatted_data.bg_color)
			else:
				control.draw_rect(rect, formatted_data.bg_color)
			
			if data[i].command.ignore_command:
				var s = font.get_string_size(no_available_icon, align, -1, font_size)
				control.draw_string(
					font, Vector2(x, y + font.get_ascent() - 4), no_available_icon,
					align, s.x, font_size
				)
				control.draw_style_box(ignored_command, rect)
				x += s.x + 4
			
			# Dibujar texto
			var start_height = 0
			for phrase in formatted_data.phrases:
				var start_width = 0
				for obj in phrase.texts:
					var displacement = obj.get("offset_x", 0)
					start_width += obj.size.x
					if obj == phrase.texts[0]:
						start_height += obj.size.y
					
					if items_selected.has(i):
						control.draw_string(
							font, Vector2(x + displacement, y + phrase.offset_y), obj.text,
							align, obj.size.x, font_size, text_selected_color
						)
					else:
						var text: String = obj.text.replace(default_text, " ")
						var text_color = Color(obj.color) if not data[i].command.ignore_command else disable_text_color
						control.draw_string(
							font, Vector2(x + displacement, y + phrase.offset_y), text,
							align, obj.size.x, font_size, text_color)
						if obj.text.find(default_text) != -1:
							text = "".lpad(obj.text.find(default_text), " ") + default_text
							text_color = Color.WHITE if not data[i].command.ignore_command else disable_text_color
							control.draw_string(
								font, Vector2(x + displacement, y + phrase.offset_y), text,
								align, -1, font_size, text_color)
						elif obj.text.find(default_no_editable_text) != -1:
							text = "".lpad(obj.text.find(default_no_editable_text), " ") + default_no_editable_text
							text_color = Color.WHITE if not data[i].command.ignore_command else disable_text_color
							control.draw_string(
								font, Vector2(x + displacement, y + phrase.offset_y), text,
								align, -1, font_size, Color.WHITE)
					x += obj.size.x
				max_page_size.x = max(max_page_size.x, start_width)
			max_page_size.y = max(max_page_size.y, start_height)
			
		else:  # Fila de relleno
			var fill_id = row.index
			if fill_id % 2 == 0:
				control.draw_rect(rect, event_line_color)
			else:
				control.draw_rect(rect, odd_line_color)
	
	if scroll_container:
		var node = get_node_or_null(scroll_container)
		if node and max_page_size.x > node.size.x:
			max_page_size.x += 240
	custom_minimum_size = max_page_size
	size = max_page_size
	
	# Dibujar las líneas divisorias solo para items reales
	for i in item_count:
		rect = get_item_rect(i)
		if rect.position.y + rect.size.y - offset_y < 0:
			continue
		elif rect.position.y - offset_y > parent.size.y:
			continue
		rect.size.x = parent.size.x
		rect.size.y = 1
		rect.position.y = rect.position.y + rect.size.y - 1
		control.draw_rect(rect, Color("#67676792"))


func _change_back_position(value: float) -> void:
	#%BackControl.position.y = -value
	pass
