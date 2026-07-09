@tool
class_name CustomSimpleItemList
extends ItemList

## Color for the odd lines
@export var odd_line_color: Color = Color("#e4ecf2") :
	set(value):
		odd_line_color = value
		var node = get_node_or_null("%BackControl")
		if node:
			node.queue_redraw()

## Color for the event lines
@export var event_line_color: Color = Color(1, 1, 1) :
	set(value):
		event_line_color = value
		var node = get_node_or_null("%BackControl")
		if node:
			node.queue_redraw()

## Color for the line separators
@export var separator_color: Color = Color("#545759") :
	set(value):
		separator_color = value
		var node = get_node_or_null("%BackControl")
		if node:
			node.queue_redraw()

## Size of the separators
@export var separator_size: int = 2 :
	set(value):
		separator_size = value
		var node = get_node_or_null("%BackControl")
		if node:
			node.queue_redraw()

## Enables or disables the drag and drop functionality for reordering items
@export var drag_and_drop_enabled: bool = false

var busy: bool = false

var locked_items: PackedInt32Array = []

var custom_row_colors: Dictionary = {}

const MINI_PADLOCK = preload("res://addons/CustomControls/Images/mini_padlock.png")

signal delete_pressed(ids: PackedInt32Array)

signal item_moved(old_index: int, new_index: int)



## Connects signals and prepares the custom item list logic
func _ready() -> void:
	%BackControl.draw.connect(_on_back_control_draw)
	draw.connect(%BackControl.queue_redraw)
	get_v_scroll_bar().value_changed.connect(_change_back_position, CONNECT_DEFERRED)
	gui_input.connect(_on_gui_input)



func clear_custom_colors() -> void:
	custom_row_colors.clear()


func set_custom_color(_index: int, _text_color: Color = Color.TRANSPARENT, _bg_color: Color = Color.WHITE) -> void:
	custom_row_colors[_index] = {"text_color": _text_color, "background_color": _bg_color}


## Adds or removes the padlock icon to the requested item index
func lock_item(index: int, value: bool) -> void:
	if not value and locked_items.has(index):
		locked_items.erase(index)
	elif value and not locked_items.has(index):
		locked_items.append(index)
		
	if get_item_count() > index:
		if value:
			set_item_icon(index, MINI_PADLOCK)
		else:
			set_item_icon(index, null)



## Draws the custom background grid and row lines behind the item list
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
			
			var color: Color
			if index % 2 == 0:
				color = odd_line_color
			else:
				color = event_line_color
				
			var color_data: Dictionary = custom_row_colors.get(index, {})
			if not color_data.is_empty() and not color_data.background_color.is_equal_approx(Color.TRANSPARENT):
				color = color_data.background_color
			
			control.draw_rect(rect, color, true)
				
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



## Processes raw input events enforcing multiselection keyboard shortcuts
func _on_gui_input(event: InputEvent) -> void:
	if select_mode != SELECT_MULTI:
		if is_anything_selected() and event is InputEventKey and event.is_pressed():
			if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
				delete_pressed.emit(get_selected_items())
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
			
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			delete_pressed.emit(get_selected_items())



## Adjusts the background control position synchronously with the scrollbar
func _change_back_position(value: float) -> void:
	var control = %BackControl
	control.position.y = -value
	control.size = size
	control.queue_redraw()



## Overrides the selection to handle single mode clearing gracefully
func select(idx: int, single: bool = true) -> void:
	if idx < 0 and single:
		deselect_all()
	else:
		super(idx, single)
		ensure_current_is_visible()



## Appends an item configuring its default tooltip behavior
func add_item_custom(text: String, icon: Texture2D = null, selectable: bool = true) -> int:
	if text.is_empty(): text = " "
	var index = add_item(text, icon, selectable)
	set_item_tooltip_enabled(index, false)

	if index in locked_items:
		set_item_icon(index, MINI_PADLOCK)
		
	return index



## Generates the drag visual preview containing the icon and text when a drag event starts
func _get_drag_data(at_position: Vector2) -> Variant:
	if not drag_and_drop_enabled:
		return null
		
	var idx: int = get_item_at_position(at_position, true)
	
	if idx < 0:
		return null
		
	var preview: Label = Label.new()
	preview.text = get_item_text(idx)
	
	var icon: Texture2D = get_item_icon(idx)
	
	if icon:
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.texture = icon
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(32, 32)
		
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_child(tex_rect)
		hbox.add_child(preview)
		set_drag_preview(hbox)
	else:
		set_drag_preview(preview)
		
	return {"type": "autotile_list_drag", "index": idx}


## Validates if the drop payload is coming natively from our custom list
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drag_and_drop_enabled:
		return false
		
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "autotile_list_drag":
		return true
		
	return false


func ensure_current_is_visible() -> void:
	super.ensure_current_is_visible()
	queue_redraw.call_deferred()



## Rearranges the list items physically and emits the update signal for the external arrays
func _drop_data(at_position: Vector2, data: Variant) -> void:
	var old_idx: int = data["index"]
	var new_idx: int = get_item_at_position(at_position, true)
	
	if new_idx < 0:
		new_idx = get_item_count() - 1
		
	if old_idx == new_idx:
		return
		
	move_item(old_idx, new_idx)
	item_moved.emit(old_idx, new_idx)
