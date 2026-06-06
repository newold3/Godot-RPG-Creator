@tool
extends DialogBase


func set_initial_config(config: Dictionary) -> void:
	super(config)
	
	if is_floating:
		%BackgroundContainer.set("theme_override_constants/margin_left", 0)
		%BackgroundContainer.set("theme_override_constants/margin_top", 0)
		%BackgroundContainer.set("theme_override_constants/margin_right", 0)
		%BackgroundContainer.set("theme_override_constants/margin_bottom", 0)
		%DialogMainContainer.set("theme_override_constants/margin_left", 28)
		%DialogMainContainer.set("theme_override_constants/margin_top", 10)
		%DialogMainContainer.set("theme_override_constants/margin_right", 28)
		%DialogMainContainer.set("theme_override_constants/margin_bottom", 2)


func _ensure_message_container_meta() -> void:
	var node = %MessageContainer
	if not node.has_meta("original_margins"):
		node.set_meta(
			"original_margins",
			{
				"left": node.get("theme_override_constants/margin_left"),
				"right": node.get("theme_override_constants/margin_right"),
				"top": node.get("theme_override_constants/margin_top"),
				"bottom": node.get("theme_override_constants/margin_bottom"),
			}
		)

func _on_face_left_frame_visibility_changed() -> void:
	if Engine.is_editor_hint(): return
	
	_ensure_message_container_meta()
	var node = %MessageContainer
	var value = node.get_meta("original_margins").left
	node.set(
		"theme_override_constants/margin_left",
		value if %FaceLeftFrame.visible else 10
	)


func _on_face_right_frame_visibility_changed() -> void:
	if Engine.is_editor_hint(): return
	
	_ensure_message_container_meta()
	var node = %MessageContainer
	var value = node.get_meta("original_margins").right
	node.set(
		"theme_override_constants/margin_right",
		value if %FaceRightFrame.visible else 10
	)
