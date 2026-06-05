@tool
class_name CustomEditItemList
extends ItemList


# To add new commands, include the command ID in the EDITABLE_CODES or NO_EDITABLE_CODES
# constants and append the command to the get_formatted_command function
# (refer to other added commands as examples).

# For multi-commands (commands that are divided into subcommands and together
# form a single command), they need to be added in the
# "get_selection_from_command" and "item_has_parent_selected" functions
# The subcommands must be added to SUB_CODES constant


## Color for odd lines
@export var odd_line_color: Color = Color("#e4ecf2") :
	set(value):
		odd_line_color = value
		if %BackControl:
			%BackControl.queue_redraw()

## Color for event lines
@export var event_line_color: Color = Color(1, 1, 1) :
	set(value):
		event_line_color = value
		if %BackControl:
			%BackControl.queue_redraw()

## Color for selected text
@export var text_selected_color: Color = Color(1, 1, 1) :
	set(value):
		text_selected_color = value
		if %BackControl:
			%BackControl.queue_redraw()

## Left margin for the text
@export var text_margin_left: int = 4 :
	set(value):
		text_margin_left = value
		if %BackControl:
			%BackControl.queue_redraw()

## Code format script reference
@export var code_format: Node

## StyleBox for the hovered command group
@export var hover_group_style: StyleBox

## Fallback color for hovered command group
@export var hover_color: Color = Color(1, 1, 1, 0.05)

## StyleBox cursor for enabled actions
@export var enabled_action_cursor_texture: StyleBox

## StyleBox cursor for non-editable actions
@export var no_editable_cursor_texture: StyleBox

## StyleBox cursor for disabled actions
@export var disabled_action_cursor: StyleBox

## StyleBox cursor for ignored commands
@export var ignored_command: StyleBox

## Default Y offset for text
@export var default_text_offset_y: int = 3

## Default prefix character
@export var default_text: String = "↪️"

## Default non-editable prefix character
@export var default_no_editable_text: String = "▪️"

## Default unavailable icon
@export var no_available_icon = "🚫"

## Draws hierarchical branch guidelines
@export var draw_vertical_guides: bool = true

## Icon assigned for collapsible commands when expanded
@export var expanded_icon: String = "▼"

## Icon assigned for collapsible commands when collapsed
@export var collapsed_icon: String = "▶"

## Color for disabled text
@export var disable_text_color = Color(0.427, 0.427, 0.427)

## Node path to the main container
@export_node_path("Control") var main_container

## Node path to the scroll container
@export_node_path("ScrollContainer") var scroll_container

var data : Array[Dictionary]
var busy: bool = false
var need_reselect_timer: float = 0.0
var last_clicked_track: Array = []
var last_click_without_shift: int
var color_theme: Dictionary = {}
var last_offset_setted: float
var backup_text: String
var potential_drag_index: int = -1
var mouse_down_time: int = 0
var drag_preview_line: int = -1
var hovered_visual_index: int = -1

const  EDITABLE_CODES: Array = [
	0, 1, 2, 4, 8, 9, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 28, 29,
	30, 31, 33, 34, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49,
	50, 52, 53, 54, 55, 57, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
	71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 87, 88, 89, 90,
	92, 93, 96, 98, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113,
	114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127,
	202, 210, 211, 300, 301, 302, 303, 500, 5000, 9999
]

const NO_EDITABLE_CODES: Array = [
	24, 26, 27, 85, 86, 91, 94, 95, 99, 100, 101, 102, 200, 201
]

const SUB_CODES = [
	3, 5, 6, 7, 11, 22, 23, 25, 32, 35, 51, 58, 97, 501, 502, 503, 504
]

signal delete_pressed(indexes: PackedInt32Array)
signal copy_requested(indexes: PackedInt32Array)
signal cut_requested(indexes: PackedInt32Array)
signal paste_requested(index: int)
signal duplicate_requested(indexes: PackedInt32Array)
signal right_click(index: int, indexes: PackedInt32Array)
signal change_position_requested(to: int, indexes: PackedInt32Array)
signal items_dropped(to_index: int, new_indent: int, indexes: PackedInt32Array)
signal command_collapsed_toggled(command: RPGEventCommand, toggled_on: bool)



## Setup core signals on creation
func _ready() -> void:
	%BackControl.draw.connect(_on_back_draw)
	draw.connect(%BackControl.queue_redraw)
	item_selected.connect(_on_item_selected)
	multi_selected.connect(_on_multi_selected)
	gui_input.connect(_on_itemlist_gui_input)
	get_v_scroll_bar().value_changed.connect(_change_back_position)
	visibility_changed.connect(_config_code_format)
	tree_entered.connect(_config_code_format)
	mouse_exited.connect(func():
		hovered_visual_index = -1
		%BackControl.queue_redraw()
	)
	_config_code_format()



## Safely resolves raw command from either dictionary wrap or pure object
func _get_cmd(target_array: Array, index: int) -> RPGEventCommand:
	var item = target_array[index]
	if item is Dictionary:
		return item.command
	return item as RPGEventCommand



## Translates underlying memory index back to valid screen visual index
func get_visual_index(real_index: int) -> int:
	for i in range(get_item_count()):
		if get_item_metadata(i) == real_index:
			return i
	return -1



## Formats list into raw command sequence
func get_command_list() -> Array[RPGEventCommand]:
	var list: Array[RPGEventCommand] = []
	for obj: Dictionary in data:
		list.append(obj.command)
	return list



## Custom overriding of internal implementation returning real selection indexes mapping
func get_real_selected_items() -> PackedInt32Array:
	var visuals = super.get_selected_items()
	var reals = PackedInt32Array()
	if visuals.size() > 0:
		for v in visuals:
			var meta = get_item_metadata(v)
			if meta != null:
				reals.append(meta)
	return reals



## Wrapper to process abstract index inputs mapping
func select_real_index(real_index: int, single: bool = true) -> void:
	if not (real_index >= 0 and data.size() > real_index):
		return
	var v_index = get_visual_index(real_index)
	if v_index == -1:
		var parent_idx = _find_visible_parent(real_index)
		if parent_idx != -1:
			v_index = get_visual_index(parent_idx)
		if v_index == -1:
			return
	if single:
		for i in 4:
			await RenderingServer.frame_post_draw
	var parent = get_node_or_null(scroll_container)
	if parent and parent is ScrollContainer:
		if v_index == get_item_count() - 1 or (v_index == get_item_count() - 2 and v_index != 0):
			parent.get_v_scroll_bar().value = parent.get_v_scroll_bar().max_value
		elif v_index == 0:
			parent.get_v_scroll_bar().value = 0
		var item_rect = get_item_rect(v_index)
		var visible_height = parent.size.y
		var item_global_pos = item_rect.position.y
		var vbar = parent.get_v_scroll_bar()
		if item_global_pos < vbar.value:
			vbar.value = item_global_pos - (visible_height / 2.0)
		elif (item_global_pos + item_rect.size.y) > (vbar.value + visible_height):
			vbar.value = (item_global_pos + item_rect.size.y) - visible_height + (item_rect.size.y * 2)
		parent.get_h_scroll_bar().value = 0
		parent.scroll_horizontal = 0
		parent.scroll_vertical = vbar.value
	select(v_index, single)
	ensure_current_is_visible()
	multi_selected.emit(v_index, true)



## Looks for an expanded parent backwards if the target item is hidden
func _find_visible_parent(real_index: int) -> int:
	var cmd = data[real_index].command
	for i in range(real_index - 1, -1, -1):
		if data[i].command.indent < cmd.indent:
			if get_visual_index(i) != -1:
				return i
	return -1



## Polls custom logic bounds for item states
func is_selected_real(real_index: int) -> bool:
	var v_index = get_visual_index(real_index)
	if v_index != -1:
		return is_selected(v_index)
	return false



## Fetches commands data directly derived from array boundaries
func get_selected_commands() -> Array[RPGEventCommand]:
	var indexes = get_real_selected_items()
	var list: Array[RPGEventCommand] = []
	if indexes.size() > 0:
		for i in range(indexes[0], indexes[-1] + 1, 1):
			if data.size() > i:
				var obj : Dictionary = data[i]
				list.append(obj.command)
	return list



## Sets dynamic theme properties required to paint custom strings formats
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



## Returns pure logical valid check state
func is_code_editable(code: int) -> bool:
	return EDITABLE_CODES.has(code)



## Monitors manual forced checks updates and timer processing delays
func _process(delta: float) -> void:
	if need_reselect_timer > 0:
		need_reselect_timer -= delta
		if need_reselect_timer <= 0:
			need_reselect_timer = 0.0
			start_reselect()
	var btn = get_node_or_null("%CollabsableCommands")
	if btn:
		var is_hovering_btn = btn.get_global_rect().has_point(get_global_mouse_position())
		var is_hovering_list = get_global_rect().has_point(get_global_mouse_position())
		if is_hovering_btn:
			pass
		elif hovered_visual_index != -1 and is_hovering_list:
			var v_idx = hovered_visual_index
			var r_idx = get_item_metadata(v_idx) if v_idx >= 0 and v_idx < get_item_count() else null
			if r_idx != null:
				var cmd = data[r_idx].command
				var is_expandable = data[r_idx].formatted_data.get("is_expandable", false)
				if is_expandable:
					var rect = get_item_rect(v_idx)
					btn.position = Vector2(2, rect.position.y + rect.size.y / 2.0 - btn.size.y / 2.0)
					if not btn.toggled.is_connected(_on_btn_toggled):
						btn.toggled.connect(_on_btn_toggled)
					btn.set_pressed_no_signal(not cmd.is_expanded)
					btn.set_meta("command_expanded", {"command": cmd})
					btn.visible = true
				else:
					btn.visible = false
			else:
				btn.visible = false
		else:
			btn.visible = false



## Triggers abstract mappings execution on system input interaction contexts
func _on_itemlist_gui_input(event: InputEvent) -> void:
	if get_item_count() == 0:
		return
	if event is InputEventMouseMotion:
		var v_index = get_item_at_position(event.position, true)
		if v_index != hovered_visual_index:
			hovered_visual_index = v_index
			%BackControl.queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var v_index = get_item_at_position(event.position, true)
		var index = get_item_metadata(v_index) if v_index >= 0 and v_index < get_item_count() else -1
		if event.is_pressed():
			if index != -1 and event.is_double_click():
				get_viewport().set_input_as_handled()
				select(v_index)
				multi_selected.emit(v_index, true)
				item_activated.emit(v_index)
				return
			if index != -1 and is_selected_real(index) and not event.is_shift_pressed() and not event.is_ctrl_pressed():
				return
			if !event.is_shift_pressed():
				last_click_without_shift = index
			if last_clicked_track.size() == 2:
				last_clicked_track.pop_front()
			last_clicked_track.append(index)
			if event.is_ctrl_pressed():
				if index != -1:
					select(v_index)
					multi_selected.emit(v_index, true)
				get_viewport().set_input_as_handled()
			elif index != -1 and last_clicked_track.size() == 2 and event.is_shift_pressed():
				var max_value = max(last_click_without_shift, last_clicked_track[1])
				var min_value = min(last_click_without_shift, last_clicked_track[1])
				var selected_items = range(min_value, max_value)
				selected_items.append(max_value)
				select_right_items(selected_items)
				get_viewport().set_input_as_handled()
			elif index != -1:
				deselect_all()
				select(v_index)
				multi_selected.emit(v_index, true)
				get_viewport().set_input_as_handled()
		else:
			if index != -1 and is_selected_real(index) and not event.is_shift_pressed() and not event.is_ctrl_pressed():
				deselect_all()
				select(v_index)
				multi_selected.emit(v_index, true)
		return 
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		var v_index = get_item_at_position(event.position, true)
		var index = get_item_metadata(v_index) if v_index >= 0 and v_index < get_item_count() else -1
		var items = get_real_selected_items()
		if index != -1 and not index in items and data[index].command.code in EDITABLE_CODES:
			select(v_index)
			multi_selected.emit(v_index, true)
			items = [index]
		if not items.is_empty():
			right_click.emit(v_index, items)
		get_viewport().set_input_as_handled()
		return
	if is_anything_selected() and event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			delete_pressed.emit(get_real_selected_items())
		elif event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
		elif event.is_ctrl_pressed():
			if event.keycode == KEY_C:
				copy_requested.emit(get_real_selected_items())
			elif event.keycode == KEY_X:
				cut_requested.emit(get_real_selected_items())
			elif event.keycode == KEY_V:
				paste_requested.emit(get_real_selected_items()[-1])
			elif event.keycode == KEY_D:
				duplicate_requested.emit(get_real_selected_items())
			elif event.keycode == KEY_UP:
				var indexes = get_real_selected_items()
				if indexes.size() > 0:
					change_position_requested.emit(indexes[0], indexes[0] - 1, indexes)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				var indexes = get_real_selected_items()
				if indexes.size() > 0:
					change_position_requested.emit(indexes[0], indexes[-1] + 1, indexes)
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP:
			var indexes = get_real_selected_items()
			if indexes.size() > 0:
				if event.is_alt_pressed() and indexes[0] > 0:
					var next_index = _get_command_index(indexes[0], indexes[0] - 1)
					if next_index != -1:
						change_position_requested.emit(indexes[0], next_index, indexes)
				else:
					var v_first = get_visual_index(indexes[0])
					if v_first > 0:
						var next_v = v_first - 1
						var new_index = get_item_metadata(next_v)
						if new_index != null:
							select(next_v)
							multi_selected.emit(next_v, true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			var indexes = get_real_selected_items()
			if indexes.size() > 0:
				if event.is_alt_pressed() and indexes[-1] < data.size() - 1:
					var next_index = _get_command_index(indexes[0], indexes[-1] + 1)
					if next_index != -1:
						change_position_requested.emit(indexes[0], next_index, indexes)
				else:
					var v_last = get_visual_index(indexes[-1])
					if v_last != -1 and v_last + 1 < get_item_count():
						var next_v = v_last + 1
						var new_index = get_item_metadata(next_v)
						if new_index != null:
							select(next_v)
							multi_selected.emit(next_v, true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			var indexes = get_real_selected_items()
			if indexes.size() > 0:
				var v_index = get_visual_index(indexes[-1])
				if v_index != -1:
					item_activated.emit(v_index)



## Prepares logic variants properties payload on items dragged action event
func _get_drag_data(at_position: Vector2) -> Variant:
	var v_index = get_item_at_position(at_position, true)
	var index = get_item_metadata(v_index) if v_index >= 0 and v_index < get_item_count() else -1
	if index == -1 or not is_selected_real(index):
		return null
	var selected = get_real_selected_items()
	if selected.is_empty():
		return null
	var first_cmd = data[selected[0]].command
	if first_cmd.code == 0 or first_cmd.code in SUB_CODES:
		return null
	var preview = Label.new()
	preview.text = " Moving %s command(s)... " % selected.size()
	set_drag_preview(preview)
	return selected



## Evaluates boundaries integrity limits protecting specific layout bounds
func _can_drop_data(at_position: Vector2, drag_data: Variant) -> bool:
	if typeof(drag_data) != TYPE_PACKED_INT32_ARRAY:
		return false
	var v_drop_index = get_item_at_position(at_position, true)
	var drop_index = get_item_metadata(v_drop_index) if v_drop_index >= 0 and v_drop_index < get_item_count() else -1
	if drop_index != -1:
		if drop_index in drag_data:
			drag_preview_line = -1
			%BackControl.queue_redraw()
			return false
		var cmd = data[drop_index].command
		if cmd.code in SUB_CODES:
			drag_preview_line = -1
			%BackControl.queue_redraw()
			return false
		if drag_data.size() > 0:
			var first_dragged = drag_data[0]
			if drop_index > first_dragged:
				var base_indent = data[first_dragged].command.indent
				var is_inside = true
				for i in range(first_dragged + 1, drop_index + 1):
					var check_cmd = data[i].command
					if check_cmd.indent < base_indent:
						is_inside = false
						break
					if check_cmd.indent == base_indent and check_cmd.code != 0 and check_cmd.code not in SUB_CODES:
						is_inside = false
						break
				if is_inside:
					drag_preview_line = -1
					%BackControl.queue_redraw()
					return false
	else:
		v_drop_index = get_item_count()
	drag_preview_line = v_drop_index
	%BackControl.queue_redraw()
	return true



## Consumes variables generated parameters ending interaction logic context drop
func _drop_data(at_position: Vector2, drag_data: Variant) -> void:
	var v_drop_index = drag_preview_line
	drag_preview_line = -1
	%BackControl.queue_redraw()
	if v_drop_index == -1:
		v_drop_index = get_item_at_position(at_position, true)
		if v_drop_index == -1:
			v_drop_index = get_item_count()
	var drop_index = get_item_metadata(v_drop_index) if v_drop_index < get_item_count() else data.size()
	if drop_index == null: drop_index = data.size()
	items_dropped.emit(drop_index, 0, drag_data)



## Looks up offset boundaries limits required parameters
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



## Recursively applies items properties based into logic tree components context
func select_right_items(items: Array) -> void:
	var current_selection_indexes = []
	var start_indent: int = -1
	for index in items:
		if data[index].command.indent < start_indent:
			break
		if not current_selection_indexes.has(index):
			current_selection_indexes.append(index)
		var child_indexes = _get_block_selection(index, data)
		for child_index in child_indexes:
			if not current_selection_indexes.has(child_index):
				current_selection_indexes.append(child_index)
		if start_indent == -1 and index in current_selection_indexes:
			start_indent = data[index].command.indent
	if items.size() == 1 and current_selection_indexes.size() == 0:
		current_selection_indexes += items 
	deselect_all()
	for index in current_selection_indexes:
		var v = get_visual_index(index)
		if v != -1:
			select(v, false)



## Requests list visual drawing process
func _on_item_selected(_item: int) -> void:
	%BackControl.queue_redraw()
	ensure_current_is_visible()



## Resolves nested command parents
func get_item_parent(index: int, indent: int) -> int:
	for i in range(index - 1, -1, -1):
		if data[i].command.indent < indent and (data[i].command.code in EDITABLE_CODES or data[i].command.code in NO_EDITABLE_CODES):
			return i
	return 0



## Checks boundaries and forces internal selection loop
func start_reselect() -> void:
	var indexes = get_real_selected_items()
	select_right_items(indexes)
	return



## Forces internal reselect interval execution schedule
func _on_multi_selected(index: int, selected: bool) -> void:
	need_reselect_timer = 0.02



## Emits clean signals parsing real dictionary commands natively
func _on_btn_toggled(toggled_on: bool) -> void:
	var node = get_node_or_null("%CollabsableCommands")
	if not node or not node.has_meta("command_expanded"): return
	var command_data = node.get_meta("command_expanded")
	command_collapsed_toggled.emit(command_data.command, toggled_on)



## Defines universally robust dynamic structure tree matching rules
func _get_block_selection(start_index: int, target_array: Array) -> Array:
	var start_cmd = _get_cmd(target_array, start_index)
	var struct = get_param_struct()
	var indexes = []
	if start_cmd.code in SUB_CODES:
		for i in range(start_index + 1, target_array.size()):
			var next_cmd = _get_cmd(target_array, i)
			if next_cmd.indent > start_cmd.indent:
				indexes.append(i)
			else:
				break
		return indexes
	var has_struct = struct.has(start_cmd.code)
	if has_struct:
		var end_code = struct[start_cmd.code].end_code
		var child_codes = struct[start_cmd.code].childs
		for i in range(start_index + 1, target_array.size()):
			var next_cmd = _get_cmd(target_array, i)
			if next_cmd.indent > start_cmd.indent:
				indexes.append(i)
			elif next_cmd.indent == start_cmd.indent:
				if end_code != -1 and next_cmd.code == end_code:
					indexes.append(i)
					break
				elif next_cmd.code in child_codes:
					indexes.append(i)
				else:
					break
			else:
				break
	else:
		for i in range(start_index + 1, target_array.size()):
			var next_cmd = _get_cmd(target_array, i)
			if next_cmd.indent > start_cmd.indent:
				indexes.append(i)
			else:
				break
	return indexes



## Determines nested command block indexes mapping directly linked
func get_selection_from_command(command: RPGEventCommand, start_index: int, custom_data: Array = []) -> PackedInt32Array:
	var target_array = custom_data if custom_data.size() > 0 else data
	if target_array.is_empty(): return PackedInt32Array()
	return PackedInt32Array(_get_block_selection(start_index, target_array))



## Retrieves dynamic internal definitions arrays configuration elements values
func get_param_struct() -> Dictionary:
	var param_struct: Dictionary = {}
	param_struct[2] = {"start_code": 2, "end_code": -1, "childs": [3]}
	param_struct[4] = {"start_code": 4, "end_code": 7, "childs": [5, 6]}
	param_struct[10] = {"start_code": 10, "end_code": -1, "childs": [11]}
	param_struct[21] = {"start_code": 21, "end_code": 23, "childs": [22]}
	param_struct[24] = {"start_code": 24, "end_code": 25, "childs": []}
	param_struct[31] = {"start_code": 31, "end_code": -1, "childs": [32]}
	param_struct[34] = {"start_code": 34, "end_code": -1, "childs": [35]}
	param_struct[50] = {"start_code": 50, "end_code": -1, "childs": [51]}
	param_struct[57] = {"start_code": 57, "end_code": -1, "childs": [58]}
	param_struct[96] = {"start_code": 96, "end_code": -1, "childs": [97]}
	param_struct[500] = {"start_code": 500, "end_code": 504, "childs": [501, 502, 503]}
	return param_struct



## Reverse bounds query context retrieving root definition code
func find_parent_code_for_child(child_code: int) -> int:
	var param_struct = get_param_struct()
	for parent_code in param_struct.keys():
		var parent_data = param_struct[parent_code]
		if child_code in parent_data.childs:
			return parent_code
		if parent_data.end_code != -1 and child_code >= parent_data.start_code and child_code <= parent_data.end_code:
			return parent_code
	return -1



## Validates element inheritance active selection limits dependency bounds
func item_has_parent_selected(command: RPGEventCommand) -> bool:
	var selected_items = get_real_selected_items()
	if command.code in EDITABLE_CODES:
		return true
	var parent_code: int = find_parent_code_for_child(command.code)
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
			if selected_items.has(i):
				return true
			else:
				return false
	return false



## Queries command arrays formatting bounds indexes properties variants
func get_parent_code_data(index: int) -> Dictionary:
	var command: RPGEventCommand = data[index].command
	var command_data = {"start_index": -1, "end_index": -1, "childs": []}
	if command.indent > 0:
		for i in range(index - 1, -1, -1):
			var other_command: RPGEventCommand = data[i].command
			if other_command.indent == command.indent - 1 and other_command.code in EDITABLE_CODES:
				command_data.start_index = i
				break
	return command_data



## Drops content tracking dictionaries memory flushing limits arrays
func clear_all() -> void:
	data.clear()
	clear()
	if %BackControl:
		%BackControl.position.y = 0
		%BackControl.queue_redraw()



## Integrates formatted mapping loops rendering array properties logic visually
func set_data(_data: Array) -> void:
	var parent_scroll = get_node_or_null(scroll_container)
	var saved_v_scroll = 0.0
	var saved_h_scroll = 0.0
	if parent_scroll and parent_scroll is ScrollContainer:
		saved_v_scroll = parent_scroll.get_v_scroll_bar().value
		saved_h_scroll = parent_scroll.get_h_scroll_bar().value
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
	var hidden_indexes = {}
	var structural_markers_to_keep = [3, 5, 6, 7, 11, 22, 23, 25, 51, 97, 501, 502, 503, 504]
	var v_idx = 0
	for i in _data.size():
		var cmd = _data[i]
		var selection = _get_block_selection(i, _data)
		var is_expandable = selection.size() > 0
		if not is_expandable and i + 1 < _data.size() and _data[i + 1].indent > cmd.indent:
			is_expandable = true
			for j in range(i + 1, _data.size()):
				if _data[j].indent > cmd.indent:
					selection.append(j)
				else:
					break
		if is_expandable and not cmd.is_expanded:
			var struct = get_param_struct()
			var end_code = struct[cmd.code].end_code if struct.has(cmd.code) else -1
			for child_idx in selection:
				var child_cmd = _data[child_idx]
				if child_cmd.indent == cmd.indent and child_cmd.code == end_code:
					pass
				else:
					hidden_indexes[child_idx] = true
	for i in _data.size():
		var cmd = _data[i]
		var is_hidden = hidden_indexes.has(i)
		var selection = _get_block_selection(i, _data)
		var is_expandable = selection.size() > 0
		if not is_expandable and i + 1 < _data.size() and _data[i + 1].indent > cmd.indent:
			is_expandable = true
		var formatted_data = get_formated_command(cmd, font, font_size, align, v_separation, i, _data)
		formatted_data["is_expandable"] = is_expandable
		formatted_data["is_collapsed"] = not cmd.is_expanded
		data.append({
			"command": cmd,
			"formatted_data": formatted_data
		})
		if not is_hidden:
			total_size.x = max(total_size.x, formatted_data.total_size.x)
			total_size.y += formatted_data.total_size.y + v_separation
			add_item(" ")
			set_item_metadata(v_idx, i)
			v_idx += 1
	if main_container:
		var node = get_node(main_container)
		node.custom_minimum_size.x = max(total_size.x, get_parent().size.x)
		node.custom_minimum_size.y = max(total_size.y, get_parent().size.y)
	custom_minimum_size.x = max(total_size.x, get_parent().size.x)
	custom_minimum_size.y = max(total_size.y, get_parent().size.y)
	if custom_minimum_size.x > get_parent().size.x:
		custom_minimum_size.x += 20
	if custom_minimum_size.y > get_parent().size.y:
		custom_minimum_size.y += 20
	if parent_scroll and parent_scroll is ScrollContainer:
		if custom_minimum_size.x > parent_scroll.size.x:
			custom_minimum_size.x += 20
	size = custom_minimum_size
	size += Vector2(40, 40)
	if parent_scroll and parent_scroll is ScrollContainer:
		parent_scroll.get_v_scroll_bar().max_value = max(parent_scroll.get_v_scroll_bar().max_value, size.y)
		parent_scroll.get_v_scroll_bar().value = saved_v_scroll
		parent_scroll.get_h_scroll_bar().value = saved_h_scroll
	%BackControl.queue_redraw()



## Produces fallback formatting dictionaries limits tracking
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



## Retrieves element content reference safely preventing crashes arrays bounds
func get_item_data(data: Array, id: int) -> Variant:
	if data.size() > id:
		return data[id]
	else:
		return null



## Extracts specific index array attributes strings correctly formatted values
func get_item_data_name(data: Array, id: int) -> String:
	if data.size() > id:
		return data[id].name
	else:
		return "⚠ Invalid Data"



## Queries current scene elements generating generic readable lists identifiers strings
func get_event_name(id: int) -> String:
	var data = ["Player"]
	var node = get_tree().get_first_node_in_group("event_editor")
	if node:
		var events = node.events.get_events()
		data.append("This Event")
		for ev in events:
			data.append("%s: %s" % [ev.id, ev.name])
	if !node:
		return "Player"
	else:
		if data.size() > id:
			return data[id]
		else:
			return "⚠ Invalid Data"



## Gets database formatting properties mapped strings ids targets
func get_actor_name(id: int) -> String:
	var data = RPGSYSTEM.database.actors
	if id > 0 and data.size() > id:
		return "< %s: %s >" % [id, data[id].name]
	return "⚠ Invalid Data"



## Formats explicitly routing motion strings combinations visual identifiers outputs
func get_formated_movement_command(command: RPGMovementCommand) -> String:
	if !command:
		return ""
	match command.code:
		1:
			return("Move Down")
		4:
			return("Move Left")
		7:
			return("Move Right")
		10:
			return("Move Up")
		13:
			return("Move Southwest")
		16:
			return("Move Souteast")
		19:
			return("Move Northwest")
		22:
			return("Move Northeast")
		25:
			return("Random Movement")
		28:
			return("Move To The Player")
		31:
			return("Move Away From The Player")
		34:
			return("Step Ahead")
		37:
			return("Step Backward")
		40:
			return("Jump to %s" % command.parameters[0])
		43:
			return("Wait %s Seconds" % command.parameters[0])
		46:
			return("Z-Index =  %s" % command.parameters[0])
		2:
			return("Look Down")
		5:
			return("look Left")
		8:
			return("Look Right")
		11:
			return("Look Up")
		14:
			return("Turn 90º Left")
		17:
			return("Turn 90º Right")
		20:
			return("Turn 180º")
		23:
			return("Turn 90º Random")
		26:
			return("Look Random")
		29:
			return("Look Player")
		32:
			return("Look Opposite Player")
		35:
			var id = str(command.parameters[0]).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
			var switch_name = id + ": " + RPGSYSTEM.system.switches.get_item_name(command.parameters[0])
			return("Switch ON: %s" % switch_name)
		38:
			var id = str(command.parameters[0]).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
			var switch_name = id + ": " + RPGSYSTEM.system.switches.get_item_name(command.parameters[0])
			return("Switch OFF: %s" % switch_name)
		41:
			return("Change Speed To %s" % command.parameters[0])
		44:
			return("Delay Beetween Motion %s" % command.parameters[0])
		3:
			return("Walkink Animation ON")
		6:
			return("Walkink Animation OFF")
		9:
			return("Idle Animation ON")
		12:
			return("Idle Animation OFF")
		15:
			return("Fix Direction ON")
		18:
			return("Fix Direction OFF")
		21:
			return("Walk Through ON")
		24:
			return("Walk Through OFF")
		27:
			return("Invisible ON")
		30:
			return("Invisible OFF")
		33:
			return("Change Graphic To %s" % command.parameters[0])
		36:
			return("Change Opacity To %s" % command.parameters[0])
		39:
			var blend_modes = ["Mix", "Add", "Subtract", "Multiply", "Premult Alpha"]
			return("Change Blend To %s" % blend_modes[command.parameters[0]])
		42:
			return("Play SE %s" % command.parameters[0].get_file())
		45:
			return("Script: %s" % command.parameters[0])
		_:
			return ""



## Determines database formatting strings parameters variations properties elements bounds limits values combinations
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



## Renders complete format commands strings spacing variations variables values visual trees combinations logic
func get_formated_command(command: RPGEventCommand, font: Font, font_size: int, align: HorizontalAlignment, v_separation: int, index: int, full_data: Array) -> Dictionary:
	if command.code == 9999:
		var result = {}
		var bg_val = command.parameters.get("background_color", Color.DARK_GRAY)
		result["bg_color"] = bg_val if typeof(bg_val) == TYPE_COLOR else Color(bg_val)
		result["phrases"] = []
		result["phrases"].append({
			"texts": [{"text": command.parameters.get("text", "--- SEPARATOR ---"), "color": "#ffffff"}],
			"offset_y": default_text_offset_y
		})
		result["total_size"] = Vector2(0, font.get_string_size("A", align, -1, font_size).y)
		return result
	var result: Dictionary
	result["bg_color"] = event_line_color if index % 2 == 0 else odd_line_color
	result["phrases"] = []
	result["offset_y"] = 0
	var tabs: String = ""
	for level in range(1, command.indent + 1):
		var is_last_child = true
		for j in range(index + 1, full_data.size()):
			var next_cmd = _get_cmd(full_data, j)
			if next_cmd.indent < level:
				break
			if next_cmd.indent == level:
				if next_cmd.code != 0:
					is_last_child = false
				break
		if draw_vertical_guides:
			if level == command.indent:
				tabs += "       └─ " if is_last_child else "       ├─ "
			else:
				tabs += "          " if is_last_child else "       │  "
		else:
			tabs += "          "
	if code_format:
		var code_result = code_format.get_formatted_code(command, font, font_size, align, v_separation, index)
		if code_result.has("phrases") and code_result.phrases.size() > 0 and code_result.phrases[0].texts.size() > 0:
			var first_text = code_result.phrases[0].texts[0]
			first_text.text = tabs + first_text.text
			first_text.size = font.get_string_size(first_text.text, align, -1, font_size)
			var new_total_x = 0
			for phrase in code_result.phrases:
				var w = 0
				for obj in phrase.texts:
					w += obj.size.x
				new_total_x = max(new_total_x, w)
			code_result.total_size.x = new_total_x
		return code_result
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



## Returns logical valid properties check variables codes arrays components states variations limits bounds attributes identifiers targets checks inputs values parameters strings vectors combinations
func can_edit_event(event: RPGEventCommand) -> bool:
	return event.code in EDITABLE_CODES



## Exposes abstract parameters strings configurations logic components checks
func is_not_editable_event(event: RPGEventCommand) -> bool:
	return event.code in NO_EDITABLE_CODES



## Main component executing raw canvas coordinates rendering items strings limits bounds formatting states visual matrices operations mappings combinations vectors values parameters variables identifiers parameters dependencies arrays checks
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
	var items_selected = get_real_selected_items()
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
	var all_rows = []
	if item_count > 0:
		for v_idx in item_count:
			var real_index = get_item_metadata(v_idx)
			if real_index == null: continue
			var formatted_data = data[real_index].formatted_data
			rect = get_item_rect(v_idx)
			if rect.position.y + rect.size.y - offset_y < 0:
				continue
			elif rect.position.y - offset_y > parent.size.y:
				continue
			rect.size.x = parent.size.x
			all_rows.append({
				"type": "real",
				"visual_index": v_idx,
				"real_index": real_index,
				"rect": rect,
				"formatted_data": formatted_data
			})
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
	if all_rows.size() > 0:
		all_rows[-1].rect.size.y += 6
	for row in all_rows:
		rect = row.rect
		if row.type == "real":
			control.draw_rect(rect, row.formatted_data.bg_color)
		else:
			var fill_id = row.index
			if fill_id % 2 == 0:
				control.draw_rect(rect, event_line_color)
			else:
				control.draw_rect(rect, odd_line_color)
	if hovered_visual_index != -1:
		var real_hovered = get_item_metadata(hovered_visual_index)
		if real_hovered != null:
			var block_start = real_hovered
			var cmd = data[real_hovered].command
			var has_children = false
			if real_hovered + 1 < data.size() and data[real_hovered + 1].command.indent > cmd.indent:
				has_children = true
			var structural_blocks = [4, 10, 21, 24, 31, 34, 50, 57, 96, 500]
			var branch_codes = [3, 5, 6, 7, 11, 22, 23, 25, 32, 35, 51, 58, 97, 501, 502, 503, 504]
			if not cmd.code in structural_blocks and not cmd.code in branch_codes:
				for i in range(real_hovered - 1, -1, -1):
					if data[i].command.indent < cmd.indent:
						block_start = i
						break
			var selection = _get_block_selection(block_start, data)
			var start_v = get_visual_index(block_start)
			var end_v = start_v
			for child_idx in selection:
				var v = get_visual_index(child_idx)
				if v != -1:
					end_v = max(end_v, v)
			if start_v != -1 and end_v != -1:
				var start_rect = get_item_rect(start_v)
				var end_rect = get_item_rect(end_v)
				var hover_rect = start_rect.merge(end_rect)
				hover_rect.position.x = 0
				hover_rect.size.x = parent.size.x
				if hover_group_style:
					control.draw_style_box(hover_group_style, hover_rect)
				else:
					control.draw_rect(hover_rect, hover_color)
	for row in all_rows:
		if row.type == "real":
			var r_i = row.real_index
			var formatted_data = row.formatted_data
			rect = row.rect
			if items_selected.has(r_i):
				if enabled_action_cursor_texture:
					if can_edit_event(data[r_i].command) or item_has_parent_selected(data[r_i].command) or is_not_editable_event(data[r_i].command):
						control.draw_style_box(enabled_action_cursor_texture, rect)
					else:
						var rect2 = rect
						rect2.size.y -= 6 if row == all_rows[-1] else 0
						rect2.size.x = size.x - 42
						if main_container:
							var scrolling_panel = get_node(main_container)
							if scrolling_panel.get_v_scroll_bar().visible:
								rect2.size.x = max(scrolling_panel.size.x, rect2.size.x) - scrolling_panel.get_v_scroll_bar().size.x - 4
							if scrolling_panel.get_h_scroll_bar().visible:
								rect2.size.x = max(rect2.size.x, scrolling_panel.get_h_scroll_bar().max_value - 2)
						control.draw_style_box(no_editable_cursor_texture, rect)
			var x = rect.position.x + text_margin_left
			var y_pos = font.get_ascent() + rect.position.y
			if data[r_i].command.code == 9999:
				var txt = data[r_i].command.parameters.get("text", " SEPARATOR ")
				var txt_val = data[r_i].command.parameters.get("text_color", Color.WHITE)
				var txt_color = txt_val if typeof(txt_val) == TYPE_COLOR else Color(txt_val)
				if items_selected.has(r_i):
					txt_color = text_selected_color
				var text_size = font.get_string_size(txt, align, -1, font_size)
				var center_x = rect.position.x + (rect.size.x / 2.0) - (text_size.x / 2.0)
				var new_offset_y = formatted_data.phrases[0].offset_y
				var padding = 15.0
				var start_x = rect.position.x + text_margin_left + 10.0
				var end_x = rect.position.x + rect.size.x - text_margin_left - 10.0
				var line_y = rect.position.y + (rect.size.y / 2.0)
				if txt == "":
					control.draw_dashed_line(Vector2(start_x, line_y), Vector2(end_x, line_y), txt_color, 1.0, 4.0)
				else:
					control.draw_string_outline(font, Vector2(center_x, y_pos + new_offset_y), txt, align, -1, font_size, 4, Color.BLACK)
					control.draw_string(font, Vector2(center_x, y_pos + new_offset_y), txt, align, -1, font_size, txt_color)
					var end_left = center_x - padding
					if end_left > start_x:
						control.draw_dashed_line(Vector2(start_x, line_y), Vector2(end_left, line_y), txt_color, 1.0, 4.0)
					var start_right = center_x + text_size.x + padding
					if end_x > start_right:
						control.draw_dashed_line(Vector2(start_right, line_y), Vector2(end_x, line_y), txt_color, 1.0, 4.0)
				continue
			if data[r_i].command.ignore_command:
				var s = font.get_string_size(no_available_icon, align, -1, font_size)
				control.draw_string(
					font, Vector2(x, y_pos + font.get_ascent() - 4), no_available_icon,
					align, s.x, font_size
				)
				control.draw_style_box(ignored_command, rect)
				x += s.x + 4
			var start_height = 0
			for phrase in formatted_data.phrases:
				var start_width = 0
				for obj in phrase.texts:
					var displacement = obj.get("offset_x", 0)
					start_width += obj.size.x
					if obj == phrase.texts[0]:
						start_height += obj.size.y
					var default_idx = obj.text.find(default_text)
					var no_edit_idx = obj.text.find(default_no_editable_text)
					var text_color = Color(obj.color) if not data[r_i].command.ignore_command else disable_text_color
					if items_selected.has(r_i): text_color = text_selected_color
					if default_idx != -1:
						var prefix = obj.text.substr(0, default_idx)
						var suffix = obj.text.substr(default_idx + default_text.length())
						var icon_to_draw = default_text
						if formatted_data.get("is_expandable", false):
							icon_to_draw = collapsed_icon if formatted_data.get("is_collapsed", false) else expanded_icon
						control.draw_string(font, Vector2(x + displacement, y_pos + phrase.offset_y), prefix, align, -1, font_size, text_color)
						var prefix_width = font.get_string_size(prefix, align, -1, font_size).x
						control.draw_string(font, Vector2(x + displacement + prefix_width, y_pos + phrase.offset_y), icon_to_draw, align, -1, font_size, text_color)
						var icon_width = font.get_string_size(icon_to_draw, align, -1, font_size).x
						control.draw_string(font, Vector2(x + displacement + prefix_width + icon_width, y_pos + phrase.offset_y), suffix, align, -1, font_size, text_color)
					elif no_edit_idx != -1:
						var prefix = obj.text.substr(0, no_edit_idx)
						var suffix = obj.text.substr(no_edit_idx + default_no_editable_text.length())
						control.draw_string(font, Vector2(x + displacement, y_pos + phrase.offset_y), prefix, align, -1, font_size, text_color)
						var prefix_width = font.get_string_size(prefix, align, -1, font_size).x
						control.draw_string(font, Vector2(x + displacement + prefix_width, y_pos + phrase.offset_y), default_no_editable_text, align, -1, font_size, text_color)
						var icon_width = font.get_string_size(default_no_editable_text, align, -1, font_size).x
						control.draw_string(font, Vector2(x + displacement + prefix_width + icon_width, y_pos + phrase.offset_y), suffix, align, -1, font_size, text_color)
					else:
						control.draw_string(font, Vector2(x + displacement, y_pos + phrase.offset_y), obj.text, align, obj.size.x, font_size, text_color)
					x += obj.size.x
				max_page_size.x = max(max_page_size.x, start_width)
			max_page_size.y = max(max_page_size.y, start_height)
	if scroll_container:
		var node = get_node_or_null(scroll_container)
		if node and max_page_size.x > node.size.x:
			max_page_size.x += 240
	custom_minimum_size = max_page_size
	size = max_page_size
	for v_idx in item_count:
		rect = get_item_rect(v_idx)
		if rect.position.y + rect.size.y - offset_y < 0:
			continue
		elif rect.position.y - offset_y > parent.size.y:
			continue
		rect.size.x = parent.size.x
		rect.size.y = 1
		rect.position.y = rect.position.y + rect.size.y - 1
		control.draw_rect(rect, Color("#67676792"))
	if drag_preview_line != -1:
		var preview_rect: Rect2
		var indent_x: float = text_margin_left
		if drag_preview_line < item_count:
			preview_rect = get_item_rect(drag_preview_line)
			var r_idx = get_item_metadata(drag_preview_line)
			if r_idx != null:
				var cmd = data[r_idx].command
				var sep = "        "
				var tabs: String = ""
				for i in cmd.indent:
					tabs += sep
				if cmd.indent > 0 and tabs.length() > 0:
					tabs = tabs.substr(0, tabs.length() - 1)
				indent_x += font.get_string_size(tabs, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				var phrases = data[r_idx].formatted_data.phrases
				if phrases.size() > 0 and phrases[0].texts.size() > 0:
					indent_x += phrases[0].texts[0].get("offset_x", 0)
		else:
			if item_count > 0:
				preview_rect = get_item_rect(item_count - 1)
				preview_rect.position.y += preview_rect.size.y
				var r_idx = get_item_metadata(item_count - 1)
				if r_idx != null:
					var cmd = data[r_idx].command
					var sep = "        "
					var tabs: String = ""
					for i in cmd.indent:
						tabs += sep
					if cmd.indent > 0 and tabs.length() > 0:
						tabs = tabs.substr(0, tabs.length() - 1)
					indent_x += font.get_string_size(tabs, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
					var phrases = data[r_idx].formatted_data.phrases
					if phrases.size() > 0 and phrases[0].texts.size() > 0:
						indent_x += phrases[0].texts[0].get("offset_x", 0)
			else:
				preview_rect = Rect2(0, 0, size.x, 20)
		var y_pos = preview_rect.position.y - offset_y
		if y_pos >= 0 and y_pos <= parent.size.y:
			var secondary_color = Color(0.6, 0.6, 0.6, 0.8)
			var arrow_size = 4.0
			var start_x = text_margin_left
			control.draw_line(Vector2(start_x, y_pos - arrow_size), Vector2(start_x + arrow_size, y_pos), secondary_color, 2.0)
			control.draw_line(Vector2(start_x + arrow_size, y_pos), Vector2(start_x, y_pos + arrow_size), secondary_color, 2.0)
			var line_start_x = start_x + arrow_size + 4.0
			if line_start_x < indent_x:
				control.draw_line(Vector2(line_start_x, y_pos), Vector2(indent_x, y_pos), secondary_color, 2.0)
			var indicator_size = 6.0
			var rect_pos = Vector2(max(indent_x, line_start_x), y_pos - indicator_size / 2.0)
			control.draw_rect(Rect2(rect_pos, Vector2(indicator_size, indicator_size)), Color.YELLOW)
			control.draw_line(Vector2(rect_pos.x + indicator_size, y_pos), Vector2(size.x, y_pos), Color.YELLOW, 2.0)


## Fixes virtual offsets limits boundaries checks constraints variables dependencies layouts visually values matrices parameters bindings rendering arrays inputs structures states updates values combinations logic
func _change_back_position(value: float) -> void:
	pass
