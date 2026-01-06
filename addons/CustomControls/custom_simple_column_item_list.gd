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

## Enabled Multi-Selection
@export var enable_multiselection: bool = false :
	set(value):
		enable_multiselection = value
		var node: ItemList = get_node_or_null("%ItemList")
		if node:
			node.select_mode = ItemList.SELECT_MULTI if value else ItemList.SELECT_SINGLE
			notify_property_list_changed()

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


var cache_columns_width: PackedInt32Array
var busy: bool = false

var font = get_theme_default_font()
var font_size = get_theme_font_size("font_size", "ItemList")
var align = HORIZONTAL_ALIGNMENT_LEFT

var can_drag: bool = false
var can_move: bool = false
var current_resize_column: int = -1
var current_drag_column: int = -1
var current_drag_target_column = -1
var dragging: bool = false
var click_position: int
var current_size: int

var disabled: bool = false

var queue_fill_delay: float = 0
var fill_delay_max_time: float = 0.01

var lock_items: PackedInt32Array = []

var default_tooltip: String
var current_tooltip: String

var custom_row_column = {}

var current_order: Array = []

var row_colors: Dictionary = {} # Dictionary[index: int] = Color / Stylebox
var text_row_colors: Dictionary = {} # Dictionary[index: int] = Color

var custom_icons: Dictionary = {} # Dictionary[index: int] = Texture

var lock_enter: bool

var space_enabled: bool = true

var current_filter: String = ""

const MINI_PADLOCK = preload("res://addons/CustomControls/Images/mini_padlock.png")


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


func _ready() -> void:
	for i in cache_columns_width.size():
		current_order.append(i)
		
	%ItemList.draw.connect(_on_itemlist_draw)
	draw.connect(%ItemList.queue_redraw)
	draw.connect(%TopMenu.queue_redraw)
	%TopMenu.draw.connect(_on_top_menu_draw)
	%ItemList.item_activated.connect(func(index: int): item_activated.emit(index) )
	%ItemList.item_selected.connect(func(index: int): item_selected.emit(index) )
	%ItemList.multi_selected.connect(func(index: int, selected: bool): multi_selected.emit(index, selected) )
	%ItemList.gui_input.connect(_on_itemlist_gui_input)
	%ItemList.focus_exited.connect(_on_focus_exited)
	%TopMenu.gui_input.connect(_on_top_gui_input)
	
	update_name_and_sizes()
	fill_items()
	
	set_process(false)
	
	default_tooltip = itemlist_tooltip
	
	resized.connect(_on_resized)


func set_filter(filter: String) -> void:
	current_filter = filter


func _on_resized() -> void:
	if busy: return
	busy = true
	call_deferred("update_name_and_sizes")
	await get_tree().process_frame
	queue_redraw()
	set_deferred("busy", false)


func _on_parent_resized() -> void:
	if busy: return
	call_deferred("update_name_and_sizes")


func force_update_sizes() -> void:
	if busy: return
	if is_inside_tree():
		await get_tree().process_frame
	size.x = get_parent().size.x
	size.y = get_parent().size.y
	update_name_and_sizes()


func disconnect_gui_input() -> void:
	if %ItemList.gui_input.is_connected(_on_itemlist_gui_input):
		%ItemList.gui_input.disconnect(_on_itemlist_gui_input)


# color = Color or Stylebox
func add_row_color(index: int, color: Variant) -> void:
	row_colors[index] = color


func add_row_text_color(index: int, color: Color) -> void:
	text_row_colors[index] = color


# index = Item index
# icon = String (path) or Texture
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


func set_lock_items(items: PackedInt32Array) -> void:
	lock_items = items


func _on_focus_exited():
	if deselect_when_lost_focus:
		%ItemList.deselect_all()


func get_item_at_position(pos: Vector2) -> int:
	return %ItemList.get_item_at_position(pos, true)


func get_item_rect(index: int) -> Rect2:
	return %ItemList.get_item_rect(index)


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


func get_v_scroll_bar() -> VScrollBar:
	return %ItemList.get_v_scroll_bar()


func select(index: int, single: bool = true) -> void:
	if %ItemList.get_item_count() > index and index != -1:
		%ItemList.select(index, single)
		%ItemList.ensure_current_is_visible()
		if index == %ItemList.get_item_count() - 2 and placeholder_text.length() > 0:
			await get_tree().process_frame
			%ItemList.get_v_scroll_bar().value = %ItemList.get_v_scroll_bar().max_value


func deselect(index: int) -> void:
	%ItemList.deselect(index)


func select_items(indexes: PackedInt32Array) -> void:
	for index in indexes:
		if %ItemList.get_item_count() > index:
			%ItemList.select(index, false)
	
	%ItemList.ensure_current_is_visible()
	if indexes[-1] == %ItemList.get_item_count() - 2 and placeholder_text.length() > 0:
		await get_tree().process_frame
		%ItemList.get_v_scroll_bar().value = %ItemList.get_v_scroll_bar().max_value


func deselect_all() -> void:
	%ItemList.deselect_all()


func fill_items() -> void:
	var node = %ItemList
	node.clear()
	for item in items:
		node.add_item(" ")
		
	if placeholder_text.length() > 0:
		node.add_item(" ")
	
	queue_redraw()


func sum(accum, number):
	return accum + number


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
	
	# Calcular el ancho total disponible
	var total_width = size.x
	if get_node_or_null("%ItemList"):
		total_width = get_parent().size.x if get_parent() is Control else size.x
	
	# Calcular espacio usado por separadores
	var extra_size = (column_separator_margin * 2 + column_separator_width) * columns
	var available_width = total_width - extra_size
	
	# Primera pasada: calcular tamaños fijos y contar columnas con tamaño negativo
	var fixed_width_total = 0
	var negative_columns = []
	var temp_widths = []
	
	for i in sizes.size():
		var real_index = current_order[i]
		if sizes[real_index] < 0:
			# Columna con tamaño negativo, se ajustará después
			negative_columns.append(real_index)
			temp_widths.append(0)
		elif sizes[real_index] == 0:
			# Autosize basado en el nombre de la columna
			if columns == 1 and get_node_or_null("%ItemList"):
				temp_widths.append(available_width)
				fixed_width_total += available_width
			else:
				var s = font.get_string_size(
					names[real_index],
					align,
					-1,
					font_size
				).x
				var width = max(min_column_size, s)
				temp_widths.append(width)
				fixed_width_total += width
		else:
			# Tamaño fijo especificado
			var width = max(min_column_size, sizes[real_index])
			temp_widths.append(width)
			fixed_width_total += width
	
	# Segunda pasada: distribuir el ancho restante entre columnas con tamaño negativo
	if negative_columns.size() > 0:
		fixed_width_total += column_separator_margin * (columns + 1) + column_separator_width * (columns + 1)
		var remaining_width = available_width - fixed_width_total
		var width_per_negative_column = max(min_column_size, remaining_width / negative_columns.size())
		
		for i in sizes.size():
			var real_index = current_order[i]
			if sizes[real_index] < 0:
				temp_widths[i] = width_per_negative_column
				sizes[real_index] = width_per_negative_column

	
	# Asignar los anchos calculados
	cache_columns_width = temp_widths
	
	if get_node_or_null("%TopMenu"):
		var h = font.get_string_size(" ", 0, -1, font_size).y
		%TopMenu.set_deferred("size", Vector2.ZERO)
		#%TopMenu.custom_minimum_size = %TopMenu.size
		%TopMenu.custom_minimum_size.y = h
		#%TopMenu.custom_minimum_size.x = Array(cache_columns_width).reduce(sum, extra_size) + extra_size
	
	#if is_node_ready():
		#busy = true
		#size = Vector2.ZERO
		#custom_minimum_size = Vector2.ZERO
		#%ItemList.size = Vector2.ZERO
		#%ItemList.custom_minimum_size = Vector2.ZERO
		#if is_inside_tree():
			#await get_tree().process_frame
		#%ItemList.custom_minimum_size = get_parent().size
		#busy = false
	if size.x < min_size.x: size.x = min_size.x
	if size.y < min_size.y: size.y = min_size.y
	#custom_minimum_size = size
	
	
	queue_redraw()


func clear() -> void:
	set_process(true)
	queue_fill_delay = fill_delay_max_time
	custom_row_column.clear()
	row_colors.clear()
	custom_icons.clear()
	items.clear()
	%ItemList.clear()


func add_column(contents: PackedStringArray) -> void:
	items.append(contents)
	queue_fill_delay = fill_delay_max_time
	set_process(true)


func get_column(id: int) -> PackedStringArray:
	if items.size() > id:
		return items[id]
	else:
		return []


func _on_itemlist_gui_input(event: InputEvent) -> void:
	if %ItemList.get_item_count() == 0:
		return
	
	if %ItemList.is_anything_selected() and event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			delete_pressed.emit(%ItemList.get_selected_items())
		elif event.is_ctrl_pressed():
			if event.keycode == KEY_C:
				copy_requested.emit(%ItemList.get_selected_items())
			elif event.keycode == KEY_X:
				cut_requested.emit(%ItemList.get_selected_items())
			elif event.keycode == KEY_V:
				paste_requested.emit(%ItemList.get_selected_items()[-1])
			elif event.keycode == KEY_D:
				duplicate_requested.emit(%ItemList.get_selected_items())
		elif event.keycode == KEY_UP:
			var indexes = %ItemList.get_selected_items()
			if indexes.size() > 0:
				var new_index = max(0, indexes[0] - 1)
				%ItemList.select(new_index)
				multi_selected.emit(new_index, true)
			else:
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			var indexes = %ItemList.get_selected_items()
			if indexes.size() > 0:
				var new_index = min(%ItemList.get_item_count() - 1, indexes[-1] + 1)
				%ItemList.select(new_index)
				multi_selected.emit(new_index, true)
			else:
				get_viewport().set_input_as_handled()
		elif space_enabled and event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			var index = %ItemList.get_selected_items()[-1]
			%ItemList.item_activated.emit(index)
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		var index = get_item_at_position(%ItemList.get_local_mouse_position())
		if index != -1:
			var selected_items_amount = %ItemList.get_selected_items().size()
			if selected_items_amount <= 1:
				select(index)
			button_right_pressed.emit(%ItemList.get_selected_items())
	
	if event is InputEventMouseMotion:
		get_custom_tooltip()


func disable_space_input(value: bool) -> void:
	space_enabled = !value


func get_custom_tooltip() -> String:
	var result = ""
	var old_tooltip = current_tooltip
	var index = %ItemList.get_item_at_position(%ItemList.get_local_mouse_position())
	if index >= 0 and items_tooltip.size() > index and items_tooltip[index] and items_tooltip[index].length() > 0:
		result = items_tooltip[index]
	elif default_tooltip and default_tooltip.length() > 0:
		result = default_tooltip
	
	current_tooltip = result
	
	if old_tooltip and old_tooltip != current_tooltip:
		%ItemList.tooltip_changed.emit()
	
	return current_tooltip


func _on_top_gui_input(event: InputEvent):
	if event is InputEventMouseMotion:
		if dragging and current_resize_column != -1:
			sizes[current_resize_column] = max(min_column_size, current_size + event.position.x - click_position)
		elif current_drag_column != -1:
			current_drag_target_column = -1
			var x = 0
			for i in range(0, cache_columns_width.size(), 1):
				var real_index = current_order[i]
				x += cache_columns_width[real_index]
				if event.position.x <= x or i == cache_columns_width.size() - 1:
					current_drag_target_column = i
					break
			%TopMenu.queue_redraw()
		else:
			var extra_size = column_separator_margin * 2 + column_separator_width
			%TopMenu.mouse_default_cursor_shape = Control.CURSOR_ARROW
			can_drag = false
			current_resize_column = -1
			var x = 0
			for i in range(0, cache_columns_width.size() - 1):
				var real_index = current_order[i]
				x += cache_columns_width[real_index]
				if (
					(event.position.x >= x and event.position.x - extra_size * 2 <= x) or
					(event.position.x <= x and event.position.x + extra_size >= x)
				):
					%TopMenu.mouse_default_cursor_shape = Control.CURSOR_HSIZE
					can_drag = true
					current_resize_column = i
					break
			if current_resize_column == -1:
				%TopMenu.mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif can_drag and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.is_pressed()
		if dragging:
			click_position = event.position.x
			current_size = sizes[current_resize_column]
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			current_drag_column = -1
			var x = 0
			for i in range(0, cache_columns_width.size(), 1):
				var real_index = current_order[i]
				x += cache_columns_width[real_index]
				if event.position.x <= x or i == cache_columns_width.size() - 1:
					current_drag_column = i
					current_drag_target_column = current_drag_column
					break
		else:
			if current_drag_column != -1 and current_drag_target_column != -1 and current_drag_column != current_drag_target_column:
				busy = true
				var from = current_drag_column
				var to = current_drag_target_column
				
				# Solo intercambiar el orden, no los datos
				var temp_order = current_order[from]
				current_order[from] = current_order[to]
				current_order[to] = temp_order
				
				busy = false
				await get_tree().process_frame
				%TopMenu.queue_redraw()
				%ItemList.queue_redraw()
			current_drag_column = -1
			current_drag_target_column = -1
	
	# ensure disable drags
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.is_pressed():
		current_drag_column = -1
		current_resize_column = -1
		current_drag_target_column = -1


func _validate_property(property):
	return
	#if property.name == "names" or property.name == "sizes" or property.name == "items":
		#if columns > 0:
			#property.usage = PROPERTY_USAGE_EDITOR
		#else:
			#property.usage &= ~PROPERTY_USAGE_EDITOR


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
			node.draw_string(
				font,
				Vector2(x + text_margin_left, y),
				names[real_index],
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

	var last_item_rect: Rect2
	if node.get_item_count() > 0:
		last_item_rect = node.get_item_rect(node.get_item_count() - 1)
		
		custom_minimum_size.x = 0
		for index in node.get_item_count():
			rect = node.get_item_rect(index)
			rect.position.y += offset
			var current_line_color = odd_line_color if index % 2 else event_line_color
			var row_color = row_colors.get(index, current_line_color)
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
			
			# Calcular el tamaño extra del icono una sola vez por fila
			var row_icon_size = 0
			if lock_items.has(index):
				row_icon_size = 24
			elif custom_icons.has(index):
				row_icon_size = custom_icons[index].get_size().x + 2

			# Dibujar el icono ANTES del bucle de columnas, sin afectar x
			if lock_items.has(index):
				var icon_rect = Rect2(Vector2(2, rect.position.y), Vector2(20, 20))
				node.draw_texture_rect(MINI_PADLOCK, icon_rect, false)
			elif custom_icons.has(index):
				var icon_rect = Rect2(Vector2(2, rect.position.y), custom_icons[index].get_size())
				node.draw_texture_rect(custom_icons[index], icon_rect, false)

			if index < items.size():
				for i in columns:
					var real_index = current_order[i]
					
					if i > 0:
						x += column_separator_margin * 2 + column_separator_width
					
					if i < items[index].size():
						var text_size = -1
						if i != items[index].size() - 1:
							text_size = cache_columns_width[real_index]
							# Solo aplicamos la reducción del icono en la primera columna
							if i == 0:
								text_size = max(5, text_size - row_icon_size)
							else:
								text_size = max(5, text_size)
						
						var current_text_color = items_text_default_color
						var key = str([index, real_index])
						if text_row_colors.has(index):
							current_text_color = text_row_colors[index]
						else:
							if custom_row_column.has(key) and custom_row_column[key] is Color:
								current_text_color = custom_row_column[key]
							elif columns_text_colors.size() > real_index and columns_text_colors[real_index] is Color:
								current_text_color = columns_text_colors[real_index]
						# Calcular la posición x del texto, aplicando desplazamiento solo en primera columna
						var text_x = x + text_margin_left
						if i == 0:
							text_x += row_icon_size
						
						var text = items[index][real_index]
						var text_y = rect.position.y + y
						
						if not padding_start_char.is_empty():
							if not text.begins_with(padding_start_char):
								text_x += start_padding
								
						node.draw_string(
							font,
							Vector2(
								text_x,
								text_y
							),
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

					if i == columns - 1 and items.size() > index and items[index].size() > real_index and items[index][real_index].length() > 0:
						var text_width = font.get_string_size(items[index][real_index], 0, -1, font_size).x
						var current_size = x + text_width
						custom_minimum_size.x = max(custom_minimum_size.x, current_size)
					
					x += cache_columns_width[real_index]
						
			elif index == node.get_item_count() - 1 and placeholder_text.length() > 0:
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
			var last_id = node.item_count # + (1 if placeholder_text else 0)
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


func set_disabled(value: bool) -> void:
	disabled = value
	if value:
		set_process_mode(Node.PROCESS_MODE_DISABLED)
		modulate.a = 0.6
	else:
		set_process_mode(Node.PROCESS_MODE_INHERIT)
		modulate.a = 1.0


func set_item_selectable(index: int, value: bool) -> void:
	%ItemList.set_item_selectable(index, value)


func is_item_selectable(index: int) -> bool:
	return %ItemList.is_item_selectable(index)


func _draw() -> void:
	if panel_style:
		var rect = get_rect()
		rect.position = Vector2.ZERO
		draw_style_box(panel_style, rect)


func get_selected_items() -> PackedInt32Array:
	return %ItemList.get_selected_items()


func set_selected_items(ids) -> void:
	var node = %ItemList
	for id in ids:
		node.select(id, false)


func get_item_list() -> ItemList:
	return %ItemList as ItemList


func get_item_count() -> int:
	return get_item_list().get_item_count()


func _on_item_list_item_rect_changed() -> void:
	var parent = get_parent()
	if parent and parent is Container:
		parent.queue_sort()
