extends Control
class_name ItemAnimationControl

# Visual configuration
@export var text_size: int = 16
@export var icon_size: Vector2 = Vector2(26, 26)
@export var icon_separation: float = 10.0
@export var prefix_color: Color = Color.WHITE
@export var quantity_color: Color = Color.WHITE
@export var font: Font
@export var text_background_style: StyleBox

# Animation configuration
@export var item_lifetime: float = 3.0
@export var move_duration: float = 0.3
@export var bounce_distance: float = 15.0
@export var vertical_spacing: float = 30.0
@export var horizontal_offset: float = 20.0
@export var vertical_offset: float = 20.0
@export var spawn_delay: float = 0.05

# Item states
enum State {ENTERING, STABLE, EXITING}

# System
var items: Array[Dictionary] = []
var pending_queue: Array = []
var spawn_timer: float = 0.0
var icons_cache: Dictionary = {}

func _ready():
	if not font:
		font = ThemeDB.fallback_font
	set_process(true)

# ================== PUBLIC FUNCTIONS ==================

func add_items(new_items: Array):
	if new_items.is_empty():
		return
	pending_queue.append_array(new_items)

func add_single_item(item_data: Dictionary):
	add_items([item_data])

func get_active_items_count() -> int:
	return items.size()

func get_pending_items_count() -> int:
	return pending_queue.size()

func clear_all_items():
	items.clear()
	pending_queue.clear()
	icons_cache.clear()

# ================== MAIN SYSTEM ==================

func _process(delta: float):
	spawn_timer += delta
	update_items(delta)
	
	# Try to process queue if it's spawn time
	if spawn_timer >= spawn_delay and not pending_queue.is_empty():
		try_spawn_next_item()
	
	# Redraw if there are items
	if not items.is_empty() or not pending_queue.is_empty():
		queue_redraw()
	else:
		icons_cache.clear()

func try_spawn_next_item():
	var next_item_data = pending_queue[0]
	var item_size = calculate_item_size(next_item_data)
	
	if can_fit_item(item_size, next_item_data):
		pending_queue.remove_at(0)
		push_items_up(item_size.y + get_vertical_separation(next_item_data))
		create_item(next_item_data, item_size)
		spawn_timer = 0.0
	else:
		spawn_timer = 0.0 # Retry soon

func update_items(delta: float):
	for i in range(items.size() - 1, -1, -1):
		var item = items[i]
		update_item(item, delta)
		
		# Remove items that finished
		if item.state == State.EXITING and item.alpha <= 0.0:
			items.remove_at(i)

# ================== CALCULATIONS AND VALIDATIONS ==================

func calculate_item_size(item_data: Dictionary) -> Vector2:
	var prefix = item_data.get("prefix", "")
	var item_name = item_data.get("item_name", "Item")
	var quantity_text = " x%d" % item_data.get("quantity", 1)
	
	var prefix_size = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size) if prefix != "" else Vector2.ZERO
	var name_size = font.get_string_size(item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	var quantity_size = font.get_string_size(quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	
	var text_width = prefix_size.x + name_size.x + quantity_size.x
	var text_height = max(prefix_size.y, name_size.y, quantity_size.y)
	
	# StyleBox margins
	var margins = Vector2.ZERO
	if text_background_style:
		margins.x = text_background_style.get_content_margin(SIDE_LEFT) + text_background_style.get_content_margin(SIDE_RIGHT)
		margins.y = text_background_style.get_content_margin(SIDE_TOP) + text_background_style.get_content_margin(SIDE_BOTTOM)
	
	# Calculate real width based on whether it has an icon or not
	var has_icon = has_valid_icon(item_data.get("icon_path"))
	var content_width = text_width
	if has_icon:
		content_width += icon_size.x + icon_separation
	
	var content_height = max(icon_size.y, text_height)
	
	return Vector2(content_width + margins.x, content_height + margins.y)

func can_fit_item(item_size: Vector2, item_data: Dictionary) -> bool:
	# If the last item is entering, wait
	#if not items.is_empty() and items[-1].state == State.ENTERING:
		#return false
	var available_height = size.y - (vertical_offset * 2)
	var needed_height = item_size.y
	
	# Add height of existing items + separations
	for item in items:
		needed_height += item.size.y + get_vertical_separation(item_data)
	
	return needed_height <= available_height

func get_vertical_separation(new_item_data: Dictionary) -> float:
	# If no items or separation is not negative, use normal
	if items.is_empty() or vertical_spacing >= 0:
		return vertical_spacing
	
	# If separation is negative, check icon compatibility
	var last_item_data = items[-1].data
	var new_has_icon = has_valid_icon(new_item_data.get("icon_path"))
	var last_has_icon = has_valid_icon(last_item_data.get("icon_path"))
	
	# If incompatible, use 0 instead of negative
	return 0.0 if new_has_icon != last_has_icon else vertical_spacing

func has_valid_icon(icon_path) -> bool:
	if icon_path == null:
		return false
	
	if icon_path is String:
		return ResourceLoader.exists(icon_path)
	elif icon_path is RPGIcon:
		return ResourceLoader.exists(icon_path.path)
	
	return false

# ================== CREATION AND POSITIONING ==================

func create_item(item_data: Dictionary, item_size: Vector2):
	var icon = load_icon(item_data.icon_path)

	# Target position using REAL item width
	var target_x = size.x - item_size.x - horizontal_offset
	var target_y = size.y - item_size.y - vertical_offset
	
	# Initial position (off screen to the right)
	var start_x = size.x + item_size.x
	
	var item = {
		"data": item_data,
		"state": State.ENTERING,
		"timer": 0.0,
		"lifetime_timer": 0.0,
		"alpha": 0.0,
		"size": item_size,
		"icon": icon,
		"start_pos": Vector2(start_x, target_y),
		"target_pos": Vector2(target_x, target_y),
		"current_pos": Vector2(start_x, target_y)
	}
	
	items.append(item)

func push_items_up(distance: float):
	for item in items:
		item.target_pos.y -= distance
		item.current_pos.y -= distance
		if "start_pos" in item:
			item.start_pos.y -= distance

# ================== ANIMATIONS ==================

func update_item(item: Dictionary, delta: float):
	item.timer += delta
	item.lifetime_timer += delta
	
	match item.state:
		State.ENTERING:
			update_entering(item)
		State.STABLE:
			update_stable(item)
		State.EXITING:
			update_exiting(item)

func update_entering(item: Dictionary):
	var progress = min(item.timer / move_duration, 1.0)
	var eased_progress = ease_out_back(progress)
	
	# Horizontal movement with bounce
	var target_x = item.target_pos.x
	if progress < 0.8: # Go a little further first
		target_x -= bounce_distance * (1.0 - progress / 0.8)
	
	item.current_pos.x = lerp(item.start_pos.x, target_x, eased_progress)
	
	# Fade in
	item.alpha = min(progress * 2.0, 1.0)
	
	if progress >= 1.0:
		item.state = State.STABLE
		item.timer = 0.0
		item.current_pos.x = item.target_pos.x

func update_stable(item: Dictionary):
	# Check if it should exit
	if item.lifetime_timer >= item_lifetime:
		item.state = State.EXITING
		item.timer = 0.0
		item.start_pos = item.current_pos

func update_exiting(item: Dictionary):
	var progress = min(item.timer / move_duration, 1.0)
	
	if progress < 0.5:
		# First half: move a little to the left
		var left_progress = progress * 2.0
		item.current_pos.x = item.start_pos.x - bounce_distance * ease_out_cubic(left_progress)
	else:
		# Second half: exit to the right
		var right_progress = (progress - 0.5) * 2.0
		var target_x = size.x + item.size.x + 50
		var start_x = item.start_pos.x - bounce_distance
		item.current_pos.x = lerp(start_x, target_x, ease_in_cubic(right_progress))
	
	# Fade out
	item.alpha = 1.0 - progress

# ================== UTILITIES ==================

func load_icon(icon_path) -> Texture2D:
	if icon_path == null:
		return null
	
	var tex: Texture2D = null
	
	if icon_path is String and ResourceLoader.exists(icon_path):
		tex = ResourceLoader.load(icon_path)
	elif icon_path is RPGIcon:
		var icon: RPGIcon = icon_path
		if ResourceLoader.exists(icon.path):
			var base_tex = ResourceLoader.load(icon.path)
			if icon.region:
				tex = ImageTexture.create_from_image(base_tex.get_image().get_region(icon.region))
			else:
				tex = base_tex
	
	if tex and not tex in icons_cache:
		icons_cache[tex] = true
	
	return tex

func ease_out_back(t: float) -> float:
	var c1 = 1.70158
	var c3 = c1 + 1.0
	return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)

func ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func ease_in_cubic(t: float) -> float:
	return t * t * t

# ================== DRAWING ==================

func _draw():
	for item in items:
		draw_item(item)

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
	
	# Calculate text sizes
	var prefix_size = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size) if prefix != "" else Vector2.ZERO
	var name_size = font.get_string_size(item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	var quantity_size = font.get_string_size(quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	var text_height = max(prefix_size.y, name_size.y, quantity_size.y)
	
	# StyleBox margins
	var margins = Vector4.ZERO # left, top, right, bottom
	if text_background_style:
		margins.x = text_background_style.get_content_margin(SIDE_LEFT)
		margins.y = text_background_style.get_content_margin(SIDE_TOP)
		margins.z = text_background_style.get_content_margin(SIDE_RIGHT)
		margins.w = text_background_style.get_content_margin(SIDE_BOTTOM)
	
	# Draw StyleBox with REAL item size
	if text_background_style:
		var style_rect = Rect2(pos, item.size)
		text_background_style.draw(get_canvas_item(), style_rect)
	
	# Content position
	var content_pos = pos + Vector2(margins.x, margins.y)
	var content_height = item.size.y - margins.y - margins.w
	
	# Initial content position
	var current_x = content_pos.x
	
	# Text position
	var text_y = content_pos.y + (content_height * 0.5) + (font.get_ascent(text_size) - text_height * 0.5)
	var text_pos = Vector2(current_x, text_y)
	
	# Draw prefix
	if prefix != "":
		var prefix_color_alpha = prefix_color
		prefix_color_alpha.a = item.alpha
		draw_string(font, text_pos, prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, prefix_color_alpha)
		text_pos.x += prefix_size.x
	
	# Draw icon if exists
	if item.icon:
		var icon_y = content_pos.y + (content_height - icon_size.y) * 0.5
		draw_texture_rect(item.icon, Rect2(Vector2(text_pos.x, icon_y), icon_size), false)
		text_pos.x += icon_size.x + icon_separation
	
	# Draw rest of texts
	draw_string(font, text_pos, item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, base_color)
	text_pos.x += name_size.x
	
	var quantity_color_alpha = quantity_color
	quantity_color_alpha.a = item.alpha
	draw_string(font, text_pos, quantity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, quantity_color_alpha)
