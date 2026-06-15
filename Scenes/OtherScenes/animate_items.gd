extends Control
class_name ItemAnimationControl

## Size of the text font
@export var text_size: int = 16
## Size of the icon
@export var icon_size: Vector2 = Vector2(26, 26)
## Separation between icon and text
@export var icon_separation: float = 10.0
## Color of the prefix text
@export var prefix_color: Color = Color.WHITE
## Color of the quantity text
@export var quantity_color: Color = Color.WHITE
## Font resource used for rendering text
@export var font: Font
## Background style for the item
@export var text_background_style: StyleBox
## How long the item stays visible
@export var item_lifetime: float = 3.0
## Duration of the entry and exit animations
@export var move_duration: float = 0.3
## Distance the item bounces during animation
@export var bounce_distance: float = 15.0
## Vertical spacing between items
@export var vertical_spacing: float = 30.0
## Horizontal offset from the screen edge
@export var horizontal_offset: float = 20.0
## Vertical offset from the screen edge
@export var vertical_offset: float = 20.0
## Delay between spawning multiple items
@export var spawn_delay: float = 0.05
## The exact screen position where items will spawn by default
@export var spawn_position: SpawnPosition = SpawnPosition.BOTTOM_RIGHT
## How new items interact with existing ones by default
@export var spawn_behavior: SpawnBehavior = SpawnBehavior.PUSH_EXISTING
## Global offset applied to the final position and animation
@export var global_offset: Vector2 = Vector2.ZERO

enum State {ENTERING, STABLE, EXITING}
enum SpawnBehavior {PUSH_EXISTING, APPEND_AT_END}
enum SpawnPosition {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	CENTER_LEFT, CENTER, CENTER_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT
}

var items: Array[Dictionary] = []
var pending_queue: Array = []
var spawn_timer: float = 0.0
var icons_cache: Dictionary = {}
var _was_drawing: bool = false


#region Core Functions
## Initializes the component and sets the fallback font if needed
func _ready():
	if not font:
		font = ThemeDB.fallback_font
	set_process(true)
#endregion


#region Public Functions
## Adds multiple items to the pending queue with optional custom position and behavior
func add_items(new_items: Array, custom_pos: int = -1, custom_behavior: int = -1):
	if new_items.is_empty():
		return
	
	for item in new_items:
		pending_queue.append({
			"data": item,
			"pos": custom_pos,
			"beh": custom_behavior
		})


## Adds a single item to the pending queue with optional custom position and behavior
func add_single_item(item_data: Dictionary, custom_pos: int = -1, custom_behavior: int = -1):
	add_items([item_data], custom_pos, custom_behavior)


## Returns the count of currently active items
func get_active_items_count() -> int:
	return items.size()


## Returns the count of items waiting to be spawned
func get_pending_items_count() -> int:
	return pending_queue.size()


## Clears all active and pending items as well as the cache
func clear_all_items():
	items.clear()
	pending_queue.clear()
	icons_cache.clear()
	queue_redraw()
#endregion


#region Main System
## Processes the timer, queues, and triggers redraws
func _process(delta: float):
	if not pending_queue.is_empty():
		spawn_timer += delta
	else:
		spawn_timer = 0.0
	
	update_items(delta)
	
	if spawn_timer >= spawn_delay and not pending_queue.is_empty():
		try_spawn_next_item()
	
	if not items.is_empty() or not pending_queue.is_empty():
		queue_redraw()
		_was_drawing = true
	elif _was_drawing:
		queue_redraw()
		_was_drawing = false
		icons_cache.clear()


## Attempts to spawn the next item from the queue based on selected mode
func try_spawn_next_item():
	var next_pending = pending_queue[0]
	var item_data = next_pending.data
	
	var pos_type = next_pending.pos if next_pending.pos != -1 else spawn_position
	var beh_type = next_pending.beh if next_pending.beh != -1 else spawn_behavior
	
	var item_size = calculate_item_size(item_data)
	
	if can_fit_item(item_size, item_data, pos_type):
		pending_queue.remove_at(0)
		create_item(item_data, item_size, pos_type, beh_type)
		spawn_timer = 0.0
	else:
		spawn_timer = 0.0


## Updates the state of all active items and removes finished ones
func update_items(delta: float):
	var needs_recalc = false
	
	for i in range(items.size() - 1, -1, -1):
		var item = items[i]
		update_item(item, delta)
		
		if item.state == State.EXITING and item.alpha <= 0.0:
			items.remove_at(i)
			needs_recalc = true
			
	if needs_recalc:
		recalculate_targets()
#endregion


#region Calculations And Validations
## Calculates the total size of the item including text and icons
func calculate_item_size(item_data: Dictionary) -> Vector2:
	var prefix = item_data.get("prefix", "")
	var item_name = item_data.get("item_name", "Item")
	var quantity_text = " x%d" % item_data.get("quantity", 1)
	
	var prefix_size = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size) if prefix != "" else Vector2.ZERO
	var name_size = font.get_string_size(item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	var quantity_size = font.get_string_size(quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	
	var text_width = prefix_size.x + name_size.x + quantity_size.x
	var text_height = max(prefix_size.y, name_size.y, quantity_size.y)
	
	var margins = Vector2.ZERO
	if text_background_style:
		margins.x = text_background_style.get_content_margin(SIDE_LEFT) + text_background_style.get_content_margin(SIDE_RIGHT)
		margins.y = text_background_style.get_content_margin(SIDE_TOP) + text_background_style.get_content_margin(SIDE_BOTTOM)
	
	var has_icon = has_valid_icon(item_data.get("icon_path"))
	var content_width = text_width
	
	if has_icon:
		content_width += icon_size.x + icon_separation
	
	var content_height = max(icon_size.y, text_height)
	
	return Vector2(content_width + margins.x, content_height + margins.y)


## Checks if the new item fits in the remaining screen space for its specific position
func can_fit_item(item_size: Vector2, item_data: Dictionary, pos_type: int) -> bool:
	var available_height = size.y - (vertical_offset * 2)
	var needed_height = item_size.y
	var last_item = null
	
	for item in items:
		if item.spawn_position == pos_type:
			needed_height += item.size.y + get_vertical_separation(item.data, last_item.data if last_item else {})
			last_item = item
	
	needed_height += get_vertical_separation(item_data, last_item.data if last_item else {})
	
	return needed_height <= available_height


## Calculates the vertical separation dynamically checking against the previous item
func get_vertical_separation(new_data: Dictionary, last_data: Dictionary) -> float:
	if last_data.is_empty() or vertical_spacing >= 0:
		return vertical_spacing
	
	var new_has = has_valid_icon(new_data.get("icon_path"))
	var last_has = has_valid_icon(last_data.get("icon_path"))
	
	return 0.0 if new_has != last_has else vertical_spacing


## Validates if the provided icon path corresponds to a loadable resource
func has_valid_icon(icon_path) -> bool:
	if icon_path == null:
		return false
	
	if icon_path is String:
		return AssetManager.exists(icon_path)
	elif icon_path is RPGIcon:
		return AssetManager.exists(icon_path.path)
	
	return false


## Determines the vertical direction for stacking items based on spawn position and behavior
func get_y_direction(pos_type: int, beh_type: int) -> float:
	if pos_type in [SpawnPosition.BOTTOM_LEFT, SpawnPosition.BOTTOM_CENTER, SpawnPosition.BOTTOM_RIGHT]:
		return -1.0
	elif pos_type in [SpawnPosition.TOP_LEFT, SpawnPosition.TOP_CENTER, SpawnPosition.TOP_RIGHT]:
		return 1.0
	else:
		if beh_type == SpawnBehavior.PUSH_EXISTING:
			return -1.0
		else:
			return 1.0


## Calculates the base X position based on the current spawn position
func get_base_x(item_width: float, pos_type: int) -> float:
	if pos_type in [SpawnPosition.TOP_LEFT, SpawnPosition.CENTER_LEFT, SpawnPosition.BOTTOM_LEFT]:
		return horizontal_offset + global_offset.x
	elif pos_type in [SpawnPosition.TOP_RIGHT, SpawnPosition.CENTER_RIGHT, SpawnPosition.BOTTOM_RIGHT]:
		return size.x - item_width - horizontal_offset + global_offset.x
	else:
		return (size.x - item_width) / 2.0 + global_offset.x


## Calculates the base Y position based on the current spawn position
func get_base_y(item_height: float, pos_type: int) -> float:
	if pos_type in [SpawnPosition.TOP_LEFT, SpawnPosition.TOP_CENTER, SpawnPosition.TOP_RIGHT]:
		return vertical_offset + global_offset.y
	elif pos_type in [SpawnPosition.BOTTOM_LEFT, SpawnPosition.BOTTOM_CENTER, SpawnPosition.BOTTOM_RIGHT]:
		return size.y - item_height - vertical_offset + global_offset.y
	else:
		return (size.y - item_height) / 2.0 + global_offset.y
#endregion


#region Creation And Positioning
## Creates a new item and calculates its starting and target positions
func create_item(item_data: Dictionary, item_size: Vector2, pos_type: int, beh_type: int):
	var icon = load_icon(item_data.get("icon_path"))
	
	var item = {
		"data": item_data,
		"spawn_position": pos_type,
		"spawn_behavior": beh_type,
		"state": State.ENTERING,
		"timer": 0.0,
		"lifetime_timer": 0.0,
		"alpha": 0.0,
		"size": item_size,
		"icon": icon,
		"start_pos": Vector2.ZERO,
		"target_pos": Vector2.ZERO,
		"current_pos": Vector2.ZERO
	}
	
	if beh_type == SpawnBehavior.PUSH_EXISTING:
		items.push_front(item)
	else:
		items.append(item)
		
	recalculate_targets()
	
	var is_center_x = pos_type in [SpawnPosition.TOP_CENTER, SpawnPosition.CENTER, SpawnPosition.BOTTOM_CENTER]
	var is_left = pos_type in [SpawnPosition.TOP_LEFT, SpawnPosition.CENTER_LEFT, SpawnPosition.BOTTOM_LEFT]
	
	if is_center_x:
		item.start_pos.x = item.target_pos.x
		var y_dir = get_y_direction(pos_type, beh_type)
		
		if pos_type == SpawnPosition.TOP_CENTER:
			item.start_pos.y = -item.size.y + global_offset.y
		elif pos_type == SpawnPosition.BOTTOM_CENTER:
			item.start_pos.y = size.y + item.size.y + global_offset.y
		else:
			item.start_pos.y = item.target_pos.y - (50.0 * y_dir)
			
		item.current_pos.y = item.start_pos.y
	else:
		if is_left:
			item.start_pos.x = -item.size.x + global_offset.x
		else:
			item.start_pos.x = size.x + item.size.x + global_offset.x
		item.current_pos.y = item.target_pos.y
		
	item.current_pos.x = item.start_pos.x


## Recalculates the target positions dynamically grouping by specific spawn positions
func recalculate_targets():
	var offsets = {}
	var last_items = {}
	
	for item in items:
		var pos_type = item.spawn_position
		var beh_type = item.spawn_behavior
		
		if not offsets.has(pos_type):
			offsets[pos_type] = 0.0
			
		var y_dir = get_y_direction(pos_type, beh_type)
		var target_x = get_base_x(item.size.x, pos_type)
		var target_y = get_base_y(item.size.y, pos_type) + (offsets[pos_type] * y_dir)
			
		item.target_pos = Vector2(target_x, target_y)
		
		var sep = get_vertical_separation(item.data, last_items[pos_type].data if last_items.has(pos_type) else {})
		offsets[pos_type] += item.size.y + sep
		last_items[pos_type] = item
#endregion


#region Animations
## Updates the animation and lifecycle timers for a single item
func update_item(item: Dictionary, delta: float):
	item.timer += delta
	item.lifetime_timer += delta
	
	var is_center_x = item.spawn_position in [SpawnPosition.TOP_CENTER, SpawnPosition.CENTER, SpawnPosition.BOTTOM_CENTER]
	var animating_y = is_center_x and item.state != State.STABLE
	
	if not animating_y:
		item.current_pos.y = lerp(item.current_pos.y, item.target_pos.y, 15.0 * delta)
	
	match item.state:
		State.ENTERING:
			update_entering(item)
		State.STABLE:
			update_stable(item)
		State.EXITING:
			update_exiting(item)


## Handles the entry animation logic for an item
func update_entering(item: Dictionary):
	var progress = min(item.timer / move_duration, 1.0)
	var eased_progress = ease_out_back(progress)
	
	var pos_type = item.spawn_position
	var is_center_x = pos_type in [SpawnPosition.TOP_CENTER, SpawnPosition.CENTER, SpawnPosition.BOTTOM_CENTER]
	
	if is_center_x:
		var y_dir = get_y_direction(pos_type, item.spawn_behavior)
		var target_y = item.target_pos.y
		
		if progress < 0.8:
			target_y += (bounce_distance * y_dir) * (1.0 - progress / 0.8)
			
		item.current_pos.y = lerp(item.start_pos.y, target_y, eased_progress)
		item.current_pos.x = item.target_pos.x
		item.alpha = min(progress * 2.0, 1.0)
	else:
		var is_left = pos_type in [SpawnPosition.TOP_LEFT, SpawnPosition.CENTER_LEFT, SpawnPosition.BOTTOM_LEFT]
		var direction = -1.0 if is_left else 1.0
		var target_x = item.target_pos.x
		
		if progress < 0.8:
			target_x -= (bounce_distance * direction) * (1.0 - progress / 0.8)
			
		item.current_pos.x = lerp(item.start_pos.x, target_x, eased_progress)
		item.alpha = min(progress * 2.0, 1.0)
	
	if progress >= 1.0:
		item.state = State.STABLE
		item.timer = 0.0
		item.current_pos.x = item.target_pos.x
		item.current_pos.y = item.target_pos.y


## Handles the stable display logic for an item
func update_stable(item: Dictionary):
	if item.lifetime_timer >= item_lifetime:
		item.state = State.EXITING
		item.timer = 0.0
		item.start_pos = item.current_pos


## Handles the exit animation logic for an item
func update_exiting(item: Dictionary):
	var progress = min(item.timer / move_duration, 1.0)
	
	var pos_type = item.spawn_position
	var is_center_x = pos_type in [SpawnPosition.TOP_CENTER, SpawnPosition.CENTER, SpawnPosition.BOTTOM_CENTER]
	
	if is_center_x:
		var y_dir = get_y_direction(pos_type, item.spawn_behavior)
		
		if progress < 0.5:
			var left_progress = progress * 2.0
			item.current_pos.y = item.start_pos.y + (bounce_distance * y_dir) * ease_out_cubic(left_progress)
		else:
			var right_progress = (progress - 0.5) * 2.0
			var target_y = 0.0
			
			if pos_type == SpawnPosition.TOP_CENTER:
				target_y = -item.size.y - 50.0 + global_offset.y
			elif pos_type == SpawnPosition.BOTTOM_CENTER:
				target_y = size.y + item.size.y + 50.0 + global_offset.y
			else:
				target_y = item.start_pos.y - (50.0 * y_dir) + global_offset.y
				
			var start_y = item.start_pos.y + (bounce_distance * y_dir)
			item.current_pos.y = lerp(start_y, target_y, ease_in_cubic(right_progress))
			
		item.alpha = 1.0 - progress
	else:
		var is_left = pos_type in [SpawnPosition.TOP_LEFT, SpawnPosition.CENTER_LEFT, SpawnPosition.BOTTOM_LEFT]
		var direction = -1.0 if is_left else 1.0
		
		if progress < 0.5:
			var left_progress = progress * 2.0
			item.current_pos.x = item.start_pos.x - (bounce_distance * direction) * ease_out_cubic(left_progress)
		else:
			var right_progress = (progress - 0.5) * 2.0
			var target_x = (-item.size.x - 50.0 + global_offset.x) if is_left else (size.x + item.size.x + 50.0 + global_offset.x)
			var start_x = item.start_pos.x - (bounce_distance * direction)
			item.current_pos.x = lerp(start_x, target_x, ease_in_cubic(right_progress))
			
		item.alpha = 1.0 - progress
#endregion


#region Utilities
## Loads and returns an icon texture from the given path or object
func load_icon(icon_path) -> Texture2D:
	if icon_path == null:
		return null
	
	var tex: Texture2D = null
	
	if icon_path is String and AssetManager.exists(icon_path):
		tex = ResourceLoader.load(icon_path)
	elif icon_path is RPGIcon:
		var icon: RPGIcon = icon_path
		if AssetManager.exists(icon.path):
			var base_tex = ResourceLoader.load(icon.path)
			if icon.region:
				tex = ImageTexture.create_from_image(base_tex.get_image().get_region(icon.region))
			else:
				tex = base_tex
	
	if tex and not tex in icons_cache:
		icons_cache[tex] = true
	
	return tex


## Calculates an ease-out-back interpolation curve
func ease_out_back(t: float) -> float:
	var c1 = 1.70158
	var c3 = c1 + 1.0
	return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)


## Calculates an ease-out-cubic interpolation curve
func ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


## Calculates an ease-in-cubic interpolation curve
func ease_in_cubic(t: float) -> float:
	return t * t * t
#endregion


#region Drawing
## Triggers the drawing operations for all active items
func _draw():
	for item in items:
		draw_item(item)


## Renders a single item to the screen using its calculated properties
func draw_item(item: Dictionary):
	if item.alpha <= 0.0:
		return
	
	var item_data = item.data
	var base_color = item_data.get("item_color", Color.WHITE)
	base_color.a = item.alpha

	var pos = item.current_pos
	var prefix = item_data.get("prefix", "")
	var item_name = item_data.get("item_name", "Item")
	var quantity_text = " x%d" % item_data.get("quantity", 1)
	var icon_align = item_data.get("icon_align", "left")

	var prefix_size = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size) if prefix != "" else Vector2.ZERO
	var name_size = font.get_string_size(item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	var quantity_size = font.get_string_size(quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	var text_height = max(prefix_size.y, name_size.y, quantity_size.y)

	var margins = Vector4.ZERO
	if text_background_style:
		margins.x = text_background_style.get_content_margin(SIDE_LEFT)
		margins.y = text_background_style.get_content_margin(SIDE_TOP)
		margins.z = text_background_style.get_content_margin(SIDE_RIGHT)
		margins.w = text_background_style.get_content_margin(SIDE_BOTTOM)

	if text_background_style:
		var style_rect = Rect2(pos, item.size)
		text_background_style.draw(get_canvas_item(), style_rect)

	var content_pos = pos + Vector2(margins.x, margins.y)
	var content_height = item.size.y - margins.y - margins.w
	var current_x = content_pos.x

	var text_y = content_pos.y + (content_height * 0.5) + (font.get_ascent(text_size) - text_height * 0.5)
	var text_pos = Vector2(current_x, text_y)

	if prefix != "":
		var prefix_color_alpha = prefix_color
		prefix_color_alpha.a = item.alpha
		draw_string(font, text_pos, prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, prefix_color_alpha)
		text_pos.x += prefix_size.x

	if item.icon and icon_align != "right":
		var icon_y = content_pos.y + (content_height - icon_size.y) * 0.5
		draw_texture_rect(item.icon, Rect2(Vector2(text_pos.x, icon_y), icon_size), false, Color(1.0, 1.0, 1.0, item.alpha))
		text_pos.x += icon_size.x + icon_separation

	draw_string(font, text_pos, item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, base_color)
	text_pos.x += name_size.x

	var quantity_color_alpha = quantity_color
	quantity_color_alpha.a = item.alpha
	draw_string(font, text_pos, quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, quantity_color_alpha)

	if item.icon and icon_align == "right":
		var icon_x = pos.x + item.size.x - margins.z - icon_size.x
		var icon_y = content_pos.y + (content_height - icon_size.y) * 0.5
		draw_texture_rect(item.icon, Rect2(Vector2(icon_x, icon_y), icon_size), false, Color(1.0, 1.0, 1.0, item.alpha))
#endregion
