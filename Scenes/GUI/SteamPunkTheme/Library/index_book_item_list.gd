@tool
class_name CustomTargetItemList
extends ItemList

## Unique identifier for this list to avoid static signal conflicts.
@export var list_id: String = "default_list"

## Signal name for the signal on hover
@export var hover_signal_name: String = "item_hovered_local"

## Signal name for the signal on unhover
@export var unhover_signal_name: String = "item_unhovered_local"

## background style for items
@export var background_style: StyleBox

## Array of outline sizes to be drawn sequentially.
@export var outline_stack: PackedInt32Array = []

## Array of outline colors corresponding to the sizes in the stack.
@export var outline_color_stack: PackedColorArray = []

## Fixed horizontal margin from the left edge.
@export var custom_left_margin: float = 16.0

## Fixed horizontal margin from the right edge.
@export var custom_right_margin: float = 16.0

## If true, fills the list with 50 debug items on ready.
@export var debug_mode: bool = false

var _item_data: Array[Dictionary] = []

#region Signals Block
var _hover_signal_name: String
var _unhover_signal_name: String
#endregion


#region Initialization Block
## Initializes the item list and hooks the scrollbar.
func _ready() -> void:
	var v_scroll = get_v_scroll_bar()
	if v_scroll and not v_scroll.value_changed.is_connected(_on_scroll_changed):
		v_scroll.value_changed.connect(_on_scroll_changed)

	if debug_mode and not Engine.is_editor_hint():
		_fill_debug_data()
	elif not debug_mode:
		_extract_native_items()
	
	_hover_signal_name = "%s_%s" % [list_id, hover_signal_name]
	_unhover_signal_name = "%s_%s" % [list_id, unhover_signal_name]
	
	StaticSignal.create_signal(_hover_signal_name)
	StaticSignal.create_signal(_unhover_signal_name)
	
	grab_focus.call_deferred()


## Fills the list with 50 dummy items for testing purposes.
func _fill_debug_data() -> void:
	var debug_list: Array[Dictionary] = []

	for i in range(1, 51):
		debug_list.append({
			"name": "Data #" + str(i),
			"target_page": str(i * 2)
		})

	populate_custom_items(debug_list)


## Extracts pre-existing items defined in the editor into the custom dictionary format.
func _extract_native_items() -> void:
	if item_count > 0 and _item_data.is_empty():
		var extracted: Array[Dictionary] = []

		for i in range(item_count):
			var dict = {}
			var item_text = get_item_text(i)
			var item_icon = get_item_icon(i)
			var item_meta = get_item_metadata(i)

			if item_text != "" and item_text != " ":
				dict["name"] = item_text

			if item_icon:
				dict["icon"] = item_icon

			if item_meta != null:
				dict["target_page"] = item_meta

			extracted.append(dict)

		populate_custom_items(extracted)


## Triggers a visual refresh when the internal scrollbar value changes.
func _on_scroll_changed(_val: float) -> void:
	queue_redraw()
#endregion


## Processes mouse movement over the list and emits local position signals for external cursor handling.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered_index: int = get_item_at_position(event.position, true)
		
		if hovered_index != -1:
			if not is_selected(hovered_index):
				select(hovered_index)
			
			var rect: Rect2 = get_item_rect(hovered_index)
			var local_pos: Vector2 = rect.position + Vector2(0, rect.size.y * 0.5)
			
			if get_v_scroll_bar() and get_v_scroll_bar().visible:
				local_pos.y -= get_v_scroll_bar().value
			
			StaticSignal.emit(_hover_signal_name, [local_pos, self])
		else:
			StaticSignal.emit(_unhover_signal_name, [self])


## Cleans up forced cursor targeting when the mouse exits the control entirely.
func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		StaticSignal.emit(_unhover_signal_name, [self])


#region Data Management Block
## Fills the internal list with data dictionaries and injects blank items visually.
func populate_custom_items(data: Array[Dictionary]) -> void:
	clear()
	_item_data = data

	for i in range(_item_data.size()):
		add_item(" ")

	queue_redraw()
#endregion


#region Custom Drawing Block
## Intercepts native drawing to overlay the custom elements directly.
func _draw() -> void:
	if _item_data.is_empty() or item_count == 0:
		return

	var list_font = get_theme_font("font")
	var list_font_size = get_theme_font_size("font_size")
	var font_h = list_font.get_height(list_font_size)
	var font_color = get_theme_color("font_color")
	var total_outline_size = 0

	for s in outline_stack:
		total_outline_size += s

	var v_scroll_bar = get_v_scroll_bar()
	var scroll_offset = v_scroll_bar.value if (v_scroll_bar and v_scroll_bar.visible) else 0.0

	for i in range(item_count):
		if i >= _item_data.size():
			continue

		var data = _item_data[i]
		var rect = get_item_rect(i)
		rect.position.y -= scroll_offset

		if rect.position.y + rect.size.y < 0 or rect.position.y > size.y:
			continue

		if background_style:
			var rect2 = rect
			rect2.position.y += 10
			background_style.draw(get_canvas_item(), rect2)

		var current_x = rect.position.x + custom_left_margin
		var text_y = rect.position.y + (rect.size.y - font_h) / 2.0 + list_font.get_ascent(list_font_size)

		if data.has("icon") and data["icon"] is Texture2D:
			var icon = data["icon"]
			var icon_y = rect.position.y + (rect.size.y - icon.get_height()) / 2.0
			draw_texture(icon, Vector2(current_x, icon_y))
			current_x += icon.get_width() + 4.0

		var name_width = 0.0
		
		if data.has("name"):
			var n_text = str(data["name"])
			var pos = Vector2(current_x, text_y)
			var current_size = total_outline_size

			for j in range(outline_stack.size()):
				if current_size > 0:
					var out_color = outline_color_stack[j] if j < outline_color_stack.size() else (outline_color_stack[-1] if outline_color_stack.size() > 0 else Color.BLACK)
					list_font.draw_string_outline(get_canvas_item(), pos, n_text, HORIZONTAL_ALIGNMENT_LEFT, -1, list_font_size, current_size, out_color)
				current_size -= outline_stack[j]

			list_font.draw_string(get_canvas_item(), pos, n_text, HORIZONTAL_ALIGNMENT_LEFT, -1, list_font_size, font_color)
			name_width = list_font.get_string_size(n_text, HORIZONTAL_ALIGNMENT_LEFT, -1, list_font_size).x

		var target_x_start = rect.position.x + rect.size.x - custom_right_margin

		if data.has("target_page"):
			var t_text = str(data["target_page"])
			var t_width = list_font.get_string_size(t_text, HORIZONTAL_ALIGNMENT_LEFT, -1, list_font_size).x
			target_x_start -= t_width
			var target_pos = Vector2(target_x_start, text_y)
			var current_size = total_outline_size

			for j in range(outline_stack.size()):
				if current_size > 0:
					var out_color = outline_color_stack[j] if j < outline_color_stack.size() else (outline_color_stack[-1] if outline_color_stack.size() > 0 else Color.BLACK)
					list_font.draw_string_outline(get_canvas_item(), target_pos, t_text, HORIZONTAL_ALIGNMENT_LEFT, -1, list_font_size, current_size, out_color)
				current_size -= outline_stack[j]

			list_font.draw_string(get_canvas_item(), target_pos, t_text, HORIZONTAL_ALIGNMENT_LEFT, -1, list_font_size, font_color)

		var dots_start_x = current_x + name_width + 4.0
		var dots_end_x = target_x_start - 4.0
		var filler_width = dots_end_x - dots_start_x

		if filler_width > 0:
			var dot_width = list_font.get_string_size(".", HORIZONTAL_ALIGNMENT_LEFT, -1, list_font_size).x
			var num_dots = floor(filler_width / dot_width)
			var filler_string = ".".repeat(num_dots)
			var dot_color = font_color
			dot_color.a *= 0.6
			var current_size = total_outline_size
			
			for j in range(outline_stack.size()):
				if current_size > 0:
					var out_color = outline_color_stack[j] if j < outline_color_stack.size() else (outline_color_stack[-1] if outline_color_stack.size() > 0 else Color.BLACK)
					list_font.draw_string_outline(get_canvas_item(), Vector2(dots_start_x, text_y), filler_string, HORIZONTAL_ALIGNMENT_LEFT, -1, list_font_size, current_size, out_color)
				current_size -= outline_stack[j]
			
			list_font.draw_string(get_canvas_item(), Vector2(dots_start_x, text_y), filler_string, HORIZONTAL_ALIGNMENT_LEFT, -1, list_font_size, dot_color)
#endregion
