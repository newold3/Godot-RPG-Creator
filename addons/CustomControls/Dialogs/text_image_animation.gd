@tool
extends Window

var busy: bool = true
var new_size: Vector2

signal effect_selected(effect: Dictionary)


func _ready() -> void:
	close_requested.connect(queue_free)
	connect_checkboxes(self)
	propagate_call("set_disabled", [true])
	for node in [
		%ImageType, %Duration, %Move, %Rotate, %Scale, %Transition, %Modulate,
		%OKButton, %CancelButton, %ID, %Shake, %WaitToFinish, %IdleAnimation, %FacePosition,
		%EaseType, %EaseTransition
	]:
		node.set_disabled(false)
	child_controls_changed()


func set_data(effect: Dictionary) -> void:
	var current_focus
	var busy = true
	if "image_type" in effect:
		effect.image_type = clamp(effect.image_type, 0, %ImageType.get_item_count() - 1)
		%ImageType.select(effect.image_type)
		%ImageType.item_selected.emit(effect.image_type)
	if "image_id" in effect:
		%ID.value = effect.image_id
		current_focus = %ID.get_line_edit()
	if "face_position" in effect:
		effect.face_position = clamp(effect.face_position, 0, %FacePosition.get_item_count() - 1)
		%FacePosition.select(effect.face_position)
	if "idle_animation" in effect:
		effect.idle_animation = clamp(effect.idle_animation, 0, %IdleAnimation.get_item_count() - 1)
		%IdleAnimation.select(effect.idle_animation)
	if "duration" in effect:
		%Duration.value = effect.duration
		current_focus = %Duration.get_line_edit()
	if "move_selected" in effect and effect.move_selected:
		%Move.set_pressed(true)
		if "move_x" in effect:
			current_focus = %MovementX.get_line_edit()
			%MovementX.value = effect.move_x
		if "move_y" in effect: %MovementY.value = effect.move_y
		
	if "rotate_selected" in effect and effect.rotate_selected:
		%Rotate.set_pressed(true)
		if "rotation" in effect:
			%Rotation.value = effect.rotation
			current_focus = %Rotation.get_line_edit()
	if "scale_selected" in effect and effect.scale_selected:
		%Scale.set_pressed(true)
		if "zoom" in effect:
			%Zoom.value = effect.zoom
			current_focus = %Zoom.get_line_edit()
	if "transition_selected" in effect and effect.transition_selected:
		%Transition.set_pressed(true)
		if "transition_type" in effect:
			effect.transition_type = clamp(effect.transition_type, 0, %TransitionType.get_item_count() - 1)
			%TransitionType.select(effect.transition_type)
	if "modulate_selected" in effect and effect.modulate_selected:
		%Modulate.set_pressed(true)
		if "modulate" in effect: %ImageModulate.set_color(effect.modulate)
	if "shake_selected" in effect and effect.shake_selected:
		%Shake.set_pressed(true)
		if "shake_amplitude" in effect:
			%ShakeAmplitude.value = effect.shake_amplitude
			current_focus = %ShakeAmplitude.get_line_edit()
		if "shake_frequency" in effect:
			%ShakeFrequency.value = effect.shake_frequency
	if "wait" in effect and effect.wait:
		%WaitToFinish.set_pressed(true)
	
	%EaseType.select(clamp(effect.get("ease_type", 0), 0, %EaseType.get_item_count() - 1))
	%EaseTransition.select(clamp(effect.get("ease_transition", 0), 0, %EaseTransition.get_item_count() - 1))
	
	busy = false
	
	if current_focus:
		await get_tree().process_frame
		current_focus.grab_focus()


func connect_checkboxes(node: Node) -> void:
	if node is CheckBox:
		node.toggled.connect(_on_checkbox_toggled.bind(node))
	
	for child in node.get_children():
		connect_checkboxes(child)


func _on_checkbox_toggled(toggled_on: bool, node: CheckBox) -> void:
	node.get_parent().propagate_call("set_disabled", [!toggled_on])
	node.set_disabled(false)


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	var effect = {
		"image_type": %ImageType.get_selected_id(),
		"image_id": %ID.value,
		"face_position": %FacePosition.get_selected_id(),
		"idle_animation": %IdleAnimation.get_selected_id(),
		"wait": %WaitToFinish.is_pressed(),
		"duration": %Duration.value,
		"move_selected": %Move.is_pressed(),
		"move_x": %MovementX.value,
		"move_y": %MovementY.value,
		"rotate_selected": %Rotate.is_pressed(),
		"rotation": %Rotation.value,
		"scale_selected": %Scale.is_pressed(),
		"zoom": %Zoom.value,
		"transition_selected": %Transition.is_pressed(),
		"transition_type": %TransitionType.get_selected_id(),
		"modulate_selected": %Modulate.is_pressed(),
		"modulate": %ImageModulate.get_color(),
		"shake_selected": %Shake.is_pressed(),
		"shake_amplitude": %ShakeAmplitude.value,
		"shake_frequency": %ShakeFrequency.value,
		"ease_type": %EaseType.get_selected_id(),
		"ease_transition": %EaseTransition.get_selected_id(),
	}
	if (
		effect.move_selected or effect.rotate_selected or effect.scale_selected or
		effect.transition_selected or effect.modulate_selected or
		effect.shake_selected or effect.image_type == 1
	):
		effect_selected.emit(effect)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_image_modulate_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Image Modulate")
	dialog.color_selected.connect(_on_image_modulate_selected)
	dialog.set_color(%ImageModulate.get_color())
	
	size.y = min_size.y


func _on_image_modulate_selected(color: Color) -> void:
	%ImageModulate.set_color(color)


func _on_image_type_item_selected(index: int) -> void:
	%ImageID.visible = index == 1
	%IdleAnimationContainer.visible = index == 1
	%TransitionContainer.visible = index == 1
	%FacePositionContainer.visible = index == 0
	size.y = min_size.y


func _on_move_toggled(toggled_on: bool) -> void:
	if busy: return
	if toggled_on:
		%MovementX.get_line_edit().grab_focus()


func _on_rotate_toggled(toggled_on: bool) -> void:
	if busy: return
	if toggled_on:
		%Rotation.get_line_edit().grab_focus()


func _on_scale_toggled(toggled_on: bool) -> void:
	if busy: return
	if toggled_on:
		%Zoom.get_line_edit().grab_focus()


func _on_shake_toggled(toggled_on: bool) -> void:
	if busy: return
	if toggled_on:
		%ShakeAmplitude.get_line_edit().grab_focus()


func _on_timer_timeout() -> void:
	if new_size and (size.x < new_size.x or size.y < new_size.y):
		size = Vector2(max(size.x, new_size.x), max(size.y, new_size.y))
		wrap_controls = true
		wrap_controls = false


func _on_margin_container_item_rect_changed() -> void:
	new_size = $MarginContainer.size


func _on_ease_type_item_selected(index: int) -> void:
	pass # Replace with function body.


func _on_trans_type_item_selected(index: int) -> void:
	pass # Replace with function body.
