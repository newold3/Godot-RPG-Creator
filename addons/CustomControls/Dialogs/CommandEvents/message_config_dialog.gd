@tool
extends CommandBaseDialog


var dialog_scene_file: String
var fx_file: String

var font_selected: String = ""

var lenght_cache = {
	"Bounce": 16.0,
	"Console": 1.0,
	"Embers": 8.0,
	"Prickle": 16.0,
	"Redacted": 8.0,
	"WFC": 32.0,
	"Word": 4.0
}

var preview_message_dialog: Window
var showing_preview_window: bool = true

var last_config: Dictionary

var busy: bool = false


func _ready() -> void:
	super()
	parameter_code = 1
	focus_exited.connect(func(): wrap_controls = false)
	focus_entered.connect(_on_focus_entered)
	%PresetComposeScene.load_preset_requested.connect(_on_load_preset)
	%PresetComposeScene.save_preset_requested.connect(_on_save_preset)


func _on_focus_entered() -> void:
	wrap_controls = true
	if preview_message_dialog and is_instance_valid(preview_message_dialog) and preview_message_dialog.mode == Window.MODE_MINIMIZED and not busy:
		busy = true
		preview_message_dialog.queue_free()
		await get_tree().process_frame
		%PreviewConfig.pressed.emit()
		await get_tree().process_frame
		busy = false


func grab_focus() -> void:
	if preview_message_dialog and is_instance_valid(preview_message_dialog) and preview_message_dialog.visible:
		var rect = Rect2(
			DisplayServer.window_get_position(preview_message_dialog.get_window_id()),
			preview_message_dialog.size
		)
		if rect.has_point(DisplayServer.mouse_get_position()):
			if not preview_message_dialog.has_focus():
				preview_message_dialog.grab_focus()
		elif not has_focus():
			super()


func set_data() -> void:
	set_config(parameters[0].parameters)


func set_config(config: Dictionary) -> void:
	dialog_scene_file = config.get("scene_path", "res://Scenes/DialogTemplates/base_dialog.tscn")
	fx_file = config.get("fx_path", "res://Assets/Sounds/typewrite2.ogg")
	%DialogScene.set_text(dialog_scene_file.get_file() if dialog_scene_file else "Select dialog scene")
	%TextBoxPosition.select(max(0, min(config.get("text_box_position", 7), %TextBoxPosition.get_item_count() - 1)))
	%TextBoxMarginLeft.value = config.get("text_box_margin_left", 16)
	%TextBoxMarginRight.value = config.get("text_box_margin_right", 16)
	%TextBoxMarginTop.value = config.get("text_box_margin_top", 16)
	%TextBoxMarginBottom.value = config.get("text_box_margin_bottom", 16)
	font_selected = config.get("font", "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf")
	%Font.text = font_selected.get_file()
	%TextColor.set_color(config.get("text_color", Color.WHITE))
	%TextSize.value = config.get("text_size", 22)
	%TextAlign.select(max(0, min(config.get("text_align", 0), %TextAlign.get_item_count() - 1)))
	%MaxWidth.value = config.get("max_width", 800)
	%MaxLines.value = config.get("max_lines", 4)
	%CharacterDelay.value = config.get("character_delay", 0.03)
	%DotDelay.value = config.get("dot_delay", 0.35)
	%CommaDelay.value = config.get("comma_delay", 0.15)
	%ParagraphDelay.value = config.get("paragraph_delay", 1.5)
	var skip_index = max(0, min(config.get("skip_mode", 3), %SkipMode.get_item_count() - 1))
	%SkipMode.select(skip_index)
	%SkipSpeed.value = config.get("skip_speed", 0.01)
	%SkipSpeed.set_disabled(skip_index != 3)
	%StartAnimation.select(max(0, min(config.get("start_animation", 2), %StartAnimation.get_item_count() - 1)))
	%StartAnimationDuration.value = config.get("start_animation_duration", 0.45)
	%StartAnimationTransitionType.select(
		max(0, min(config.get("start_animation_trans_type", 10), %StartAnimationTransitionType.get_item_count() - 1))
	)
	%StartAnimationTransitionEase.select(
		max(0, min(config.get("start_animation_ease_type", 1), %StartAnimationTransitionEase.get_item_count() - 1))
	)
	%EndAnimation.select(max(0, min(config.get("end_animation", 1), %EndAnimation.get_item_count() - 1)))
	%EndAnimationDuration.value = config.get("end_animation_duration", 0.45)
	%EndAnimationTransitionType.select(
		max(0, min(config.get("end_animation_trans_type", 10), %EndAnimationTransitionType.get_item_count() - 1))
	)
	%EndAnimationTransitionEase.select(
		max(0, min(config.get("end_animation_ease_type", 0), %EndAnimationTransitionEase.get_item_count() - 1))
	)
	var text_transition_index = max(0, min(config.get("text_transition", 0), %TextTransition.get_item_count() - 1))
	%TextTransition.select(text_transition_index)
	set_text_transition_values(config, text_transition_index)
	%TextTransition.item_selected.emit(text_transition_index)
	%FX.set_text(fx_file if fx_file else "Select Audio File")
	%Volume.value = config.get("fx_volume", 0)
	%PitchMin.value = config.get("fx_pitch_min", 0.7)
	%PitchMax.value = config.get("fx_pitch_max", 1.1)
	
	%PasteParameters.set_disabled(!StaticEditorVars.CLIPBOARD.has("message_config"))
	
	%OutlineSize.value = config.get("outline_size", 2)
	%OutlineColor.set_color(config.get("outline_color", Color.BLACK))
	
	var shadow_offset = config.get("shadow_offset", Vector2(2, 2))
	%ShadowOffsetX.value = shadow_offset.x
	%ShadowOffsetY.value = shadow_offset.y
	%ShadowColor.set_color(config.get("shadow_color", Color("#00000093")))


func set_text_transition_values(config: Dictionary, index: int) -> void:
	var parameters = config.get("text_transition_parameters", {})
	%Length.value = parameters.get("length", 8.0)
	match index:
		0:
			%DefaultFadeTime.value = parameters.get("fade_time", 0.3)
		1:
			%BounceIntensity.value = parameters.get("intensity", 8.0)
		2:
			%ConsoleCursorText.text = parameters.get("cursor", "┃")
			%ConsoleCursorColor.set_color(parameters.get("color", Color.GREEN_YELLOW))
			%UseTextColor.set_pressed(parameters.get("use_text_color", false))
		3:
			%EmberText.text = parameters.get("ember", ".")
			%EmberColor.set_color(parameters.get("color", Color.RED))
			%EmberScale.value = parameters.get("scale", 16.0)
		4:
			%PricklePow.value = parameters.get("pow", 2.0)
		5:
			%RedactedFrecuency.value = parameters.get("freq", 1.0)
			%RedactedScale.value = parameters.get("scale", 1.0)


func get_parameters(index: int) -> Dictionary:
	var parameters = {}
	parameters.length = %Length.value
	match index:
		0:
			parameters.fade_time = %DefaultFadeTime.value
		1:
			parameters.intensity = %BounceIntensity.value
		2:
			parameters.cursor = %ConsoleCursorText.text
			if %UseTextColor.is_pressed():
				parameters.use_text_color = true
			else:
				parameters.color = %ConsoleCursorColor.get_color()
		3:
			parameters.ember = %EmberText.text
			parameters.color = %EmberColor.get_color()
			parameters.scale = %EmberScale.value
		4:
			parameters.pow = %PricklePow.value
		5:
			parameters.freq = %RedactedFrecuency.value
			parameters.scale = %RedactedScale.value
		
	
	return parameters

func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	
	var config = {
		"scene_path": dialog_scene_file,
		"text_box_position": %TextBoxPosition.get_selected_id(),
		"text_box_margin_left": %TextBoxMarginLeft.value,
		"text_box_margin_right": %TextBoxMarginRight.value,
		"text_box_margin_top": %TextBoxMarginTop.value,
		"text_box_margin_bottom": %TextBoxMarginBottom.value,
		"font": font_selected,
		"text_color": %TextColor.get_color(),
		"text_size": %TextSize.value,
		"outline_size": %OutlineSize.value,
		"outline_color": %OutlineColor.get_color(),
		"shadow_offset": Vector2(%ShadowOffsetX.value, %ShadowOffsetY.value),
		"shadow_color": %ShadowColor.get_color(),
		"text_align": %TextAlign.get_selected_id(),
		"max_width": %MaxWidth.value,
		"max_lines": %MaxLines.value,
		"character_delay": %CharacterDelay.value,
		"dot_delay": %DotDelay.value,
		"comma_delay": %CommaDelay.value,
		"paragraph_delay": %ParagraphDelay.value,
		"skip_mode": %SkipMode.get_selected_id(),
		"skip_speed": %SkipSpeed.value,
		"start_animation": %StartAnimation.get_selected_id(),
		"start_animation_duration": %StartAnimationDuration.value,
		"start_animation_trans_type": %StartAnimationTransitionType.get_selected_id(),
		"start_animation_ease_type":%StartAnimationTransitionEase .get_selected_id(),
		"end_animation": %EndAnimation.get_selected_id(),
		"end_animation_duration": %EndAnimationDuration.value,
		"end_animation_trans_type": %EndAnimationTransitionType.get_selected_id(),
		"end_animation_ease_type":%EndAnimationTransitionEase .get_selected_id(),
		"text_transition": %TextTransition.get_selected_id(),
		"text_transition_parameters": get_parameters(%TextTransition.get_selected_id()),
		"fx_path": fx_file,
		"fx_volume": %Volume.value,
		"fx_pitch_min": %PitchMin.value,
		"fx_pitch_max": %PitchMax.value
	}
	
	commands[-1].parameters = config
	
	return commands


func _on_play_button_pressed() -> void:
	if ResourceLoader.exists(fx_file):
		propagate_call("apply")
		var node: AudioStreamPlayer = $AudioStreamPlayer
		node.stop()
		node.stream = load(fx_file)
		node.pitch_scale = randf_range(%PitchMin.value, %PitchMax.value)
		node.volume_db = %Volume.value
		node.play()


func _on_fx_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.auto_play_sounds = true
	dialog.target_callable = _update_sound
	dialog.set_file_selected(fx_file)
	dialog.set_dialog_mode(0)
	
	dialog.fill_files("sounds")


func _update_sound(path: String) -> void:
	fx_file = path
	%FX.text = fx_file.get_file()


func _on_fx_middle_click_pressed() -> void:
	fx_file = ""
	%FX.text = TranslationManager.tr("Select Audio File")


func _on_dialog_scene_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _update_dialog_file
	dialog.set_file_selected(dialog_scene_file)
	dialog.set_dialog_mode(0)

	dialog.fill_files("message_dialogs")


func _update_dialog_file(path: String) -> void:
	dialog_scene_file = path
	%DialogScene.text = dialog_scene_file.get_file()


func _on_skip_mode_item_selected(index: int) -> void:
	%SkipSpeed.set_disabled(index != 3)


func _on_text_transition_item_selected(index: int) -> void:
	if index == 0:
		%TextTransitionvalueExtra.visible = false
		%DefaultParameters.visible = true
	else:
		%TextTransitionvalueExtra.visible = true
		%DefaultParameters.visible = false
		var nodes = [%Bounce, %Console, %Ember, %Prickle, %Redacted]
		for node in nodes:
			node.visible = false
		match index:
			1: %Bounce.visible = true
			2: %Console.visible = true
			3: %Ember.visible = true
			4: %Prickle.visible = true
			5: %Redacted.visible = true
		
		var length = lenght_cache[["", "Bounce", "Console", "Embers", "Prickle", "Redacted", "WFC", "Word"][index]]
		%Length.value = length
		
	size = Vector2i.ZERO


func open_color_dialog(color: Color, target_id: int):
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Transition Color")
	dialog.color_selected.connect(_color_dialog_color_selected.bind(target_id))
	dialog.set_color(color)


func _color_dialog_color_selected(color: Color, target_id: int) -> void:
	if target_id == 0:
		%ConsoleCursorColor.set_color(color)
	elif target_id == 1:
		%EmberColor.set_color(color)
	elif target_id == 2:
		%TextColor.set_color(color)
	elif target_id == 3:
		%OutlineColor.set_color(color)
	elif target_id == 4:
		%ShadowColor.set_color(color)


func _on_console_cursor_color_pressed() -> void:
	open_color_dialog(%ConsoleCursorColor.get_color(), 0)


func _on_ember_color_pressed() -> void:
	open_color_dialog(%EmberColor.get_color(), 1)


func _on_text_color_pressed() -> void:
	open_color_dialog(%TextColor.get_color(), 2)


func _on_length_value_changed(value: float) -> void:
	var index = %TextTransition.get_selected_id()
	if index > 0:
		lenght_cache[["", "Bounce", "Console", "Embers", "Prickle", "Redacted", "WFC", "Word"][index]] = value


func _on_font_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _on_font_selected
	dialog.set_dialog_mode(0)
	
	if font_selected:
		dialog.set_file_selected(font_selected)
	
	dialog.fill_files("fonts")


func _on_font_selected(path: String) -> void:
	if path:
		font_selected = path
		%Font.text = font_selected.get_file()


func get_dummy_text() -> String:
	var text = "Start transmission:
This is a sample message for preview purposes.
This is the comma delay, and this is de dot delay.
End transmission"
	
	return text


func _on_preview_config_pressed(perform_apply: bool = true) -> void:
	if perform_apply: propagate_call("apply")
	if !preview_message_dialog:
		showing_preview_window = true
		var path = "res://addons/CustomControls/Dialogs/message_preview_dialog.tscn"
		preview_message_dialog = load(path).instantiate()
		preview_message_dialog.tree_exited.connect(
			func():
				preview_message_dialog = null
				showing_preview_window = false
		)
		preview_message_dialog.mouse_entered.connect(
			func():
				preview_message_dialog.grab_focus()
		)
		preview_message_dialog.visible = false
		add_child(preview_message_dialog)
		if not preview_message_dialog.visible:
			preview_message_dialog.show()
		await get_tree().process_frame
		await get_tree().process_frame
		preview_message_dialog.position = position - Vector2i(preview_message_dialog.size.x, 0)
		preview_message_dialog.position.x = max(10, preview_message_dialog.position.x)
	else:
		await get_tree().process_frame
		preview_message_dialog.hide()
		preview_message_dialog.show()
	
	var config = build_command_list()[0].parameters
	preview_message_dialog.set_main_config(config)
	await get_tree().process_frame
	preview_message_dialog.set_text(get_dummy_text(), {})


func _on_timer_timeout() -> void:
	if preview_message_dialog and DisplayServer.window_is_focused(get_window_id()):
		var config = build_command_list()[0].parameters
		if last_config != config:
			last_config = config
			preview_message_dialog.set_main_config(config)
			await get_tree().process_frame
			preview_message_dialog.set_text(get_dummy_text(), {})


func _on_copy_parameters_pressed() -> void:
	var config = build_command_list()[0].parameters
	StaticEditorVars.CLIPBOARD.message_config = config
	%PasteParameters.set_disabled(false)


func _on_paste_parameters_pressed() -> void:
	if StaticEditorVars.CLIPBOARD.has("message_config"):
		set_config(StaticEditorVars.CLIPBOARD.message_config)


func _on_outline_color_pressed() -> void:
	open_color_dialog(%OutlineColor.get_color(), 3)


func _on_shadow_color_pressed() -> void:
	open_color_dialog(%ShadowColor.get_color(), 4)


func _on_load_preset(data: Variant) -> void:
	set_config(data)


func _on_save_preset(options: Dictionary, target_key: String) -> void:
	var current_config = build_command_list()[-1].parameters
	options[target_key] = current_config
