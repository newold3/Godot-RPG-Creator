@tool
extends VBoxContainer



func get_class(): return "ColumnItemList"



#region Exports
@export_category("Row Colors")
## Set Color for odd row.
@export var odd_line_color: Color = Color("#e4ecf2") :
	set(value):
		odd_line_color = value
		queue_redraw()

## Set Color for event row.
@export var event_line_color: Color = Color(1, 1, 1) :
	set(value):
		event_line_color = value
		queue_redraw()

## Set the minimun size for the item list
@export var min_size: Vector2 = Vector2.ZERO

@export_category("Other Colors")
## Color used in the top menu text.
@export var top_bar_text_color: Color = Color.WHITE :
	set(value):
		top_bar_text_color = value
		queue_redraw()

## Style used to draw the top menu.
@export var top_bar_style: StyleBox :
	set(value):
		top_bar_style = value
		queue_redraw()

## Color used in the items added to the list.
@export var items_text_default_color: Color = Color.WHITE :
	set(value):
		items_text_default_color = value
		queue_redraw()

## Colors by columns. If there is a color in the indicated index, the text is drawn with that color, otherwise it will be drawn with the default color.
@export var columns_text_colors: PackedColorArray

## Style used to draw the cursor over the selected item.
@export var cursor_style: StyleBox :
	set(value):
		cursor_style = value
		queue_redraw()

## Style used to draw the cursor over the selected item.
@export var panel_style: StyleBox :
	set(value):
		panel_style = value
		queue_redraw()

@export_category("Columns Data")
## Set Columns Count
@export_range(0, 20, 1) var columns: int = 1 :
	set(value):
		columns = value
		names.resize(columns)
		sizes.resize(columns)
		queue_redraw()
		notify_property_list_changed()

## Set the name for the columns.
@export var show_column_names: bool = true:
	set(value):
		show_column_names = value
		var node = get_node_or_null("%TopMenu")
		if node:
			node.visible = value
	get: return show_column_names

## Set the name for the columns.
@export var names: PackedStringArray :
	set(value):
		names = value
		update_name_and_sizes()
	get: return names

## Set the size for the columns.[br]
## Leave this in 0 to autosize.
## Use any negative number so that the column adapts to the entire available width, taking into account the other columns.
@export var sizes: PackedInt32Array :
	set(value):
		sizes = value
		if not busy:
			update_name_and_sizes()
	get: return sizes

## Minimun size for the columns.
@export var min_column_size: int = 20 :
	set(value):
		min_column_size = value
		update_name_and_sizes()
	get: return min_column_size

## Margin beetween columns
@export var column_separator_margin: int = 2 :
	set(value):
		column_separator_margin = value
		queue_redraw()

## Separator column width
@export var column_separator_width: int = 2 :
	set(value):
		column_separator_width = value
		queue_redraw()

## Separator column color
@export var column_separator_color: Color = Color.BLACK :
	set(value):
		column_separator_color = value
		queue_redraw()

## Text margin left
@export var text_margin_left: int = 2 :
	set(value):
		text_margin_left = value
		queue_redraw()

@export_category("Items")
## Items added to the list
@export var items: Array[PackedStringArray] :
	set(value):
		items = value
		for item in items:
			if item.size() != columns:
				item.resize(columns)
		fill_items()
		notify_property_list_changed()
		queue_redraw()
	get: return items

## Placeholder text
@export var placeholder_text: String = "" :
	set(value):
		placeholder_text = value
		queue_redraw()

## Determines the specific behavior when multiple selection is enabled
@export_enum("Toggle=0", "Multi=1") var multiselection_style: int = 0 :
	set(value):
		multiselection_style = value
		_update_selection_mode()

## Enabled Multi-Selection
@export var enable_multiselection: bool = false :
	set(value):
		enable_multiselection = value
		_update_selection_mode()
		notify_property_list_changed()

## Show a checkbox when multiselection is enabled
@export var show_checkboxes: bool = false:
	set(value):
		show_checkboxes = value
		queue_redraw()

## Deselect when lost focus
@export var deselect_when_lost_focus: bool = false :
	set(value):
		deselect_when_lost_focus = value

## ItemList tooltip
@export_multiline var itemlist_tooltip: String = "" :
	set(value):
		itemlist_tooltip = value
		get_child(0).tooltip_text = value
		get_child(1).tooltip_text = value

## Tooltip for each item
@export_multiline var items_tooltip: PackedStringArray

@export var padding_start_char: String = ""
#endregion



#region InternalVariables
enum SortMode {
	NORMAL,
	ASCENDING,
	DESCENDING
}

var current_sort_column: int = -1
var current_sort_mode: SortMode = SortMode.NORMAL
var visual_to_real_id: PackedInt32Array = []
var real_to_visual_id: PackedInt32Array = []

var cache_columns_width: PackedInt32Array
var busy: bool = false

var font = get_theme_default_font()
var font_size = get_theme_font_size("font_size", "ItemList")
var align = HORIZONTAL_ALIGNMENT_LEFT

var can_drag: bool = false
var current_resize_column: int = -1
var current_drag_column: int = -1
var current_drag_target_column = -1
var dragging: bool = false
var click_position: float
var current_size: int

var disabled: bool = false

var queue_fill_delay: float = 0
var fill_delay_max_time: float = 0.01

var lock_items: PackedInt32Array = []

var default_tooltip: String
var current_tooltip: String

var custom_row_column = {}

var current_order: Array = []

var row_colors: Dictionary = {} 
var text_row_colors: Dictionary = {} 

var custom_icons: Dictionary = {} 

var lock_enter: bool
var space_enabled: bool = true

var current_filter: String = ""
var metadata_list: Dictionary = {}
var last_clicked_index: int = -1

const MINI_PADLOCK = preload("res://addons/CustomControls/Images/mini_padlock.png")
#endregion



#region Signals
signal item_activated(index: int)
signal item_selected(index: int)
signal multi_selected(index: int, selected: bool)
signal delete_pressed(indexes: PackedInt32Array)
signal copy_requested(indexes: PackedInt32Array)
signal cut_requested(indexes: PackedInt32Array)
signal duplicate_requested(indexes: PackedInt32Array)
signal paste_requested(index: int)
signal columns_setted()
signal button_right_pressed(indexes: PackedInt32Array)
#endregion



## Updates the ItemList selection behavior based on the exported variables.
func _update_selection_mode() -> void:
	var node: ItemList = get_node_or_null("%ItemList")
	if not node: return
		
	if enable_multiselection:
		if multiselection_style == 0:
			node.select_mode = ItemList.SelectMode.SELECT_TOGGLE
		else:
			node.select_mode = ItemList.SelectMode.SELECT_MULTI
	else:
		node.select_mode = ItemList.SELECT_SINGLE



## Built-in ready function.
func _ready() -> void:
	var top_menu = get_node_or_null("%TopMenu")
	
	if top_menu:
		for child in top_menu.get_children():
			child.queue_free()
			
	%ItemList.draw.connect(_on_itemlist_draw)
	draw.connect(%ItemList.queue_redraw)
	draw.connect(%TopMenu.queue_redraw)
	%TopMenu.draw.connect(_on_top_menu_draw)
	%ItemList.item_activated.connect(func(index: int): item_activated.emit(_get_real_id(index)) )
	%ItemList.item_selected.connect(_on_internal_item_selected)
	%ItemList.multi_selected.connect(_on_internal_multi_selected)
	%ItemList.gui_input.connect(_on_itemlist_gui_input)
	%ItemList.focus_exited.connect(_on_focus_exited)
	%TopMenu.gui_input.connect(_on_top_gui_input)
	
	update_name_and_sizes()
	fill_items()
	
	set_process(false)
	default_tooltip = itemlist_tooltip
	resized.connect(_on_resized)



func _on_internal_item_selected(index: int) -> void:
	var real_id = _get_real_id(index)
	
	if not enable_multiselection:
		item_selected.emit(real_id)
		multi_selected.emit(real_id, true)


func _on_internal_multi_selected(index: int, selected: bool) -> void:
	var real_id = _get_real_id(index)
	
	if enable_multiselection:
		multi_selected.emit(real_id, selected)


## Triggers automatically when the Control visibility changes (fixes hidden tabs size issue).
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			call_deferred("force_update_sizes")



## Setup the toggled selection mode for the item list.
func set_toggled_mode(value: bool) -> void:
	var node = %ItemList
	if value:
		node.select_mode = ItemList.SelectMode.SELECT_TOGGLE
	else:
		node.select_mode = ItemList.SelectMode.SELECT_SINGLE



## Setup the text filter for highlighting elements.
func set_filter(filter: String) -> void:
	current_filter = filter



## Handle resize callback.
func _on_resized() -> void:
	if busy: return
	busy = true
	call_deferred("update_name_and_sizes")
	await get_tree().process_frame
	queue_redraw()
	set_deferred("busy", false)



## Handle parent resize callback.
func _on_parent_resized() -> void:
	if busy: return
	call_deferred("update_name_and_sizes")



## Forces sizes to be updated protecting against hidden rendering bounds.
func force_update_sizes() -> void:
	if busy: return
	if is_inside_tree():
		await get_tree().process_frame
	var p = get_parent()
	if p and p is Control:
		size.x = p.size.x
		size.y = p.size.y
	update_name_and_sizes()



## Disconnects the gui input from the internal item list.
func disconnect_gui_input() -> void:
	if %ItemList.gui_input.is_connected(_on_itemlist_gui_input):
		%ItemList.gui_input.disconnect(_on_itemlist_gui_input)



## Applies a custom color or stylebox for a specific row index (real id).
func add_row_color(index: int, color: Variant) -> void:
	row_colors[index] = color



## Restores row color logic for a specific real id row.
func restore_row_color(index: int) -> void:
	if row_colors.size() > index and index >= 0:
		var current_line_color = odd_line_color if index % 2 else event_line_color
		row_colors[index] = current_line_color



## Applies a custom text color for a specific row index (real id).
func add_row_text_color(index: int, color: Color) -> void:
	text_row_colors[index] = color



## Gets the custom assigned texture for a real id index.
func add_custom_icon(index: int, icon: Variant) -> void:
	var current_icon = null
	if icon is String:
		if ResourceLoader.exists(icon):
			var img = ResourceLoader.load(icon)
			current_icon = img
	elif icon is Texture:
		current_icon = icon
	
	if current_icon:
		custom_icons[index] = current_icon



## Stores the locked items array.
func set_lock_items(p_items: PackedInt32Array) -> void:
	lock_items = p_items



## Deselects all items if the control loses focus.
func _on_focus_exited():
	if deselect_when_lost_focus:
		%ItemList.deselect_all()



## Built-in process callback for queue draw optimizations.
func _process(delta: float) -> void:
	if queue_fill_delay > 0:
		queue_fill_delay -= delta
		if queue_fill_delay <= 0:
			queue_fill_delay = 0
			set_process(false)
			fill_items()
			queue_redraw()
			await get_tree().process_frame
			columns_setted.emit()



## Returns the vertical scrollbar.
func get_v_scroll_bar() -> VScrollBar:
	return %ItemList.get_v_scroll_bar()



## Fills the items processing current sorting mode.
func fill_items() -> void:
	_apply_sorting()
	
	var node = %ItemList
	node.clear()
	for item in items:
		node.add_item(" ")
		
	if placeholder_text.length() > 0:
		node.add_item(" ")
	
	queue_redraw()



## Custom accumulator for widths.
func sum(accum, number):
	return accum + number



## Updates names and calculates dynamic sizes mapped precisely.
func update_name_and_sizes(step = 50) -> void:
	if names.size() != columns:
		names.resize(columns)
	if sizes.size() != columns:
		sizes.resize(columns)
	if current_order.size() != columns:
		current_order.resize(columns)
		for i in columns:
			current_order[i] = i
			
	cache_columns_width.clear()
	
	if !names or !sizes:
		return
		
	var total_width = size.x
	if get_node_or_null("%ItemList"):
		total_width = get_parent().size.x if get_parent() is Control else size.x
		
	var extra_size = (column_separator_margin * 2 + column_separator_width) * columns
	var available_width = total_width - extra_size
	
	var fixed_width_total = 0
	var negative_columns = []
	var temp_widths = []
	temp_widths.resize(columns)
	
	for i in columns:
		var real_index = current_order[i]
		if sizes[real_index] < 0:
			negative_columns.append(real_index)
			temp_widths[real_index] = 0
		elif sizes[real_index] == 0:
			if columns == 1 and get_node_or_null("%ItemList"):
				temp_widths[real_index] = available_width
				fixed_width_total += available_width
			else:
				var s = font.get_string_size(names[real_index], align, -1, font_size).x
				var width = max(min_column_size, s)
				temp_widths[real_index] = width
				fixed_width_total += width
		else:
			var width = max(min_column_size, sizes[real_index])
			temp_widths[real_index] = width
			fixed_width_total += width
			
	if negative_columns.size() > 0:
		fixed_width_total += column_separator_margin * (columns + 1) + column_separator_width * (columns + 1)
		var remaining_width = available_width - fixed_width_total
		var width_per_negative_column = max(min_column_size, remaining_width / negative_columns.size())
		
		for real_index in negative_columns:
			temp_widths[real_index] = width_per_negative_column
			
	cache_columns_width = PackedInt32Array(temp_widths)
	
	if get_node_or_null("%TopMenu"):
		var h = font.get_string_size(" ", 0, -1, font_size).y
		%TopMenu.set_deferred("size", Vector2.ZERO)
		%TopMenu.custom_minimum_size.y = h
		%TopMenu.custom_minimum_size.x = total_width
		
	if size.x < min_size.x: size.x = min_size.x
	if size.y < min_size.y: size.y = min_size.y
	
	queue_redraw()



## Clears the list and resets internal variables.
func clear() -> void:
	set_process(true)
	queue_fill_delay = fill_delay_max_time
	custom_row_column.clear()
	row_colors.clear()
	custom_icons.clear()
	items.clear()
	last_clicked_index = -1
	%ItemList.clear()



## Adds a column to the item list dynamically.
func add_column(contents: PackedStringArray) -> void:
	items.append(contents)
	queue_fill_delay = fill_delay_max_time
	set_process(true)



## Returns the entire row representation from the data set.
func get_column(id: int) -> PackedStringArray:
	if items.size() > id:
		return items[id]
	return []



## Handles GUI input for the internal ItemList.
func _on_itemlist_gui_input(event: InputEvent) -> void:
	if %ItemList.get_item_count() == 0:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var mouse_pos = %ItemList.get_local_mouse_position()
		var index = %ItemList.get_item_at_position(mouse_pos, true)
		
		if index != -1:
			var real_id = _get_real_id(index)
			
			if event.double_click:
				%ItemList.item_activated.emit(index)
				get_viewport().set_input_as_handled()
				return
				
			if enable_multiselection:
				if event.shift_pressed or event.ctrl_pressed:
					if last_clicked_index == -1:
						last_clicked_index = index
						
					var start_idx = min(last_clicked_index, index)
					var end_idx = max(last_clicked_index, index)
					var all_selected = true
					
					for i in range(start_idx, end_idx + 1):
						if not %ItemList.is_selected(i):
							all_selected = false
							break
							
					for i in range(start_idx, end_idx + 1):
						var local_real_id = _get_real_id(i)
						
						if all_selected:
							%ItemList.deselect(i)
							multi_selected.emit(local_real_id, false)
						else:
							%ItemList.select(i, false)
							multi_selected.emit(local_real_id, true)
							
					last_clicked_index = index
					get_viewport().set_input_as_handled()
					return
				else:
					last_clicked_index = index
					
					if show_checkboxes:
						var checkbox_width = 24
						
						if mouse_pos.x <= checkbox_width + text_margin_left:
							if %ItemList.is_selected(index):
								%ItemList.deselect(index)
								multi_selected.emit(real_id, false)
							else:
								%ItemList.select(index, false)
								multi_selected.emit(real_id, true)
								
							get_viewport().set_input_as_handled()
							return
			else:
				%ItemList.select(index, true)
				item_selected.emit(real_id)
				multi_selected.emit(real_id, true)
				get_viewport().set_input_as_handled()
				return
				
	if %ItemList.is_anything_selected() and event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			delete_pressed.emit(get_selected_ids())
		elif event.is_ctrl_pressed():
			if event.keycode == KEY_C:
				copy_requested.emit(get_selected_ids())
			elif event.keycode == KEY_X:
				cut_requested.emit(get_selected_ids())
			elif event.keycode == KEY_V:
				var sel_items = get_selected_ids()
				paste_requested.emit(sel_items[-1] if sel_items.size() > 0 else -1)
			elif event.keycode == KEY_D:
				duplicate_requested.emit(get_selected_ids())
		elif event.keycode == KEY_UP:
			var indexes = %ItemList.get_selected_items()
			
			if indexes.size() > 0:
				var new_index = max(0, indexes[0] - 1)
				%ItemList.select(new_index)
				var new_real_id = _get_real_id(new_index)
				
				if enable_multiselection:
					multi_selected.emit(new_real_id, true)
				else:
					item_selected.emit(new_real_id)
					multi_selected.emit(new_real_id, true)
			else:
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			var indexes = %ItemList.get_selected_items()
			
			if indexes.size() > 0:
				var new_index = min(%ItemList.get_item_count() - 1, indexes[-1] + 1)
				%ItemList.select(new_index)
				var new_real_id = _get_real_id(new_index)
				
				if enable_multiselection:
					multi_selected.emit(new_real_id, true)
				else:
					item_selected.emit(new_real_id)
					multi_selected.emit(new_real_id, true)
			else:
				get_viewport().set_input_as_handled()
		elif space_enabled and event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			var index = %ItemList.get_selected_items()[-1]
			%ItemList.item_activated.emit(index)
			
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		var index = %ItemList.get_item_at_position(%ItemList.get_local_mouse_position(), true)
		
		if index != -1:
			var selected_items_amount = %ItemList.get_selected_items().size()
			
			if selected_items_amount <= 1:
				%ItemList.select(index)
				
			button_right_pressed.emit(get_selected_ids())
			
	if event is InputEventMouseMotion:
		get_custom_tooltip()



## Switch toggle space input.
func disable_space_input(value: bool) -> void:
	space_enabled = !value



## Retrieves tooltip considering mapped item order.
func get_custom_tooltip() -> String:
	var result = ""
	var old_tooltip = current_tooltip
	var visual_index = %ItemList.get_item_at_position(%ItemList.get_local_mouse_position(), true)
	
	if visual_index >= 0:
		var real_id = _get_real_id(visual_index)
		if items_tooltip.size() > real_id and items_tooltip[real_id] and items_tooltip[real_id].length() > 0:
			result = items_tooltip[real_id]
		elif default_tooltip and default_tooltip.length() > 0:
			result = default_tooltip
	else:
		if default_tooltip and default_tooltip.length() > 0:
			result = default_tooltip
	
	current_tooltip = result
	
	if old_tooltip and old_tooltip != current_tooltip:
		%ItemList.tooltip_changed.emit()
	
	return current_tooltip



## Handles Top Menu Interactions mapping visually the hovers and resolving sorting clicks or drag events mathematically.
func _on_top_gui_input(event: InputEvent) -> void:
	var extra_size = column_separator_margin * 2 + column_separator_width
	var total_width = size.x
	if get_node_or_null("%ItemList"):
		total_width = get_parent().size.x if get_parent() is Control else size.x
		
	if event is InputEventMouseMotion:
		if dragging and current_resize_column != -1:
			sizes[current_resize_column] = max(min_column_size, current_size + event.position.x - click_position)
			update_name_and_sizes()
			%TopMenu.queue_redraw()
			%ItemList.queue_redraw()
		elif current_drag_column != -1:
			current_drag_target_column = -1
			var x = 0
			for i in range(columns):
				var real_index = current_order[i]
				if i > 0:
					x += extra_size
					
				var col_width = cache_columns_width[real_index]
				if i == columns - 1:
					col_width = max(col_width, total_width - x)
					
				x += col_width
				if event.position.x <= x:
					current_drag_target_column = i
					break
			%TopMenu.queue_redraw()
		else:
			var target_cursor = Control.CURSOR_ARROW
			can_drag = false
			current_resize_column = -1
			var hovered_header_col = -1
			
			var x = 0
			for i in range(columns):
				var real_index = current_order[i]
				var col_width = cache_columns_width[real_index]
				if i == columns - 1:
					col_width = max(col_width, total_width - x)
					
				if i > 0:
					var handle_start = x - 4
					var handle_end = x + extra_size + 4
					
					if event.position.x >= handle_start and event.position.x <= handle_end:
						target_cursor = Control.CURSOR_HSIZE
						can_drag = true
						current_resize_column = current_order[i-1]
						break
						
					x += extra_size
					
				var header_start = x
				var header_end = x + col_width
				
				if event.position.x > header_start + 4 and event.position.x < header_end - 4:
					hovered_header_col = real_index
					
				x += col_width
				
			if not can_drag and hovered_header_col != -1:
				target_cursor = Control.CURSOR_POINTING_HAND
				
			if %TopMenu.mouse_default_cursor_shape != target_cursor:
				%TopMenu.mouse_default_cursor_shape = target_cursor
				
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			if can_drag:
				dragging = true
				click_position = event.position.x
				current_size = cache_columns_width[current_resize_column]
				sizes[current_resize_column] = current_size
			else:
				current_drag_column = -1
				var x = 0
				
				for i in range(columns):
					var real_index = current_order[i]
					var col_width = cache_columns_width[real_index]
					if i == columns - 1:
						col_width = max(col_width, total_width - x)
						
					if i > 0:
						x += extra_size
						
					if event.position.x >= x and event.position.x <= x + col_width:
						current_drag_column = i
						current_drag_target_column = current_drag_column
						break
						
					x += col_width
		else:
			dragging = false
			
			if current_drag_column != -1 and current_drag_target_column != -1:
				if current_drag_column != current_drag_target_column:
					busy = true
					var temp_order = current_order[current_drag_column]
					current_order[current_drag_column] = current_order[current_drag_target_column]
					current_order[current_drag_target_column] = temp_order
					busy = false
					
					await get_tree().process_frame
					update_name_and_sizes()
					%TopMenu.queue_redraw()
					%ItemList.queue_redraw()
				else:
					var real_col = current_order[current_drag_column]
					
					if current_sort_column == real_col:
						if current_sort_mode == SortMode.NORMAL:
							current_sort_mode = SortMode.ASCENDING
						elif current_sort_mode == SortMode.ASCENDING:
							current_sort_mode = SortMode.DESCENDING
						else:
							current_sort_mode = SortMode.NORMAL
					else:
						current_sort_column = real_col
						current_sort_mode = SortMode.ASCENDING
						
					queue_fill_delay = fill_delay_max_time
					set_process(true)
					%TopMenu.queue_redraw()
					
			current_drag_column = -1
			current_drag_target_column = -1



## Property Validation.
func _validate_property(property):
	return



## Top Menu Drawing Routine mapping the visual sorting marks.
func _on_top_menu_draw() -> void:
	var node = %TopMenu
	if !node: return
	
	var h = font.get_string_size(" ", 0, -1, font_size).y
	var rect = Rect2(Vector2.ZERO, Vector2(size.x, h))
	
	if top_bar_style:
		node.draw_style_box(top_bar_style, rect)
	else:
		node.draw_rect(rect, event_line_color, true)
	
	if names.size() > 0 and top_bar_style:
		var x = 0
		var y = font.get_ascent()
		for i in names.size():
			var real_index = current_order[i]
			if i > 0:
				x += column_separator_margin
				var rect2 = Rect2(Vector2(x, 0), Vector2(column_separator_width, h))
				node.draw_rect(rect2, column_separator_color, true)
				x += column_separator_margin + column_separator_width
				
			var color = Color.BLUE if current_drag_column == i else top_bar_text_color
			var text_width = cache_columns_width[real_index] if i < names.size() - 1 else - 1
			
			var text_to_draw = names[real_index]
			if current_sort_column == real_index:
				if current_sort_mode == SortMode.ASCENDING:
					text_to_draw += " ▼"
				elif current_sort_mode == SortMode.DESCENDING:
					text_to_draw += " ▲"
					
			node.draw_string(
				font,
				Vector2(x + text_margin_left, y),
				text_to_draw,
				HORIZONTAL_ALIGNMENT_LEFT,
				text_width,
				font_size,
				color
			)
			x += cache_columns_width[real_index]
	
	if current_drag_column != -1 and current_drag_target_column != -1:
		rect = Rect2(0, 0, column_separator_width * 4, h)
		if current_drag_column != current_drag_target_column:
			var x = 0
			for i in range(0, current_drag_target_column, 1):
				var real_index = current_order[i]
				x += cache_columns_width[real_index]
			rect.position.x = x
			if current_drag_target_column > current_drag_column:
				if current_drag_target_column == cache_columns_width.size() - 1:
					rect.position.x = size.x - column_separator_width * 4
				else:
					var real_index = current_order[current_drag_target_column]
					rect.position.x += cache_columns_width[real_index]
			node.draw_rect(rect, Color.ORANGE, true)



## Internal Draw handling mapping visual space into real backend representation values.
func _on_itemlist_draw() -> void:
	if busy:
		return
	busy = true
	
	var node = %ItemList
	if !node: return
	
	var rect: Rect2
	var item_selected: PackedInt32Array = node.get_selected_items()
	
	var v_separation = node.get("theme_override_constants/v_separation")
	if !v_separation and v_separation != 0:
		v_separation = 2
	
	var offset = -node.get_v_scroll_bar().value
	
	if cache_columns_width.size() != columns:
		update_name_and_sizes()
	
	var start_padding = 0 if padding_start_char.is_empty() else font.get_string_size(padding_start_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	var draw_checkbox = show_checkboxes and enable_multiselection
	var checkbox_checked_tex: Texture2D
	var checkbox_unchecked_tex: Texture2D
	var checkbox_width = 0
	
	if draw_checkbox:
		checkbox_checked_tex = get_theme_icon("checked", "CheckBox")
		checkbox_unchecked_tex = get_theme_icon("unchecked", "CheckBox")
		checkbox_width = 24

	if node.get_item_count() > 0:
		custom_minimum_size.x = 0
		for index in node.get_item_count():
			var real_id = _get_real_id(index)
			var is_placeholder = index == node.get_item_count() - 1 and placeholder_text.length() > 0
			
			rect = node.get_item_rect(index)
			rect.position.y += offset
			var current_line_color = odd_line_color if index % 2 else event_line_color
			var row_color = row_colors.get(real_id, current_line_color)
			
			if rect.position.y + rect.size.y + v_separation < 0:
				continue
			elif rect.position.y + rect.size.y > size.y:
				break
				
			if index in item_selected and cursor_style:
				node.draw_style_box(cursor_style, rect)
			else:
				if row_color is Color:
					node.draw_rect(rect, row_color, true)
				elif row_color is StyleBox:
					node.draw_style_box(row_color, rect)
			
			var x = 0
			var y = font.get_ascent()
			
			if draw_checkbox:
				var icon_to_draw = checkbox_checked_tex if index in item_selected else checkbox_unchecked_tex
				if icon_to_draw:
					var icon_y = rect.position.y + (rect.size.y - icon_to_draw.get_height()) / 2
					var icon_rect = Rect2(Vector2(text_margin_left, icon_y), icon_to_draw.get_size())
					node.draw_texture_rect(icon_to_draw, icon_rect, false)

			var row_icon_size = 0
			if not is_placeholder:
				if lock_items.has(real_id):
					row_icon_size = 24
				elif custom_icons.has(real_id):
					row_icon_size = custom_icons[real_id].get_size().x + 2
			
			var custom_icon_x_offset = 2
			if draw_checkbox:
				custom_icon_x_offset += checkbox_width

			if not is_placeholder:
				if lock_items.has(real_id):
					var icon_rect = Rect2(Vector2(custom_icon_x_offset, rect.position.y), Vector2(20, 20))
					node.draw_texture_rect(MINI_PADLOCK, icon_rect, false)
				elif custom_icons.has(real_id):
					var icon_rect = Rect2(Vector2(custom_icon_x_offset, rect.position.y), custom_icons[real_id].get_size())
					node.draw_texture_rect(custom_icons[real_id], icon_rect, false)

			if not is_placeholder and real_id < items.size():
				for i in columns:
					var real_index = current_order[i]
					
					if i > 0:
						x += column_separator_margin * 2 + column_separator_width
					
					if i < items[real_id].size():
						var text_size = -1
						if i != items[real_id].size() - 1:
							text_size = cache_columns_width[real_index]
							if i == 0:
								text_size = max(5, text_size - row_icon_size - checkbox_width)
							else:
								text_size = max(5, text_size)
						
						var current_text_color = items_text_default_color
						var key = str([real_id, real_index])
						if text_row_colors.has(real_id):
							current_text_color = text_row_colors[real_id]
						else:
							if custom_row_column.has(key) and custom_row_column[key] is Color:
								current_text_color = custom_row_column[key]
							elif columns_text_colors.size() > real_index and columns_text_colors[real_index] is Color:
								current_text_color = columns_text_colors[real_index]
						
						var text_x = x + text_margin_left
						
						if i == 0:
							text_x += row_icon_size + checkbox_width
						
						var text = items[real_id][real_index]
						var text_y = rect.position.y + y
						
						if not padding_start_char.is_empty():
							if not text.begins_with(padding_start_char):
								text_x += start_padding
								
						node.draw_string(
							font,
							Vector2(text_x, text_y),
							text,
							HORIZONTAL_ALIGNMENT_LEFT,
							text_size,
							font_size,
							current_text_color
						)
						
						if current_filter.length() > 0:
							var find_pos = text.to_lower().find(current_filter.to_lower())
							if find_pos != -1:
								var offset_x = font.get_string_size(text.substr(0, find_pos), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
								var match_width = font.get_string_size(text.substr(find_pos, current_filter.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
								var highlight_rect = Rect2(text_x + offset_x, rect.position.y, match_width, rect.size.y)
								node.draw_rect(highlight_rect, Color(1, 1, 0, 0.3))

					if i == columns - 1 and items.size() > real_id and items[real_id].size() > real_index and items[real_id][real_index].length() > 0:
						var text_width = font.get_string_size(items[real_id][real_index], 0, -1, font_size).x
						var cur_size = x + text_width
						custom_minimum_size.x = max(custom_minimum_size.x, cur_size)
					
					x += cache_columns_width[real_index]
						
			elif is_placeholder:
				node.draw_string(
					font,
					Vector2(text_margin_left, rect.position.y + y),
					placeholder_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					font_size,
					Color("#96969668") if !index in item_selected else Color.WHITE
				)
		
		if rect.position.y + rect.size.y + v_separation < size.y:
			var last_id = node.item_count
			while rect.position.y - rect.size.y - v_separation < size.y:
				rect.position.y += v_separation + rect.size.y
				if last_id % 2 == 0:
					node.draw_rect(rect, event_line_color)
				else:
					node.draw_rect(rect, odd_line_color)
				last_id += 1
	else:
		var sy = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y
		var i = 1
		rect.position = Vector2.ZERO
		rect.size = Vector2(size.x, sy)
		while rect.position.y < size.y + v_separation:
			if i % 2 == 0:
				node.draw_rect(rect, event_line_color)
			else:
				node.draw_rect(rect, odd_line_color)
			if i == 1 and placeholder_text.length() > 0:
				node.draw_string(
					font,
					Vector2(text_margin_left, font.get_ascent()),
					placeholder_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					font_size,
					Color("#96969668")
				)
			rect.position.y += v_separation + sy
			i += 1
			
	busy = false



## Modify the block condition.
func set_disabled(value: bool) -> void:
	disabled = value
	if value:
		set_process_mode(Node.PROCESS_MODE_DISABLED)
		modulate.a = 0.6
	else:
		set_process_mode(Node.PROCESS_MODE_INHERIT)
		modulate.a = 1.0



## Disables clicking for the specific item relying on real id logic mapping.
func set_item_selectable(index: int, value: bool) -> void:
	var vis_id = _get_visual_id(index)
	%ItemList.set_item_selectable(vis_id, value)



## Consult click status based on real id index.
func is_item_selectable(index: int) -> bool:
	var vis_id = _get_visual_id(index)
	return %ItemList.is_item_selectable(vis_id)



## Final Draw hook.
func _draw() -> void:
	if panel_style:
		var rect = get_rect()
		rect.position = Vector2.ZERO
		draw_style_box(panel_style, rect)



## Returns real ID selection converting visual to original index mapping.
func get_selected_ids() -> PackedInt32Array:
	var visual_ids = %ItemList.get_selected_items()
	var real_ids = PackedInt32Array()
	for vid in visual_ids:
		real_ids.append(_get_real_id(vid))
	return real_ids



## Backwards support wrapping inner select call array.
func get_selected_items() -> PackedInt32Array:
	return get_selected_ids()



## Wrapper applying mapping over real id items to their visual index select counterpart.
func set_selected_items(ids: PackedInt32Array) -> void:
	var node = %ItemList
	for id in ids:
		var vis_id = _get_visual_id(id)
		node.select(vis_id, false)



## Retrieves the internal node reference directly.
func get_item_list() -> ItemList:
	return %ItemList as ItemList



## Gets item main text identifier based on real mapping layout structure.
func get_item_name(id: int) -> String:
	if id >= 0 and id < items.size():
		return items[id][0]
	return "item " + str(id)



## Returns inner element quantities based on items data context length.
func get_item_count() -> int:
	return items.size()



## Fixes parent bounds based on child internal node change notification.
func _on_item_list_item_rect_changed() -> void:
	var parent = get_parent()
	if parent and parent is Container:
		parent.queue_sort()



## Metadata external injections handler pointing to the proper data slot.
func set_item_metadata(id: int, metadata: Variant) -> void:
	if id < 0:
		id = items.size() + id
	id = clamp(id, 0, items.size() - 1)
	metadata_list[id] = metadata



## Obtains metadata logic pointers for external script management.
func get_item_metadata(id: int) -> Variant:
	if id < 0:
		id = items.size() + id
	id = clamp(id, 0, items.size() - 1)
	return metadata_list.get(id, null)



## Helper selecting directly using original backend real array id.
func select(index: int, single: bool = true) -> void:
	var vis_id = _get_visual_id(index)
	if %ItemList.get_item_count() > vis_id and vis_id != -1:
		%ItemList.select(vis_id, single)
		%ItemList.ensure_current_is_visible()
		if vis_id == %ItemList.get_item_count() - 2 and placeholder_text.length() > 0:
			await get_tree().process_frame
			%ItemList.get_v_scroll_bar().value = %ItemList.get_v_scroll_bar().max_value



## Selects the entire set mapping original real mapped logic internally context bounds constraints correctly translated down dynamically into the main drawing process safely.
func select_current() -> void:
	var idxs = %ItemList.get_selected_items()
	deselect_all()
	for idx in idxs:
		%ItemList.select(idx, false)
	%ItemList.grab_focus()



## Deselect single element from data representation properly targeting mapped target.
func deselect(index: int) -> void:
	var vis_id = _get_visual_id(index)
	%ItemList.deselect(vis_id)



## Multiple batch array selector over real id structure conversion parameters into direct draw references mapping.
func select_items(indexes: PackedInt32Array) -> void:
	var last_vis_id = 0
	for index in indexes:
		var vis_id = _get_visual_id(index)
		if %ItemList.get_item_count() > vis_id:
			%ItemList.select(vis_id, false)
			last_vis_id = vis_id
	
	%ItemList.ensure_current_is_visible()
	if last_vis_id == %ItemList.get_item_count() - 2 and placeholder_text.length() > 0:
		await get_tree().process_frame
		%ItemList.get_v_scroll_bar().value = %ItemList.get_v_scroll_bar().max_value



## Clear current internal control structure selection logic safely directly targeted properly downwards dynamically properly updated context execution bindings perfectly encapsulated properly bounds checked accurately.
func deselect_all() -> void:
	%ItemList.deselect_all()



## Target and apply full selections upon internal drawing backend limits safely mapped appropriately against real structures arrays.
func select_all() -> void:
	var node = %ItemList
	for i in node.get_item_count():
		%ItemList.select(i, false)



## Calculates bounding logic using internal map conversion pointers dynamically updated properly correctly targeting constraints context bounds carefully over mapped limits.
func get_item_at_position(pos: Vector2) -> int:
	var visual_id = %ItemList.get_item_at_position(pos, true)
	return _get_real_id(visual_id)



## Fetches drawing rectangles over translated structure mapped bindings correctly assigned dynamically dynamically processed targeting structures.
func get_item_rect(index: int) -> Rect2:
	var vis_id = _get_visual_id(index)
	return %ItemList.get_item_rect(vis_id)



## Scrolls the list to ensure the given item index is visible.
func ensure_current_is_visible(index: int) -> void:
	var vis_id = _get_visual_id(index)
	var node = %ItemList
	if vis_id < 0 or vis_id >= node.get_item_count():
		return
	var scroll = node.get_v_scroll_bar()
	var rect = node.get_item_rect(vis_id)
	var list_height = node.size.y
	var item_top = rect.position.y
	var item_bottom = item_top + rect.size.y
	if item_top < scroll.value:
		scroll.value = item_top
	elif item_bottom > scroll.value + list_height:
		scroll.value = item_bottom - list_height



## Assigns the specific visual header column naming parameter directly updated on bounds mappings mapping safely properly bounds limits structurally mapped directly context bounds correctly.
func set_column_name(column_id: int, new_text: String) -> void:
	if column_id >= 0 and names.size() > column_id:
		names[column_id] = new_text
		queue_redraw()



#region SortingHelpers
## Maps a visual list index to the real underlying item ID.
func _get_real_id(visual_index: int) -> int:
	if visual_index >= 0 and visual_index < visual_to_real_id.size():
		return visual_to_real_id[visual_index]
	return visual_index



## Maps a real underlying item ID to its current visual list index.
func _get_visual_id(real_id: int) -> int:
	if real_id >= 0 and real_id < real_to_visual_id.size():
		return real_to_visual_id[real_id]
	return real_id



## Applies the current sorting mode to the item list using natural sorting and updates index maps.
func _apply_sorting() -> void:
	var count = items.size()
	visual_to_real_id.resize(count)
	real_to_visual_id.resize(count)
	
	var temp_array: Array = []
	for i in count:
		temp_array.append(i)
		
	if current_sort_mode != SortMode.NORMAL and current_sort_column >= 0 and current_sort_column < columns:
		temp_array.sort_custom(func(a, b):
			var text_a = items[a][current_sort_column] if items[a].size() > current_sort_column else ""
			var text_b = items[b][current_sort_column] if items[b].size() > current_sort_column else ""
			
			if text_a == text_b:
				return a < b
			
			if text_a.is_valid_float() and text_b.is_valid_float():
				if current_sort_mode == SortMode.ASCENDING:
					return text_a.to_float() < text_b.to_float()
				else:
					return text_a.to_float() > text_b.to_float()
			
			if current_sort_mode == SortMode.ASCENDING:
				return text_a.naturalnocasecmp_to(text_b) < 0
			else:
				return text_a.naturalnocasecmp_to(text_b) > 0
		)
		
	for i in count:
		visual_to_real_id[i] = temp_array[i]
		real_to_visual_id[temp_array[i]] = i
#endregion
