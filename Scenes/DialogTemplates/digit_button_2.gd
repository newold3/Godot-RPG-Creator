@tool
extends PanelContainer

@export var valid_characters: String = "0123456789":
	set(value):
		valid_characters = value
		_update_characters_array()
		if canvas1:
			canvas1.queue_redraw()

@export var no_selected_style: StyleBox:
	set(value):
		no_selected_style = value
		if canvas2:
			canvas2.queue_redraw()

@export var selected_style: StyleBox:
	set(value):
		selected_style = value
		if canvas2:
			canvas2.queue_redraw()


var character_height: int
var current_index: int = 0
var offset: float = 0.0
var final_offset: float = 0.0
var character_separation: int = 4
var characters: Array = []
var font_size: int = 32
var is_animating: bool = false
var is_selected: bool = false
var animation_time = 0.25
var main_tween: Tween


@onready var canvas1: Control = %Canvas1
@onready var canvas2: Control = %Canvas2


signal value_updated(current_char: String, direction: int)
signal selected(node: PanelContainer)
signal pressed(direction: int)


func _ready():
	canvas1.draw.connect(_on_canvas1_draw)
	canvas2.draw.connect(_on_canvas2_draw)
	_update_characters_array()
	offset = calculate_offset_for_index(current_index)
	mouse_entered.connect(select.bind(true))


func _update_characters_array() -> void:
	characters.clear()
	for i in range(valid_characters.length()):
		characters.append(valid_characters[i])


func select(value: bool, can_emit_signal: bool = true) -> void:
	grab_focus()
	is_selected = value
	canvas1.queue_redraw()
	canvas2.queue_redraw()
	if value and can_emit_signal:
		selected.emit(self)


func calculate_offset_for_index(index: int) -> float:
	var font = get_theme_default_font()
	font_size = get_theme_default_font_size()
	character_height = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y + character_separation
	return -(index * character_height)


func _on_canvas1_draw() -> void:
	var center_y = size.y / 2
	var center_x = size.x / 2
	var font = ThemeDB.fallback_font
	var text_height = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y

	# Cuántos caracteres caben en pantalla + margen
	var total_visible = int(size.y / character_height) + 4
	
	# Índice flotante basado en el offset actual
	var float_index = -offset / character_height
	var base_index = int(floor(float_index))

	for i in range(-total_visible, total_visible + 1):
		var char_index = (base_index + i) % characters.size()
		if char_index < 0:
			char_index += characters.size()
		
		var text = characters[char_index]

		var visual_y = center_y + ((base_index + i - float_index) * character_height)
		var draw_y = visual_y - text_height / 2 - font.get_descent() - 2
		
		if draw_y < -character_height or draw_y > size.y + character_height:
			continue

		# Opacidad dependiendo de la distancia al centro
		var distance_to_center = abs(visual_y - center_y)
		var alpha = 1.0 - (distance_to_center / (size.y / 2))
		alpha = clamp(alpha, 0.2, 1.0)

		var font_color = Color.WHITE
		font_color.a = alpha

		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		canvas1.draw_string(
			font,
			Vector2(center_x - text_size.x / 2, draw_y + text_height),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			font_color
		)


func _on_canvas2_draw() -> void:
	var st = no_selected_style if not is_selected else selected_style
	var rect = Rect2(Vector2.ZERO, size)
	canvas2.draw_style_box(st, rect)


func _process(_delta: float) -> void:
	_check_button_pressed()


func _check_button_pressed() -> void:
	if !is_animating and is_selected:
		var direction = ControllerManager.get_pressed_direction()
		if direction:
			if direction == "up":
				move_up()
			elif direction == "down":
				move_down()


func animate_to_offset(new_offset: float, direction: int):
	#is_animating = true
	
	if main_tween:
		main_tween.kill()
	
	main_tween = create_tween()
	main_tween.set_ease(Tween.EASE_OUT)
	main_tween.set_trans(Tween.TRANS_CUBIC)
	
	var current_pos = offset
	var movement = character_height * direction
	
	main_tween.tween_method(move, current_pos, current_pos + movement, animation_time)
	
	main_tween.tween_callback(func(): 
		#is_animating = false
		offset = calculate_offset_for_index(current_index)
		canvas1.queue_redraw()
		canvas2.queue_redraw()
	)


func get_current_offset() -> float:
	return offset


func animate_by_direction(direction: int):
	if main_tween:
		main_tween.kill()

	main_tween = create_tween()
	main_tween.set_ease(Tween.EASE_OUT)
	main_tween.set_trans(Tween.TRANS_CUBIC)

	var movement = character_height * direction
	var target_offset = final_offset + movement

	main_tween.tween_method(move, offset, target_offset, animation_time)

	#main_tween.tween_callback(func():
		## "Snap" visual offset a múltiplo exacto
		#offset = wrapf(target_offset, -character_height * characters.size(), 0)
		#current_index = get_index_from_offset(offset)
		#canvas1.queue_redraw()
		#canvas2.queue_redraw()
	#)
	
	main_tween.tween_callback(_on_animation_finished.bind(direction))
	
	pressed.emit(direction)
	
	final_offset = target_offset


func _on_animation_finished(direction: int) -> void:
	var float_index = -offset / character_height
	var snapped_index = round(float_index)
	var final_offset = -snapped_index * character_height

	value_updated.emit(characters[current_index], direction)
	
	var snap_tween = create_tween()
	snap_tween.set_ease(Tween.EASE_OUT)
	snap_tween.set_trans(Tween.TRANS_CIRC)
	snap_tween.tween_method(move, get_current_offset(), final_offset, 0.1)

	snap_tween.tween_callback(func():
		offset = final_offset
		current_index = int(snapped_index) % characters.size()
		if current_index < 0:
			current_index += characters.size()

		canvas1.queue_redraw()
		canvas2.queue_redraw()
	)



func get_index_from_offset(off: float) -> int:
	var float_index = -off / character_height
	var idx = int(round(float_index)) % characters.size()
	if idx < 0:
		idx += characters.size()
	return idx


func move(value: float) -> void:
	get_viewport().set_input_as_handled()
	offset = value
	canvas1.queue_redraw()
	canvas2.queue_redraw()


func move_up():
	if not is_selected: return
	animate_by_direction(1)
	is_selected = true
	canvas2.queue_redraw()
	#if not is_selected: return
	#
	#current_index = (current_index - 1 + characters.size()) % characters.size()
	#animate_to_offset(offset, 1)
	#value_updated.emit(characters[current_index], -1)
	#is_selected = true
	#canvas2.queue_redraw()


func move_down():
	if not is_selected: return
	animate_by_direction(-1)
	is_selected = true
	canvas2.queue_redraw()
	#if not is_selected: return
	#
	#current_index = (current_index + 1) % characters.size()
	#animate_to_offset(offset, -1)
	#value_updated.emit(characters[current_index], 1)
	#is_selected = true
	#canvas2.queue_redraw()


func get_current_character() -> String:
	return characters[current_index]


func get_current_index() -> int:
	return current_index
