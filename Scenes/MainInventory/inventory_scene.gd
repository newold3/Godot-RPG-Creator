extends Control

@export_range(0, 20) var min_columns: int = 3

@export_category("Item Styles")
@export var background_normal: StyleBox
@export var background_hover: StyleBox
@export var background_selected: StyleBox
@export var background_tube: Texture
@export var text_color: Color = Color(0.99, 0.997, 1)


# Visualization configuration
const ICON_SIZE = Vector2(48, 48)
const ITEM_PADDING = Vector2(8, 8)
const HOVER_SCALE = 1.05
const CURSOR_BLINK_SPEED = 0.5
const ANIMATION_SPEED = 0.2

var font: Font
var font_size = 16

# Calculated values
var item_height: int = 0
var item_base_width: int = 0
var columns: int = 1
var total_rows: int = 0
var text_real_height: int = 0

# Animation state
var cursor_alpha = 0.0
var cursor_time = 0.0
var hover_scales = {}
var active_tweens = {}
var is_enabled: bool = false

# Resource cache
var texture_cache = {}
var text_widths = {}

# Interaction state
var hovered_cell: int = -1
var selected_cell: int = -1
var dragging_item = null

# Inventory data
var inventory_items = []

@onready var scroll_container: SmoothScrollContainer = %ScrollContainer
@onready var canvas: Control = %Canvas
@onready var context_menu: Label = %ContextMenu


func generar_nombre_aleatorio(min_len: int, max_len: int) -> String:
	var caracteres = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var longitud = randi_range(min_len, max_len)
	var nombre = ""
	
	for i in range(longitud):
		nombre += caracteres[randi_range(0, caracteres.length() - 1)]
	
	return nombre


func _ready():
	GameManager.set_text_config(context_menu)
	context_menu.focus_neighbor_left = context_menu.get_path()
	context_menu.focus_neighbor_top = context_menu.get_path()
	context_menu.focus_neighbor_right = context_menu.get_path()
	context_menu.focus_neighbor_bottom = context_menu.get_path()
	context_menu.focus_next = context_menu.get_path()
	context_menu.focus_previous = context_menu.get_path()
	item_rect_changed.connect(
		func():
			precalculate_dimensions()
			calculate_grid_dimensions()
			canvas.queue_redraw()
	)
	# Example data
	for i in range(21):
		inventory_items.append({
			"item_id": "potion",
			"item_name": generar_nombre_aleatorio(4, 8),
			"icon_path": "res://Assets/Images/SceneMenu/hp_icon.png",
			"quantity": randi() % 99 + 1
		})

	font = %ContextMenu.get_theme_font("font")
	for i in range(inventory_items.size()):
		hover_scales[i] = 1.0

	precalculate_dimensions()
	calculate_grid_dimensions()
	
	canvas.draw.connect(_on_canvas_draw)
	canvas.queue_redraw()


func get_item_count() -> int:
	return inventory_items.size()


func _process(delta):
	if not is_enabled: return
	
	# Update cursor blink
	cursor_time += delta
	cursor_alpha = 0.5 + 0.5 * sin(cursor_time * PI * 2 / CURSOR_BLINK_SPEED)
	canvas.queue_redraw()
	
	# Update context position
	update_context_menu_position()


func focus() -> void:
	context_menu.grab_focus()


func select_item(id: int) -> void:
	if id >= 0 and get_item_count() > id:
		selected_cell = id
		update_context_menu_position()
		context_menu.grab_focus()
		set_vertical_scrollbar_value()
	else:
		selected_cell = -1
		if context_menu.has_focus():
			context_menu.release_focus()


func precalculate_dimensions():
	var max_text_width = 0
	text_real_height = int(font.get_ascent() - font.get_descent()) # font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y
	var max_text_height = max(ICON_SIZE.y, text_real_height)
	
	for item in inventory_items:
		if not texture_cache.has(item.icon_path):
			texture_cache[item.icon_path] = load(item.icon_path)
		var full_text = "%s (%d)" % [item.item_name, item.quantity]
		var text_width = font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		text_widths[full_text] = text_width
		max_text_width = max(max_text_width, text_width)

	item_height = max_text_height + ITEM_PADDING.y * 2
	item_base_width = ICON_SIZE.x + ITEM_PADDING.x * 3 + max_text_width


func calculate_grid_dimensions():
	if not scroll_container:
		return
	columns = max(max(1, min_columns), min(inventory_items.size(), floor(scroll_container.size.x / item_base_width)))
	item_base_width = int(scroll_container.size.x / columns - ITEM_PADDING.x)
	total_rows = ceil(float(inventory_items.size()) / columns)
	canvas.custom_minimum_size = Vector2(columns * item_base_width, total_rows * item_height)
	canvas.size = canvas.custom_minimum_size


func _on_canvas_draw():
	if not scroll_container:
		return

	var scroll_offset = Vector2(scroll_container.get_h_scroll_bar().value, scroll_container.get_v_scroll_bar().value)
	var visible_rect = Rect2(scroll_offset, scroll_container.size)

	var start_row = floor(scroll_offset.y / item_height)
	var end_row = min(total_rows, ceil((scroll_offset.y + scroll_container.size.y) / item_height))

	for row in range(start_row, end_row):
		for col in range(columns):
			var index = row * columns + col
			if index >= inventory_items.size():
				break
			var item_pos = Vector2(col * item_base_width, row * item_height)
			var item_rect = Rect2(item_pos, Vector2(item_base_width, item_height))
			if visible_rect.intersects(item_rect):
				draw_item(index, inventory_items[index], item_pos)


func draw_item(index: int, item: Dictionary, pos: Vector2):
	# Get scale for this item (default 1.0)
	var sc = hover_scales.get(index, 1.0)
	# Calculate offset to center scaled item within its cell
	var center_offset = (Vector2(item_base_width - ITEM_PADDING.x * 2, item_height - ITEM_PADDING.y * 2) * sc - Vector2(item_base_width - ITEM_PADDING.x * 2, item_height - ITEM_PADDING.y * 2)) / 2
	var transform_pos = pos + ITEM_PADDING - center_offset # Añadir padding y centrar
	
	# Draw item background
	var item_rect = Rect2(Vector2.ZERO, Vector2(item_base_width - ITEM_PADDING.x * 2, item_height - ITEM_PADDING.y * 2))
	
	# draw back tube without zoom
	if background_tube:
		# Restore transform to draw tube without scale
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		
		var tube_rect = Rect2()
		# Calculate tube width to next item or edge
		var tube_width = 0
		var col = index % int(columns)
		if col == columns - 1 or index == inventory_items.size() - 1:
			# If last column, extend to scroll_container edge
			tube_width = scroll_container.size.x - (pos.x + item_rect.size.x)
		else:
			# If not last column or last item, extend to next item
			tube_width = item_base_width - item_rect.size.x
		
		# Make tube wider extending to the right
		tube_rect.size.x = item_rect.size.x + tube_width # Extender hasta el siguiente ítem o borde
		tube_rect.size.y = item_rect.size.y * 0.6 # 60% del alto del item
		
		# Center tube vertically and position it
		tube_rect.position = pos + Vector2(10, 0) # Comenzar desde el inicio del ítem + 10 px a la derecha
		tube_rect.position.y += (item_rect.size.y - tube_rect.size.y) / 2 # Centrar verticalmente
		
		# Draw tube
		canvas.draw_texture_rect(background_tube, tube_rect, false)
	
	# Apply transform to rest of elements (for zoom/scale)
	canvas.draw_set_transform(transform_pos, 0, Vector2(sc, sc))
	
	# Apply background padding
	if background_normal:
		canvas.draw_style_box(background_normal, item_rect)
		
	var style: StyleBox
	if index == hovered_cell and background_hover:
		style = background_hover
		if "modulate_color" in style:
			style.modulate_color.a = cursor_alpha
	elif index == selected_cell and background_selected:
		style = background_selected
	
	if style:
		canvas.draw_style_box(style, item_rect)
	
	
	# Calculate element positions within item
	var p = Vector2(ITEM_PADDING.x, item_rect.size.y * 0.5 - ICON_SIZE.y * 0.5)
	# Icon to the left with padding
	var icon_rect = Rect2(p, ICON_SIZE)
	# Text to the right of icon
	var text_pos = Vector2(
		ICON_SIZE.x + ITEM_PADDING.x,
		float((item_height - font_size) / 2.0 + text_real_height / 2.0)
	)
	# Quantity text
	var quantity_text = "%d" % item.quantity
	# Quantity to the right
	var quantity_pos = Vector2(
		item_base_width - ITEM_PADDING.x * 3 - font.get_string_size(quantity_text).x,
		float((item_height - font_size) / 2.0 + text_real_height / 2.0)
	)
	# Draw icon
	if texture_cache.has(item.icon_path):
		canvas.draw_texture_rect(texture_cache[item.icon_path], icon_rect, false)
	# Draw text (item name)
	var full_text = item.item_name
	var outline_size = %ContextMenu.get("theme_override_constants/outline_size")
	var outline_color = %ContextMenu.get("theme_override_colors/font_outline_color")
	var shadow_offset = Vector2(
		%ContextMenu.get("theme_override_constants/shadow_offset_x"),
		%ContextMenu.get("theme_override_constants/shadow_offset_y")
	)
	var shadow_color = %ContextMenu.get("theme_override_colors/font_shadow_color")
	var align = HORIZONTAL_ALIGNMENT_LEFT
	canvas.draw_string(font, text_pos + shadow_offset, full_text, align, -1, font_size, shadow_color) # Shadow
	canvas.draw_string_outline(font, text_pos, full_text, align, -1, font_size, outline_size, outline_color) # Border
	canvas.draw_string(font, text_pos, full_text, align, -1, font_size, text_color) # text
	# Draw quantity (right aligned)
	canvas.draw_string(font, quantity_pos + shadow_offset, quantity_text, align, -1, font_size, shadow_color) # Shadow
	canvas.draw_string_outline(font, quantity_pos, quantity_text, align, -1, font_size, outline_size, outline_color) # Border
	canvas.draw_string(font, quantity_pos, quantity_text, align, -1, font_size, text_color) # text
	# Restore transform to original state
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _gui_input(event):
	if event is InputEventMouseMotion:
		var prev_hover = hovered_cell
		hovered_cell = get_cell_at_position(event.global_position)
		if hovered_cell != prev_hover:
			if prev_hover >= 0 and prev_hover != selected_cell:
				animate_hover_scale(prev_hover, 1.0)
			if hovered_cell >= 0:
				animate_hover_scale(hovered_cell, HOVER_SCALE)
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW
			queue_redraw()
	elif event.is_action_pressed("Mouse Left"):
		if selected_cell >= 0:
			animate_hover_scale(selected_cell, 1.0)
		selected_cell = hovered_cell
		context_menu.grab_focus()


func _input(_event: InputEvent) -> void:
	if not is_enabled: return
	if GameManager.is_key_pressed(["ui_up", "ui_down", "ui_left", "ui_right"], true):
		var callable = func():
			var direction: String = GameManager.get_last_key_pressed()
			var index: int = selected_cell
			var items_amount: int = get_item_count()
			@warning_ignore("integer_division")
			var current_row: int = int(index / columns)
			var current_column: int = int(index % columns)
			if index != -1:
				match direction:
					"ui_left":
						index = wrapi(index - 1, 0, items_amount)
					"ui_right":
						index = wrapi(index + 1, 0, items_amount)
					"ui_up":
						index -= columns
						if index < 0:
							index = min(items_amount - 1, (total_rows - 1) * columns + current_column)
					"ui_down":
						index += columns
						if index > items_amount - 1:
							if current_row == total_rows - 2:
								index = items_amount - 1
							else:
								index = current_column
				select_item(index)
		var action_name = GameManager.get_last_key_pressed()
		GameManager.add_key_callback(action_name, callable)


func animate_hover_scale(index: int, target_scale: float):
	if active_tweens.has(index):
		active_tweens[index].kill()
	var tween = create_tween()
	tween.tween_method(process_animate_hover_scale.bind(index), hover_scales[index], target_scale, ANIMATION_SPEED)
	tween.finished.connect(queue_redraw)
	active_tweens[index] = tween


func process_animate_hover_scale(value: float, index: int) -> void:
	hover_scales[index] = value


func get_cell_at_position(_global_pos: Vector2) -> int:
	# Convert global mouse position to local canvas coordinates
	var local_pos = canvas.get_local_mouse_position()

	# Get scroll offset
	var offsetx = scroll_container.get_h_scroll_bar().value * scroll_container.get_h_scroll_bar().step
	var offsety = scroll_container.get_v_scroll_bar().value * scroll_container.get_v_scroll_bar().step
	var scroll_offset = Vector2(offsetx, offsety)

	# Adjust position with scroll offset
	var adjusted_pos = local_pos + scroll_offset
	
	var grid_width = columns * item_base_width
	var grid_height = ceil(float(inventory_items.size()) / columns) * item_height
	if adjusted_pos.x < 0 or adjusted_pos.x >= grid_width or adjusted_pos.y < 0 or adjusted_pos.y >= grid_height:
		return -1 # Outside grid limits

	# Calculate row and column
	var row = floor(adjusted_pos.y / item_height)
	var col = floor(adjusted_pos.x / item_base_width)

	# Calculate item index
	var index = row * columns + col

	# Verify index is valid
	if index >= 0 and index < inventory_items.size():
		var item_pos = Vector2(col * item_base_width, row * item_height)
		var item_rect = Rect2(item_pos, Vector2(item_base_width, item_height))

		# Check if point is within item rectangle
		if item_rect.has_point(adjusted_pos):
			return index

	return -1


func set_vertical_scrollbar_value():
	if selected_cell >= 0:
		# Calculate row and column
		@warning_ignore("integer_division")
		var row = int(selected_cell / columns)
		var col = int(selected_cell % columns)
		
		# Calculate item's absolute position
		var item_rect = Rect2(
			col * item_base_width, # x position
			row * item_height, # y position
			item_base_width, # width
			item_height # height
		)
		
		# Get vertical scrollbar
		var vbar = scroll_container.get_v_scroll_bar()
		
		# Calculate scrollbar value based on item's y position
		var normalized_y = item_rect.position.y
		vbar.value = normalized_y


func update_context_menu_position():
	if selected_cell >= 0 and context_menu:
		if is_item_visible_on_parent():
			GameManager.hand_cursor.visible = true
		else:
			GameManager.hand_cursor.visible = false
		# Get row and column of selected item
		@warning_ignore("integer_division")
		var row = int(selected_cell / columns)
		var col = int(selected_cell % columns)
		
		# Calculate item position on canvas
		var item_pos = Vector2(
			col * item_base_width,
			row * item_height
		)
		
		context_menu.size = Vector2(item_base_width, item_height)
		
		# Get scroll offset
		var scroll_offset = Vector2(
			scroll_container.get_h_scroll_bar().value,
			scroll_container.get_v_scroll_bar().value
		)
		
		# Adjust item position with scroll offset
		var adjusted_item_pos = item_pos - scroll_offset
		
		# Calculate context_menu position
		#var context_menu_pos = Vector2(
			#adjusted_item_pos.x - context_menu.size.x - ITEM_PADDING.x,  # A la izquierda del ítem
			#adjusted_item_pos.y + (item_height - context_menu.size.y) / 2  # Centrado verticalmente
		#)
		var context_menu_pos = Vector2(
			adjusted_item_pos.x, # A la izquierda del ítem
			adjusted_item_pos.y # Centrado verticalmente
		)
		
		# Ensure context_menu doesn't go off screen
		context_menu_pos.x = max(context_menu_pos.x, 0)
		context_menu_pos.y = max(context_menu_pos.y, 0)
		
		# Set context_menu position
		context_menu.position = context_menu_pos


func is_item_visible_on_parent() -> bool:
	# Check if an item is selected
	if selected_cell == -1:
		return false

	# Get row and column of selected item
	@warning_ignore("integer_division")
	var row = int(selected_cell / columns)
	var col = int(selected_cell % columns)

	# Calculate item rectangle in local canvas coordinates
	var item_rect = Rect2(
		Vector2(col * item_base_width, row * item_height),
		Vector2(item_base_width, item_height)
	)

	# Get scroll offset
	var scroll_offset = Vector2(
		scroll_container.get_h_scroll_bar().value,
		scroll_container.get_v_scroll_bar().value
	)

	# Adjust item position with scroll offset
	var adjusted_item_rect = Rect2(
		item_rect.position - scroll_offset,
		item_rect.size
	)

	# Verify if item is completely outside visible area
	var margin = 28
	var is_item_visible = (
		adjusted_item_rect.end.x > margin and
		adjusted_item_rect.position.x < scroll_container.size.x - margin and
		adjusted_item_rect.end.y > margin and
		adjusted_item_rect.position.y < scroll_container.size.y - margin
	)

	return is_item_visible


func remove_item(item_id: String, amount: int = 1) -> bool:
	for i in range(len(inventory_items)):
		if inventory_items[i].item_id == item_id:
			inventory_items[i].quantity -= amount
			if inventory_items[i].quantity <= 0:
				inventory_items.remove_at(i)
				calculate_grid_dimensions()
			queue_redraw()
			return true
	return false


func add_item(item: Dictionary) -> bool:
	inventory_items.append(item)

	# Cache new item resources
	if not texture_cache.has(item.icon_path):
		texture_cache[item.icon_path] = load(item.icon_path)

	var full_text = "%s (%d)" % [item.item_name, item.quantity]
	if not text_widths.has(full_text):
		text_widths[full_text] = font.get_string_size(
			full_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		).x

	calculate_grid_dimensions()
	queue_redraw()
	return true


func _notification(what):
	if what == NOTIFICATION_MOUSE_EXIT:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		if hovered_cell >= 0:
			animate_hover_scale(hovered_cell, 1.0)
			hovered_cell = -1
			queue_redraw()
