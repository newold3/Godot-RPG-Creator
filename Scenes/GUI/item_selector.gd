extends HBoxContainer

@export var items: Array[SimpleItem] = []  # Array of items (SimpleItem -> Resource -> name and value)
@export var background_style_selected: StyleBox
@export var background_style_unselected: StyleBox
@export var background_style_highlight: StyleBox
@export var item_selected_color: Color = Color.WHITE
@export var item_unselected_color: Color = Color(0.374, 0.374, 0.374)
@export var item_highlight_color: Color = Color.WHITE
@export var smoothing_factor: float = 8.0  # Velocidad de scroll
@export var item_width: int = 200  # Ancho de cada item
@export var item_spacing: int = 50  # Espacio entre items
@export var selected_index: int = 0  # Índice del item seleccionado
@export var text_offset: int = 0
@export var slide_fx: AudioStream
@export var  focus_on_hover: bool = true

var main_tween: Tween

# Configuración del menú

# Variables de control
var target_position: float = 0
var current_position: float = 0
var is_dragging = false
var drag_start_position: float = 0
var initial_touch_position: float = 0
var press_button_delay: float = 0.15
var current_button_delay: float = 0.0


signal item_changed(value: Variant)
signal selected()
signal start_scroll()
signal end_scroll()

@onready var canvas: Control = %Canvas
@onready var previous_item: TextureButton = %PreviousItem
@onready var next_item: TextureButton = %NextItem


func _ready():
	GameManager.set_text_config(self)
	
	canvas.draw.connect(_on_canvas_draw)
	canvas.mouse_entered.connect(func(): mouse_entered.emit())
	
	var arrows = [previous_item, next_item]
	for arrow in arrows:
		arrow.focus_neighbor_left = arrow.get_path()
		arrow.focus_neighbor_top = arrow.get_path()
		arrow.focus_neighbor_right = arrow.get_path()
		arrow.focus_neighbor_bottom = arrow.get_path()
		arrow.focus_next = arrow.get_path()
		arrow.focus_previous = arrow.get_path()
		arrow.mouse_entered.connect(
			func():
				if focus_on_hover:
					arrow.grab_focus()
					selected.emit()
		)
		arrow.focus_entered.connect(
			func():
				focus_entered.emit()
				
				if main_tween:
					main_tween.kill()
					
				main_tween = create_tween()
				main_tween.tween_property(arrow, "scale", Vector2(1.1, 1.1), 0.1)
				main_tween.tween_property(arrow, "scale", Vector2.ONE, 0.2)
				
				var hand = MainHandCursor.HandPosition.LEFT if arrow == previous_item \
					else MainHandCursor.HandPosition.RIGHT

				GameManager.set_hand_position(hand, GameManager.get_cursor_manipulator())
		)
		arrow.set_disabled(items.size() <= 1)
	
	# Inicializar posición
	current_position = 0
	target_position = 0
	
	focus_neighbor_left = get_path()
	focus_neighbor_top = get_path()
	focus_neighbor_right = get_path()
	focus_neighbor_bottom = get_path()
	focus_next = get_path()
	focus_previous = get_path()
	
	await get_tree().process_frame
	
	for arrow in arrows:
		arrow.set_meta("original_position", arrow.position)
		arrow.pivot_offset = arrow.size * 0.5
	
	_force_selected_position()


func set_value(value: Variant) -> void:
	var string_value = str(value)
	for i in items.size():
		if items[i].value == string_value:
			selected_index = i
			_move_to_selected()
			break


func _force_selected_position() -> void:
	var item_full_width = item_width + item_spacing
	target_position = -selected_index * item_full_width
	current_position = target_position
	canvas.queue_redraw()


func update() -> void:
	var arrows = [previous_item, next_item]
	for arrow in arrows:
		arrow.set_disabled(items.size() <= 1)

	_force_selected_position()


func select() -> void:
	previous_item.grab_focus()


func _process(delta):
	# Suavizar el movimiento
	if current_position != target_position:
		if abs(current_position - target_position) > 0.1: # Usamos un umbral pequeño para evitar cálculos innecesarios
			var weight = 1.0 - exp(-delta * smoothing_factor)
			current_position = lerp(current_position, target_position, weight)
			
			# Esta parte para "anclar" la posición final sigue siendo una buena idea
			if abs(current_position - target_position) < 3:
				current_position = target_position
				end_scroll.emit()
			
			canvas.queue_redraw()
	
	
	if current_button_delay > 0.0:
		current_button_delay -= delta
	
	_check_button_pressed()


func _get_visible_item_range() -> Dictionary:
	var item_full_width = item_width + item_spacing
	
	# Calcular el rango visible en el viewport
	var left_edge = -current_position - canvas.size.x/2 - item_full_width
	var right_edge = -current_position + canvas.size.x/2 + item_full_width
	
	# Calcular los índices virtuales del primer y último item visible
	var first_virtual_index = floor(left_edge / item_full_width)
	var last_virtual_index = ceil(right_edge / item_full_width)
	
	return {
		"first": first_virtual_index,
		"last": last_virtual_index
	}


func _get_real_index(virtual_index: int) -> int:
	var real_index = virtual_index % items.size()
	if real_index < 0:
		real_index += items.size()
	return real_index


func get_selected_item_closest_to_center() -> int:
	var item_full_width = item_width + item_spacing
	var center_pos = -current_position
	
	# Encontrar el índice virtual más cercano al centro
	var nearest_virtual_index = round(center_pos / item_full_width)
	
	# Calcular cuántos items completos hay que moverse para llegar al selected_index
	var current_real_index = _get_real_index(nearest_virtual_index)
	var steps_to_selected = selected_index - current_real_index
	
	# Ajustar los pasos si es más corto ir en la dirección opuesta
	if abs(steps_to_selected) > items.size() / 2.0:
		if steps_to_selected > 0:
			steps_to_selected -= items.size()
		else:
			steps_to_selected += items.size()
	
	return nearest_virtual_index + steps_to_selected


func _on_canvas_draw():
	var item_full_width = item_width + item_spacing
	canvas.custom_minimum_size.x = item_full_width
	var visible_range = _get_visible_item_range()
	
	var nearest_virtual_item_selected = get_selected_item_closest_to_center()
	
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	
	var main_label = %MainFormatLabel
	var font = main_label.get("theme_override_fonts/font")
	var outline_size = main_label.get("theme_override_constants/outline_size")
	var outline_color = main_label.get("theme_override_colors/font_outline_color")
	var shadow = Vector2(
		main_label.get("theme_override_constants/shadow_offset_x"),
		main_label.get("theme_override_constants/shadow_offset_y")
	)
	var shadow_color = main_label.get("theme_override_colors/font_shadow_color")
	
	for virtual_index in range(visible_range.first, visible_range.last + 1):
		var real_index = _get_real_index(virtual_index)
		
		var item_position = Vector2(
			canvas.size.x / 2 + current_position + virtual_index * item_full_width,
			canvas.size.y / 2
		)
		
		var sc = 1.0
		
		var is_selected = virtual_index == nearest_virtual_item_selected
		
		var style_rect: Rect2 = Rect2(
			item_position.x - (item_width * sc) / 2,
			item_position.y - (50 * sc) / 2,
			item_width * sc,
			50 * sc
		)
		
		var text_color: Color
		var style: StyleBox = background_style_unselected
		if style_rect.has_point(get_local_mouse_position()):
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			style = background_style_highlight
			text_color = item_highlight_color
			if is_selected:
				sc = 1.2
		else:
			if is_selected:
				text_color = item_selected_color
				style = background_style_selected
				sc = 1.2
			else:
				style = background_style_unselected
				text_color = item_unselected_color
		
		if style:
			canvas.draw_style_box(
				style,
				style_rect
			)
		
		var font_size = 20 * sc
		var text = items[real_index].name
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_height = font.get_ascent() + font.get_descent()
		var vertical_offset = (text_height / 2) - font.get_descent() + text_offset
		var text_position_y = item_position.y + vertical_offset
		
		if shadow:
			canvas.draw_string(
				font,
				Vector2(
					item_position.x - text_size.x / 2 + shadow.x,
					text_position_y + shadow.y
				),
				text,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				font_size,
				shadow_color
			)
		
		if outline_size:
			canvas.draw_string_outline(
				font,
				Vector2(
					item_position.x - text_size.x / 2,
					text_position_y
				),
				text,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				font_size,
				outline_size,
				outline_color
			)
		
		canvas.draw_string(
			font,
			Vector2(
				item_position.x - text_size.x / 2,
				text_position_y
			),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			font_size,
			text_color
		)


func is_mouse_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func _check_button_pressed():
	var focus_owner = get_viewport().gui_get_focus_owner()
	if not [previous_item, next_item].has(focus_owner):
		return
	
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		if ["left", "right"].has(direction):
			if focus_owner == previous_item:
				next_item.grab_focus()
				GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT)
			else:
				previous_item.grab_focus()
				GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT)
	
	elif ControllerManager.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		ControllerManager.remove_last_action_registered()
		if previous_item.get_global_rect().has_point(previous_item.get_global_mouse_position()):
			focus_owner = previous_item
			previous_item.grab_focus()
			GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT)
		elif next_item.get_global_rect().has_point(next_item.get_global_mouse_position()):
			focus_owner = next_item
			next_item.grab_focus()
			GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT)
				
	elif current_button_delay <= 0 and ControllerManager.is_confirm_pressed():
		ControllerManager.remove_last_action_registered()
		if focus_owner == previous_item:
			_on_previous_item_pressed()
		else:
			_on_next_item_pressed()


func _move_to_next_item(direction: int):
	if items.size() <= 1: return
	
	# Calcular el nuevo índice seleccionado
	var new_index = selected_index + direction
	
	# Asegurarse de que el índice esté dentro del rango de ítems reales
	new_index = wrapi(new_index, 0, items.size())
	
	# Calcular la distancia necesaria para mover los ítems
	var item_full_width = item_width + item_spacing
	var distance = direction * item_full_width
	
	# Actualizar la posición objetivo
	target_position -= distance
	
	# Actualizar el índice seleccionado
	selected_index = new_index
	item_changed.emit(items[selected_index].value)
	start_scroll.emit()
	get_viewport().set_input_as_handled()
	canvas.queue_redraw()


func _snap_to_nearest():
	var item_full_width = item_width + item_spacing
	var center_pos = -current_position
	
	# Encontrar el item virtual más cercano al centro
	var nearest_virtual_index = round(center_pos / item_full_width)
	selected_index = _get_real_index(nearest_virtual_index)
	
	_move_to_selected()


func _move_to_selected():
	var item_full_width = item_width + item_spacing
	
	# Calcular la posición objetivo para centrar el ítem seleccionado
	target_position = -selected_index * item_full_width



func _on_previous_item_pressed() -> void:
	current_button_delay = press_button_delay
	_move_to_next_item(-1)
	var button = previous_item
	var original_position = button.get_meta("original_position")
	var t = create_tween()
	t.tween_property(button, "position:x", original_position.x - 10, 0.1)
	t.tween_property(button, "position:x", original_position.x, 0.05)
	
	if slide_fx:
		GameManager.play_se(slide_fx)


func _on_next_item_pressed() -> void:
	current_button_delay = press_button_delay
	_move_to_next_item(1)
	var button = next_item
	var original_position = button.get_meta("original_position")
	var t = create_tween()
	t.tween_property(button, "position:x", original_position.x + 10, 0.1)
	t.tween_property(button, "position:x", original_position.x, 0.05)
	
	if slide_fx:
		GameManager.play_se(slide_fx)
