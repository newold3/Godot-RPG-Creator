@tool
extends Label

@export var auto_adjust_text: bool = true
@export var min_font_size: int = 8 : 
	set(value):
		min_font_size = value
		if is_node_ready():
			adjust_text_fit(3)
		
@export var max_font_size: int = 500 : 
	set(value):
		max_font_size = value
		if is_node_ready():
			adjust_text_fit(3)
		
@export var force_text_size: int = -1 : 
	set(value):
		force_text_size = value
		if is_node_ready():
			adjust_text_fit(3)
		

@export var mark_current_size_as_default: bool = false :
	set(value):
		set_meta("original_size", size)

var old_text: String
var busy: bool = false
var original_size: Vector2

signal font_size_changed(new_size: int)



## Initializes the label and triggers the first text fit adjustment
func _ready() -> void:
	old_text = text
	adjust_text_fit.call_deferred(3)


## Processes changes in text dynamically and updates shader brightness
func _process(_delta: float) -> void:
	if auto_adjust_text and old_text != text:
		old_text = text
		adjust_text_fit(3)
	
	if GameManager.current_game_options:
		var brightness = GameManager.current_game_options.brightness
		if get_material():
			get_material().set_shader_parameter("brightness", brightness)


## Retrieves the actual font used by the label or the current theme
func get_actual_font() -> Font:
	var custom_font = get("theme_override_fonts/font")
	if custom_font == null:
		custom_font = get_theme_font("font")
	
	if custom_font:
		return custom_font
	else:
		return get_theme_default_font()


## Calculates the maximum available size inside the parent container taking theme margins into account
func get_effective_target_size() -> Vector2:
	var parent = get_parent() as Control
	if not parent:
		return size
	var available_size = parent.size
	if parent is MarginContainer:
		var m_left = parent.get_theme_constant("margin_left")
		var m_top = parent.get_theme_constant("margin_top")
		var m_right = parent.get_theme_constant("margin_right")
		var m_bottom = parent.get_theme_constant("margin_bottom")
		available_size.x -= (m_left + m_right)
		available_size.y -= (m_top + m_bottom)
	elif parent is PanelContainer:
		var style = parent.get_theme_stylebox("panel")
		if style:
			available_size.x -= (style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT))
			available_size.y -= (style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM))
	elif parent is Container:
		return size
	return available_size


## Adapts the font size to fit the text perfectly inside the target bounds using a binary search
func adjust_text_fit(loops: int = 0) -> void:
	if !is_inside_tree() or not is_node_ready():
		if loops > 0:
			await RenderingServer.frame_post_draw
			adjust_text_fit(loops - 1)
		return
		
	if force_text_size != -1:
		set("theme_override_font_sizes/font_size", force_text_size)
		if label_settings:
			label_settings.font_size = force_text_size
		font_size_changed.emit(force_text_size)
		await get_tree().process_frame
		pivot_offset = size * 0.5
		if loops > 0:
			adjust_text_fit(loops - 1)
		return
	else:
		await get_tree().process_frame
		
	if busy:
		if loops > 0:
			await RenderingServer.frame_post_draw
			adjust_text_fit(loops - 1)
		return
		
	if !text:
		set("theme_override_font_sizes/font_size", min_font_size)
		if label_settings:
			label_settings.font_size = min_font_size
		font_size_changed.emit(min_font_size)
		return
	
	busy = true
	clip_text = true
	var font = get_actual_font()
	var target_size = get_effective_target_size()
			
	var font_size = min_font_size
	var min_size := min_font_size
	var max_size := max_font_size

	while min_size <= max_size:
		var mid_size := (min_size + max_size) / 2
		var text_size = font.get_string_size(text + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, mid_size)

		if text_size.x > target_size.x or text_size.y > target_size.y:
			max_size = mid_size - 1
		else:
			min_size = mid_size + 1
			font_size = mid_size
	
	set("theme_override_font_sizes/font_size", font_size + 1)
	if label_settings:
		label_settings.font_size = font_size + 1
	font_size_changed.emit(font_size + 1)
	custom_minimum_size = target_size
	set.call_deferred("clip_text", false)
	
	if is_inside_tree():
		await get_tree().process_frame
		pivot_offset = size * 0.5
		busy = false
		if loops > 0:
			adjust_text_fit(loops - 1)


## Handles specific node notifications to update layout dynamically
func _notification(what: int) -> void:
	if busy: return
	if auto_adjust_text:
		if what == NOTIFICATION_RESIZED:
			adjust_text_fit(3)
