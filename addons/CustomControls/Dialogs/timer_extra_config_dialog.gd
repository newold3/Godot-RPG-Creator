@tool
extends Window

var config: Dictionary

var font_base = "res://Assets/Fonts/Cinzel-Bold.ttf"
var text_gradient_base = "res://Scenes/TimerScenes/Resources/default_timer_text_gradient.tres"
var default_background = "res://Scenes/TimerScenes/Resources/default_background.tres"
var default_curve = "res://Scenes/TimerScenes/Resources/default_timer_curve.tres"

signal config_changed(config: Dictionary)


func _ready() -> void:
	close_requested.connect(queue_free)


func set_config(real_config: Dictionary) -> void:
	config = real_config.duplicate()
	
	%TitleAlign.select(config.get("title_align", 2))
	%TitleModulate.set_color(config.get("title_modulate", Color("#9da9d5")))
	%TitleModulateMix.value = config.get("title_modulate_mix_amount", 0.42)
	%TextFormat.text = config.get("timer_text_format", "HHh : MMm : SSs")
	%TimerPosition.select(config.get("position_index", 1))
	var custom_position = config.get("custom_position", Vector2.ZERO)
	%CustomPositionX.value = custom_position.x
	%CustomPositionY.value = custom_position.y
	var margin = config.get("margin", Vector2(20, 2))
	%HorizontalMargin.value = margin.x
	%VerticalMargin.value = margin.x
	%ShowBackground.set_pressed(config.get("show_background", true))
	_set_property(config.get("timer_background", default_background), "timer_background", %BackgroundImage)
	var background_size = config.get("background_size", Vector2(0, 0))
	%BackgroundWidth.value = background_size.x
	%BackgroundHeight.value = background_size.x
	_set_property(config.get("timer_font", font_base), "timer_font", %TimerFont)
	%TimerSize.value = config.get("timer_font_size", 48)
	%TitleSize.value = config.get("title_font_size", 32)
	%OutlineSize.value = config.get("outline_size", 8)
	%OutlineColor.set_color(config.get("outline_color", Color.BLACK))
	_set_property(config.get("text_gradient", text_gradient_base), "text_gradient", %TextGradient)
	_set_property(config.get("start_fx", ""), "start_fx", %StartFX)
	_set_property(config.get("timeout_fx", ""), "timeout_fx", %TimeoutFX)
	_set_property(config.get("warning_fx", ""), "warning_fx", %WarningFX)
	_set_property(config.get("tick_fx", ""), "tick_fx", %TickFX)
	%WarningStart.value = config.get("warning_start_time", 10)
	_set_property(config.get("warning_curve", default_curve), "warning_curve", %WarningCurve)
	%EnableBlink.set_pressed(config.get("enable_blink", true))
	%BlinkStart.value = config.get("blink_start_time", 10)
	_set_property(config.get("blink_curve", default_curve), "blink_curve", %BlinkCurve)


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	config_changed.emit(config)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _open_file_dialog() -> Window:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.set_dialog_mode(0)
	
	return dialog


func _select_file(selected_file: String, target_callable: Callable, fill: String, dialog_title: String = "Select Image") -> void:
	var dialog = await _open_file_dialog()
	
	dialog.title = dialog_title
	dialog.auto_play_sounds = (fill == "sounds")
	
	dialog.target_callable = target_callable
	dialog.set_file_selected(selected_file)
	
	dialog.fill_files(fill)


func _set_property(path: String, property: String, target: Node) -> void:
	config[property] = path
	
	if target:
		target.set_text(path.get_file().replace("." + path.get_extension(), ""))


func _on_title_align_item_selected(index: int) -> void:
	config.title_align = index


func _on_title_modulate_pressed() -> void:
	_show_color_dialog(%TitleModulate.get_color(), _update_color.bind("title_modulate", %TitleModulate))


func _on_title_modulate_mix_value_changed(value: float) -> void:
	config.title_modulate_mix_amount = value


func _on_text_format_text_changed(new_text: String) -> void:
	config.timer_text_format = new_text


func _on_timer_position_item_selected(index: int) -> void:
	config.position_index = index
	%CustomPositionX.set_disabled(index != 6)
	%CustomPositionY.set_disabled(index != 6)


func _on_custom_position_x_value_changed(value: float) -> void:
	config.custom_position = Vector2(value, %CustomPositionY.value)


func _on_custom_position_y_value_changed(value: float) -> void:
	config.custom_position = Vector2(%CustomPositionx.value, value)


func _on_horizontal_margin_value_changed(value: float) -> void:
	config.margin = Vector2(value, %VerticalMargin.value)


func _on_vertical_margin_value_changed(value: float) -> void:
	config.margin = Vector2(%HorizontalMargin.value, value)


func _on_show_background_toggled(toggled_on: bool) -> void:
	config.show_background = toggled_on
	%BackgroundImage.set_disabled(!toggled_on)
	%BackgroundWidth.set_disabled(!toggled_on)
	%BackgroundHeight.set_disabled(!toggled_on)


func _show_color_dialog(selected_color: Color, callable: Callable) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = tr("Select Color")

	dialog.color_selected.connect(callable)
	dialog.set_color(selected_color)


func _update_color(color: Color, key: String, target: Node) -> void:
	config[key] = color
	
	if target.has_method("set_color"):
		target.set_color(color)


func _on_background_image_pressed() -> void:
	_select_file(config.get("timer_background", ""), _set_property.bind("timer_background", %BackgroundImage), "images", tr("Select Timer Background"))


func _on_background_width_value_changed(value: float) -> void:
	config.background_size = Vector2(value, %BackgroundHeight.value)


func _on_background_height_value_changed(value: float) -> void:
	config.background_size = Vector2(%BackgroundWidth.value, value)


func _on_timer_font_pressed() -> void:
	_select_file(config.get("timer_font", ""), _set_property.bind("timer_font", %TimerFont), "fonts", tr("Select Font"))


func _on_timer_size_value_changed(value: float) -> void:
	config.timer_font_size = value


func _on_title_size_value_changed(value: float) -> void:
	config.title_font_size = value


func _on_outline_size_value_changed(value: float) -> void:
	config.outline_size = value


func _on_outline_color_pressed() -> void:
	_show_color_dialog(%OutlineColor.get_color(), _update_color.bind("outline_color", %OutlineColor))


func _on_text_gradient_pressed() -> void:
	_select_file(config.get("text_gradient", ""), _set_property.bind("text_gradient", %TextGradient), "images", tr("Select Timer Gradient"))


func _on_start_fx_pressed() -> void:
	_select_file(config.get("start_fx", ""), _set_property.bind("start_fx", %StartFX), "sounds", tr("Select Start Fx"))


func _on_timeout_fx_pressed() -> void:
	_select_file(config.get("timeout_fx", ""), _set_property.bind("timeout_fx", %TimeoutFX), "sounds", tr("Select Timeout Fx"))


func _on_warning_fx_pressed() -> void:
	_select_file(config.get("warning_fx", ""), _set_property.bind("warning_fx", %WarningFX), "sounds", tr("Select Warning Fx"))


func _on_tick_fx_pressed() -> void:
	_select_file(config.get("tick_fx", ""), _set_property.bind("tick_fx", %TickFX), "sounds", tr("Select tick Fx"))


func _on_warning_start_value_changed(value: float) -> void:
	config.warning_start_time = value


func _on_warning_curve_pressed() -> void:
	_select_file(config.get("warning_curve", ""), _set_property.bind("warning_curve", %WarningCurve), "curves", tr("Select Warning Curve"))


func _on_enable_blink_toggled(toggled_on: bool) -> void:
	config.enable_blink = toggled_on
	%BlinkStart.set_disabled(!toggled_on)
	%BlinkCurve.set_disabled(!toggled_on)


func _on_blink_start_value_changed(value: float) -> void:
	config.blink_start_time = value


func _on_blink_curve_pressed() -> void:
	_select_file(config.get("blink_curve", ""), _set_property.bind("blink_curve", %BlinkCurve), "curves", tr("Select Blink Gradient"))
