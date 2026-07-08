extends Control
class_name ItemsStatsCanvas

enum AlignmentMode {
	SPREAD,           ## Subtitle on left edge, Value on right edge
	LEFT_ADJACENT,    ## Subtitle and Value on left edge
	RIGHT_ADJACENT,   ## Subtitle and Value on right edge
	CENTERED_ADJACENT ## Subtitle and Value centered together
}

## Controls the justification of the subtitle and value on non-title items
@export var alignment_mode: AlignmentMode = AlignmentMode.SPREAD

## The font used to draw the text of the items
@export var font: Font
## The base font size before dynamic scaling
@export var font_size: int = 16
## Array of outline sizes to apply to the text
@export var outline_sizes: Array[int] = []
## Array of outline colors corresponding to the outline sizes
@export var outline_colors: Array[Color] = []
## Array of positional offsets corresponding to each outline layer
@export var outline_offsets: Array[Vector2] = []
## Default color used for the text
@export var default_text_color: Color = Color.WHITE
## Color used for titles
@export var title_color: Color = Color.WHITE
## Color used for subtitles (the name of the stat/property)
@export var subtitle_color: Color = Color.GRAY
## Color used for values (the value of the stat/property)
@export var value_color: Color = Color.WHITE
## If true, items will only be drawn with the default text color ignoring the dictionary color
@export var force_default_color: bool = false
## If true, the node will not draw anything and will occupy no space
@export var is_disabled: bool = false:
	set(value):
		is_disabled = value
		_update_minimum_size()
		queue_redraw()

@export_group("Layout & Margins")
## Left margin for the list.
@export var margin_left: int = 10
## Right margin for the list.
@export var margin_right: int = 10
## Vertical margin for each item.
@export var margin_vertical: int = 5
## Spacing between elements horizontally.
@export var spacing: int = 5
## Vertical margin/separation between items.
@export var item_separator: int = 4
## Extra margin added above and below titles (the first title does not get the top margin).
@export var title_separation: int = 15
## StyleBox used to draw a visual separator line above titles (skipped for the first title)
@export var title_upper_separator: StyleBox
## StyleBox used to draw a visual separator line below titles
@export var title_bottom_separator: StyleBox
## StyleBox to draw as the background for each item
@export var background_style: StyleBox
## StyleBox used to draw a visual separator line or graphic between items
@export var separator_style: StyleBox

var _stats_items: Array[Dictionary] = []


#region Setup
## Sets the items to be drawn and triggers a redraw and minimum size update
func set_items(items: Array[Dictionary]) -> void:
	_stats_items = items
	_update_minimum_size()
	queue_redraw()


## Clear all items in the list
func clear() -> void:
	_stats_items.clear()
	_update_minimum_size()
	queue_redraw()
#endregion



#region Lifecycle
func _ready() -> void:
	set_notify_transform(true)

## Called when the control receives notifications, used to handle resizing
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_minimum_size()
		queue_redraw()
	elif what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()
#endregion



#region Layout
## Updates the custom minimum size of the control based on its contents
func _update_minimum_size() -> void:
	if is_disabled or _stats_items.is_empty():
		custom_minimum_size = Vector2.ZERO
		return

	var font_to_use: Font = font if font else ThemeDB.fallback_font
	var right_width: float = 0.0
	var effective_width = size.x - margin_left - margin_right
	if effective_width < 10:
		effective_width = 10
	
	for item in _stats_items:
		if not item.get("is_title", false):
			var value_text = item.get("value", "")
			var lw = font_to_use.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font_to_use else 0.0
			if lw > right_width:
				right_width = lw

	var left_col_width = effective_width - right_width - spacing
	if left_col_width < 10:
		left_col_width = 10

	var total_height: float = 0.0
	var sep_height: float = separator_style.get_minimum_size().y if separator_style else 0.0
	if separator_style and sep_height == 0:
		sep_height = 1

	for i in range(_stats_items.size()):
		var item = _stats_items[i]
		var text: String = item.get("text", "")
		var is_title: bool = item.get("is_title", false)
		
		if is_title:
			if i > 0:
				total_height += title_separation
				if title_upper_separator:
					total_height += maxf(1.0, title_upper_separator.get_minimum_size().y)
			total_height += title_separation
			if title_bottom_separator:
				total_height += maxf(1.0, title_bottom_separator.get_minimum_size().y)
		
		var available_name_width = effective_width if is_title else left_col_width
		
		var name_lines = _wrap_text(font_to_use, text, font_size, available_name_width)
		var name_height = name_lines.size() * font_to_use.get_height(font_size) if font_to_use else 0.0
		var left_height = name_height
		
		var right_height = 0.0
		if not is_title:
			right_height = font_to_use.get_height(font_size) if font_to_use else 0.0
		
		var item_height = maxf(left_height, right_height) + margin_vertical * 2
		total_height += item_height

	total_height += (item_separator + sep_height) * maxf(0, _stats_items.size() - 1)

	if background_style:
		var bg_margins: float = background_style.get_margin(SIDE_TOP) + background_style.get_margin(SIDE_BOTTOM)
		total_height += bg_margins * _stats_items.size()

	custom_minimum_size = Vector2(0, total_height)
#endregion



#region Drawing
## Draws the items with their backgrounds and dynamically sized text
func _draw() -> void:
	if is_disabled or _stats_items.is_empty():
		return

	var font_to_use: Font = font if font else ThemeDB.fallback_font
	var right_width: float = 0.0
	var effective_width = size.x - margin_left - margin_right
	if effective_width < 10:
		effective_width = 10
	
	for item in _stats_items:
		if not item.get("is_title", false):
			var value_text = item.get("value", "")
			var lw = font_to_use.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font_to_use else 0.0
			if lw > right_width:
				right_width = lw

	var left_col_width = effective_width - right_width - spacing
	if left_col_width < 10:
		left_col_width = 10

	var visible_top: float = -1e9
	var visible_bottom: float = 1e9
	var p = get_parent()
	while p and p is Control:
		if p.clip_contents:
			var offset_y = global_position.y - p.global_position.y
			visible_top = -offset_y
			visible_bottom = visible_top + p.size.y
			break
		p = p.get_parent()

	var current_y: float = 0.0
	var item_count: int = _stats_items.size()

	for i in range(item_count):
		var item: Dictionary = _stats_items[i]
		var text: String = item.get("text", "")
		var is_title: bool = item.get("is_title", false)
		var value_text: String = item.get("value", "")
		
		var text_color: Color = default_text_color
		var current_value_color: Color = default_text_color
		
		if not force_default_color:
			if is_title:
				text_color = title_color
			else:
				text_color = subtitle_color
				current_value_color = value_color
				
			if item.has("color"):
				text_color = Color(item.get("color"))

		var available_name_width = effective_width if is_title else left_col_width
		
		var name_lines = _wrap_text(font_to_use, text, font_size, available_name_width)
		var line_height = font_to_use.get_height(font_size) if font_to_use else 0.0
		var ascent = font_to_use.get_ascent(font_size) if font_to_use else 0.0
		var name_height = name_lines.size() * line_height
		var left_height = name_height
		
		var right_height = line_height if not is_title else 0.0
		var item_height: float = maxf(left_height, right_height) + margin_vertical * 2

		var bg_margin_top: float = background_style.get_margin(SIDE_TOP) if background_style else 0.0
		var bg_margin_bottom: float = background_style.get_margin(SIDE_BOTTOM) if background_style else 0.0
		var total_item_height: float = item_height + bg_margin_top + bg_margin_bottom

		var item_full_height = 0.0
		if is_title and i > 0:
			item_full_height += title_separation
			if title_upper_separator:
				item_full_height += maxf(1.0, title_upper_separator.get_minimum_size().y)
		item_full_height += total_item_height
		if is_title:
			if title_bottom_separator:
				item_full_height += maxf(1.0, title_bottom_separator.get_minimum_size().y)
			item_full_height += title_separation
		if i < item_count - 1:
			item_full_height += item_separator / 2.0
			if separator_style and not is_title and not _stats_items[i+1].get("is_title", false):
				var sep_height: float = separator_style.get_minimum_size().y
				if sep_height == 0: sep_height = 1
				item_full_height += sep_height
			item_full_height += item_separator / 2.0
			
		if visible_top > -1e8:
			var is_visible = not ((current_y + item_full_height) < visible_top or current_y > visible_bottom)
			if not is_visible:
				current_y += item_full_height
				continue

		if is_title and i > 0:
			current_y += title_separation
			if title_upper_separator:
				var upper_sep_height: float = maxf(1.0, title_upper_separator.get_minimum_size().y)
				var upper_sep_rect = Rect2(margin_left, current_y, size.x - margin_left - margin_right, upper_sep_height)
				title_upper_separator.draw(get_canvas_item(), upper_sep_rect)
				current_y += upper_sep_height

		if background_style and not is_title:
			background_style.draw(get_canvas_item(), Rect2(0, current_y, size.x, total_item_height))

		var content_y: float = current_y + bg_margin_top
		
		var left_start_y = content_y + (item_height - left_height) / 2.0
		var name_start_y = left_start_y + (left_height - name_height) / 2.0 + ascent
		
		var current_x = margin_left
		
		var space_width = font_to_use.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 2.0 if font_to_use else 0.0
		var subtitle_width = font_to_use.get_string_size(name_lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font_to_use and name_lines.size() > 0 else 0.0
		var value_width = font_to_use.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font_to_use else 0.0
		
		var target_name_x = margin_left
		var target_draw_x = size.x - margin_right - value_width
		
		if not is_title:
			match alignment_mode:
				AlignmentMode.SPREAD:
					target_name_x = margin_left
					target_draw_x = size.x - margin_right - value_width
				AlignmentMode.LEFT_ADJACENT:
					target_name_x = margin_left
					target_draw_x = target_name_x + subtitle_width + space_width
				AlignmentMode.RIGHT_ADJACENT:
					target_draw_x = size.x - margin_right - value_width
					target_name_x = target_draw_x - space_width - subtitle_width
				AlignmentMode.CENTERED_ADJACENT:
					var total_w = subtitle_width + space_width + value_width
					target_name_x = margin_left + (effective_width - total_w) / 2.0
					target_draw_x = target_name_x + subtitle_width + space_width
		
		if font_to_use:
			var outline_count: int = mini(outline_sizes.size(), outline_colors.size())
			var name_x = target_name_x
			
			if is_title:
				var title_width = font_to_use.get_string_size(name_lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				name_x = margin_left + (effective_width - title_width) / 2.0
			
			for l in range(name_lines.size()):
				var line_text = name_lines[l]
				var text_y = name_start_y + l * line_height
				
				if is_title and l > 0:
					var text_width = font_to_use.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
					name_x = margin_left + (effective_width - text_width) / 2.0
					
				for j in range(outline_count):
					var offset: Vector2 = outline_offsets[j] if j < outline_offsets.size() else Vector2.ZERO
					draw_string_outline(font_to_use, Vector2(name_x, text_y) + offset, line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_sizes[j], outline_colors[j])

				draw_string(font_to_use, Vector2(name_x, text_y), line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

		var right_start_y = content_y + (item_height - right_height) / 2.0 + ascent
		if font_to_use and not is_title:
			var outline_count: int = mini(outline_sizes.size(), outline_colors.size())
			var text_y = right_start_y
			
			var draw_x = target_draw_x
			
			for j in range(outline_count):
				var offset: Vector2 = outline_offsets[j] if j < outline_offsets.size() else Vector2.ZERO
				draw_string_outline(font_to_use, Vector2(draw_x, text_y) + offset, value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_sizes[j], outline_colors[j])

			draw_string(font_to_use, Vector2(draw_x, text_y), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, current_value_color)

		current_y += total_item_height
		
		if is_title:
			if title_bottom_separator:
				var bottom_sep_height: float = maxf(1.0, title_bottom_separator.get_minimum_size().y)
				var bottom_sep_rect = Rect2(margin_left, current_y, size.x - margin_left - margin_right, bottom_sep_height)
				title_bottom_separator.draw(get_canvas_item(), bottom_sep_rect)
				current_y += bottom_sep_height
			current_y += title_separation

		if i < item_count - 1:
			current_y += item_separator / 2.0
			
			if separator_style and not is_title and not _stats_items[i+1].get("is_title", false):
				var sep_height: float = separator_style.get_minimum_size().y
				if sep_height == 0:
					sep_height = 1
				var separator_rect = Rect2(margin_left, current_y, size.x - margin_left - margin_right, sep_height)
				separator_style.draw(get_canvas_item(), separator_rect)
				current_y += sep_height
				
			current_y += item_separator / 2.0
#endregion



#region Helpers
## Wraps text into lines based on the available width
func _wrap_text(font_to_use: Font, text: String, f_size: int, max_width: float) -> PackedStringArray:
	var words = text.split(" ")
	var lines = PackedStringArray()
	var current_line = ""
	
	if not font_to_use or max_width <= 0:
		lines.append(text)
		return lines

	for word in words:
		var test_line = current_line + (" " if current_line != "" else "") + word
		if font_to_use.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size).x > max_width and current_line != "":
			lines.append(current_line)
			current_line = word
		else:
			current_line = test_line
			
	if current_line != "":
		lines.append(current_line)
		
	return lines
#endregion
