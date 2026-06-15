@tool
class_name ToastManager
extends Node

enum ToastPos {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	MIDDLE_LEFT,
	MIDDLE_CENTER,
	MIDDLE_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT
}

var active_toasts: Array[PanelContainer] = []
var toast_canvas: CanvasLayer


## Initializes the dedicated canvas layer for toasts and attaches it to the scene root
func _ready() -> void:
	toast_canvas = CanvasLayer.new()
	toast_canvas.name = "ToastCanvas"
	toast_canvas.layer = 127
	get_tree().root.call_deferred("add_child", toast_canvas)


## Updates the position of node-anchored toasts every frame to follow camera or node movement
func _process(_delta: float) -> void:
	for toast in active_toasts:
		if is_instance_valid(toast) and toast.get_meta("is_node_anchored", false):
			var node = toast.get_meta("anchor_node")
			
			if is_instance_valid(node) and node is CanvasItem:
				var wrapper = toast.get_parent()
				
				if is_instance_valid(wrapper) and wrapper is Node2D:
					wrapper.position = node.get_global_transform_with_canvas().origin


## Shows a floating notification dynamically generated in a specific screen position
func show_message(message: String, pos: ToastPos = ToastPos.BOTTOM_RIGHT, over_node: Node = null, y_offset: float = 0.0) -> void:
	var node_id = str(over_node.get_instance_id()) if is_instance_valid(over_node) else "none"
	var msg_id = "msg_" + message + "_pos_" + str(pos) + "_node_" + node_id
	
	for i in range(active_toasts.size() - 1, -1, -1):
		if not is_instance_valid(active_toasts[i]) or active_toasts[i].is_queued_for_deletion():
			active_toasts.remove_at(i)
		elif active_toasts[i].get_meta("toast_id", "") == msg_id:
			if active_toasts[i].get_meta("is_node_anchored", false):
				active_toasts[i].get_parent().queue_free()
			else:
				active_toasts[i].queue_free()
			active_toasts.remove_at(i)
	
	var toast = PanelContainer.new()
	toast.set_meta("toast_id", msg_id)
	var wrapper: Node2D = null
	
	if is_instance_valid(over_node):
		wrapper = Node2D.new()
		wrapper.add_child(toast)
	
	_setup_toast_ui(toast, message, pos, over_node, y_offset)
	
	if is_instance_valid(toast_canvas):
		if wrapper:
			toast_canvas.add_child(wrapper)
		else:
			toast_canvas.add_child(toast)
	
	if not is_instance_valid(over_node):
		var shift_dir = -1.0
		if pos == ToastPos.TOP_LEFT or pos == ToastPos.TOP_CENTER or pos == ToastPos.TOP_RIGHT:
			shift_dir = 1.0
		
		var offset = (float(toast.size.y) + 10.0) * shift_dir
		for t in active_toasts:
			if is_instance_valid(t) and t.get_meta("pos_id", ToastPos.BOTTOM_RIGHT) == pos and not t.get_meta("is_node_anchored", false):
				_shift_toast_up(t, offset)
	
	active_toasts.append(toast)
	_animate_toast_in(toast)


## Configures the internal nodes, base styling, and calculates starting coordinates for standard messages
func _setup_toast_ui(toast: PanelContainer, message: String, pos: ToastPos, over_node: Node, y_offset: float) -> void:
	var is_anchored = is_instance_valid(over_node)
	toast.top_level = not is_anchored
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_meta("pos_id", pos)
	toast.set_meta("is_node_anchored", is_anchored)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.16, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.6, 1.0, 1.0)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	toast.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.text = message
	toast.add_child(label)
	
	toast.reset_size()
	toast.size = toast.get_minimum_size()
	
	var target_x = 0.0
	var target_y = 0.0
	var start_x = 0.0
	var start_y = 0.0
	
	if is_anchored and over_node is CanvasItem:
		toast.set_meta("anchor_node", over_node)
		target_x = -(toast.size.x / 2.0)
		target_y = -(toast.size.y / 2.0) + y_offset
		start_x = target_x
		start_y = target_y + 20.0
	else:
		var width = ProjectSettings.get_setting("display/window/size/viewport_width")
		var height = ProjectSettings.get_setting("display/window/size/viewport_height")
		var screen_size = Vector2(width, height)
		
		match pos:
			ToastPos.TOP_LEFT:
				target_x = 30.0
				target_y = 30.0
				start_x = -toast.size.x - 20.0
				start_y = target_y
			ToastPos.TOP_CENTER:
				target_x = (screen_size.x - toast.size.x) / 2.0
				target_y = 30.0
				start_x = target_x
				start_y = -toast.size.y - 20.0
			ToastPos.TOP_RIGHT:
				target_x = screen_size.x - toast.size.x - 30.0
				target_y = 30.0
				start_x = screen_size.x + 20.0
				start_y = target_y
			ToastPos.MIDDLE_LEFT:
				target_x = 30.0
				target_y = (screen_size.y - toast.size.y) / 2.0
				start_x = -toast.size.x - 20.0
				start_y = target_y
			ToastPos.MIDDLE_CENTER:
				target_x = (screen_size.x - toast.size.x) / 2.0
				target_y = (screen_size.y - toast.size.y) / 2.0
				start_x = target_x
				start_y = target_y + 20.0
			ToastPos.MIDDLE_RIGHT:
				target_x = screen_size.x - toast.size.x - 30.0
				target_y = (screen_size.y - toast.size.y) / 2.0
				start_x = screen_size.x + 20.0
				start_y = target_y
			ToastPos.BOTTOM_LEFT:
				target_x = 30.0
				target_y = screen_size.y - toast.size.y - 30.0
				start_x = -toast.size.x - 20.0
				start_y = target_y
			ToastPos.BOTTOM_CENTER:
				target_x = (screen_size.x - toast.size.x) / 2.0
				target_y = screen_size.y - toast.size.y - 30.0
				start_x = target_x
				start_y = screen_size.y + 20.0
			ToastPos.BOTTOM_RIGHT, _:
				target_x = screen_size.x - toast.size.x - 30.0
				target_y = screen_size.y - toast.size.y - 30.0
				start_x = screen_size.x + 20.0
				start_y = target_y
	
	toast.position = Vector2(start_x, start_y)
	toast.modulate.a = 0.0
	toast.set_meta("target_x", target_x)
	toast.set_meta("target_y", target_y)


## Starts the sequence: slide in, fade in, wait, float up, and fade out
func _animate_toast_in(toast: PanelContainer) -> void:
	var tween = toast.create_tween().set_parallel(true)
	var target_x = toast.get_meta("target_x")
	var target_y = toast.get_meta("target_y")
	
	tween.tween_property(toast, "position", Vector2(target_x, target_y), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(toast, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_interval(3.0)
	tween.chain().tween_property(toast, "position:y", target_y - 40.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(toast, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if toast.get_meta("is_node_anchored", false):
		tween.chain().tween_callback(toast.get_parent().queue_free)
	else:
		tween.chain().tween_callback(toast.queue_free)


## Shows a floating notification detailing the items that couldn't be picked up or centered over a node
func show_overflow_error(items: Array, pos: ToastPos = ToastPos.BOTTOM_RIGHT, over_node: Node = null, y_offset: float = 0.0) -> void:
	var node_id = str(over_node.get_instance_id()) if is_instance_valid(over_node) else "none"
	var item_str = "overflow_"
	
	for item in items:
		item_str += item.name + str(item.amount)
	
	item_str += "_pos_" + str(pos) + "_node_" + node_id
	
	for i in range(active_toasts.size() - 1, -1, -1):
		if not is_instance_valid(active_toasts[i]) or active_toasts[i].is_queued_for_deletion():
			active_toasts.remove_at(i)
		elif active_toasts[i].get_meta("toast_id", "") == item_str:
			if active_toasts[i].get_meta("is_node_anchored", false):
				active_toasts[i].get_parent().queue_free()
			else:
				active_toasts[i].queue_free()
			active_toasts.remove_at(i)
	
	var toast = PanelContainer.new()
	toast.set_meta("toast_id", item_str)
	var wrapper: Node2D = null
	
	if is_instance_valid(over_node):
		wrapper = Node2D.new()
		wrapper.add_child(toast)
	
	_setup_overflow_toast_ui(toast, items, pos, over_node, y_offset)
	
	if is_instance_valid(toast_canvas):
		if wrapper:
			toast_canvas.add_child(wrapper)
		else:
			toast_canvas.add_child(toast)
	
	if not is_instance_valid(over_node):
		var shift_dir = -1.0
		if pos == ToastPos.TOP_LEFT or pos == ToastPos.TOP_CENTER or pos == ToastPos.TOP_RIGHT:
			shift_dir = 1.0
		
		var offset = (float(toast.size.y) + 10.0) * shift_dir
		for t in active_toasts:
			if is_instance_valid(t) and t.get_meta("pos_id", ToastPos.BOTTOM_RIGHT) == pos and not t.get_meta("is_node_anchored", false):
				_shift_toast_up(t, offset)
	
	active_toasts.append(toast)
	_animate_toast_in(toast)


## Configures the internal UI for the overflow error toast with a list of items and handles positioning
func _setup_overflow_toast_ui(toast: PanelContainer, items: Array, pos: ToastPos, over_node: Node, y_offset: float) -> void:
	var is_anchored = is_instance_valid(over_node)
	toast.top_level = not is_anchored
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_meta("pos_id", pos)
	toast.set_meta("is_node_anchored", is_anchored)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.16, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_bottom = 3
	style.border_color = Color(0.9, 0.3, 0.3, 1.0)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	toast.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	toast.add_child(vbox)
	
	var header = Label.new()
	header.text = tr("You were unable to pick up these items, maximum quantity reached.")
	header.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	vbox.add_child(header)
	
	for item in items:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		
		var icon_rect = TextureRect.new()
		if item.icon is Texture:
			icon_rect.texture = item.icon
		elif item.icon is RPGIcon and AssetManager.exists(item.icon.path):
			icon_rect.texture = AtlasTexture.new()
			icon_rect.texture.atlas = load(item.icon.path)
			icon_rect.texture.region = item.icon.region
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon_rect)
		
		var label = Label.new()
		label.text = item.name + " - x" + str(item.amount)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(label)
		
		vbox.add_child(hbox)
	
	toast.reset_size()
	toast.size = toast.get_minimum_size()
	
	var target_x = 0.0
	var target_y = 0.0
	var start_x = 0.0
	var start_y = 0.0
	
	if is_anchored and over_node is CanvasItem:
		toast.set_meta("anchor_node", over_node)
		target_x = -(toast.size.x / 2.0)
		target_y = -(toast.size.y / 2.0) + y_offset
		start_x = target_x
		start_y = target_y + 20.0
	else:
		var width = ProjectSettings.get_setting("display/window/size/viewport_width")
		var height = ProjectSettings.get_setting("display/window/size/viewport_height")
		var screen_size = Vector2(width, height)
		
		match pos:
			ToastPos.TOP_LEFT:
				target_x = 30.0
				target_y = 30.0
				start_x = -toast.size.x - 20.0
				start_y = target_y
			ToastPos.TOP_CENTER:
				target_x = (screen_size.x - toast.size.x) / 2.0
				target_y = 30.0
				start_x = target_x
				start_y = -toast.size.y - 20.0
			ToastPos.TOP_RIGHT:
				target_x = screen_size.x - toast.size.x - 30.0
				target_y = 30.0
				start_x = screen_size.x + 20.0
				start_y = target_y
			ToastPos.MIDDLE_LEFT:
				target_x = 30.0
				target_y = (screen_size.y - toast.size.y) / 2.0
				start_x = -toast.size.x - 20.0
				start_y = target_y
			ToastPos.MIDDLE_CENTER:
				target_x = (screen_size.x - toast.size.x) / 2.0
				target_y = (screen_size.y - toast.size.y) / 2.0
				start_x = target_x
				start_y = target_y + 20.0
			ToastPos.MIDDLE_RIGHT:
				target_x = screen_size.x - toast.size.x - 30.0
				target_y = (screen_size.y - toast.size.y) / 2.0
				start_x = screen_size.x + 20.0
				start_y = target_y
			ToastPos.BOTTOM_LEFT:
				target_x = 30.0
				target_y = screen_size.y - toast.size.y - 30.0
				start_x = -toast.size.x - 20.0
				start_y = target_y
			ToastPos.BOTTOM_CENTER:
				target_x = (screen_size.x - toast.size.x) / 2.0
				target_y = screen_size.y - toast.size.y - 30.0
				start_x = target_x
				start_y = screen_size.y + 20.0
			ToastPos.BOTTOM_RIGHT, _:
				target_x = screen_size.x - toast.size.x - 30.0
				target_y = screen_size.y - toast.size.y - 30.0
				start_x = screen_size.x + 20.0
				start_y = target_y
	
	toast.position = Vector2(start_x, start_y)
	toast.modulate.a = 0.0
	toast.set_meta("target_x", target_x)
	toast.set_meta("target_y", target_y)


## Moves the notification up or down to make room for a new one based on its start position
func _shift_toast_up(toast: PanelContainer, amount: float) -> void:
	var new_target = toast.get_meta("target_y") + amount
	toast.set_meta("target_y", new_target)
	
	if toast.has_meta("shift_tween"):
		var old_tween = toast.get_meta("shift_tween")
		if is_instance_valid(old_tween):
			old_tween.kill()
	
	var current_tween = toast.create_tween()
	toast.set_meta("shift_tween", current_tween)
	current_tween.tween_property(toast, "position:y", new_target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
