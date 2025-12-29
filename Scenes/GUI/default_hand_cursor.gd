@tool
class_name MainHandCursor
extends CanvasLayer


enum HandPosition { NONE=-1, LEFT, RIGHT, UP, DOWN}

var hand_tween: Tween
var mouse_timer: Timer
var keep_cursor_alive: bool = false
var cursor_is_hidden: bool = false
var cursor_hand_is_hidden: bool = false

var hand_offset: Vector2 = Vector2.ZERO


const HAND_POSITION_LERP_SPEED = 18
const HAND_ROTATION_LERP_SPEED = 8
const HIDE_DELAY = 15.0
const CURSOR_DISPLACEMENT = 4
const L_MOVEMENT_THRESHOLD = 250.0

var current_hand_position: HandPosition = HandPosition.LEFT
var hide_hand_when_mouse_over_focused: bool = true

var manipulator: String : set = _set_manipulator # Current scene controlling the cursor (using a reference ID)

var is_hidden: bool = true
var is_force_hidden: bool = false
var is_permanently_hidden: bool = false

var pause_reposition: bool = false

var confined_area: Rect2

var _is_real_cursor_visible: bool = false
var _real_cursor_time_to_hide: float = 0.0

var busy: bool = false

@onready var cursor: Sprite2D = %Cursor


#region Private methods
func _ready() -> void:
	cursor.modulate = Color.WHITE
	cursor.self_modulate = Color.TRANSPARENT
	_create_hand_animation_tween()


func _process(delta: float) -> void:
	if _real_cursor_time_to_hide > 0.0:
		_real_cursor_time_to_hide -= delta
		if _real_cursor_time_to_hide <= 0:
			_real_cursor_time_to_hide = 0
			_is_real_cursor_visible = false
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
			
	if is_permanently_hidden:
		cursor.visible = false
		return
	
	var focus_owner = get_viewport().gui_get_focus_owner()

	if not focus_owner and cursor.self_modulate.a > 0:
		cursor.self_modulate.a -= delta * 10
	
	if not is_force_hidden:
		if not focus_owner and cursor.self_modulate.a > 0 and is_hidden:
			cursor.self_modulate.a -= delta
		elif focus_owner and not is_hidden and cursor.self_modulate.a < 1.0:
			cursor.self_modulate.a += delta * 5
	
	if confined_area and not confined_area.has_point(%Cursor.position):
		cursor.self_modulate.a = 0
		is_force_hidden = true
		if hand_tween:
			hand_tween.kill()
	else:
		is_force_hidden = false
	
	cursor.self_modulate.a = clamp(cursor.self_modulate.a, 0.0, 1.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not _is_real_cursor_visible:
			_is_real_cursor_visible = true
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
			_real_cursor_time_to_hide = HIDE_DELAY


func _create_hand_animation_tween() -> void:
	var t = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.set_loops()
	t.tween_method(_animate_cursor, 0.0, -CURSOR_DISPLACEMENT, 0.2)
	t.tween_method(_animate_cursor, -CURSOR_DISPLACEMENT, 0.0, 0.2)
	t.tween_method(_animate_cursor, 0.0, CURSOR_DISPLACEMENT, 0.2)
	t.tween_method(_animate_cursor, CURSOR_DISPLACEMENT, 0.0, 0.2)


func _animate_cursor(offset_x: float) -> void:
	cursor.offset.x = offset_x


func _on_mouse_timer_timeout() -> void:
	if not keep_cursor_alive:
		hide_cursor()


func _animate_fade_cursor(final_color: Color, duration: float, set_hidden_value: bool) -> void:
	if hand_tween:
		hand_tween.kill()
	
	hand_tween = create_tween()
	hand_tween.tween_property(cursor, "self_modulate", final_color, duration)
	hand_tween.tween_callback(set.bind("is_hidden", set_hidden_value))


func _update_hand_position(delta: float, force_position: bool = false) -> void:
	if pause_reposition and is_inside_tree() or not get_viewport(): return
	if cursor:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner:
			var target_position: Vector2
			var target_rotation: float
			var target_scale: Vector2
			
			match current_hand_position:
				HandPosition.LEFT:
					if focus_owner is ItemList:
						if focus_owner.is_anything_selected():
							var selected_index = focus_owner.get_selected_items()[0]
							var rect: Rect2 = focus_owner.get_item_rect(selected_index)
							target_position = focus_owner.global_position + rect.position + Vector2(0, rect.size.y * 0.5)
							target_position.y -= focus_owner.get_v_scroll_bar().value
					else:
						var w = cursor.get_texture().get_width() * 0.5
						target_position = focus_owner.global_position + Vector2(-w, focus_owner.size.y * 0.5)
					target_rotation = 0
					target_scale = Vector2(1, 1)
				HandPosition.RIGHT:
					var w = cursor.get_texture().get_width() * 0.5
					target_position = focus_owner.global_position + Vector2(focus_owner.size.x + w, focus_owner.size.y * 0.5)
					target_rotation = deg_to_rad(180)
					target_scale = Vector2(1, -1)
				HandPosition.UP:
					var h = cursor.get_texture().get_height() * 0.5
					target_position = focus_owner.global_position + Vector2(focus_owner.size.x * 0.5, -h)
					target_rotation = deg_to_rad(90)
					target_scale = Vector2(1, -1)
				HandPosition.DOWN:
					var h = cursor.get_texture().get_height() * 0.5
					target_position = focus_owner.global_position + Vector2(focus_owner.size.x * 0.5, focus_owner.size.y + h)
					target_rotation = deg_to_rad(90)
					target_scale = Vector2(-1, 1)

			if not force_position:
				# Velocidad adaptativa: más rápido cuando está lejos
				var distance_to_target = cursor.global_position.distance_to(target_position)
				var pos_speed = HAND_POSITION_LERP_SPEED
				if distance_to_target > 300.0:
					pos_speed = HAND_POSITION_LERP_SPEED * 2.5 # Más rápido a larga distancia
				
				# El factor de suavizado correcto e independiente de los FPS
				var pos_weight = 1.0 - exp(-delta * pos_speed)
				var rot_weight = 1.0 - exp(-delta * HAND_ROTATION_LERP_SPEED)
				
				# Interpolar suavemente hacia la posición objetivo
				cursor.global_position = lerp(cursor.global_position, target_position + hand_offset, pos_weight)
				cursor.rotation = lerp_angle(cursor.rotation, target_rotation, rot_weight)
				cursor.scale = lerp(cursor.scale, target_scale, rot_weight)
			else:
				cursor.global_position = target_position + hand_offset
				cursor.rotation = target_rotation
				cursor.scale = target_scale
		#if not _is_real_cursor_visible:
			#Input.warp_mouse(cursor.position)
			#DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
			#DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
			#get_viewport().set_input_as_handled()
			
#endregion


#region Public Methods
func show_cursor(hand_position : HandPosition = HandPosition.LEFT, manipulator_context: Variant = null, default_offset: Vector2 = Vector2.ZERO) -> void:
	if is_permanently_hidden: return
	
	pause_reposition = false
	hand_offset = default_offset
	if manipulator and str(manipulator_context) != str(manipulator): return
	if hand_tween:
		hand_tween.kill()
	if hand_position != -1:
		current_hand_position = hand_position
	cursor.modulate.a = 1.0
	_animate_fade_cursor(Color.WHITE, 0.35, false)


func force_show() -> void:
	if hand_tween:
		hand_tween.kill()
	
	cursor.modulate.a = 1.0
	cursor.self_modulate.a = 1.0
	cursor.visible = true
	
	is_permanently_hidden = false
	is_force_hidden = false
	is_hidden = false


func force_hide() -> void:
	if hand_tween:
		hand_tween.kill()
	
	cursor.modulate.a = 0.0
	cursor.self_modulate.a = 0.0
	cursor.visible = false
	
	is_permanently_hidden = true
	is_force_hidden = true
	is_hidden = true


func hide_cursor(instant_hide: bool = false, manipulator_context: Variant = null) -> void:
	if is_permanently_hidden: return
	
	pause_reposition = false
	if manipulator and str(manipulator_context) != manipulator: return
	if hand_tween:
		hand_tween.kill()
	if instant_hide:
		cursor.self_modulate = Color.TRANSPARENT
		is_hidden = true
	else:
		_animate_fade_cursor(Color.TRANSPARENT, 0.175, true)
	
	confined_area = Rect2()


func force_hand_position_over_node(manipulator_context: Variant = null) -> void:
	if manipulator and str(manipulator_context) != manipulator: return
	_update_hand_position(0, true)


func update(delta: float) -> void:
	_update_hand_position(delta)


func get_cursor_position() -> Vector2:
	return cursor.global_position


func set_cursor_offset(value: Vector2, manipulator_context: Variant = null) -> void:
	if manipulator and str(manipulator_context) != manipulator: return
	hand_offset = value


func _set_manipulator(value: String) -> void:
	manipulator = value


func set_manipulator(manipulator_context: Variant) -> void:
	manipulator = str(manipulator_context)


func set_confin_area(area: Rect2 = Rect2(), manipulator_context: Variant = null) -> void:
	if manipulator and str(manipulator_context) != manipulator: return
	confined_area = area
#endregion
