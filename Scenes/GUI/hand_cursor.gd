extends CanvasLayer


enum HandPosition { LEFT, RIGHT, UP, DOWN}

var current_hand_position: HandPosition = HandPosition.LEFT
var hide_hand_when_mouse_over_focused: bool = true

var hand_tween: Tween
var mouse_timer: Timer
var keep_cursor_alive: bool = false
var cursor_is_hidden: bool = false
var cursor_hand_is_hidden: bool = false

var hand_offset: Vector2 = Vector2.ZERO

var default_mouse_visibility = DisplayServer.MOUSE_MODE_VISIBLE # DisplayServer.MOUSE_MODE_HIDDEN in final game

const HAND_POSITION_LERP_SPEED = 25
const HAND_ROTATION_LERP_SPEED = 10
const HIDE_DELAY = 4.0
const CURSOR_DISPLACEMENT = 4

@onready var cursor: Sprite2D = %Cursor


func _ready() -> void:
	cursor.modulate = Color.WHITE
	cursor.self_modulate = Color.TRANSPARENT
		
	var t = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	t.set_loops()
	t.tween_method(_animate_cursor, 0.0, -CURSOR_DISPLACEMENT, 0.2)
	t.tween_method(_animate_cursor, -CURSOR_DISPLACEMENT, 0.0, 0.2)
	t.tween_method(_animate_cursor, 0.0, CURSOR_DISPLACEMENT, 0.2)
	t.tween_method(_animate_cursor, CURSOR_DISPLACEMENT, 0.0, 0.2)
	
	mouse_timer = Timer.new()
	add_child(mouse_timer)
	mouse_timer.one_shot = true
	mouse_timer.wait_time = HIDE_DELAY
	mouse_timer.timeout.connect(_on_mouse_timer_timeout)
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if cursor_is_hidden:
			show_cursor()
		mouse_timer.start()
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		
	elif not event is InputEventMouse and not cursor_is_hidden:
		hide_cursor()
		if not mouse_timer.is_stopped():
			mouse_timer.stop()
		DisplayServer.mouse_set_mode(default_mouse_visibility)


func _on_mouse_timer_timeout() -> void:
	if not keep_cursor_alive:
		hide_cursor()


func set_hand_position(value: String) -> void:
	var pos = value.to_upper()
	if HandPosition.has(pos):
		current_hand_position = HandPosition[pos]


func set_keep_cursor_alive(value: bool) -> void:
	keep_cursor_alive = value
	if value and cursor_is_hidden:
		show_cursor()
		if not mouse_timer.is_stopped():
			mouse_timer.stop()
	elif not value and not cursor_is_hidden:
		mouse_timer.start()


func show_cursor() -> void:
	cursor_is_hidden = false
	tween_hand_cursor_modulate(Color.WHITE)
		
	mouse_timer.start()
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)


func hide_cursor() -> void:
	cursor_is_hidden = true
	tween_hand_cursor_modulate(Color.TRANSPARENT)
		
	DisplayServer.mouse_set_mode(default_mouse_visibility)
	if not mouse_timer.is_stopped():
		mouse_timer.stop()


func force_show_cursor() -> void:
	if not cursor_hand_is_hidden: return
	
	if hand_tween:
		hand_tween.kill()
	
	cursor_hand_is_hidden = false
	
	hand_tween = create_tween()
	hand_tween.set_parallel(true)
	hand_tween.tween_property(cursor, "self_modulate", Color.WHITE, 0.35)


func force_hide_cursor() -> void:
	if cursor_hand_is_hidden: return
	
	if hand_tween:
		hand_tween.kill()
	
	cursor_hand_is_hidden = true
	
	hand_tween = create_tween()
	hand_tween.set_parallel(true)
	hand_tween.tween_property(cursor, "self_modulate", Color.TRANSPARENT, 0.35)


func force_hand_position_over_node() -> void:
	update_hand_position(0, true)
	#for i in 3:
		#await get_tree().process_frame


func tween_hand_cursor_modulate(target_color: Color) -> void:
	if hand_tween:
		hand_tween.kill()
	
	hand_tween = create_tween()
	hand_tween.tween_property(cursor, "self_modulate", target_color, 0.35)


func _animate_cursor(offset_x: float) -> void:
	cursor.offset.x = offset_x


func update(delta: float) -> void:
	update_hand_position(delta)
	
	if hide_hand_when_mouse_over_focused:
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner:
			if focus_owner.get_global_rect().has_point(focus_owner.get_global_mouse_position()):
				cursor.self_modulate.a = lerp(cursor.self_modulate.a, 0.0, delta * 35)
			else:
				var focus_parent = focus_owner.get_parent()
				while focus_parent and not focus_parent.is_in_group("top_container"):
					focus_parent = focus_parent.get_parent()
				if focus_parent:
					var cursor_rect = Rect2(cursor.global_position, cursor.get_rect().size)
					if focus_parent.get_global_rect().intersects(cursor_rect):
						cursor.self_modulate.a = lerp(cursor.self_modulate.a, 1.0, delta * 35)
					else:
						cursor.self_modulate.a = lerp(cursor.self_modulate.a, 0.0, delta * 35)
				else:
					cursor.self_modulate.a = lerp(cursor.self_modulate.a, 1.0, delta * 35)
	
	var focus_owner = get_viewport().gui_get_focus_owner()
	if not focus_owner or not focus_owner.visible:
		hide_cursor()


func update_hand_position(delta: float, force_position: bool = false) -> void:
	if cursor:
		var focus_owner = get_viewport().gui_get_focus_owner()

		if focus_owner:
			var target_position: Vector2
			var target_rotation: float
			var target_scale: Vector2
			
			var limit_distance = 50.0
			if cursor.global_position.distance_squared_to(focus_owner.global_position) > limit_distance * limit_distance:
				var direction = (cursor.global_position - focus_owner.global_position).normalized()
				cursor.global_position = cursor.global_position - direction * limit_distance
			
			match current_hand_position:
				HandPosition.LEFT:
					if focus_owner is ItemList:
						if focus_owner.is_anything_selected():
							var selected_index = focus_owner.get_selected_items()[0]
							var rect: Rect2 = focus_owner.get_item_rect(selected_index)
							target_position = focus_owner.global_position + rect.position + Vector2(0, rect.size.y * 0.5)
							target_position.y -= focus_owner.get_v_scroll_bar().value
					else:
						target_position = focus_owner.global_position + Vector2(0, focus_owner.size.y * 0.5)
					target_rotation = 0
					target_scale = Vector2(1, 1)
				HandPosition.RIGHT:
					target_position = focus_owner.global_position + Vector2(focus_owner.size.x, focus_owner.size.y * 0.5)
					target_rotation = deg_to_rad(180)
					target_scale = Vector2(1, -1)
				HandPosition.UP:
					target_position = focus_owner.global_position + Vector2(focus_owner.size.x * 0.5, 0)
					target_rotation = deg_to_rad(90)
					target_scale = Vector2(1, 1)
				HandPosition.DOWN:
					target_position = focus_owner.global_position + Vector2(focus_owner.size.x * 0.5, focus_owner.size.y)
					target_rotation = deg_to_rad(90)
					target_scale = Vector2(-1, -1)

			if not force_position:
				cursor.global_position = lerp(cursor.global_position, target_position, delta * HAND_POSITION_LERP_SPEED) + hand_offset
			else:
				cursor.global_position = target_position
			cursor.rotation = lerp_angle(cursor.rotation, target_rotation, delta * HAND_ROTATION_LERP_SPEED)
			cursor.scale = lerp(cursor.scale, target_scale, delta * HAND_ROTATION_LERP_SPEED)
