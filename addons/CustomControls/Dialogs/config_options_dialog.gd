@tool
extends Window

var font_selected: String


signal config_changed(config: Dictionary)


func _ready() -> void:
	close_requested.connect(queue_free)
	set_data({})


func set_data(config: Dictionary) -> void:
	font_selected = config.get("font", "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf")
	%Font.text = font_selected.get_file()
	%TextColor.set_color(config.get("text_color", Color.WHITE))
	
	%TextSize.value = config.get("text_size", 22)
	%TextAlign.select(max(0, min(config.get("text_align", 0), %TextAlign.get_item_count() - 1)))
	
	%OutlineSize.value = config.get("outline_size", 2)
	%OutlineColor.set_color(config.get("outline_color", Color.BLACK))
	
	var shadow_offset = config.get("shadow_offset", Vector2(2, 2))
	%ShadowOffsetX.value = shadow_offset.x
	%ShadowOffsetY.value = shadow_offset.y
	%ShadowColor.set_color(config.get("shadow_color", Color("#00000093")))
	
	var using_custom_config = config.get("use_message_config", true)

	%UseMessageConfig.set_pressed(using_custom_config)
	%UseMessageConfig.toggled.emit(using_custom_config)


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


func open_color_dialog(color: Color, target_id: int):
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Transition Color")
	dialog.color_selected.connect(_color_dialog_color_selected.bind(target_id))
	dialog.set_color(color)


func _color_dialog_color_selected(color: Color, target_id: int) -> void:
	if target_id == 0:
		%TextColor.set_color(color)
	elif target_id == 1:
		%OutlineColor.set_color(color)
	elif target_id == 2:
		%ShadowColor.set_color(color)


func _on_text_color_pressed() -> void:
	open_color_dialog(%TextColor.get_color(), 0)


func _on_outline_color_pressed() -> void:
	open_color_dialog(%OutlineColor.get_color(), 1)


func _on_shadow_color_pressed() -> void:
	open_color_dialog(%ShadowColor.get_color(), 2)


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	var config = {
		"use_message_config": %UseMessageConfig.is_pressed(),
		"font": font_selected,
		"text_color": %TextColor.get_color(),
		"text_size": %TextSize.value,
		"text_align": %TextAlign.get_selected_id(),
		"outline_size": %OutlineSize.value,
		"outline_color": %OutlineColor.get_color(),
		"shadow_offset": Vector2(%ShadowOffsetX.value, %ShadowOffsetY.value),
		"shadow_color": %ShadowColor.get_color()
	}
	
	config_changed.emit(config)
	
	queue_free()


func _on_cancel_button_button_down() -> void:
	queue_free()


func _on_use_message_config_toggled(toggled_on: bool) -> void:
	%SelfConfigContainer.propagate_call("set_disabled", [toggled_on])
