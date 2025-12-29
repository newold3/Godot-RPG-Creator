@tool
extends PanelContainer

func get_class() -> String:
	return "SelectDigitsScene"


@export var first_button: PanelContainer

@export var title_color: Color = Color.WHITE :
	set(value):
		title_color = value
		if is_node_ready():
			%Title.set("theme_override_colors/font_color", title_color)

@export var number_selected_color: Color = Color("#00cc00") :
	set(value):
		number_selected_color = value
		if is_node_ready():
			%Digits.set("theme_override_colors/caret_color", number_selected_color)
			%Digits.set("theme_override_colors/font_color", number_selected_color)

@export var empty_character: String = "▫"

var can_write_letters: Array


var current_text_font: Font
var enabled: bool = false
var move_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var select_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var remove_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var current_number = "0"

var format_config: Dictionary = {}
var scene_position: int = 0
var fix_position_delay: float = 0.1
var max_position_delay: float = 0.1
var use_the_message_boundaries: bool = false
var position_offset: Vector2 = Vector2.ZERO
var max_length: int = 9

var button_selected: int = 0

var started = false


signal value_selected(value: int)


func _ready() -> void:
	if not Engine.is_editor_hint():
		GameManager.set_text_config(self, false)
		start()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if fix_position_delay > 0.0:
		fix_position_delay -= delta
		if fix_position_delay <= 0.0:
			fix_position_delay = max_position_delay
			_update_position()


func start() -> void:
	GameManager.manage_cursor(self, Vector2(-3, 0))
	modulate.a = 0.0
	await get_tree().process_frame
	for digit in %DigitContainer.get_children():
		digit.button_pressed.connect(_on_digit_button_pressed)
		digit.focus_entered.connect(func(): button_selected = digit.id - 1)
		digit.back_pressed.connect(_on_button_back_pressed)
		digit.select_child.connect(_on_digit_selected)
	%Digits.text = format_number(current_number)
	%Digits.caret_column = %Digits.text.length()
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.6)
	t.tween_callback(
		func():
			GameManager.force_hand_position_over_node(self)
			GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, self)
			set("enabled", true)
	)
	
	fill_letters_allowed()
	
	_update_position()
	
	ControllerManager.clear()
	for digit in %DigitContainer.get_children():
		digit.deselect()
	first_button.select()
	GameManager.force_hand_position_over_node(self)
	GameManager.hand_cursor.show_cursor(MainHandCursor.HandPosition.LEFT, self)
	
	started = true


func fill_letters_allowed() -> void:
	can_write_letters = []
	
	# Numbers
	for i in range(48, 58):
		can_write_letters.append(char(i))
	
	# Pad Number:
	for i in range(10):
		can_write_letters.append("kp %s" % (i))


func end() -> void:
	GameManager.set_cursor_manipulator("")
	enabled = false
	for button in %DigitContainer.get_children():
		button.enabled = false
	GameManager.hide_cursor(false, self)
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)


func _on_digit_selected(node: DigitButton) -> void:
	if node:
		node.select()


func _update_position() -> void:
	if !GameManager or !GameManager.message:
		return
		
	var pos: Vector2
	var offset: Vector2
	var message: RichTextLabel = GameManager.message.get_message_box()
	var screen_size: Vector2 = get_window().content_scale_size

	if !message or !message.get_parent().get_parent().visible or !use_the_message_boundaries:
		match scene_position:
			0: # Top Left
				pos = Vector2.ZERO
				offset = Vector2.ZERO
			1: # Top Center
				pos = Vector2(0.5, 0)
				offset = Vector2(-size.x * 0.5, 0)
			2: # Top Right
				pos = Vector2(1, 0)
				offset = Vector2(-size.x, 0)
			3: # Left
				pos = Vector2(0, 0.5)
				offset = Vector2(0, -size.y * 0.5)
			4: # Center
				pos = Vector2(0.5, 0.5)
				offset = Vector2(-size.x * 0.5, -size.y * 0.5)
			5: # Right
				pos = Vector2(1, 0.5)
				offset = Vector2(-size.x, -size.y * 0.5)
			6: # Bottom Left
				pos = Vector2(0, 1)
				offset = Vector2(0, -size.y)
			7: # Bottom Center
				pos = Vector2(0.5, 1)
				offset = Vector2(-size.x * 0.5, -size.y)
			8: # Bottom Right
				pos = Vector2.ONE
				offset = Vector2(-size.x, -size.y)
		
		position = screen_size * pos + offset + position_offset
	else:
		var other_offset = message.global_position + position_offset
		match scene_position:
			0: # Top Left
				pos = Vector2.ZERO
				offset = Vector2(-size.x, -size.y)
			1: # Top Center
				pos = Vector2(0.5, 0)
				offset = Vector2(-size.x * 0.5, -size.y)
			2: # Top Right
				pos = Vector2(1, 0)
				offset = Vector2(0, -size.y)
			3: # Left
				pos = Vector2(0, 0.5)
				offset = Vector2(-size.x, -size.y * 0.5)
			4: # Center
				pos = Vector2(0.5, 0.5)
				offset = Vector2(-size.x * 0.5, -size.y * 0.5)
			5: # Right
				pos = Vector2(1, 0.5)
				offset = Vector2(0, -size.y * 0.5)
			6: # Bottom Left
				pos = Vector2(0, 1)
				offset = Vector2(-size.x, 0)
			7: # Bottom Center
				pos = Vector2(0.5, 1)
				offset = Vector2(-size.x * 0.5, 0)
			8: # Bottom Right
				pos = Vector2.ONE
				offset = Vector2(0, 0)
			
		position = message.size * pos + offset + other_offset
		
	position.x = clamp(position.x, 10, screen_size.x - 10 - size.x)
	position.y = clamp(position.y, 10, screen_size.y - 10 - size.y)


func set_data(config: Dictionary) -> void:
	%Title.text = config.get("title", "Enter Value")
	var digits = config.get("digits", 3)
	max_length = digits
	%Digits.text = format_number(current_number)
	%Digits.caret_column = %Title.text.length()
	
	scene_position = config.get("position", 0)
	position_offset = config.get("offset", Vector2.ZERO)
	
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
	use_the_message_boundaries = config.get("use_message_config", true)
	if use_the_message_boundaries:
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
	
	_update_config()


func _update_config() -> void:
	var font = format_config.get("font")
	if font == null:
		font = "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf"
	if ResourceLoader.exists(font):
		current_text_font = load(font)
	var text_color = format_config.get("text_color")
	if text_color == null:
		text_color = Color.WHITE
	var text_size = format_config.get("text_size")
	if text_size == null:
		text_size = 22
	var text_align = format_config.get("text_align")
	if text_align == null:
		text_align = 0
	var outline_size = format_config.get("outline_size")
	if outline_size == null:
		outline_size = 2
	var outline_color = format_config.get("outline_color")
	if outline_color == null:
		outline_color = Color.BLACK
	var shadow_offset = format_config.get("shadow_offset")
	if shadow_offset == null:
		shadow_offset = Vector2(2, 2)
	var shadow_color = format_config.get("shadow_color")
	if shadow_color == null:
		shadow_color = Color("#00000093")
	
	empty_character = format_config.get("empty_place", "·")
	
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
	
	%Title.set("theme_override_colors/font_color", title_color)
	%Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%Digits.set("theme_override_colors/font_color", number_selected_color)
	%Digits.set("theme_override_colors/caret_color", number_selected_color)


func play_fx(fx_data: Dictionary) -> void:
	var audio_player: AudioStreamPlayer = %AudioPlayer
	audio_player.stop()
	audio_player.stream = fx_data.stream
	audio_player.volume_db = fx_data.volume
	audio_player.pitch_scale = fx_data.pitch
	audio_player.play()


func get_number_length(number: String) -> int:
	# Cuenta solo dígitos, ignorando separadores
	var count = 0
	for digit in number:
		if digit.is_valid_int():
			count += 1
	return count


func format_number(number: String) -> String:
	var locale = TranslationServer.get_locale()
	
	var final_string = ""
	var count = 0
	var separator = "." if locale in ["es", "de"] else ","
	
	for i in range(number.length() - 1, -1, -1):
		if count == 3:
			final_string = separator + final_string
			count = 0
		final_string = number[i] + final_string
		count += 1
	
	if final_string.length() > 1 and final_string[0] == "0":
		if final_string[1] == "," or final_string[1] == ".":
			final_string = final_string.substr(2, final_string.length())
		else:
			final_string = final_string.substr(1, final_string.length())
	
	if !final_string or final_string == "0":
		final_string = ""
	
	while final_string.length() < max_length + final_string.count(separator):
		final_string = empty_character + final_string
	
	if int(number) == 0:
		final_string[-1] = "0"
	
	return(final_string)


func _on_button_pressed(digit: int) -> void:
	var current_length = current_number.length()
	if current_number == "0":
		current_number = str(digit)
	else:
		var clean_number = ""
		for c in current_number:
			if c.is_valid_int():
				clean_number += c
				
		if clean_number.length() >= max_length - 1:
			clean_number = clean_number.substr(0, max_length - 1)

		clean_number += str(digit)
		current_number = clean_number
	
	%Digits.text = format_number(current_number)
	%Digits.caret_column = %Digits.text.length()
	
	if current_length != current_number.length() and current_number.length() == max_length:
		for child in %DigitContainer.get_children():
			if child is DigitButton and child.id == 12:
				child.select()
				break
		
	
	play_fx(select_fx)


func _on_button_back_pressed(_id : int = -1) -> void:
	_find_button_and_animate_with_text(%DigitContainer, 10) # Animate back button
	current_number = current_number.substr(0, current_number.length() - 1)
	%Digits.text = format_number(current_number)
	%Digits.caret_column = %Digits.text.length()
	play_fx(remove_fx)


func _on_button_ok_pressed() -> void:
	value_selected.emit(int(current_number))
	play_fx(select_fx)
	end()


func _on_button_focus_entered() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if started:
			play_fx(move_fx)


func _on_digit_button_pressed(id: int) -> void:
	if not started:
		return
	
	if ControllerManager.is_force_confirm_pressed():
		_on_button_ok_pressed()
		return
		
	if id < 10:
		_on_button_pressed(id)
	elif id == 10:
		_on_button_back_pressed()
	elif id == 11:
		_on_button_pressed(0)
	elif id == 12:
		_on_button_ok_pressed()


func _input(event: InputEvent) -> void:
	if not enabled: return
	
	if event is InputEventKey:
		if event.pressed and not event.echo:
			var key_string = OS.get_keycode_string(event.keycode).to_lower()
			if key_string in can_write_letters:
				_find_button_and_press_with_text(%DigitContainer, str(int(key_string)))


func _find_button_and_press_with_text(node: Node, text: String) -> void:
	if node is DigitButton and node.get_text().to_lower() == text:
		node.select()
		node.button_pressed.emit(node.id)
		get_viewport().set_input_as_handled()
		return
	
	for child in node.get_children():
		_find_button_and_press_with_text(child, text)


func _find_button_and_animate_with_text(node: Node, id: int) -> void:
	if node is DigitButton and node.id == id:
		node._animate_button()
		return
	
	for child in node.get_children():
		_find_button_and_animate_with_text(child, id)
