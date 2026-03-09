@tool
class_name IngameItemList
extends Control

@export_category("Pagination")
## External paginator control to handle page splitting
@export var paginator: ItemPaginator:
	set(value):
		if is_instance_valid(paginator) and paginator.page_changed.is_connected(_on_page_changed):
			paginator.page_changed.disconnect(_on_page_changed)
		paginator = value
		if is_instance_valid(paginator):
			if not paginator.page_changed.is_connected(_on_page_changed):
				paginator.page_changed.connect(_on_page_changed)
			paginator.setup_pagination(items.size())
		refresh()

@export_category("Buttons")
## Normal background style for the item
@export var normal_style: StyleBox:
	set(value):
		normal_style = value
		refresh()
## Background style when the item is selected
@export var selected_style: StyleBox:
	set(value):
		selected_style = value
		refresh()
## Background style when the mouse hovers the item
@export var hover_style: StyleBox:
	set(value):
		hover_style = value
		refresh()
## Background style when the item is disabled
@export var disabled_style: StyleBox:
	set(value):
		disabled_style = value
		refresh()
## Base height of each drawn button
@export var button_height: int = 32:
	set(value):
		button_height = value
		_update_minimum_size()
		refresh()
## Sound effect when moving the cursor
@export var cursor_fx: AudioStream
## Sound effect when selecting or clicking an item
@export var select_fx: AudioStream
## Default texture for normal items
@export var default_item_icon: Texture2D:
	set(value):
		default_item_icon = value
		refresh()
## Default texture for weapons
@export var default_weapon_icon: Texture2D:
	set(value):
		default_weapon_icon = value
		refresh()
## Default texture for armors
@export var default_armor_icon: Texture2D:
	set(value):
		default_armor_icon = value
		refresh()
## Default texture for costumes
@export var default_custome_icon: Texture2D:
	set(value):
		default_custome_icon = value
		refresh()

@export_category("Visual")
## Number of columns for the list
@export var columns: int = 1:
	set(value):
		columns = max(1, value)
		_update_minimum_size()
		refresh()
## Horizontal separation between items
@export var horizontal_separation: int = 4:
	set(value):
		horizontal_separation = value
		refresh()
## Vertical separation between rows
@export var vertical_separation: int = 4:
	set(value):
		vertical_separation = value
		_update_minimum_size()
		refresh()
## Size of the drawn icons
@export var icon_size: Vector2 = Vector2(26, 26):
	set(value):
		icon_size = value
		refresh()
## Extra vertical padding added at the end for scrolling
@export var extra_bottom_padding: int = 32:
	set(value):
		extra_bottom_padding = value
		_update_minimum_size()

## Font used for the name and quantity
@export var font: Font:
	set(value):
		font = value
		refresh()
## Size of the font
@export_range(8, 256) var font_size: int = 26:
	set(value):
		font_size = value
		refresh()
## Text color for the item name
@export var name_color: Color = Color.WHITE:
	set(value):
		name_color = value
		refresh()
## Text color when the item is hovered or selected
@export var hover_text_color: Color = Color.WHITE:
	set(value):
		hover_text_color = value
		refresh()
## Text color when the item is disabled
@export var disabled_text_color: Color = Color(0.5, 0.5, 0.5, 1.0):
	set(value):
		disabled_text_color = value
		refresh()
## Font outline thickness
@export var font_outline: int = 8:
	set(value):
		font_outline = value
		refresh()
## Font outline color
@export var font_outline_color: Color = Color.BLACK:
	set(value):
		font_outline_color = value
		refresh()
## Text color for the quantity
@export var quantity_color: Color = Color.WHITE:
	set(value):
		quantity_color = value
		refresh()

## External scroll container to use its scroll bar for offset calculations
@export var scroll_container_node: ScrollContainer
## Correction applied to the right margin when the scrollbar is visible
@export var right_offset_correction: int = 12:
	set(value):
		right_offset_correction = value
		refresh()

@export_category("In-Editor only")
## Enable this in the editor to generate dummy buttons
@export var max_dummy_items: int = 600
@export var add_dummy_items: bool : set = _create_dummy_buttons

## Emitted when the player confirms or clicks an item
signal item_activated(item_type: int, item_id: int)
## Emitted when an item receives focus
signal item_focused(item_type: int, item_id: int)
## Signal emitted when the dialog requests to be closed
signal close_requested()

#{
	#"name": string,
	#"icon": Texture or null,
	#"item_color": Color or null,
	#"quantity": int,
	# 0 = items, 1 = weapons, 2 = armors, 3 = costumes, 4 = key item, 5 = skills
	#"item_type": int,
	#"item_id": int (real database id),
	#"is_disabled": bool
#}
var items: Array = []
var item_rects: Array[Rect2] = []
var ghost_cursor: Control
var audio_player: AudioStreamPlayer
var selected_index: int = -1
var pressed_index: int = -1
var anim_states: Array[float] = []
var _last_scroll_offset: float = -999999.0
var _last_real_mouse_pos: Vector2 = Vector2.INF

var manipulator = GameManager.MANIPULATOR_MODES.ITEM_MENU1



## Configures internal nodes and establishes the base logic for inputs
func _ready() -> void:
	ghost_cursor = Control.new()
	ghost_cursor.name = "GhostCursor"
	ghost_cursor.focus_mode = Control.FOCUS_ALL
	ghost_cursor.mouse_filter = Control.MOUSE_FILTER_PASS
	ghost_cursor.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(ghost_cursor, false, Node.INTERNAL_MODE_FRONT)
	ghost_cursor.focus_entered.connect(_config_hand_cursor)
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player, false, Node.INTERNAL_MODE_FRONT)
	focus_mode = Control.FOCUS_CLICK
	_update_minimum_size()
	_create_dummy_buttons(false)
	var scroll_node = _get_valid_scroll_node()
	if scroll_node and scroll_node.has_method("set_focus_target"):
		scroll_node.set_focus_target(ghost_cursor)



## Configures the main hand cursor visual position
func _config_hand_cursor() -> void:
	GameManager.set_cursor_manipulator(manipulator)
	if scroll_container_node:
		var rect = Rect2(0, scroll_container_node.global_position.y + 16, get_viewport().size.x, scroll_container_node.size.y - 16)
		GameManager.set_confin_area(rect, manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(16, 0), manipulator)
	GameManager.force_show_cursor()



## Returns configuration warnings for the editor validating the node hierarchy
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if get_parent() is ScrollContainer:
		warnings.append("This node should not be a direct child of a ScrollContainer. Make it a child of the node that controls the ScrollContainer to properly handle position offsets.")
	return warnings



## Responds to structural layout changes
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_minimum_size()
		refresh()
		_update_ghost_cursor()



## Receives dynamic page updates from the external paginator node
func _on_page_changed(_page: int) -> void:
	selected_index = -1
	pressed_index = -1
	_update_minimum_size()
	refresh()
	var scroll = _get_valid_scroll_node()
	if scroll:
		scroll.scroll_vertical = 0
	_select_item(0, true)



## Updates item zoom animations in real time tracking local changes and custom controller inputs
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	_handle_controller_input()
	var needs_redraw = false
	var current_offset = _get_local_scroll_offset()
	if current_offset != _last_scroll_offset:
		_last_scroll_offset = current_offset
		needs_redraw = true
		_update_ghost_cursor()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var current_global_mouse = get_global_mouse_position()
		if current_global_mouse == _last_real_mouse_pos:
			var scroll_node = _get_valid_scroll_node()
			if scroll_node and scroll_node.get_global_rect().has_point(current_global_mouse):
				var pos = get_local_mouse_position()
				var idx = _get_item_at_pos(pos)
				if idx != -1 and idx != selected_index:
					_select_item(idx, false)
	var count = _get_current_page_count()
	if anim_states.size() != count:
		anim_states.resize(count)
		anim_states.fill(1.0)
		needs_redraw = true
	var visible_range = _get_visible_row_range()
	var start_idx = visible_range.x * columns
	var end_idx = min(count, visible_range.y * columns)
	for i in range(start_idx, end_idx):
		var target_scale = 1.0
		if i == pressed_index:
			target_scale = 0.95
		elif i == selected_index:
			target_scale = 1.05
		if abs(anim_states[i] - target_scale) > 0.005:
			anim_states[i] = lerpf(anim_states[i], target_scale, 15.0 * delta)
			needs_redraw = true
		else:
			anim_states[i] = target_scale
	if selected_index >= 0 and selected_index < count and (selected_index < start_idx or selected_index >= end_idx):
		if abs(anim_states[selected_index] - 1.05) > 0.005:
			anim_states[selected_index] = lerpf(anim_states[selected_index], 1.05, 15.0 * delta)
			needs_redraw = true
		else:
			anim_states[selected_index] = 1.05
	if pressed_index >= 0 and pressed_index < count and (pressed_index < start_idx or pressed_index >= end_idx):
		if abs(anim_states[pressed_index] - 0.95) > 0.005:
			anim_states[pressed_index] = lerpf(anim_states[pressed_index], 0.95, 15.0 * delta)
			needs_redraw = true
		else:
			anim_states[pressed_index] = 0.95
	if needs_redraw:
		queue_redraw()



## Draws the items pulling exact local coordinates directly from the precomputed cache
func _draw() -> void:
	var count = _get_current_page_count()
	if count <= 0 or item_rects.is_empty():
		return
	var visible_range = _get_visible_row_range()
	var start_idx = visible_range.x * columns
	var end_idx = min(count, visible_range.y * columns)
	var ipp = _get_items_per_page()
	var page_offset = 0 if ipp <= 0 else _get_current_page() * ipp
	for i in range(start_idx, end_idx):
		if i >= item_rects.size() or (page_offset + i) >= items.size():
			break
		var item = items[page_offset + i]
		var is_disabled = item.get("is_disabled", false)
		var item_rect = item_rects[i]
		var current_scale = anim_states[i] if i < anim_states.size() else 1.0
		var local_rect = item_rect
		if current_scale != 1.0:
			var center = item_rect.position + item_rect.size / 2.0
			draw_set_transform(center, 0.0, Vector2(current_scale, current_scale))
			local_rect = Rect2(-item_rect.size / 2.0, item_rect.size)
		else:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var style = disabled_style if (is_disabled and disabled_style) else normal_style
		if i == pressed_index and selected_style:
			style = selected_style
		elif i == selected_index and hover_style:
			style = hover_style
		elif i == selected_index and selected_style:
			style = selected_style
		if style:
			style.draw(get_canvas_item(), local_rect)
		var content_rect = local_rect
		if style:
			content_rect.position.x += style.get_margin(SIDE_LEFT)
			content_rect.position.y += style.get_margin(SIDE_TOP)
			content_rect.size.x -= style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
			content_rect.size.y -= style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
		var icon = item.get("icon")
		if not icon or typeof(icon) == TYPE_STRING:
			var type = item.get("item_type", 0)
			if type == 0:
				icon = default_item_icon
			elif type == 1:
				icon = default_weapon_icon
			elif type == 2:
				icon = default_armor_icon
			elif type == 3:
				icon = default_custome_icon
		if icon:
			var icon_rect = Rect2(content_rect.position.x, content_rect.position.y + (content_rect.size.y - icon_size.y) / 2.0, icon_size.x, icon_size.y)
			var icon_modulate = Color(1.0, 1.0, 1.0, 0.5) if is_disabled else Color.WHITE
			icon.draw_rect(get_canvas_item(), icon_rect, false, icon_modulate)
		var text_x = content_rect.position.x + icon_size.x + 8.0
		var text_y = content_rect.position.y + (content_rect.size.y / 2.0) + (font_size / 3.0)
		var current_font = font
		if not current_font:
			current_font = ThemeDB.fallback_font
		if current_font:
			var qty_text = "x" + str(item.get("quantity", 0))
			var qty_size = current_font.get_string_size(qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var qty_x = content_rect.position.x + content_rect.size.x - qty_size.x
			var color = item.get("item_color")
			var final_qty_color = quantity_color
			if is_disabled:
				color = disabled_text_color
				final_qty_color = disabled_text_color
			else:
				if i == selected_index:
					color = hover_text_color
					final_qty_color = hover_text_color
				elif color == null or typeof(color) != TYPE_COLOR:
					color = name_color
			var name_str = item.get("name", "")
			var max_name_width = max(0.0, qty_x - text_x - 8.0)
			if font_outline > 0:
				draw_string_outline(current_font, Vector2(text_x, text_y), name_str, HORIZONTAL_ALIGNMENT_LEFT, max_name_width, font_size, font_outline, font_outline_color)
			draw_string(current_font, Vector2(text_x, text_y), name_str, HORIZONTAL_ALIGNMENT_LEFT, max_name_width, font_size, color)
			if font_outline > 0:
				draw_string_outline(current_font, Vector2(qty_x, text_y), qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_outline, font_outline_color)
			draw_string(current_font, Vector2(qty_x, text_y), qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, final_qty_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)



## Extractor helper mapping external properties securely
func _get_items_per_page() -> int:
	return paginator.items_per_page if is_instance_valid(paginator) else 0



## Extractor helper pulling the current bound selection state
func _get_current_page() -> int:
	return paginator.current_page if is_instance_valid(paginator) else 0



## Helper to extract the safe bounded size for the active page sequence
func _get_current_page_count() -> int:
	var ipp = _get_items_per_page()
	if ipp <= 0:
		return items.size()
	var page_start = _get_current_page() * ipp
	var page_end = min(items.size(), page_start + ipp)
	return page_end - page_start



## Processes mouse input differentiating physical interaction from passive overlap
func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			return
		var current_global_mouse = get_global_mouse_position()
		if current_global_mouse == _last_real_mouse_pos:
			return
		_last_real_mouse_pos = current_global_mouse
		var pos = get_local_mouse_position()
		var idx = _get_item_at_pos(pos)
		if idx != selected_index and idx != -1:
			_select_item(idx, true)
	elif event is InputEventMouseButton:
		var pos = get_local_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			var idx = _get_item_at_pos(pos)
			if event.pressed:
				var count = _get_current_page_count()
				var ipp = _get_items_per_page()
				var page_offset = 0 if ipp <= 0 else _get_current_page() * ipp
				if idx != -1 and idx < count and not items[page_offset + idx].get("is_disabled", false):
					pressed_index = idx
					if is_instance_valid(ghost_cursor):
						ghost_cursor.grab_focus()
			else:
				if pressed_index != -1 and pressed_index == idx:
					_activate_item(pressed_index)
				pressed_index = -1



## Handles gamepad and keyboard inputs via the custom ControllerManager
func _handle_controller_input() -> void:
	if GameManager.get_cursor_manipulator() != manipulator:
		return

	var direction = ControllerManager.get_pressed_direction()
	var count = _get_current_page_count()
	if direction and count > 0:
		if direction == "down":
			_select_item(min(selected_index + columns, count - 1), true)
		elif direction == "up":
			_select_item(max(selected_index - columns, 0), true)
		elif direction == "right":
			_select_item(min(selected_index + 1, count - 1), true)
		elif direction == "left":
			_select_item(max(selected_index - 1, 0), true)
	elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner:
			focus_owner.release_focus()
		close_requested.emit()
	elif ControllerManager.is_confirm_just_pressed(true, [KEY_ENTER, KEY_KP_ENTER]):
		var ipp = _get_items_per_page()
		var page_offset = 0 if ipp <= 0 else _get_current_page() * ipp
		if selected_index != -1 and selected_index < count and not items[page_offset + selected_index].get("is_disabled", false):
			pressed_index = selected_index
			_activate_item(selected_index)
			pressed_index = -1



## Calculates the true local position of the scroll viewport without relying on float32 global coordinates
func _get_local_scroll_offset() -> float:
	var scroll_node = _get_valid_scroll_node()
	if not scroll_node:
		return 0.0
	var current = self
	var offset_y = 0.0
	while current and current != scroll_node:
		offset_y += current.position.y
		current = current.get_parent()
	return -offset_y



## Returns the controlling scroll container by traversing the tree safely
func _get_valid_scroll_node() -> ScrollContainer:
	if scroll_container_node:
		return scroll_container_node
	var p = get_parent()
	while p:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null



## Mathematically projects the scroll container window using robust local accumulations
func _get_visible_row_range() -> Vector2i:
	var count = _get_current_page_count()
	if count <= 0 or columns <= 0:
		return Vector2i(0, 0)
	var scroll_node = _get_valid_scroll_node()
	var local_top = 0.0
	var local_bottom = float(size.y)
	if scroll_node:
		local_top = _get_local_scroll_offset()
		local_bottom = local_top + float(scroll_node.size.y)
	var row_height: int = button_height + vertical_separation
	var safe_margin = float(row_height * 10)
	var total_rows = int(ceil(count / float(columns)))
	var start_row = clampi(int(floor((local_top - safe_margin) / float(row_height))), 0, max(0, total_rows - 1))
	var end_row = clampi(int(ceil((local_bottom + safe_margin) / float(row_height))), 0, total_rows)
	return Vector2i(start_row, end_row)



## Returns the maximum available width considering the parent scrollbar
func _get_available_width() -> float:
	var max_width = size.x
	var parent = _get_valid_scroll_node()
	if parent:
		var vbar = parent.get_v_scroll_bar()
		if vbar and vbar.visible:
			max_width -= right_offset_correction
	return max_width



## Calculates the item index strictly matching the integer cache logic
func _get_item_at_pos(pos: Vector2) -> int:
	if columns <= 0 or pos.x < 0.0 or pos.y < 0.0:
		return -1
	var max_width = _get_available_width()
	if pos.x > max_width:
		return -1
	var col_width = int((max_width - (columns - 1) * horizontal_separation) / float(columns))
	var row_height: int = button_height + vertical_separation
	var col = int(floor(pos.x / float(col_width + horizontal_separation)))
	var row = int(floor(pos.y / float(row_height)))
	var idx = row * columns + col
	if idx >= 0 and idx < _get_current_page_count() and col < columns:
		return idx
	return -1



## Selects an item forcefully based on index
func select_item(idx: int) -> void:
	_select_item(idx, true)
	_config_hand_cursor()
	GameManager.force_hand_position_over_node(manipulator)



## Updates selection and synchronizes the cursor and sounds based on true interaction
func _select_item(idx: int, force_focus: bool = false) -> void:
	if selected_index == idx:
		return
	selected_index = idx
	_update_ghost_cursor()
	_play_sound(cursor_fx)
	if force_focus and is_instance_valid(ghost_cursor):
		if not ghost_cursor.has_focus():
			ghost_cursor.grab_focus()
		else:
			ghost_cursor.release_focus()
			ghost_cursor.grab_focus()
	var count = _get_current_page_count()
	var ipp = _get_items_per_page()
	var page_offset = 0 if ipp <= 0 else _get_current_page() * ipp
	if idx >= 0 and idx < count and (page_offset + idx) < items.size():
		var item = items[page_offset + idx]
		var type = item.get("item_type", 0)
		var id = item.get("item_id", -1)
		item_focused.emit(type, id)



## Triggers the activation of an item
func _activate_item(idx: int) -> void:
	var count = _get_current_page_count()
	var ipp = _get_items_per_page()
	var page_offset = 0 if ipp <= 0 else _get_current_page() * ipp
	if idx >= 0 and idx < count and (page_offset + idx) < items.size():
		var item = items[page_offset + idx]
		if item.get("is_disabled", false):
			return
		_play_sound(select_fx)
		var type = item.get("item_type", 0)
		var id = item.get("item_id", -1)
		item_activated.emit(type, id)



## Repositions the ghost cursor naturally mapping it pulling exactly from the cached Rect2
func _update_ghost_cursor() -> void:
	if selected_index == -1 or not is_instance_valid(ghost_cursor) or selected_index >= item_rects.size():
		return
	var rect = item_rects[selected_index]
	if ghost_cursor.position != rect.position:
		ghost_cursor.position = rect.position
	if ghost_cursor.size != rect.size:
		ghost_cursor.size = rect.size



## Caches the Rect2 configurations natively mapping items to perfect grid positions
func _recalculate_cache() -> void:
	item_rects.clear()
	var count = _get_current_page_count()
	if count <= 0 or columns <= 0:
		return
	var max_width = _get_available_width()
	var col_width = int((max_width - (columns - 1) * horizontal_separation) / float(columns))
	var row_height: int = button_height + vertical_separation
	for i in range(count):
		var row = i / columns
		var col = i % columns
		var item_local_y: int = row * row_height
		var item_local_x: int = col * (col_width + horizontal_separation)
		item_rects.append(Rect2(item_local_x, item_local_y, col_width, button_height))



## Replaces all current items with a new array of items
func add_items(new_items: Array) -> void:
	items = new_items.duplicate(true)
	selected_index = -1
	pressed_index = -1
	if is_instance_valid(paginator):
		paginator.setup_pagination(items.size())
	_update_minimum_size()
	refresh()



## Adds a single item to the current list
func add_item(item: Dictionary) -> void:
	items.append(item)
	if is_instance_valid(paginator):
		paginator.setup_pagination(items.size())
	_update_minimum_size()
	refresh()



## Clears all items from the list
func clear() -> void:
	items.clear()
	selected_index = -1
	pressed_index = -1
	if is_instance_valid(paginator):
		paginator.setup_pagination(0)
	_update_minimum_size()
	refresh()



## Forces a clean frame redraw and regenerates positional math
func refresh() -> void:
	_recalculate_cache()
	_update_minimum_size()
	queue_redraw()



## Plays an audio stream directly
func _play_sound(stream: AudioStream) -> void:
	if stream and is_instance_valid(audio_player):
		audio_player.stream = stream
		audio_player.play()



## Adjusts the minimum height of the control physically pushing parent boundaries and allocating paginator space with an extra safety margin
func _update_minimum_size() -> void:
	if columns <= 0:
		return
	var count = _get_current_page_count()
	var rows = ceil(count / float(columns))
	var pag_height = 0.0
	if is_instance_valid(paginator) and paginator.visible:
		pag_height = max(paginator.size.y, paginator.get_minimum_size().y) + 32.0
	var total_height = rows * button_height + max(0, rows - 1) * vertical_separation + extra_bottom_padding + pag_height
	custom_minimum_size = Vector2(custom_minimum_size.x, total_height)



## Generates fake elements solely for visual purposes in the editor
func _create_dummy_buttons(_value: bool) -> void:
	items.clear()
	for i in max_dummy_items:
		items.append({
			"name": "Item %s" % (i + 1),
			"icon": null,
			"item_color": null,
			"quantity": randi_range(1, 99),
			"item_type": i % 4,
			"item_id": -1,
			"is_disabled": i % 3 == 2
		})
	selected_index = -1
	pressed_index = -1
	if is_instance_valid(paginator):
		paginator.setup_pagination(items.size())
	_update_minimum_size()
	refresh()
