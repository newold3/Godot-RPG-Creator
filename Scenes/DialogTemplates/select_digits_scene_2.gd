@tool
extends PanelContainer


func get_class() -> String:
	return "SelectDigitsScene"


@export var minimum_height: int = 58 :
	set(value):
		minimum_height = value
		if is_node_ready():
			custom_minimum_size.y = minimum_height
			size.y = minimum_height


var move_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var select_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}


var enabled: bool = false
var current_button = 0


const DIGIT_BUTTON = preload("res://Scenes/DialogTemplates/digit_button2.tscn")


@onready var digit_container: HBoxContainer = %DigitContainer
@onready var arrow_up: TextureButton = %ArrowUp
@onready var arrow_down: TextureButton = %ArrowDown


var current_text_font: Font
var format_config: Dictionary = {}
var scene_position: int = 0
var fix_position_delay: float = 0.1
var max_position_delay: float = 0.1
var use_the_message_boundaries: bool = false
var position_offset: Vector2 = Vector2.ZERO

var tween_button_up: Tween
var tween_button_down: Tween


signal value_selected(value: int)


func _ready() -> void:
	if not Engine.is_editor_hint():
		start()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if fix_position_delay > 0.0:
		fix_position_delay -= delta
		if fix_position_delay <= 0.0:
			fix_position_delay = max_position_delay
			_update_position()
	
	_check_button_pressed()


func start() -> void:
	GameManager.manage_cursor(self, Vector2(-20, 0))
	modulate.a = 0.0
	await get_tree().process_frame
	update_arrows_positions()
	_update_position()
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.6)
	t.tween_callback(
		func():
			GameManager.force_hand_position_over_node(self)
			GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, self)
			set("enabled", true)
	)
	digit_container.get_child(current_button).select(true)


func end() -> void:
	enabled = false
	GameManager.hide_cursor(false, self)
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)


func _update_position() -> void:
	if !GameManager or !GameManager.message:
		return
		
	var pos: Vector2
	var offset: Vector2
	var message: RichTextLabel = GameManager.message.get_message_box()
	var screen_size: Vector2 = get_viewport().size

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
	var digits = config.get("digits", 3)
	create_digits(digits)
	
	scene_position = config.get("position", 0)
	position_offset = config.get("offset", Vector2.ZERO)
	
	var fxs = ["move_fx", "select_fx"]
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
	
	await get_tree().process_frame
	%DigitContainer.get_child(0).select(true, false)


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


func create_digits(amount: int) -> void:
	DIGIT_BUTTON
	var container = %DigitContainer
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	size = custom_minimum_size
	
	for i in amount:
		var button = DIGIT_BUTTON.instantiate()
		button.name = "Digit%s" % (i + 1)
		button.pressed.connect(_on_digit_button_value_updated)
		button.selected.connect(
			func(node: PanelContainer):
				digit_container.get_child(current_button).select(false)
				node.select(true, false)
				current_button = button.get_index()
				update_arrows_positions()
				play_fx.bind(move_fx)
		)
		container.add_child(button)


func play_fx(fx_data: Dictionary) -> void:
	var audio_player: AudioStreamPlayer = %AudioPlayer
	audio_player.stop()
	audio_player.stream = fx_data.stream
	audio_player.volume_db = fx_data.volume
	audio_player.pitch_scale = fx_data.pitch
	audio_player.play()


func _check_button_pressed() -> void:
	if !enabled:
		return
	
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		if direction == "left":
			move_left()
		elif direction == "right":
			move_right()
	elif ControllerManager.is_confirm_pressed():
		if ControllerManager.last_action_registered.keycode == MOUSE_BUTTON_LEFT:
			return
		ControllerManager.remove_last_action_registered()
		_on_ok_button_pressed()


func _on_ok_button_pressed() -> void:
	get_viewport().set_input_as_handled()
	var current_number = ""
	for digit in %DigitContainer.get_children():
		current_number += str(digit.get_current_character())
	
	value_selected.emit(int(current_number))
	end()
	play_fx(select_fx)


func move(n: int) -> void:
	get_viewport().set_input_as_handled()
	var index = wrapi(current_button + n, 0, digit_container.get_child_count())
	digit_container.get_child(current_button).select(false, false)
	current_button = index
	var target = digit_container.get_child(current_button)
	target.select(true, false)
	
	update_arrows_positions() 
	
	play_fx(move_fx)


func update_arrows_positions() -> void:
	if digit_container.get_child_count() <= current_button:
		return
		
	arrow_up.visible = true
	arrow_down.visible = true
	
	var target = digit_container.get_child(current_button)
	
	var extra_size = 1
	arrow_up.size.x = target.size.x
	arrow_up.global_position = Vector2(
		target.global_position.x,
		target.global_position.y - arrow_up.size.y - extra_size
	)
	arrow_down.global_position = Vector2(
		target.global_position.x,
		target.global_position.y + target.size.y + extra_size
	)


func move_left() -> void:
	move(-1)


func move_right() -> void:
	move(1)


func _on_arrow_up_pressed() -> void:
	var target = digit_container.get_child(current_button)
	if not target.is_animating:
		target.move_up()


func _on_arrow_down_pressed() -> void:
	var target = digit_container.get_child(current_button)
	if not target.is_animating:
		target.move_down()


func _on_digit_button_value_updated(direction: int) -> void:
	update_arrows_positions()
	var target = arrow_down if direction == -1 else arrow_up
	target.toggle_mode = true
	target.set_pressed_no_signal(true)
	play_fx(move_fx)
	
	var t: Tween
	
	if direction == -1:
		if tween_button_up:
			tween_button_up.custom_step(0.2)
			tween_button_up.kill()
		tween_button_up = create_tween()
		t = tween_button_up
	else:
		if tween_button_down:
			tween_button_down.custom_step(0.2)
			tween_button_down.kill()
		tween_button_down = create_tween()
		t = tween_button_down
	
	t.tween_property(target, "position:y", target.position.y + 2 * (-direction), 0.1)
	t.tween_property(target, "position:y", target.position.y, 0.1)
	
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	
	target.toggle_mode = false
	target.set_pressed_no_signal(false)
