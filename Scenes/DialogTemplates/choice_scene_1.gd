@tool
extends PanelContainer


var current_text_font: Font
var old_selected_index: int = -5


func get_class() -> String:
	return "ChoiceScene"


var move_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var select_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}
var cancel_fx: Dictionary = {"stream": AudioStream, "volume": 0, "pitch": 1}


var cancel_target = 1
var scene_position = 0
var max_choices = 4
var use_the_message_boundaries: bool = false
var position_offset: Vector2 = Vector2.ZERO


var current_selected: int = -1
var max_pages: int = 1
var current_page: int = 0

var all_options: PackedStringArray

var enabled: bool = false

var fix_position_delay: float = 0.1
var max_position_delay: float = 0.1

var format_config: Dictionary = {}

var main_tween: Tween

var old_size_and_position: String

const MAX_WIDTH_SCREEN_PERCENT = 0.95


@onready var selector: TextureRect = %Selector
@onready var audio_player: AudioStreamPlayer = %AudioPlayer
@onready var page_label: Label = %PageLabel



signal option_selected(id: int)
signal cancel()
signal finish()



func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	GameManager.manage_cursor(self, Vector2(-20, 0))
		
	GameManager.set_text_config(self)
		
	%ButtonBack.pressed.connect(show_previous_page)
	%ButtonNext.pressed.connect(show_next_page)

	option_selected.connect(func(_x): finish.emit())
	cancel.connect(func(): finish.emit())
	finish.connect(end)

	start()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or !enabled:
		return
	
	_update_position()
	
	_check_button_pressed()


func start() -> void:
	await get_tree().process_frame
	if main_tween:
		main_tween.kill()
		
	modulate.a = 0.0
	
	_update_position()
	
	if not max_pages > current_page:
		current_page = 0
		change_page(0)
		current_selected = -1

	if not all_options.size() > current_selected:
		current_selected = -1
	
	%ButtonBack.visible = current_page > 0
	%ButtonNext.visible = current_page != max_pages - 1 and max_pages > 1
	
	if current_selected != -1:
		var container = %OptionsContainer
		if container.get_child_count() > 0:
			var child_index: int = current_selected % int(max_choices)
			var node = container.get_child(child_index)
			call_deferred("_select_first_item", node)
			selector.reparent(node)
			selector.position = Vector2.ZERO
			selector.size = node.size
	else:
		call_deferred("disabled")
	
	main_tween = create_tween()
	main_tween.tween_property(self, "modulate:a", 1.0, 0.6)
	main_tween.tween_callback(
		func():
			enabled = true
	)


func _select_first_item(node: Control) -> void:
	node.grab_focus()
	GameManager.force_hand_position_over_node(self)
	GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, self)


func disabled() -> void:
	current_selected = 0
	change_page(0, true)
	%OptionsContainer.get_child(0).grab_focus()
	GameManager.force_hand_position_over_node(self)
	GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, self)


func end() -> void:
	if main_tween:
		main_tween.kill()
		
	enabled = false
	
	GameManager.hide_cursor(false, self)
	main_tween = create_tween()
	main_tween.tween_property(self, "modulate:a", 0.0, 0.6)
	main_tween.tween_callback(queue_free)


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
	
	set_initial_cursor_position()


func set_data(config: Dictionary, options: PackedStringArray) -> void:
	all_options = options
	max_choices = config.get("max_choices", 4)
	cancel_target = config.get("cancel", 1)
	%ButtonNext.label_text = config.get("next", tr("Next"))
	%ButtonBack.label_text = config.get("previous", tr("Previous"))
	scene_position = config.get("position", 0)
	use_the_message_boundaries = config.get("use_message_bounds", true)
	position_offset = config.get("offset", Vector2.ZERO)
	
	var fxs = ["move_fx", "select_fx", "cancel_fx"]
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
	
	max_pages = ceil(options.size() / float(max_choices))
	
	format_config = {}
	var using_message_dialog_text_format = config.get("use_message_config", true)
	if using_message_dialog_text_format:
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
			"font": config.get("font", "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf"),
			"text_color": config.get("text_color", Color.WHITE),
			"text_size": config.get("text_size", 22),
			"text_align": config.get("text_align", 0),
			"outline_size": config.get("outline_size", 2),
			"outline_color": config.get("outline_color", Color.BLACK),
			"shadow_offset": config.get("shadow_offset", Vector2(2, 2)),
			"shadow_color": config.get("shadow_color", Color("#00000093"))
		}
	
	
	var default_target = config.get("default", 0)
	if not all_options.size() > default_target:
		default_target = 0
	if default_target == 0:
		current_page = 0
		current_selected = -1
		selector.visible = false
	else:
		current_page = floor(default_target / max_choices)
		current_selected = default_target - 1
		selector.visible = true
		call_deferred("_set_selector_size")
	
	%ButtonBack.visible = current_page > 0
	%ButtonNext.visible = max_pages > 1
	
	var start_index = current_page * max_choices
	set_options(all_options, start_index)
	
	_update_page_label()
	
	await get_tree().process_frame
	_preccalculate_dialog_size()
	_on_option_selected(current_selected)


func _preccalculate_dialog_size() -> void:
	var panel: StyleBox = get("theme_override_styles/panel")
	var margin: int = 0
	if panel:
		if "content_margin_left" in panel:
			margin += int(panel.content_margin_left + panel.content_margin_right)
			
	var align = HORIZONTAL_ALIGNMENT_LEFT
	var font: String = format_config.get("font", "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf")
	if ResourceLoader.exists(font):
		current_text_font = load(font)
		var text_size: int = format_config.get("text_size", 22)
		var page_text = " (%s %s / %s)" % [tr("Page"), max_pages, max_pages]
		var max_width: int = current_text_font.get_string_size(page_text, align, -1, text_size).x
		max_width += %ButtonBack.size.x + %ButtonNext.size.x + margin
		for option: String in all_options:
			var w = current_text_font.get_string_size(option, align, -1, text_size).x + margin
			max_width = max(max_width, w)
		
		var max_width_allowed = get_viewport().size.x * MAX_WIDTH_SCREEN_PERCENT
		if max_width > max_width_allowed:
			max_width = max_width_allowed
			for option: Label in %OptionsContainer.get_children():
					option.clip_text = true
					option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
					option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		custom_minimum_size.x = max_width
		size.x = max_width


func _set_selector_size() -> void:
	if current_selected != -1:
		var label_index = current_selected % int(max_choices)
		var node = %OptionsContainer.get_child(label_index)
		if not selector.is_ancestor_of(node):
			selector.reparent(node)
		selector.visible = true
		selector.size = node.size


func set_options(options: PackedStringArray, start_index: int = 0) -> void:
	var container = %OptionsContainer
	if selector.get_parent() != self:
		selector.reparent(self)
		
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
		
	var current_option = 0
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
	
	for i in range(start_index, options.size()):
		var option = options[i]
		var button = Label.new()
		button.text = option
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_CLICK
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.mouse_entered.connect(func(): _on_option_selected(i); play_fx(move_fx))
		button.focus_entered.connect(
			func():
				await get_tree().process_frame
				if is_instance_valid(button):
					selector.reparent(button)
					selector.position = Vector2.ZERO
					selector.size = button.size
					selector.visible = true
		)
		
		if current_text_font:
			button.set("theme_override_fonts/font", current_text_font)
		button.set("theme_override_colors/font_color", text_color)
		button.set("theme_override_font_sizes/font_size", text_size)
		button.set("theme_override_constants/outline_size", outline_size)
		button.set("theme_override_constants/shadow_offset_x", shadow_offset.x)
		button.set("theme_override_constants/shadow_offset_y", shadow_offset.y)
		button.set("theme_override_colors/font_outline_color", outline_color)
		button.set("theme_override_colors/font_shadow_color", shadow_color)
		button.set("horizontal_alignment", text_align)
		
		container.add_child(button)
		
		current_option += 1

		if current_option >= max_choices:
			break


func show_next_page() -> void:
	change_page(1, true)
	play_fx(move_fx)


func show_previous_page() -> void:
	change_page(-1, true)
	play_fx(move_fx)


func _update_page_label() -> void:
	if max_pages < 2:
		page_label.visible = false
		page_label.text = ""
	else:
		page_label.visible = true
		page_label.text = " (%s %s / %s)" % [tr("Page"), current_page + 1, max_pages]


func change_page(mod: int, set_selected: bool = false) -> void:
	var old_page = current_page
	current_page = wrapi(current_page + mod, 0, max_pages)
	if old_page == current_page:
		return
	var start_index = current_page * max_choices
	%ButtonBack.visible = current_page > 0
	%ButtonNext.visible = max_pages > 1 and current_page < max_pages - 1
	set_options(all_options, start_index)
	await get_tree().process_frame
	if set_selected:
		current_selected = start_index if current_selected != -1 else -1
	_on_option_selected(current_selected)
	_update_page_label()


func _on_option_selected(index: int) -> void:
	current_selected = max(-1, min(index, all_options.size() - 1))
	
	if current_selected == -1:
		disabled()
		return

	
	var item_index = current_selected % int(max_choices)
	var container = %OptionsContainer
	if container.get_child_count() > item_index:
		container.get_child(item_index).grab_focus()
	elif container.get_child_count() > 0:
		disabled()


func set_initial_cursor_position() -> void:
	pass


func _check_button_pressed() -> void:
	var current_control_focused = get_viewport().gui_get_focus_owner()
	if !current_control_focused or not current_control_focused is Label:
		return
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		if direction in ["up", "down"]:
			var step = -1 if direction == "up" else 1
			selected_next_option(step)
		if direction in ["left", "right"]:
			show_previous_page() if direction == "left" else show_next_page()
	elif ControllerManager.is_confirm_pressed(true):
		ControllerManager.remove_last_action_registered()
		option_selected.emit(current_selected)
		play_fx(select_fx)
	elif Input.is_action_pressed("mouse_wheel_down"):
		show_next_page()
	elif Input.is_action_pressed("mouse_wheel_up"):
		show_previous_page()
	elif cancel_target != 1 and ControllerManager.is_cancel_pressed():
		ControllerManager.remove_last_action_registered()
		play_fx(cancel_fx)
		if cancel_target == 0:
			cancel.emit()
		else:
			option_selected.emit(cancel_target)


func play_fx(fx_data: Dictionary) -> void:
	if old_selected_index != current_selected or fx_data.stream != move_fx.stream:
		@warning_ignore("shadowed_variable")
		var audio_player: AudioStreamPlayer = %AudioPlayer
		audio_player.stop()
		audio_player.stream = fx_data.stream
		audio_player.volume_db = fx_data.volume
		audio_player.pitch_scale = fx_data.pitch
		audio_player.play()
	
	old_selected_index = current_selected


func selected_next_option(mod: int) -> void:
	if all_options.size() < 1:
		return
		
	var index = wrapi(current_selected + mod, 0, all_options.size())
	var target_page = floor(index / max_choices)
	
	current_selected = index
		
	if target_page != current_page:
		var new_page_mod = target_page - current_page
		await change_page(new_page_mod)
	
	@warning_ignore("redundant_await")
	await _on_option_selected(current_selected)
	
	#var position_index = current_selected % int(max_choices)
	
	play_fx(move_fx)
