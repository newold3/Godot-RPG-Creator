@tool
class_name RequestInputFromUser
extends PanelContainer


## Array containing all the interactive key buttons of the virtual keyboard
@export var buttons: Array[BaseButton] = []

## Reference to the button that will be focused when the interface starts
@export var initial_selected_button: BaseButton

## Reference to the backspace or delete button
@export var back_button: BaseButton

## Reference to the confirmation button
@export var ok_button: BaseButton

## Reference to the space bar button. If null, Space key confirms current selection
@export var space_button: BaseButton

## Label used to display the title or prompt message
@export var title_node: Label

## Label used to display the current text entry
@export var entry_label: Label


var started: bool = false
var current_button: TextureButton
var manipulator: String = GameManager.MANIPULATOR_MODES.GUI_SCENE
var max_chars: int = 6
var empty_char: String = "▪️"
var current_text = ""
var buffer: Array[String] = []
var current_index: int = 0
var current_config: Dictionary = {}
var format_config: Dictionary = {}
var move_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var select_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var remove_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}


signal is_started()
signal key_selected(key: String)
signal ok_selected()
signal back_selected()
signal value_selected(value: Variant)


## Initialize configuration and common buffer logic
func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	_config_buttons()
	_create_buffer()
	
	key_selected.connect(_on_key_selected_base)
	back_selected.connect(_on_back_selected_base)
	ok_selected.connect(_on_ok_selected_base)

	start.call_deferred()


func _create_buffer() -> void:
	buffer.clear()
	for i in max_chars:
		buffer.append(empty_char)
	
	current_index = max_chars - 1
	_update_label()


func _update_position() -> void:
	if !GameManager or !GameManager.message:
		return
		
	var pos: Vector2
	var offset: Vector2
	var message: RichTextLabel = GameManager.message.get_message_box()
	var screen_size: Vector2 = get_window().content_scale_size
	var use_the_message_boundaries = current_config.get("use_message_config", true)
	var scene_position = current_config.get("position", 0)
	var position_offset = current_config.get("offset", Vector2.ZERO)

	if !message or !message.get_parent().get_parent().visible or !use_the_message_boundaries:
		match scene_position:
			0: pos = Vector2.ZERO; offset = Vector2.ZERO
			1: pos = Vector2(0.5, 0); offset = Vector2(-size.x * 0.5, 0)
			2: pos = Vector2(1, 0); offset = Vector2(-size.x, 0)
			3: pos = Vector2(0, 0.5); offset = Vector2(0, -size.y * 0.5)
			4: pos = Vector2(0.5, 0.5); offset = Vector2(-size.x * 0.5, -size.y * 0.5)
			5: pos = Vector2(1, 0.5); offset = Vector2(-size.x, -size.y * 0.5)
			6: pos = Vector2(0, 1); offset = Vector2(0, -size.y)
			7: pos = Vector2(0.5, 1); offset = Vector2(-size.x * 0.5, -size.y)
			8: pos = Vector2.ONE; offset = Vector2(-size.x, -size.y)
		
		position = screen_size * pos + offset + position_offset
	else:
		var other_offset = message.global_position + position_offset
		match scene_position:
			0: pos = Vector2.ZERO; offset = Vector2(-size.x, -size.y)
			1: pos = Vector2(0.5, 0); offset = Vector2(-size.x * 0.5, -size.y)
			2: pos = Vector2(1, 0); offset = Vector2(0, -size.y)
			3: pos = Vector2(0, 0.5); offset = Vector2(-size.x, -size.y * 0.5)
			4: pos = Vector2(0.5, 0.5); offset = Vector2(-size.x * 0.5, -size.y * 0.5)
			5: pos = Vector2(1, 0.5); offset = Vector2(0, -size.y * 0.5)
			6: pos = Vector2(0, 1); offset = Vector2(-size.x, 0)
			7: pos = Vector2(0.5, 1); offset = Vector2(-size.x * 0.5, 0)
			8: pos = Vector2.ONE; offset = Vector2(0, 0)
			
		position = message.size * pos + offset + other_offset
		
	position.x = clamp(position.x, 10, screen_size.x - 10 - size.x)
	position.y = clamp(position.y, 10, screen_size.y - 10 - size.y)


func set_data(config: Dictionary) -> void:
	current_config = config
	if title_node: title_node.text = current_config.get("title", "Enter Value")
	max_chars = current_config.get("digits", 3)
	
	var fxs = ["move_fx", "select_fx", "remove_fx"]
	for fx in fxs:
		if fx in config:
			var data = config.get(fx, {})
			var audio_path = data.get("path", "")
			if ResourceLoader.exists(audio_path):
				set(fx, {
					"stream": load(audio_path),
					"volume": data.get("volume", 0),
					"pitch": data.get("pitch", 0)
				})
	
	format_config = {}

	if current_config.get("use_message_config", true):
		while !GameManager or !GameManager.message:
			await get_tree().process_frame
		var message_box = GameManager.message.get_message_box()
		format_config = {
			"font": GameManager.message.default_font,
			"text_color": GameManager.message.default_text_color,
			"text_size": GameManager.message.default_text_size,
			"text_align": GameManager.message.default_text_align,
			"outline_size": message_box.get("theme_override_constants/outline_size"),
			"outline_color": message_box.get("theme_override_colors/font_outline_color"),
			"shadow_offset": Vector2(
				message_box.get("theme_override_constants/shadow_offset_x"),
				message_box.get("theme_override_constants/shadow_offset_y")
			),
			"shadow_color": message_box.get("theme_override_colors/font_shadow_color")
		}
	else:
		format_config = {
			"font": config.text_format.get("font", "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf"),
			"text_color": config.text_format.get("text_color", Color.WHITE),
			"text_size": config.text_format.get("text_size", 22),
			"text_align": config.text_format.get("text_align", 0),
			"outline_size": config.text_format.get("outline_size", 2),
			"outline_color": config.text_format.get("outline_color", Color.BLACK),
			"shadow_offset": config.text_format.get("shadow_offset", Vector2(2, 2)),
			"shadow_color": config.text_format.get("shadow_color", Color("#00000093"))
		}
	
	format_config.empty_place = config.text_format.get("empty_place", "·")
	
	_create_buffer()
	_update_config()
	_update_position()


func _update_config() -> void:
	var font = format_config.get("font")
	var current_text_font = null
	if font == null: font = "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf"
	if ResourceLoader.exists(font): current_text_font = load(font)
	
	var text_color = format_config.get("text_color", Color.WHITE)
	var text_size = format_config.get("text_size", 22)
	var text_align = format_config.get("text_align", 0)
	var outline_size = format_config.get("outline_size", 2)
	var outline_color = format_config.get("outline_color", Color.BLACK)
	var shadow_offset = format_config.get("shadow_offset", Vector2(2, 2))
	var shadow_color = format_config.get("shadow_color", Color("#00000093"))
	
	empty_char = format_config.get("empty_place", "·")
	
	if current_text_font:
		propagate_call("set", ["theme_override_fonts/font", current_text_font])
	propagate_call("set", ["theme_override_colors/font_color", text_color])
	propagate_call("set", ["theme_override_font_sizes/font_size", text_size])
	propagate_call("set", ["theme_override_constants/outline_size", outline_size])
	propagate_call("set", ["theme_override_constants/shadow_offset_x", shadow_offset.x])
	propagate_call("set", ["theme_override_constants/shadow_offset_y", shadow_offset.y])
	propagate_call("set", ["theme_override_colors/font_outline_color", outline_color])
	propagate_call("set", ["theme_override_colors/font_shadow_color", shadow_color])
	propagate_call("set", ["horizontal_alignment", text_align])


func play_fx(fx_data: Dictionary) -> void:
	GameManager.play_se(fx_data.stream, fx_data.volume, fx_data.pitch)


## Activates the input system and grabs initial focus
func start() -> void:
	await _start_animation()
	started = true
	if initial_selected_button:
		initial_selected_button.grab_focus()
		GameManager.force_hand_position_over_node(manipulator)
	is_started.emit()


func end() -> void:
	started = false
	await _end_animation()
	queue_free()


func _start_animation() -> void:
	pass


func _end_animation() -> void:
	pass


## Sets up visual behaviors, signals, and groups for all keyboard buttons
func _config_buttons() -> void:
	for button: BaseButton in buttons:
		if not button.is_in_group("key_button"):
			button.add_to_group("key_button")
		button.pivot_offset = button.size * 0.5
		button.focus_entered.connect(
			func():
				var t = create_tween()
				t.tween_property(button, "scale", Vector2(1.1, 1.1), 0.1)
				current_button = button
				_config_hand()
				_update_label()
		)
		button.focus_exited.connect(
			func():
				var t = create_tween()
				t.tween_property(button, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		)
		button.mouse_entered.connect(button.grab_focus)


## Specialized bridge for key selection following strict navigation rules
func _on_key_selected_base(key: String) -> void:
	var was_empty = buffer[current_index] == empty_char
	var is_at_last_pos = current_index == max_chars - 1
	
	_handle_insertion(key)
	
	var is_buffer_full = _is_input_complete()
	
	if is_at_last_pos:
		if buffer[0] == empty_char:
			pass
		else:
			if is_buffer_full:
				if ok_button: ok_button.grab_focus.call_deferred()
			else:
				for i in range(max_chars):
					if buffer[i] == empty_char:
						current_index = i
						break
	else:
		if was_empty and is_buffer_full:
			if ok_button: ok_button.grab_focus()
		else:
			current_index = clampi(current_index + 1, 0, max_chars - 1)
	
	_update_label()


## Bridge for the virtual backspace signal with new movement rules
func _on_back_selected_base() -> void:
	if current_index == 0 and buffer[current_index] == empty_char:
		return
		
	play_fx(remove_fx)
	_handle_deletion()
	_update_label()


## Bridge for the confirmation logic
func _on_ok_selected_base() -> void:
	var result = "".join(buffer).replace(empty_char, "")
	_on_input_completed(result)


## Formats the label with the specific cursor and shift-on-end logic
func _update_label() -> void:
	_refresh_ok_button_state()
	
	if not entry_label: return
	
	var display_list = buffer.duplicate()
	
	if current_index == max_chars - 1 and display_list[current_index] != empty_char:
		if display_list[0] == empty_char:
			display_list.pop_front()
			display_list.append(empty_char)
	
	var text_result = ""
	var is_ok_focused = ok_button and current_button == ok_button
	
	for i in display_list.size():
		if i == current_index and not is_ok_focused:
			text_result += "[" + display_list[i] + "]"
		else:
			text_result += display_list[i]
	
	entry_label.text = text_result


## get Final text
func get_text() -> Variant:
	var text_result = ""
	for i in buffer.size():
		text_result += buffer[i]
	
	return text_result


## Buffer-only insertion logic
func _handle_insertion(key: String) -> void:
	if current_index == max_chars - 1:
		if buffer[current_index] != empty_char and buffer[0] == empty_char:
			for i in range(max_chars - 1):
				buffer[i] = buffer[i + 1]
		buffer[max_chars - 1] = key
	else:
		buffer[current_index] = key


## Functional deletion logic: clear and ALWAYS shift cursor if possible
func _handle_deletion() -> void:
	buffer[current_index] = empty_char
	
	if current_index > 0:
		current_index -= 1


## Final callback to return data
func _on_input_completed(_final_text: String) -> void:
	pass


## Handles the logic when a virtual button is pressed via UI
func _on_button_pressed(button: BaseButton) -> void:
	var key = button.name.to_lower()
	
	match key:
		"ok":
			value_selected.emit(get_text())
			play_fx(select_fx)
			end()
		"back":
			back_selected.emit()
		"left":
			_move_cursor_left()
		"right":
			_move_cursor_right()
		"space":
			key_selected.emit(" ")
			play_fx(select_fx)
		_:
			key_selected.emit(button.name)
			play_fx(select_fx)
		
	_animate_button_click(button)


func _move_cursor_left() -> void:
	current_index = clampi(current_index - 1, 0, max_chars - 1)
	_update_label()
	play_fx(move_fx)


func _move_cursor_right() -> void:
	current_index = clampi(current_index + 1, 0, max_chars - 1)
	_update_label()
	play_fx(move_fx)


## Visual feedback for button interaction
func _animate_button_click(button: BaseButton) -> void:
	var sc = Vector2(1.1, 1.1)
	var t = create_tween()
	t.tween_property(button, "scale", Vector2(0.9, 0.9), 0.05)
	t.tween_property(button, "scale", sc + Vector2(0.1, 0.0), 0.1)
	t.tween_property(button, "scale", sc, 0.05)


## Configures the custom cursor position and behavior for this UI
func _config_hand() -> void:
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(32, 0), manipulator)
	GameManager.force_show_cursor()


## Processes navigation and physical keyboard shortcuts
func _process(delta: float) -> void:
	if not started or not current_button: return
	if GameManager.get_cursor_manipulator() == manipulator:
		
		var is_tab_just_pressed = Input.is_key_pressed(KEY_TAB) and ControllerManager.is_action_just_pressed("ui_focus_next")
		var is_shift_pressed = Input.is_key_pressed(KEY_SHIFT)

		if ControllerManager.is_action_just_pressed("Button L1") or (is_tab_just_pressed and is_shift_pressed) or ControllerManager.is_action_just_pressed("Button L1 Extra"):
			_move_cursor_left()
			return
			
		elif ControllerManager.is_action_just_pressed("Button R1") or (is_tab_just_pressed and not is_shift_pressed) or (ControllerManager.is_action_just_pressed("Button R1 Extra") and not Input.is_key_pressed(KEY_SHIFT)):
			_move_cursor_right()
			return

		elif ControllerManager.is_enter_just_pressed():
			get_viewport().set_input_as_handled()
			if ok_button and ControllerManager.is_key_pressed(KEY_CTRL):
				ok_button.grab_focus()
				current_button = ok_button
				_on_button_pressed(current_button)
			elif current_button:
				current_button.pressed.emit()
				_on_button_pressed(current_button)
			return
		
		var new_control: Node
		var direction = ControllerManager.get_pressed_direction()
		
		if direction:
			new_control = ControllerManager.get_closest_focusable_control(current_button, direction, true)
		elif ControllerManager.is_confirm_pressed():
			if ControllerManager.is_key_pressed(KEY_SPACE) and space_button:
				space_button.grab_focus()
				current_button = space_button
				_on_button_pressed(current_button)
			elif current_button:
				_on_button_pressed(current_button)
			return
		elif ControllerManager.is_erase_letter_pressed():
			if back_button:
				back_button.grab_focus()
				current_button = back_button
				_on_button_pressed(current_button)
			return
		
		var key = ControllerManager.get_any_key_just_pressed()
		if key:
			if key == " " and space_button:
				space_button.grab_focus()
				current_button = space_button
				_on_button_pressed(current_button)
				return
				
			for button: BaseButton in buttons:
				if button.name.to_lower() == key.to_lower():
					button.grab_focus()
					current_button = button
					_on_button_pressed(current_button)
					return
		
		if new_control:
			new_control.grab_focus()
			play_fx(move_fx)

func _refresh_ok_button_state() -> void:
	if not ok_button: return
	
	var complete = _is_input_complete()
	
	ok_button.disabled = !complete

	if complete:
		ok_button.modulate = Color.WHITE
		ok_button.focus_mode = Control.FOCUS_CLICK
		
	else:
		ok_button.modulate = Color(0.5, 0.5, 0.5, 0.7)
		ok_button.focus_mode = Control.FOCUS_NONE


## Checks if the buffer is completely filled (no empty_char left)
func _is_input_complete() -> bool:
	for char in buffer:
		if char == empty_char:
			return false
	return true
