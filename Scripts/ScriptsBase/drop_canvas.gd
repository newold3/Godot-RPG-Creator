extends Control
class_name BestiaryRewardCanvas

## Defines the visibility conditions for the drop percentage
enum PercentMode {
	SHOW_ALWAYS,
	SHOW_IF_KILLED,
	SHOW_IF_DROPPED,
	NEVER_SHOW
}

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
## Size of the icons drawn next to items. Uses the original texture size if set to Vector2.ZERO.
@export var icon_size: Vector2 = Vector2.ZERO
## Spacing between elements horizontally.
@export var spacing: int = 5
## Vertical margin/separation between items.
@export var item_separator: int = 4
## StyleBox to draw as the background for each item
@export var background_style: StyleBox
## StyleBox used to draw a visual separator line or graphic between items
@export var separator_style: StyleBox
## Determines when the drop percentage should be displayed next to the item name
@export var percent_mode: PercentMode = PercentMode.SHOW_ALWAYS
## Indicates if the enemy associated with these drops has been defeated at least once
@export var has_been_killed: bool = false

var _reward_items: Array[Dictionary] = []



#region Setup
## Sets the items to be drawn and triggers a redraw and minimum size update
func set_items(items: Array[Dictionary]) -> void:
	_reward_items = items
	_update_minimum_size()
	queue_redraw()


## Clear all items in the list
func clear() -> void:
	_reward_items.clear()
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
	if is_disabled or _reward_items.is_empty():
		custom_minimum_size = Vector2.ZERO
		return

	var font_to_use: Font = font if font else ThemeDB.fallback_font
	var right_width: float = 0.0
	var effective_width = size.x - margin_left - margin_right
	if effective_width < 10:
		effective_width = 10
	
	for item in _reward_items:
		var lines = _get_right_column_lines(item)
		for line in lines:
			var lw = font_to_use.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font_to_use else 0.0
			if lw > right_width:
				right_width = lw

	var left_col_width = effective_width - right_width - spacing
	if left_col_width < 10:
		left_col_width = 10

	var total_height: float = 0.0
	var sep_height: float = separator_style.get_minimum_size().y if separator_style else 0.0
	if separator_style and sep_height == 0:
		sep_height = 1

	for item in _reward_items:
		var icon: Texture2D = item.get("icon", null)
		var current_icon_size: Vector2 = icon_size if icon_size != Vector2.ZERO else (icon.get_size() if icon else Vector2.ZERO)
		@warning_ignore("incompatible_ternary")
		var icon_spacing: float = spacing if icon else 0.0
		
		var available_name_width = left_col_width - current_icon_size.x - icon_spacing
		var text: String = item.get("name", "")
		
		var name_lines = _wrap_text(font_to_use, text, font_size, available_name_width)
		var name_height = name_lines.size() * font_to_use.get_height(font_size) if font_to_use else 0.0
		var left_height = maxf(current_icon_size.y, name_height)
		
		var right_lines = _get_right_column_lines(item)
		var right_height = right_lines.size() * font_to_use.get_height(font_size) if font_to_use else 0.0
		
		var item_height = maxf(left_height, right_height) + margin_vertical * 2
		total_height += item_height

	total_height += (item_separator + sep_height) * maxf(0, _reward_items.size() - 1)

	if background_style:
		var bg_margins: float = background_style.get_margin(SIDE_TOP) + background_style.get_margin(SIDE_BOTTOM)
		total_height += bg_margins * _reward_items.size()

	custom_minimum_size = Vector2(0, total_height)
#endregion



#region Drawing
## Draws the items with their backgrounds, icons, and dynamically sized text
func _draw() -> void:
	if is_disabled or _reward_items.is_empty():
		return

	var font_to_use: Font = font if font else ThemeDB.fallback_font
	var right_width: float = 0.0
	var effective_width = size.x - margin_left - margin_right
	if effective_width < 10:
		effective_width = 10
	
	for item in _reward_items:
		var lines = _get_right_column_lines(item)
		for line in lines:
			var lw = font_to_use.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font_to_use else 0.0
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
	var item_count: int = _reward_items.size()

	for i in range(item_count):
		var item: Dictionary = _reward_items[i]
		var icon: Texture2D = item.get("icon", null)
		var text: String = item.get("name", "")
		var text_color: Color = default_text_color

		if not force_default_color and item.has("color"):
			text_color = Color(item.get("color"))

		var current_icon_size: Vector2 = icon_size if icon_size != Vector2.ZERO else (icon.get_size() if icon else Vector2.ZERO)
		@warning_ignore("incompatible_ternary")
		var icon_spacing: float = spacing if icon else 0.0
		
		var available_name_width = left_col_width - current_icon_size.x - icon_spacing
		
		var name_lines = _wrap_text(font_to_use, text, font_size, available_name_width)
		var line_height = font_to_use.get_height(font_size) if font_to_use else 0.0
		var ascent = font_to_use.get_ascent(font_size) if font_to_use else 0.0
		var name_height = name_lines.size() * line_height
		var left_height = maxf(current_icon_size.y, name_height)
		
		var right_lines = _get_right_column_lines(item)
		var right_height = right_lines.size() * line_height
		
		var item_height: float = maxf(left_height, right_height) + margin_vertical * 2
		
		var bg_margin_top: float = background_style.get_margin(SIDE_TOP) if background_style else 0.0
		var bg_margin_bottom: float = background_style.get_margin(SIDE_BOTTOM) if background_style else 0.0
		var total_item_height: float = item_height + bg_margin_top + bg_margin_bottom
		
		var item_full_height = total_item_height
		if i < item_count - 1:
			var sep_height = item_separator
			if separator_style:
				var s_height: float = separator_style.get_minimum_size().y
				if s_height == 0: s_height = 1
				sep_height += s_height
			item_full_height += sep_height
			
		if visible_top > -1e8:
			var is_visible = not ((current_y + item_full_height) < visible_top or current_y > visible_bottom)
			if not is_visible:
				current_y += item_full_height
				continue

		if background_style:
			background_style.draw(get_canvas_item(), Rect2(0, current_y, size.x, total_item_height))

		var content_y: float = current_y + bg_margin_top
		
		var left_start_y = content_y + (item_height - left_height) / 2.0
		var icon_y = left_start_y + (left_height - current_icon_size.y) / 2.0
		var name_start_y = left_start_y + (left_height - name_height) / 2.0 + ascent
		
		var current_x = margin_left
		if icon:
			var icon_rect: Rect2 = Rect2(Vector2(current_x, icon_y), current_icon_size)
			draw_texture_rect(icon, icon_rect, false)
			current_x += current_icon_size.x + icon_spacing
		else:
			current_x += current_icon_size.x + icon_spacing

		if font_to_use:
			var outline_count: int = mini(outline_sizes.size(), outline_colors.size())
			var name_x = current_x
			
			for l in range(name_lines.size()):
				var line_text = name_lines[l]
				var text_y = name_start_y + l * line_height
				
				for j in range(outline_count):
					var offset: Vector2 = outline_offsets[j] if j < outline_offsets.size() else Vector2.ZERO
					draw_string_outline(font_to_use, Vector2(name_x, text_y) + offset, line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_sizes[j], outline_colors[j])

				draw_string(font_to_use, Vector2(name_x, text_y), line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

		var right_start_y = content_y + (item_height - right_height) / 2.0 + ascent
		if font_to_use:
			var outline_count: int = mini(outline_sizes.size(), outline_colors.size())
			for l in range(right_lines.size()):
				var line_text = right_lines[l]
				var text_y = right_start_y + l * line_height
				
				var text_width = font_to_use.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				var draw_x = size.x - margin_right - text_width
				
				for j in range(outline_count):
					var offset: Vector2 = outline_offsets[j] if j < outline_offsets.size() else Vector2.ZERO
					draw_string_outline(font_to_use, Vector2(draw_x, text_y) + offset, line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_sizes[j], outline_colors[j])

				draw_string(font_to_use, Vector2(draw_x, text_y), line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

		current_y += total_item_height

		if i < item_count - 1:
			current_y += item_separator / 2.0
			
			if separator_style:
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



## Generates the lines for the right column (quantities and percentage)
func _get_right_column_lines(item: Dictionary) -> PackedStringArray:
	var lines = PackedStringArray()
	var quantity1 = item.get("min_quantity", 1)
	var quantity2 = item.get("max_quantity", 1)
	
	var q1_str = GameManager.get_number_formatted(quantity1) if GameManager else str(quantity1)
	var q2_str = GameManager.get_number_formatted(quantity2) if GameManager else str(quantity2)
	
	if quantity2 > quantity1:
		lines.append("x " + q1_str)
		lines.append("-> " + q2_str)
	else:
		lines.append("x " + q1_str)
		
	if item.has("possessed_quantity"):
		var poss_qty = int(item.get("possessed_quantity"))
		var qty_str = GameManager.get_number_formatted(poss_qty) if GameManager else str(poss_qty)
		lines.append(" <" + qty_str + ">")
		
	var show_percent: bool = false
	match percent_mode:
		PercentMode.SHOW_ALWAYS:
			show_percent = true
		PercentMode.SHOW_IF_KILLED:
			show_percent = has_been_killed
		PercentMode.SHOW_IF_DROPPED:
			show_percent = _has_obtained_drop(item)
		PercentMode.NEVER_SHOW:
			show_percent = false
			
	if show_percent:
		lines.append(str(item.get("percent", 0.0)) + "%")
		
	return lines



## Checks if the specific drop item has been obtained by the player
func _has_obtained_drop(_item: Dictionary) -> bool:
	pass
	return false
#endregion



#region Debug
## Fills the reward items array with dummy data for testing and visualization
func _debug_fill_fake_items() -> void:
	var placeholder: PlaceholderTexture2D = PlaceholderTexture2D.new()
	placeholder.size = Vector2(32, 32)

	var fake_data: Array[Dictionary] = [
		{"icon": placeholder, "name": "Rusty Gear", "color": "8b5a2b", "percent": 85.0},
		{"icon": placeholder, "name": "Brass Pipe", "color": "b5a642", "percent": 50.0},
		{"icon": placeholder, "name": "Aether Core", "color": "00ffff", "percent": 10.5},
		{"icon": null, "name": "Tattered Blueprint", "color": "ffffff", "percent": 1.0}
	]

	set_items(fake_data)
#endregion
