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
## Explicit size for the icons, uses the original texture size if set to Vector2.ZERO
@export var icon_size: Vector2 = Vector2.ZERO
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
## Vertical spacing between items
@export var vertical_separator: int = 4
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
## Called when the control receives notifications, used to handle resizing
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_minimum_size()
		queue_redraw()
#endregion



#region Layout
## Updates the custom minimum size of the control based on its contents
func _update_minimum_size() -> void:
	if is_disabled or _reward_items.is_empty():
		custom_minimum_size = Vector2.ZERO
		return

	var total_height: float = 0.0
	var separator_height: float = separator_style.get_minimum_size().y if separator_style else 0.0

	for item in _reward_items:
		var current_font_size: int = font_size
		var icon: Texture2D = item.get("icon", null)
		var text: String = _get_item_text(item)
		var current_icon_size: Vector2 = icon_size if icon_size != Vector2.ZERO else (icon.get_size() if icon else Vector2.ZERO)

		if font:
			current_font_size = _get_dynamic_font_size(text, size.x - current_icon_size.x)

		var text_height: float = font.get_height(current_font_size) if font else 0.0
		var item_height: float = maxf(current_icon_size.y, text_height)

		total_height += item_height

	total_height += (vertical_separator + separator_height) * maxf(0, _reward_items.size() - 1)

	if background_style:
		var bg_margins: float = background_style.get_margin(SIDE_TOP) + background_style.get_margin(SIDE_BOTTOM)
		total_height += bg_margins * _reward_items.size()

	custom_minimum_size = Vector2(0, total_height)
#endregion



#region Drawing
## Draws the items with their backgrounds, icons, and dynamically sized text
func _draw() -> void:
	if is_disabled:
		return

	var current_y: float = 0.0
	var item_count: int = _reward_items.size()

	for i in range(item_count):
		var item: Dictionary = _reward_items[i]
		var icon: Texture2D = item.get("icon", null)
		var text: String = _get_item_text(item)
		var text_color: Color = default_text_color

		if not force_default_color and item.has("color"):
			text_color = Color(item.get("color"))

		var current_icon_size: Vector2 = icon_size if icon_size != Vector2.ZERO else (icon.get_size() if icon else Vector2.ZERO)
		var spacing: float = 4.0 if icon else 0.0
		var current_font_size: int = font_size

		if font:
			current_font_size = _get_dynamic_font_size(text, size.x - current_icon_size.x - spacing)

		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, current_font_size) if font else Vector2.ZERO
		var item_height: float = maxf(current_icon_size.y, text_size.y)
		var bg_margin_top: float = background_style.get_margin(SIDE_TOP) if background_style else 0.0
		var bg_margin_bottom: float = background_style.get_margin(SIDE_BOTTOM) if background_style else 0.0
		var total_item_height: float = item_height + bg_margin_top + bg_margin_bottom
		var total_content_width: float = current_icon_size.x + spacing + text_size.x
		var start_x: float = (size.x - total_content_width) / 2.0

		if background_style:
			background_style.draw(get_canvas_item(), Rect2(0, current_y, size.x, total_item_height))

		var content_y: float = current_y + bg_margin_top
		var icon_y: float = content_y + (item_height - current_icon_size.y) / 2.0
		var text_y: float = content_y + (item_height - text_size.y) / 2.0 + (font.get_ascent(current_font_size) if font else 0.0)

		if icon:
			var icon_rect: Rect2 = Rect2(Vector2(start_x, icon_y), current_icon_size)
			draw_texture_rect(icon, icon_rect, false)

		if font:
			var outline_count: int = mini(outline_sizes.size(), outline_colors.size())

			for j in range(outline_count):
				var offset: Vector2 = outline_offsets[j] if j < outline_offsets.size() else Vector2.ZERO
				draw_string_outline(font, Vector2(start_x + current_icon_size.x + spacing, text_y) + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, current_font_size, outline_sizes[j], outline_colors[j])

			draw_string(font, Vector2(start_x + current_icon_size.x + spacing, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, current_font_size, text_color)

		current_y += total_item_height

		if i < item_count - 1:
			current_y += vertical_separator / 2.0
			
			if separator_style:
				var sep_height: float = separator_style.get_minimum_size().y
				separator_style.draw(get_canvas_item(), Rect2(0, current_y, size.x, sep_height))
				current_y += sep_height
				
			current_y += vertical_separator / 2.0
#endregion



#region Helpers
## Calculates the maximum font size that allows the text to fit within the given width
func _get_dynamic_font_size(text: String, max_width: float) -> int:
	var current_size: int = font_size

	if not font or max_width <= 0:
		return current_size

	while current_size > 1:
		var string_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, current_size)

		if string_size.x <= max_width:
			break

		current_size -= 1

	return current_size



## Builds the final string for the item including the percentage if the current mode allows it
func _get_item_text(item: Dictionary) -> String:
	var text: String = item.get("name", "")
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
		text += " " + str(item.get("percent", 0.0)) + "%"
		
	return text



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
