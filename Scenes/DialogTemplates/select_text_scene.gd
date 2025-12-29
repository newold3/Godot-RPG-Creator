@tool
extends PanelContainer

func get_class() -> String:
	return "SelectTextsScene"


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
			%Letters.set("theme_override_colors/caret_color", number_selected_color)
			%Letters.set("theme_override_colors/font_color", number_selected_color)


var can_write_letters: Array


var current_text_font: Font
var enabled: bool = false
var move_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var select_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var remove_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var current_text = ""

var format_config: Dictionary = {}
var scene_position: int = 0
var fix_position_delay: float = 0.1
var max_position_delay: float = 0.1
var use_the_message_boundaries: bool = false
var position_offset: Vector2 = Vector2.ZERO
var max_length: int = 16

var button_selected: int = 0

var is_shift_pressed: bool = false
var shift_disabled_color: Color
var letters: Array = []


signal value_selected(value: String)


func _ready() -> void:
	if not Engine.is_editor_hint():
		GameManager.set_text_config(self, false)
		%MaxLetterLabel.set("theme_override_font_sizes/font_size", 14)
		_setup_letters()
		start()


func _setup_letters() -> void:
	letters = [
		%"1", %"2", %"3", %"4", %"5", %"6", %"7", %"8", %"9", %"0", %DELETE,
		%Q, %W, %E, %R, %T, %Y, %U, %I, %O, %P,
		%A, %S, %D, %F, %G, %H, %J, %K, %L, %"Ñ",
		%SHIFT, %Z, %X, %C, %V, %B, %N, %M, %OK,
		%SPACE
	]
	for letter in letters:
		letter.all_digits = letters


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
	shift_disabled_color = %SHIFT.button_text_color
	%SHIFT.change_text_color(shift_disabled_color)
	_connect_button_recursive(%TextContainer)
	%Letters.text = current_text
	%Letters.caret_column = %Letters.text.length()
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.6)
	t.tween_callback(
		func():
			GameManager.force_hand_position_over_node(self)
			GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, self)
			set("enabled", true)
	)
	first_button.select()
	
	fill_letters_allowed()
	_update_max_letters_label()


func fill_letters_allowed() -> void:
	can_write_letters = []
	
	# Numbers
	for i in range(48, 58):
		can_write_letters.append(char(i))

	# Upper letters
	for i in range(65, 91):
		can_write_letters.append(char(i))

	# Lower letters
	for i in range(97, 123):
		can_write_letters.append(char(i))


func _connect_button_recursive(node: Node) -> void:
	if node is DigitButton:
		node.button_pressed.connect(_on_text_button_pressed.bind(node))
		node.focus_entered.connect(func(): button_selected = node.id - 1)
		node.back_pressed.connect(_on_button_back_pressed)
		node.select_child.connect(_select_child)
	
	for child in node.get_children():
		_connect_button_recursive(child)


func end() -> void:
	enabled = false
	GameManager.set_cursor_manipulator("")
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)


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
	var text_length = config.get("digits", 3)
	max_length = text_length
	%Letters.text = current_text
	%Letters.caret_column = %Title.text.length()
	
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
	
	_update_config()
	_update_max_letters_label()


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
	%Letters.set("theme_override_colors/font_color", number_selected_color)
	%Letters.set("theme_override_colors/caret_color", number_selected_color)


func _update_max_letters_label() -> void:
	%MaxLetterLabel.set("theme_override_font_sizes/font_size", 14)
	%MaxLetterLabel.text = "%s / %s" % [%Letters.text.length(), max_length]


func play_fx(fx_data: Dictionary) -> void:
	var audio_player: AudioStreamPlayer = %AudioPlayer
	audio_player.stop()
	audio_player.stream = fx_data.stream
	audio_player.volume_db = fx_data.volume
	audio_player.pitch_scale = fx_data.pitch
	audio_player.play()


func _on_button_pressed(text: String) -> void:
	if current_text.length() < max_length:
		current_text += text
	elif not current_text.is_empty():
		current_text[-1] = text
	else:
		current_text = text
		
	%Letters.text = current_text
	%Letters.caret_column = %Letters.text.length()
	
	play_fx(select_fx)
	_update_max_letters_label()


func _on_button_back_pressed(_id : int = -1) -> void:
	_find_button_and_animate_with_text(%TextContainer, 150) # Animate back button
	current_text = current_text.substr(0, current_text.length() - 1)
	%Letters.text = current_text
	%Letters.caret_column = %Letters.text.length()
	play_fx(remove_fx)
	_update_max_letters_label()


func _select_child(node: DigitButton) -> void:
	if node:
		get_viewport().set_input_as_handled()
		node.select()


func _on_button_ok_pressed() -> void:
	value_selected.emit(current_text)
	play_fx(select_fx)
	end()


func _on_button_focus_entered() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		play_fx(move_fx)


func _on_text_button_pressed(id: int, node: DigitButton) -> void:
	if ControllerManager.is_force_confirm_pressed():
		_on_button_ok_pressed()
		return
		
	if id == 50: # Change Letter Case
		is_shift_pressed = !is_shift_pressed
		if is_shift_pressed:
			%SHIFT.change_text_color(Color("#ffffff"))
		else:
			%SHIFT.change_text_color(shift_disabled_color)
		_update_letters_case_recursive(%TextContainer)
	elif id == 150: # Remove Letter
		_on_button_back_pressed()
	elif id == 200: # OK Button
		_on_button_ok_pressed()
	else: # Write pressed letter
		_on_button_pressed(node.get_text())


func _update_letters_case_recursive(node: Node) -> void:
	if node is DigitButton:
		if node.id != 200: # convert everything except the OK button
			if is_shift_pressed:
				node.button_text = node.button_text.to_upper()
			else:
				node.button_text = node.button_text.to_lower()
	
	for child in node.get_children():
		_update_letters_case_recursive(child)


func _select_button_with_id(node: Node, id: int) -> void:
	if node is DigitButton and node.id == id:
		node.select()
		return
	
	for child in node.get_children():
		_select_button_with_id(child, id)


func _input(event: InputEvent) -> void:
	if !enabled:
		return
		
	if event is InputEventKey:
		if event.pressed and not event.echo:
			var key_string = OS.get_keycode_string(event.keycode).to_lower()
			if key_string in can_write_letters:
				_find_button_and_press_with_text(%TextContainer, key_string)
			else:
				if event.keycode == KEY_QUOTELEFT: # ñ
					_find_button_and_press_with_text(%TextContainer, "ñ")
				elif event.keycode == KEY_SHIFT or event.keycode == KEY_CAPSLOCK: # Shift
					_find_button_and_press_with_text(%TextContainer, "🡅")
				elif event.keycode == KEY_SPACE: # Space
					if not button_selected == 199: # Button OK
						_find_button_and_press_with_text(%TextContainer, " ")
				elif event.keycode in range(KEY_KP_0, KEY_KP_9 + 1): # numbers in numeric pad
					var number = event.keycode - KEY_KP_0
					_find_button_and_press_with_text(%TextContainer, str(number))
		elif not event.pressed:
			if event.keycode == KEY_SHIFT and is_shift_pressed: # Shift
				_find_button_and_press_with_text(%TextContainer, "🡅")


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
