@tool
class_name RPGMapInspectorPlugin
extends EditorInspectorPlugin


## Checks if this inspector plugin should handle the selected object.
func _can_handle(object: Object) -> bool:
	return object is RPGMap


## Intercepts editor field button properties to render them full-width.
func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if not object is RPGMap:
		return false
		
	if name == "reset_editor_fields":
		var container = MarginContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_theme_constant_override("margin_left", 4)
		container.add_theme_constant_override("margin_right", 4)
		container.add_theme_constant_override("margin_top", 2)
		container.add_theme_constant_override("margin_bottom", 2)
		
		var btn = Button.new()
		btn.text = "Reset to Default"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 28)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var base = EditorInterface.get_base_control()
		if base and base.has_theme_icon("Reload", "EditorIcons"):
			btn.icon = base.get_theme_icon("Reload", "EditorIcons")
			
		btn.pressed.connect(func():
			if is_instance_valid(object) and object.has_method("reset_editor_fields_to_defaults"):
				object.reset_editor_fields_to_defaults()
		)
		
		container.add_child(btn)
		add_custom_control(container)
		return true
		
	if name == "copy_map_id_into_clipboard":
		var container = MarginContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_theme_constant_override("margin_left", 4)
		container.add_theme_constant_override("margin_right", 4)
		container.add_theme_constant_override("margin_top", 2)
		container.add_theme_constant_override("margin_bottom", 2)
		
		var btn = Button.new()
		btn.text = "Copy Map ID"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 28)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var base = EditorInterface.get_base_control()
		if base and base.has_theme_icon("ActionCopy", "EditorIcons"):
			btn.icon = base.get_theme_icon("ActionCopy", "EditorIcons")
			
		btn.pressed.connect(func():
			if is_instance_valid(object) and object.has_method("_copy_map_id_to_clipboard"):
				object._copy_map_id_to_clipboard()
		)
		
		container.add_child(btn)
		add_custom_control(container)
		return true
		
	return false
