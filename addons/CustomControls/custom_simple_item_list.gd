@tool
extends ItemList


@export var odd_line_color: Color = Color("#e4ecf2") :
	set(value):
		odd_line_color = value
		var node = get_node_or_null("%BackControl")
		if node:
			node.queue_redraw()


@export var event_line_color: Color = Color(1, 1, 1) :
	set(value):
		event_line_color = value
		var node = get_node_or_null("%BackControl")
		if node:
			node.queue_redraw()


@export var separator_color: Color = Color("#545759") :
	set(value):
		separator_color = value
		var node = get_node_or_null("%BackControl")
		if node:
			node.queue_redraw()


@export var separator_size: int = 2 :
	set(value):
		separator_size = value
		var node = get_node_or_null("%BackControl")
		if node:
			node.queue_redraw()


var busy: bool = false

const MINI_PADLOCK = preload("res://addons/CustomControls/Images/mini_padlock.png")

func _ready() -> void:
	%BackControl.draw.connect(_on_back_control_draw)
	draw.connect(%BackControl.queue_redraw)
	get_v_scroll_bar().value_changed.connect(_change_back_position)
	gui_input.connect(_on_gui_input)


func lock_item(index: int, value: bool) -> void:
	if get_item_count() > index:
		if value:
			set_item_icon(index, MINI_PADLOCK)
		else:
			set_item_icon(index, null)


func _on_back_control_draw() -> void:
	if busy:
		return
	
	busy = true
	var rect: Rect2
	var control = %BackControl
	var last_item_rect: Rect2
	if item_count > 0:
		last_item_rect = get_item_rect(item_count - 1)
		control.size.y = last_item_rect.size.y + last_item_rect.position.y
		
		for index in get_item_count():
			rect = get_item_rect(index)
			if index % 2 == 0:
				control.draw_rect(rect, odd_line_color, true)
			else:
				control.draw_rect(rect, event_line_color, true)
			if separator_size > 0:
				var separator_rect = Rect2(rect.position.x, rect.position.y + rect.size.y - separator_size, rect.size.x, separator_size)
				control.draw_rect(separator_rect, separator_color)
		
		var v_separation = get("theme_override_constants/v_separation")
		if !v_separation:
			v_separation = 2
		if rect.position.y + rect.size.y + v_separation < size.y:
			var last_id = item_count + 1
			while rect.position.y - rect.size.y - v_separation < size.y:
				rect.position.y += v_separation + rect.size.y
				if last_id % 2 == 0:
					control.draw_rect(rect, event_line_color)
				else:
					control.draw_rect(rect, odd_line_color)
				if separator_size > 0:
					var separator_rect = Rect2(rect.position.x, rect.position.y + rect.size.y - separator_size, rect.size.x, separator_size)
					control.draw_rect(separator_rect, separator_color)
				last_id += 1
	else:
		var v_separation = get("theme_override_constants/v_separation")
		if !v_separation:
			v_separation = 2
		var font = get_theme_default_font()
		var font_size = get_theme_default_font_size()
		var sy = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y
		var y = 0
		var i = 1
		rect.position = Vector2.ZERO
		rect.size = Vector2(size.x, sy)
		while rect.position.y < size.y + v_separation:
			if i % 2 == 0:
				control.draw_rect(rect, event_line_color)
			else:
				control.draw_rect(rect, odd_line_color)
			if separator_size > 0:
				var separator_rect = Rect2(rect.position.x, rect.position.y + rect.size.y - separator_size, rect.size.x, separator_size)
				control.draw_rect(separator_rect, separator_color)
			rect.position.y += v_separation + sy
			i += 1
	
	busy = false


func _on_gui_input(event: InputEvent) -> void:
	if select_mode != SELECT_MULTI:
		return
		
	if is_anything_selected() and event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_UP:
			var indexes = get_selected_items()
			if indexes.size() > 0:
				var new_index = max(0, indexes[0] - 1)
				select(new_index)
				multi_selected.emit(new_index, true)
			else:
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			var indexes = get_selected_items()
			if indexes.size() > 0:
				var new_index = min(get_item_count() - 1, indexes[-1] + 1)
				select(new_index)
				multi_selected.emit(new_index, true)
			else:
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			var index = get_selected_items()[-1]
			select(index)
			multi_selected.emit(index, true)


func _change_back_position(value: float) -> void:
	var control = %BackControl
	control.position.y = -value
	control.size = size


func select(idx: int, single: bool = true) -> void:
	super(idx, single)
	ensure_current_is_visible()


func add_item(text: String, icon: Texture2D = null, selectable: bool = true) -> int:
	var index = super(text, icon, selectable)
	set_item_tooltip_enabled(index, false)
	return index
