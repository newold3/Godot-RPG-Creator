@tool
class_name CircularTabs
extends Control

signal tab_selected(tab_index: int)

## Visual settings for the text rendering
@export var outline_color: Color = Color.BLACK
@export var text_size: int = 24
@export var outline_size: int = 2
@export var font: Font
@export var selected_text_color: Color = Color.WHITE
@export var unselected_text_color: Color = Color.GRAY

## Styles for the tab background
@export var button_style_normal: StyleBox
@export var button_style_selected: StyleBox

## Normalized radius (0.0 to 1.0) relative to control size
@export_range(0.0, 1.0) var radius_h_ratio: float = 0.4
@export_range(0.0, 1.0) var radius_v_ratio: float = 0.1
@export var scroll_speed: float = 5.0

## Sound played when clicking to select another item from this menu.
@export var spin_fx: AudioStream

## List of tab names to display
@export var tabs: PackedStringArray = []:
	set(value):
		tabs = value
		queue_redraw()


var current_angle: float = PI / 2
var target_angle: float = PI / 2
var selected_index: int = 0


func _process(delta: float) -> void:
	if abs(current_angle - target_angle) > 0.0001:
		current_angle = lerp(current_angle, target_angle, scroll_speed * delta)
		queue_redraw()


func _draw() -> void:
	if tabs.is_empty() or not font:
		return
	
	var center = size / 2
	var r_h = size.x * radius_h_ratio
	var r_v = size.y * radius_v_ratio
	var items_data = []
	
	for i in range(tabs.size()):
		var angle_offset = (float(i) * (2.0 * PI / tabs.size()))
		var angle = current_angle + angle_offset
		
		var x = center.x + cos(angle) * r_h
		var y = center.y + sin(angle) * r_v
		var z = sin(angle) 
		
		items_data.append({"index": i, "pos": Vector2(x, y), "z": z})
	
	items_data.sort_custom(func(a, b): return a.z < b.z)
	
	for data in items_data:
		draw_tab_item(data.index, data.pos, data.z)


## Renders each individual tab with stylebox, scale and horizontal flip
func draw_tab_item(index: int, pos: Vector2, z_depth: float) -> void:
	var t = (z_depth + 1.0) / 2.0
	var scale_val = lerp(0.5, 1.0, t)
	var alpha = lerp(0.3, 1.0, t)
	var is_behind = z_depth < 0
	
	var is_selected = (index == selected_index)
	var current_style = button_style_selected if is_selected else button_style_normal
	var text_color = selected_text_color if is_selected else unselected_text_color
	text_color.a = alpha
	
	var text_to_draw = tabs[index]
	var text_size_vec = font.get_string_size(text_to_draw, HORIZONTAL_ALIGNMENT_CENTER, -1, text_size)
	
	var style_margin_l = current_style.get_margin(SIDE_LEFT) if current_style else 10.0
	var style_margin_r = current_style.get_margin(SIDE_RIGHT) if current_style else 10.0
	var style_margin_t = current_style.get_margin(SIDE_TOP) if current_style else 5.0
	var style_margin_b = current_style.get_margin(SIDE_BOTTOM) if current_style else 5.0
	
	var total_w = text_size_vec.x + style_margin_l + style_margin_r
	var total_h = text_size_vec.y + style_margin_t + style_margin_b
	
	var mirror = -1.0 if is_behind else 1.0
	draw_set_transform(pos, 0, Vector2(scale_val * mirror, scale_val))
	
	var rect = Rect2(-total_w / 2, -total_h / 2, total_w, total_h)
	
	if current_style:
		draw_style_box(current_style, rect)
	
	var text_pos = Vector2(-text_size_vec.x / 2, (text_size_vec.y / 2) - style_margin_b / 2)
	draw_string_outline(font, text_pos, text_to_draw, HORIZONTAL_ALIGNMENT_CENTER, -1, text_size, outline_size, outline_color)
	draw_string(font, text_pos, text_to_draw, HORIZONTAL_ALIGNMENT_CENTER, -1, text_size, text_color)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Adds a single tab to the list
func add_tab(text: String) -> void:
	tabs.append(text)
	queue_redraw()


## Adds multiple tabs to the list
func add_tabs(new_tabs: Array[String]) -> void:
	tabs.append_array(new_tabs)
	queue_redraw()


## Calculates the new target angle for circular rotation
func rotate_to(direction: int) -> void:
	if tabs.is_empty(): 
		return
	
	var step = 2.0 * PI / tabs.size()
	target_angle += direction * step
	
	selected_index = (selected_index - direction + tabs.size()) % tabs.size()
	tab_selected.emit(selected_index)
	
	if spin_fx:
		GameManager.play_se(spin_fx)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.position.x < size.x / 2:
				rotate_to(1)
			else:
				rotate_to(-1)
