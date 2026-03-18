@tool
class_name IngameItemList
extends Control

@export_category("Required Nodes")

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

## External scroll container to use its scroll bar for offset calculations
@export var scroll_container_node: ScrollContainer

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

## Texture used to indicate a newly added item. If empty, a red dot is drawn instead.
@export var new_item_texture: Texture2D:
	set(value):
		new_item_texture = value
		refresh()

## Offset applied to the new item indicator position (top right corner).
@export var new_item_offset: Vector2 = Vector2.ZERO:
	set(value):
		new_item_offset = value
		refresh()

## Correction applied to the right margin when the scrollbar is visible
@export var right_offset_correction: int = 12:
	set(value):
		right_offset_correction = value
		refresh()

@export_category("In-Editor only")

## Enable this in the editor to generate dummy buttons
@export var max_dummy_items: int = 600

## Triggers the creation of dummy items
@export var add_dummy_items: bool : set = _create_dummy_buttons

## Array of dictionaries containing item data
var items: Array = []
var current_used_icons: Dictionary = {}
var item_rects: Array[Rect2] = []
var ghost_cursor: Control
var audio_player: AudioStreamPlayer
var selected_index: int = -1
var pressed_index: int = -1
var anim_states: Array[float] = []
var _last_scroll_offset: float = -999999.0
var _last_real_mouse_pos: Vector2 = Vector2.INF
var enabled: bool = false
var manipulator: String
var itemlist_id: String = ""
var target_uid: String = ""
var target_global_index: int = 0
var is_restoring: bool = false
var activated_item_uid: String = ""
var dirty_refresh_time: float = 0.0
var input_cooldown: int = 0


## Emitted when the player confirms or clicks an item
signal item_activated(obj: Dictionary)

## Emitted when an item receives focus
signal item_focused(obj: Dictionary)

## Signal emitted when the dialog requests to be closed
signal close_requested()

## Signal emitted when an item being actively used rots
signal active_item_rotted()

## Signal emitted when an item is confirmed for use
signal use_item(item_data: Dictionary)

## Signal emitted when a skill is confirmed for use
signal use_skill(skill_data: Dictionary)


## Configures internal nodes and establishes the base logic for inputs
func _ready() -> void:
	ghost_cursor = Control.new()
	ghost_cursor.name = "GhostCursor"
	ghost_cursor.focus_mode = Control.FOCUS_CLICK
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
	item_focused.connect(_remove_is_new_label)
	focus_entered.connect(select_current)



## Removes the newly added flag safely from focused items
func _remove_is_new_label(obj: Dictionary) -> void:
	obj["is_new"] = false
	var real_item = obj.get("item")
	if real_item:
		real_item.newly_added = false



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
	if is_restoring: return
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
	if dirty_refresh_time > 0.0:
		dirty_refresh_time -= delta
		if dirty_refresh_time <= 0.0:
			_fetch_and_refresh_data()
	if not is_visible_in_tree(): return
	var screen_rect = get_viewport_rect()
	if not screen_rect.intersects(get_global_rect()): return
	var is_active = enabled and GameManager.get_cursor_manipulator() == manipulator
	if is_active:
		_handle_controller_input()
	var needs_redraw = false
	var current_offset = _get_local_scroll_offset()
	if current_offset != _last_scroll_offset:
		_last_scroll_offset = current_offset
		needs_redraw = true
		if is_active:
			_update_ghost_cursor()
	if is_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
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
	var has_perishable = false
	var ipp = _get_items_per_page()
	var page_offset = 0 if ipp <= 0 else _get_current_page() * ipp
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
		if (page_offset + i) < items.size() and items[page_offset + i].get("is_perishable", false):
			has_perishable = true
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
	if has_perishable:
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func clear_activated_item() -> void:
	activated_item_uid = ""


## Finds and selects the next perishable item of the same type with the lowest lifetime
func select_next_perishable(target_item_id: int) -> Dictionary:
	is_restoring = true
	var best_idx = -1
	var min_life = 999999.0
	for i in range(items.size()):
		var item = items[i]
		if item.get("item_id", -1) == target_item_id and item.get("is_perishable", false):
			var life = item.get("lifetime", 999999.0)
			if life < min_life:
				min_life = life
				best_idx = i
	if best_idx != -1:
		var local_idx = best_idx
		var ipp = _get_items_per_page()
		if ipp > 0:
			@warning_ignore("integer_division")
			var target_page = best_idx / ipp
			local_idx = best_idx % ipp
			if is_instance_valid(paginator) and paginator.current_page != target_page:
				paginator.current_page = target_page
				if paginator.has_method("setup_pagination"):
					paginator.setup_pagination(items.size())
				var scroll = _get_valid_scroll_node()
				if scroll:
					scroll.scroll_vertical = 0
		await get_tree().process_frame
		await get_tree().process_frame
		refresh()
		select_item(local_idx, true)
		var best_item = items[best_idx]
		activated_item_uid = str(best_item.get("item_type", -1)) + "_" + str(best_item.get("item_id", -1))
		is_restoring = false
		return best_item
	is_restoring = false
	return {}


## Draws the items pulling exact local coordinates directly from the precomputed cache.
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
		var is_new = item.get("is_new", false)
		var is_empty_item = item.get("is_empty", false)
		var item_type = item.get("item_type", 0)
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
		if not icon:
			if item_type == 0:
				icon = default_item_icon
			elif item_type == 1:
				icon = default_weapon_icon
			elif item_type == 2:
				icon = default_armor_icon
			elif item_type == 3:
				icon = default_custome_icon
		var icon_modulate = Color(1.0, 1.0, 1.0, 0.5) if is_disabled else Color.WHITE
		var icon_rect = Rect2(content_rect.position.x, content_rect.position.y + (content_rect.size.y - icon_size.y) / 2.0, icon_size.x, icon_size.y)
		if not is_empty_item:
			if icon is Texture2D:
				icon.draw_rect(get_canvas_item(), icon_rect, false, icon_modulate)
			elif icon is RPGIcon:
				if not icon.path in current_used_icons and AssetManager.exists(icon.path):
					var img = load(icon.path)
					current_used_icons[icon.path] = img
				var img: Texture2D = current_used_icons.get(icon.path)
				if img:
					if not icon.region:
						img.draw_rect(get_canvas_item(), icon_rect, false, icon_modulate)
					else:
						img.draw_rect_region(get_canvas_item(), icon_rect, icon.region, icon_modulate)
		var text_x = content_rect.position.x + (0.0 if is_empty_item else icon_size.x + 8.0)
		var text_y = content_rect.position.y + (content_rect.size.y / 2.0) + (font_size / 3.0)
		var current_font = font
		if not current_font:
			current_font = ThemeDB.fallback_font
		if current_font:
			var qty_text = ""
			if not is_empty_item:
				if item_type == 5:
					qty_text = str(item.get("mp_cost", 0)) + " MP"
				else:
					var q = 1 if item.get("is_perishable", false) else item.get("quantity", 0)
					qty_text = "x" + str(q)
			var qty_size = current_font.get_string_size(qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) if not is_empty_item else Vector2.ZERO
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
			if not is_empty_item:
				if font_outline > 0:
					draw_string_outline(current_font, Vector2(qty_x, text_y), qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_outline, font_outline_color)
				draw_string(current_font, Vector2(qty_x, text_y), qty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, final_qty_color)
		if item.get("is_perishable", false) and not is_empty_item:
			var real_item_ref = item.get("item")
			var max_life = item.get("max_lifetime", 1.0)
			var life = real_item_ref.lifetime if real_item_ref else item.get("lifetime", 1.0)
			var ratio = clampf(life / max_life, 0.0, 1.0) if max_life > 0.0 else 0.0
			var bar_h = 3.0
			var bar_w = content_rect.size.x - icon_size.x - 12.0
			var bar_x = content_rect.position.x + icon_size.x + 8.0
			var bar_y = content_rect.position.y + content_rect.size.y - bar_h - 2.0
			var bg_rect = Rect2(bar_x, bar_y, bar_w, bar_h)
			draw_rect(bg_rect, Color(0.1, 0.1, 0.1, 0.6))
			var fill_rect = Rect2(bar_x, bar_y, bar_w * ratio, bar_h)
			var bar_color = Color(0.2, 0.8, 0.2, 1.0)
			if ratio < 0.25:
				bar_color = Color(0.8, 0.2, 0.2, 1.0)
			elif ratio < 0.5:
				bar_color = Color(0.8, 0.8, 0.2, 1.0)
			if is_disabled:
				bar_color.a = 0.5
			draw_rect(fill_rect, bar_color)
		if is_new and not is_empty_item:
			var indicator_pos = Vector2(local_rect.position.x + local_rect.size.x, local_rect.position.y) + new_item_offset
			if new_item_texture:
				var tex_size = new_item_texture.get_size()
				var tex_rect = Rect2(indicator_pos - (tex_size / 2.0), tex_size)
				new_item_texture.draw_rect(get_canvas_item(), tex_rect, false)
			else:
				draw_circle(indicator_pos, 4.0, Color.RED)
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
	if not enabled or GameManager.get_cursor_manipulator() != manipulator: return
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


func set_enabled(value: bool) -> void:
	var mode = Control.MOUSE_FILTER_IGNORE if not value else Control.MOUSE_FILTER_STOP
	mouse_filter = mode
	enabled = value
	var focus = Control.FOCUS_CLICK if value else Control.FOCUS_NONE
	focus_mode = focus
	if ghost_cursor:
		ghost_cursor.focus_mode = focus
		mode = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE
		ghost_cursor.mouse_filter = mode


## Handles gamepad and keyboard inputs via the custom ControllerManager
func _handle_controller_input() -> void:
	if not enabled or GameManager.get_cursor_manipulator() != manipulator: return
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
func select_item(idx: int, snap_camera: bool = false) -> void:
	_select_item(idx, true, snap_camera)
	_config_hand_cursor()
	GameManager.force_hand_position_over_node(manipulator)



## Updates selection and synchronizes the cursor and sounds based on true interaction
func _select_item(idx: int, force_focus: bool = false, snap_camera: bool = false) -> void:
	if selected_index == idx:
		if force_focus:
			_focus_ghost_cursor(true)
		return
	selected_index = idx
	_update_ghost_cursor()
	_play_sound(cursor_fx)
	if force_focus:
		_focus_ghost_cursor(true)
	var count = _get_current_page_count()
	var ipp = _get_items_per_page()
	var page_offset = 0 if ipp <= 0 else _get_current_page() * ipp
	if idx >= 0 and idx < count and (page_offset + idx) < items.size():
		var item = items[page_offset + idx]
		target_uid = str(item.get("item_type", -1)) + "_" + str(item.get("item_id", -1))
		target_global_index = page_offset + idx
		item_focused.emit(item)
	if scroll_container_node and scroll_container_node.has_method("bring_focus_target_into_view"):
		var smooth = not snap_camera
		scroll_container_node.call_deferred("bring_focus_target_into_view", true, smooth)


## Selects the current stored index manually
func select_current() -> void:
	_select_item(selected_index, true)



## Regains control of the ghost cursor safely
func _focus_ghost_cursor(force_focus: bool = false) -> void:
	if is_instance_valid(ghost_cursor):
		if ghost_cursor.focus_mode != Control.FOCUS_NONE:
			if not ghost_cursor.has_focus():
				ghost_cursor.grab_focus()
			elif force_focus:
				ghost_cursor.release_focus()
				ghost_cursor.grab_focus()



## Triggers the activation of an item
func _activate_item(idx: int) -> void:
	var count = _get_current_page_count()
	var ipp = _get_items_per_page()
	var page_offset = 0 if ipp <= 0 else _get_current_page() * ipp
	if idx >= 0 and idx < count and (page_offset + idx) < items.size():
		var item = items[page_offset + idx]
		if item.get("is_disabled", false):
			return
		activated_item_uid = str(item.get("item_type", -1)) + "_" + str(item.get("item_id", -1))
		_play_sound(select_fx)
		item_activated.emit(item)
		var i_type = item.get("item_type", 0)
		if i_type == 5:
			use_skill.emit(item)
		else:
			use_item.emit(item)



## Repositions the ghost cursor naturally mapping it pulling exactly from the cached Rect2
func _update_ghost_cursor() -> void:
	if selected_index == -1 or not is_instance_valid(ghost_cursor) or selected_index >= item_rects.size():
		return
	var rect = item_rects[selected_index]
	if ghost_cursor.position != rect.position:
		ghost_cursor.position = rect.position
	if ghost_cursor.size != rect.size:
		ghost_cursor.size = rect.size
	_focus_ghost_cursor()



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
		@warning_ignore("integer_division")
		var row: int = i / columns
		var col: int = i % columns
		var item_local_y: int = row * row_height
		var item_local_x: int = col * (col_width + horizontal_separation)
		item_rects.append(Rect2(item_local_x, item_local_y, col_width, button_height))



## Restores the selection based on the cached target ID and item type, adapting to pagination
func restore_selection() -> void:
	is_restoring = true
	var found_global_idx = -1
	if target_uid != "":
		for i in range(items.size()):
			var uid = str(items[i].get("item_type", -1)) + "_" + str(items[i].get("item_id", -1))
			if uid == target_uid:
				found_global_idx = i
				if i == target_global_index:
					break
	if found_global_idx == -1 or target_uid == "-1_-1":
		if target_global_index >= 0 and target_global_index < items.size():
			found_global_idx = target_global_index
		elif items.size() > 0:
			found_global_idx = items.size() - 1
		else:
			found_global_idx = 0
	var local_idx = found_global_idx
	var ipp = _get_items_per_page()
	if ipp > 0:
		@warning_ignore("integer_division")
		var target_page = found_global_idx / ipp
		local_idx = found_global_idx % ipp
		if is_instance_valid(paginator) and paginator.current_page != target_page:
			paginator.current_page = target_page
			if paginator.has_method("setup_pagination"):
				paginator.setup_pagination(items.size())
			var scroll = _get_valid_scroll_node()
			if scroll:
				scroll.scroll_vertical = 0
	await get_tree().process_frame
	await get_tree().process_frame
	refresh()
	var count = _get_current_page_count()
	if count > 0 and local_idx >= count:
		local_idx = count - 1
	if count > 0:
		select_item(local_idx, true)
	is_restoring = false


## Replaces all current items with a new array of items
func add_items(new_items: Array) -> void:
	is_restoring = true
	items = new_items.duplicate(true)
	if items.is_empty():
		items.append({
			"name": "Empty",
			"icon": null,
			"item_color": null,
			"quantity": 0,
			"item_type": 0,
			"item_id": -1,
			"is_disabled": true,
			"is_empty": true
		})
	selected_index = -1
	pressed_index = -1
	if is_instance_valid(paginator):
		paginator.setup_pagination(items.size())
	_update_minimum_size()
	_set_item_connections(items)
	refresh()
	call_deferred("restore_selection")



## Adds a single item to the current list
func add_item(item: Dictionary) -> void:
	items.append(item)
	if is_instance_valid(paginator):
		paginator.setup_pagination(items.size())
	_update_minimum_size()
	_set_item_connections([item])
	refresh()



## Clears all rotting signal connections from the current item list
func _clear_connections() -> void:
	for obj in items:
		var real_item = obj.get("item")
		if real_item and real_item is GameItem and obj.get("is_perishable", false):
			if real_item.it_rotted.is_connected(_on_item_rotted):
				real_item.it_rotted.disconnect(_on_item_rotted)



## Establishes rotting signal connections for a given array of items
func _set_item_connections(objs: Array) -> void:
	for obj in objs:
		var real_item = obj.get("item")
		if real_item and real_item is GameItem and obj.get("is_perishable", false):
			if not real_item.it_rotted.is_connected(_on_item_rotted):
				real_item.it_rotted.connect(_on_item_rotted.bind(obj), CONNECT_DEFERRED)



## Handles when an item decays and refreshes the list
func _on_item_rotted(_real_item: GameItem, _item: Dictionary) -> void:
	var rotted_uid = str(_item.get("item_type", -1)) + "_" + str(_item.get("item_id", -1))
	if rotted_uid == activated_item_uid:
		active_item_rotted.emit()
		activated_item_uid = ""
	dirty_refresh_time = 0.1


func _fetch_and_refresh_data() -> void:
	var cache = {}
	if GameManager.game_state.in_game_options.has("lists_cache") and GameManager.game_state.in_game_options["lists_cache"].has(itemlist_id):
		cache = GameManager.game_state.in_game_options["lists_cache"][itemlist_id]
	var sort_type = cache.get("sort_type", 0)
	var collection = cache.get("collection", 0)
	var new_items = GameManager.inventory_manager.get_items(false, sort_type, collection)
	add_items(new_items)


## Clears all items from the list
func clear() -> void:
	_clear_connections()
	items.clear()
	current_used_icons.clear()
	selected_index = -1
	pressed_index = -1
	if is_instance_valid(paginator):
		paginator.setup_pagination(0)
	_update_minimum_size()
	refresh()



## Forces a clean frame redraw and regenerates positional math
func refresh() -> void:
	_recalculate_cache()
	call_deferred("_update_minimum_size")
	call_deferred("_apply_scrollbar_snapping")
	queue_redraw()



## Configures scrollbar steps to match item height
func _apply_scrollbar_snapping() -> void:
	var scroll = _get_valid_scroll_node()
	if scroll:
		var row_height = float(button_height + vertical_separation)
		scroll.scroll_vertical_custom_step = row_height
		var v_bar = scroll.get_v_scroll_bar()
		if v_bar:
			v_bar.step = row_height



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
			"is_disabled": i % 3 == 2,
			"is_new": randi() % 100 < 25
		})
	selected_index = -1
	pressed_index = -1
	if is_instance_valid(paginator):
		paginator.setup_pagination(items.size())
	_update_minimum_size()
	refresh()
