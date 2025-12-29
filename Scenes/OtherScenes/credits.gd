extends Control

@export var rich_gradient_shader: ShaderMaterial
@export_multiline var first_message: String
@export_multiline var last_message: String
@export var scene_manipulator: String = ""
@export var back_button: Control : set = _add_back_button
@export var early_tree_exited_timer: float = 0.15

var slow_speed: float = -45
var speed: float = -70
var fast_speed: float = -20000
var current_speed: float = -50
var _thread: Thread
var _credits_array: Array[String] = []
var _message_array: Array[RichTextLabel] = []
var _is_loading := false
var _is_enabled: bool = false
var _reverse_mode: bool = false
var _current_index: int = -1
var _generation_locked: bool = false
var busy: bool = false
var _is_dragging_scrollbar: bool = false
var _last_jump_index: int = -1
var _drag_target_index: int = -1
var initialized: bool = true
var initialized_timer: float = 2.5

@onready var drag_update_timer: Timer = %DragUpdateTimer
@onready var message_container: Control = %MessageContainer

var files := [
	"res://Assets/asset_credits.credits",
	"res://addons/rpg_character_creator/Data/credits/character.credits",
	"res://addons/rpg_character_creator/Data/credits/character_cm.credits",
	"res://addons/rpg_character_creator/Data/credits/gear.credits",
	"res://addons/rpg_character_creator/Data/credits/gear_cm.credits",
	"res://addons/rpg_character_creator/Data/credits/projectiles.credits",
	"res://addons/rpg_character_creator/Data/credits/spells.credits"
]

var names := [
	"ALTERNATIVE RESOURCES TO LPC", "LPC RESOURCES", "CHARACTER COLORS", "GEAR IMAGES", "GEAR COLORS",
	"PROJECTIL IMAGES", "SPELL IMAGES"
]

signal starting_end()
signal end()
signal early_tree_exited()


func _ready() -> void:
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	modulate = Color.TRANSPARENT
	
	GameManager.set_cursor_manipulator(null)
	GameManager.set_text_config(self)
	
	busy = true
	_thread = Thread.new()
	_thread.start(_load_credits_thread)
	_is_loading = true
	tree_exiting.connect(_cleanup_on_exit)
	%ProgressBar.gui_input.connect(_on_progress_bar_gui_input)
	drag_update_timer.timeout.connect(_on_drag_update_timer_timeout)


func _process(delta: float) -> void:
	if busy:
		return
	
	if initialized and initialized_timer > 0.0:
		initialized_timer -= delta
		if initialized_timer <= 0:
			initialized = false
	
	if initialized:
		_check_button_pressed()
		return
	
	if not busy:
		_check_flow()
		
	if GameManager.get_cursor_manipulator() == scene_manipulator:
		_update_speed(delta)
		_handle_movement(delta)
		set_hand_position(delta)
		_check_button_pressed()


func _check_button_pressed() -> void:
	if busy: return

	var direction = ControllerManager.get_pressed_direction()
	if direction:
		match direction:
			"up":
				if not _reverse_mode:
					_reverse_mode = true
			"down":
				if _reverse_mode:
					_reverse_mode = false
	
	elif ControllerManager.is_confirm_just_pressed():
		_on_back_button_pressed()
		
	elif ControllerManager.is_cancel_just_pressed():
		_on_back_button_pressed()


func _cleanup_on_exit() -> void:
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()


func _load_credits_thread() -> void:
	if not first_message.is_empty():
		_credits_array.append(first_message)
		_credits_array.append("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n")
	
	for i in files.size():
		_credits_array.append("\n\n")
		_credits_array.append("[center][font_size=42][color=#ffc671]%s[/color][/font_size][/center]" % [names[i].to_upper()])
		_credits_array.append("\n\n")
		
		var file = FileAccess.open(files[i], FileAccess.READ)
		var json = JSON.parse_string(file.get_as_text())
		file.close()
		
		if "items" in json:
			_credits_array.append("\n\n")
			_credits_array.append("[center][font_size=42][color=#ffc671]IMAGES[/color][/font_size][/center]")
			_credits_array.append("\n\n")
			for item in json.get("items", []):
				_credits_array.append(_format_credit_item(item))
		
		if "sounds" in json:
			_credits_array.append("\n\n")
			_credits_array.append("[center][font_size=42][color=#ffc671]SOUNDS[/color][/font_size][/center]")
			_credits_array.append("\n\n")
			for item in json.get("sounds", []):
				_credits_array.append(_format_credit_item(item))
	
	if not last_message.is_empty():
		_credits_array.append("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n")
		_credits_array.append(last_message)
	
	call_deferred("_on_credits_loaded")


func _format_credit_item(item: Dictionary) -> String:
	var formatted := "[color=#dfc09c][font_size=18]%s[/font_size][/color]\n\n" % item.get("filename", "")
	#Color(0.671, 0.663, 0.549)
	var authors: Array = item.get("authors", [])
	if not authors.is_empty():
		formatted += "[color=#ffbf7d][b]Authors[/b][/color]\n[ul]"
		formatted += "\n".join(authors)
	var licenses: Array = item.get("licenses", [])
	if not licenses.is_empty():
		formatted += "[/ul]\n\n[color=#ffbf7d][b]Licenses[/b][/color]\n[ul]"
		formatted += ", ".join(licenses)
	var urls: Array = item.get("urls", [])
	if not urls.is_empty():
		formatted += "[/ul]\n\n[color=#ffbf7d][b]URLs[/b][/color]\n[ul]"
		formatted += "\n".join(PackedStringArray(urls.map(
			func(url): return "[color=#f58f00][url]%s[/url][/color]" % url
		)))
	formatted += "[/ul]\n\n\n\n"
	return formatted


func _on_credits_loaded() -> void:
	%ProgressBar.value = 0
	_is_loading = false
	_thread.wait_to_finish()
	create_next_message()
	start()


func _create_single_message(credit_index: int, add_at_front: bool = false) -> RichTextLabel:
	var message = RichTextLabel.new()
	message.set("theme_override_colors/default_color", Color(1.0, 0.92, 0.92))
	GameManager.set_text_config(message)

	message.set_meta("credit_index", credit_index)
	if credit_index == 0:
		message.set_meta("first_message", true)
	elif credit_index == _credits_array.size() - 1:
		message.set_meta("last_message", true)

	message.size.x = message_container.size.x
	message.bbcode_enabled = true
	message.fit_content = true
	message.text = _credits_array[credit_index]
	
	if "[color=red]" in message.text:
		message.set("theme_override_constants/outline_size", 0)
		message.set("theme_override_constants/shadow_offset_y", 0)
		message.set("theme_override_constants/shadow_offset_x", 0)

	message.modulate.a = 1.0
	message.meta_clicked.connect(_on_meta_clicked)
	message.meta_hover_started.connect(_on_meta_hover_started.bind(message))
	message.meta_hover_ended.connect(_on_meta_hover_ended.bind(message))

	message_container.add_child(message)
	if add_at_front:
		message_container.move_child(message, 0)
	
	await get_tree().process_frame

	if "[color=red]" in message.text:
		message.material = rich_gradient_shader.duplicate()
		message.material.set_shader_parameter("size", message.size)
		
	return message


func create_next_message(current_messaje: RichTextLabel = null) -> void:
	if _generation_locked:
		return
		
	_current_index += (1 if not _reverse_mode else -1)
	
	if _current_index < 0 or _current_index > _credits_array.size() - 1:
		_current_index = clamp(_current_index, 0, _credits_array.size() - 1)
		return
	
	# Verificar duplicados con validación de nodos
	for i in range(_message_array.size() - 1, -1, -1):
		if not is_instance_valid(_message_array[i]):
			_message_array.remove_at(i)
			continue
		if _message_array[i].get_meta("credit_index") == _current_index:
			return
	
	# Verificar límites de generación con validación
	if _message_array.size() > 0:
		if not _reverse_mode:
			if is_instance_valid(_message_array[-1]) and _message_array[-1].get_meta("credit_index") > _current_index:
				return
		else:
			if is_instance_valid(_message_array[0]) and _message_array[0].get_meta("credit_index") < _current_index:
				return
	
	_generation_locked = true
	
	var current_text = _credits_array[_current_index]
	var message = RichTextLabel.new()
	message.set("theme_override_colors/default_color", Color(1.0, 0.92, 0.92))
	GameManager.set_text_config(message)
	
	message.set_meta("credit_index", _current_index)
	if _current_index == 0:
		message.set_meta("first_message", true)
	elif _current_index == _credits_array.size() - 1:
		message.set_meta("last_message", true)
	
	message.size.x = message_container.size.x
	message.bbcode_enabled = true
	message.fit_content = true
	message.text = current_text

	if "[color=red]" in message.text:
		message.set("theme_override_constants/outline_size", 0)
		message.set("theme_override_constants/shadow_offset_y", 0)
		message.set("theme_override_constants/shadow_offset_x", 0)
		
	message.modulate.a = 0.0
	message.meta_clicked.connect(_on_meta_clicked)
	message.meta_hover_started.connect(_on_meta_hover_started.bind(message))
	message.meta_hover_ended.connect(_on_meta_hover_ended.bind(message))
	
	# Validar que message_container sigue siendo válido
	if not is_instance_valid(message_container):
		message.queue_free()
		_generation_locked = false
		return
	
	message_container.add_child(message)
	if _reverse_mode:
		message_container.move_child(message, 0)
		
	await get_tree().process_frame
	
	# Verificar que el mensaje no fue liberado durante el await
	if not is_instance_valid(message):
		_generation_locked = false
		return
	
	if "[color=red]" in message.text:
		message.material = rich_gradient_shader.duplicate()
		message.material.set_shader_parameter("size", message.size)
	
	# Validar mensaje de referencia si es necesario
	if not initialized and current_messaje != null and not is_instance_valid(current_messaje):
		message.queue_free()
		_generation_locked = false
		return
	
	# Verificar que el mensaje sigue válido antes de posicionarlo
	if not is_instance_valid(message):
		_generation_locked = false
		return
		
	_position_new_message(message, current_messaje)
	
	_message_array.append(message)
	
	message.modulate.a = 1.0
	
	_update_progress_bar()
	_generation_locked = false


func _position_new_message(message: RichTextLabel, reference_message: RichTextLabel) -> void:
	if initialized:
		message.position = Vector2(
			message_container.size.x * 0.5 - message.size.x * 0.5,
			message_container.size.y * 0.5 - message.size.y * 0.5
		)
		var t = create_tween()
		t.tween_property(message, "modulate:a", 1.0, 1.5)
	else:
		if not reference_message:
			if not _reverse_mode:
				message.position = Vector2(
					message_container.size.x * 0.5 - message.size.x * 0.5,
					message_container.size.y
				)
			else:
				message.position = Vector2(
					message_container.size.x * 0.5 - message.size.x * 0.5,
					-message.size.y
				)
		else:
			if not _reverse_mode:
				message.position = Vector2(
					reference_message.position.x, 
					reference_message.position.y + reference_message.size.y + 5
				)
			else:
				message.position = Vector2(
					reference_message.position.x, 
					reference_message.position.y - message.size.y - 5
				)


func _update_speed(delta: float) -> void:
	busy = false
	if Input.is_action_pressed("any_direction"):
		if _reverse_mode and current_speed < -0.1:
			current_speed = lerp(current_speed, 0.0, 0.4)
		elif not _reverse_mode and current_speed > 0.1:
			current_speed = lerp(current_speed, 0.0, 0.4)
		else:
			current_speed = lerp(current_speed, (fast_speed if not _reverse_mode else -fast_speed), delta / 20.0)
	else:
		if get_global_rect().has_point(get_global_mouse_position()):
			current_speed = lerp(current_speed, (slow_speed if not _reverse_mode else -slow_speed), 2 * delta)
		else:
			current_speed = lerp(current_speed, (speed if not _reverse_mode else -speed), 2 * delta)


func _handle_movement(delta: float) -> void:
	var sp = current_speed * delta
	
	if _message_array.size() > 0:
		var should_stop = _check_boundaries()
		if not should_stop:
			_move_messages(sp)


func _check_boundaries() -> bool:
	if _message_array.is_empty():
		return false
	
	var center_y = message_container.size.y * 0.5
	
	if not _reverse_mode:
		for message in _message_array:
			if message.has_meta("last_message"):
				var message_center = message.position.y + message.size.y * 0.5
				if message_center <= center_y:
					var adjustment = center_y - message_center
					for child in _message_array:
						child.position.y += adjustment
					current_speed = 0
					return true
	else:
		for message in _message_array:
			if message.has_meta("first_message"):
				var message_center = message.position.y + message.size.y * 0.5
				if message_center >= center_y:
					var adjustment = center_y - message_center
					for child in _message_array:
						child.position.y += adjustment
					current_speed = 0
					return true
	
	return false


func _move_messages(sp: float) -> void:
	for child in _message_array:
		child.position.y += sp


func _check_flow() -> void:
	var node1: RichTextLabel = message_container.get_child(0)
	var node2: RichTextLabel = message_container.get_child(-1)
	
	if not _reverse_mode:
		var releasable_node: RichTextLabel = node1
		var creator_node: RichTextLabel = node2
		
		if releasable_node.position.y + releasable_node.size.y < -100:
			if _message_array.size() > 1:
				_remove_message(releasable_node)
				
		if creator_node.position.y + creator_node.size.y < message_container.size.y + 100:
			create_next_message(creator_node)
	else:
		var releasable_node: RichTextLabel = node2
		var creator_node: RichTextLabel = node1
		
		if releasable_node.position.y > message_container.size.y + 100:
			if _message_array.size() > 1:
				_remove_message(releasable_node)
				
		if creator_node.position.y > 0:
			create_next_message(creator_node)


func _remove_message(message: RichTextLabel) -> void:
	_message_array.erase(message)
	message.queue_free()


func _update_progress_bar() -> void:
	if _current_index <= 0:
		%ProgressBar.value = 0
		return
	elif _current_index >= _credits_array.size() - 1:
		%ProgressBar.value = 100.0
		return
		
	var progress = (_current_index + 1) / float(_credits_array.size()) * 100
	%ProgressBar.value = progress


func _on_progress_bar_gui_input(event: InputEvent) -> void:
	if _is_loading:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_is_dragging_scrollbar = true
			_perform_jump(event.position)
		else:
			_is_dragging_scrollbar = false

	if event is InputEventMouseMotion and _is_dragging_scrollbar:
		var target_index = _calculate_index_from_position(event.position)
		
		if target_index != _last_jump_index:
			_drag_target_index = target_index
			drag_update_timer.start()


func _on_drag_update_timer_timeout() -> void:
	if _drag_target_index != -1 and _drag_target_index != _last_jump_index:
		_jump_to_credit(_drag_target_index)


func _calculate_index_from_position(p: Vector2) -> int:
	var style_bg = %ProgressBar.get_theme_stylebox("background")
	var style_fg = %ProgressBar.get_theme_stylebox("fill")
	
	var margin_top = style_fg.get_content_margin(SIDE_TOP) if style_fg and style_fg.get_content_margin(SIDE_TOP) >= 0 else style_bg.get_content_margin(SIDE_TOP)
	var margin_bottom = style_fg.get_content_margin(SIDE_BOTTOM) if style_fg and style_fg.get_content_margin(SIDE_BOTTOM) >= 0 else style_bg.get_content_margin(SIDE_BOTTOM)

	var effective_y_start = margin_top
	var effective_y_end = %ProgressBar.size.y - margin_bottom

	var clamped_y = clamp(p.y, effective_y_start, effective_y_end)
	var click_ratio = remap(clamped_y, effective_y_start, effective_y_end, 0.0, 1.0)
	
	var target_index = int(click_ratio * _credits_array.size())
	return clamp(target_index, 0, _credits_array.size() - 1)


func _perform_jump(p: Vector2) -> void:
	var target_index = _calculate_index_from_position(p)
	if target_index != _last_jump_index:
		_jump_to_credit(target_index)


func _jump_to_credit(target_index: int) -> void:
	busy = true
	current_speed = 0.0
	for message in _message_array:
		message.queue_free()
	_message_array.clear()
	
	_generation_locked = false
	_reverse_mode = false
	_current_index = target_index
	
	call_deferred("_rebuild_scene_from_index", target_index)


func _rebuild_scene_from_index(target_index: int) -> void:
	# Crear el mensaje ancla
	var anchor_message = await _create_single_message(target_index)
	if not is_instance_valid(anchor_message):
		call_deferred("_resume_after_jump")
		return
	
	var screen_center_y = message_container.size.y * 0.45
	anchor_message.position = Vector2(
		message_container.size.x / 2 - anchor_message.size.x / 2,
		screen_center_y - anchor_message.size.y / 2
	)
	_message_array.append(anchor_message)

	# Poblar hacia abajo desde el ancla
	var next_index = target_index + 1
	while next_index < _credits_array.size():
		# Verificar que el último mensaje sigue siendo válido
		if _message_array.is_empty() or not is_instance_valid(_message_array[-1]):
			break
		
		var last_msg = _message_array[-1]
		var new_message = await _create_single_message(next_index)
		
		# Verificar que el mensaje se creó correctamente y que last_msg sigue válido
		if not is_instance_valid(new_message) or not is_instance_valid(last_msg):
			if is_instance_valid(new_message):
				new_message.queue_free()
			break
		
		new_message.position = Vector2(
			last_msg.position.x,
			last_msg.position.y + last_msg.size.y + 5
		)
		
		if new_message.position.y > message_container.size.y:
			new_message.queue_free()
			break
		
		_message_array.append(new_message)
		next_index += 1
	
	# Poblar hacia arriba desde el ancla
	var prev_index = target_index - 1
	while prev_index >= 0:
		# Verificar que el primer mensaje sigue siendo válido
		if _message_array.is_empty() or not is_instance_valid(_message_array[0]):
			break
		
		var first_msg = _message_array[0]
		var new_message = await _create_single_message(prev_index, true)
		
		# Verificar que el mensaje se creó correctamente y que first_msg sigue válido
		if not is_instance_valid(new_message) or not is_instance_valid(first_msg):
			if is_instance_valid(new_message):
				new_message.queue_free()
			break
		
		new_message.position = Vector2(
			first_msg.position.x,
			first_msg.position.y - new_message.size.y - 5
		)
		
		if new_message.position.y + new_message.size.y < 0:
			new_message.queue_free()
			break
		
		_message_array.insert(0, new_message)
		prev_index -= 1

	# Verificación final antes de actualizar el índice
	if not _message_array.is_empty() and is_instance_valid(_message_array[-1]):
		_current_index = _message_array[-1].get_meta("credit_index")
		_update_progress_bar()
	
	call_deferred("_resume_after_jump")


func _resume_after_jump() -> void:
	initialized_timer = 0.5 
	busy = false


func set_hand_position(_delta: float) -> void:
	if not _is_enabled:
		return
	_config_hand_in_back_button()


func _config_hand_in_back_button() -> void:
	var manipulator = scene_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.force_show_cursor()
	if back_button and not back_button.has_focus():
		back_button.grab_focus() 
		GameManager.force_hand_position_over_node(manipulator)


func start() -> void:
	GameManager.set_fx_busy(true)
	if not _credits_array.is_empty():
		create_next_message()
	var main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(self, "modulate", Color.WHITE, 2.5)
	main_tween.tween_callback(
		func():
			_is_enabled = true
			busy = false
			_config_hand_in_back_button()
			GameManager.set_fx_busy(false)
	).set_delay(0.25)


func finish() -> void:
	_is_enabled = false
	if %BackButton.has_focus():
		%BackButton.release_focus()
	%BackButton.visible = false
	GameManager.hide_cursor(false, self)


func _add_back_button(button: Control) -> void:
	back_button = button
	button.pressed.connect(_on_back_button_pressed)


func _on_back_button_pressed() -> void:
	busy = true
	starting_end.emit()

	GameManager.play_fx("cancel")
	GameManager.set_fx_busy(true)
	
	if early_tree_exited_timer > 0.0:
		var t = create_tween()
		t.tween_interval(early_tree_exited_timer)
		t.tween_callback(func(): early_tree_exited.emit())
	
	if back_button:
		if back_button.has_focus():
			back_button.release_focus()
		back_button.select()
		if "animation_finished" in back_button:
			await back_button.animation_finished
			await get_tree().create_timer(0.1).timeout
		
	end.emit()


func _on_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _on_meta_hover_started(meta: Variant, message: RichTextLabel) -> void:
	busy = true
	message.text = message.text.replace("[url]%s[/url]" % meta, "[color=red][url]%s[/url][/color]" % meta)
	current_speed = slow_speed


func _on_meta_hover_ended(meta: Variant, message: RichTextLabel) -> void:
	busy = false
	message.text = message.text.replace("[color=red][url]%s[/url][/color]" % meta, "[url]%s[/url]" % meta)


func _on_back_button_end_click() -> void:
	finish()


func _on_back_button_begin_click() -> void:
	busy = true
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.75, 0.5)
	t.tween_property(self, "scale", Vector2(1.04, 1.01), 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
