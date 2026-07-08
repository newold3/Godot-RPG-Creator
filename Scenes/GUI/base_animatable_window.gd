@tool
class_name BaseAnimatableWindow
extends Control


## Signal emitted when the in animation finishes
signal animation_in_finished
## Signal emitted when the out animation finishes
signal animation_out_finished
## Signal emitted when the starting process begins
signal started()
## Signal emitted when the process ends
signal end()
## Signal emitted if the tree is exited early
signal early_tree_exited()
## Signal emitted when the starting sequence ends
signal starting_end()


@export_group("Presets Management")
## Type the name of the new preset to save
@export var new_preset_name: String = ""
## Triggers the saving of the current configuration as a new preset
@export var save_preset: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_save_current_preset()
## Select a saved preset from the user folder
@export var selected_preset: String = ""
## Triggers the application of the selected preset
@export var apply_preset: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_apply_selected_preset()
## Check this box to confirm deletion before clicking Delete Preset
@export var confirm_delete: bool = false
## Triggers the deletion of the selected preset, requires confirm_delete to be true
@export var delete_preset: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			if confirm_delete:
				_delete_selected_preset()
				confirm_delete = false
			else:
				printerr("Please check 'Confirm Delete' before deleting a preset.")

@export_group("Testing")
## Toggles the animate in test from the editor
@export var test_animate_in: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			animate_in()
## Toggles the animate out test from the editor
@export var test_animate_out: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			animate_out()

@export_group("Behavior Settings")
## The title of the scene to display
@export var scene_title: String = "" : set = _set_scene_title
## Prevents the window from being destroyed on hide
@export var no_destroy_on_hide: bool = false
## Delay before emitting the started signal
@export var timer_to_emit_started_signal: float = 0.0
## Delay before emitting the end signal
@export var timer_to_emit_end_signal: float = 0.0

@export_group("Movement In")
## Enables the movement in animation
@export var move_in_enabled: bool = true:
	set(value):
		move_in_enabled = value
		notify_property_list_changed()
## Direction from which the window moves in
@export_enum("Top", "Bottom", "Left", "Right", "Top Left", "Top Right", "Bottom Left", "Bottom Right") var move_in_direction: int = 0
## Easing type for the movement in animation
@export var move_in_ease_type: Tween.EaseType = Tween.EASE_OUT
## Transition type for the movement in animation
@export var move_in_trans_type: Tween.TransitionType = Tween.TRANS_BACK
## Duration of the movement in animation
@export var move_in_duration: float = 0.5
## Initial delay before the movement in animation starts
@export var move_in_initial_delay: float = 0.0

@export_group("Movement Out")
## Enables the movement out animation
@export var move_out_enabled: bool = true:
	set(value):
		move_out_enabled = value
		notify_property_list_changed()
## Reverses the movement in animation values for moving out
@export var move_out_reverse_mode: bool = false:
	set(value):
		move_out_reverse_mode = value
		notify_property_list_changed()
## Direction to which the window moves out
@export_enum("Top", "Bottom", "Left", "Right", "Top Left", "Top Right", "Bottom Left", "Bottom Right") var move_out_direction: int = 0
## Easing type for the movement out animation
@export var move_out_ease_type: Tween.EaseType = Tween.EASE_OUT
## Transition type for the movement out animation
@export var move_out_trans_type: Tween.TransitionType = Tween.TRANS_BACK
## Duration of the movement out animation
@export var move_out_duration: float = 0.5
## Initial delay before the movement out animation starts
@export var move_out_initial_delay: float = 0.0

@export_group("Zoom In")
## Enables the zoom in animation
@export var zoom_in_enabled: bool = true:
	set(value):
		zoom_in_enabled = value
		notify_property_list_changed()
## Starting scale for the zoom in animation
@export var zoom_in_start: float = 0.0
## Ending scale for the zoom in animation
@export var zoom_in_end: float = 1.0
## Easing type for the zoom in animation
@export var zoom_in_ease_type: Tween.EaseType = Tween.EASE_OUT
## Transition type for the zoom in animation
@export var zoom_in_trans_type: Tween.TransitionType = Tween.TRANS_BACK
## Duration of the zoom in animation
@export var zoom_in_duration: float = 0.5
## Initial delay before the zoom in animation starts
@export var zoom_in_initial_delay: float = 0.0

@export_group("Zoom Out")
## Enables the zoom out animation
@export var zoom_out_enabled: bool = true:
	set(value):
		zoom_out_enabled = value
		notify_property_list_changed()
## Reverses the zoom in animation values for zooming out
@export var zoom_out_reverse_mode: bool = false:
	set(value):
		zoom_out_reverse_mode = value
		notify_property_list_changed()
## Starting scale for the zoom out animation
@export var zoom_out_start: float = 1.0
## Ending scale for the zoom out animation
@export var zoom_out_end: float = 0.0
## Easing type for the zoom out animation
@export var zoom_out_ease_type: Tween.EaseType = Tween.EASE_OUT
## Transition type for the zoom out animation
@export var zoom_out_trans_type: Tween.TransitionType = Tween.TRANS_BACK
## Duration of the zoom out animation
@export var zoom_out_duration: float = 0.5
## Initial delay before the zoom out animation starts
@export var zoom_out_initial_delay: float = 0.0

@export_group("Fade In")
## Enables the fade in animation
@export var fade_in_enabled: bool = true:
	set(value):
		fade_in_enabled = value
		notify_property_list_changed()
## Easing type for the fade in animation
@export var fade_in_ease_type: Tween.EaseType = Tween.EASE_OUT
## Transition type for the fade in animation
@export var fade_in_trans_type: Tween.TransitionType = Tween.TRANS_QUAD
## Duration of the fade in animation
@export var fade_in_duration: float = 0.5
## Initial delay before the fade in animation starts
@export var fade_in_initial_delay: float = 0.0

@export_group("Fade Out")
## Enables the fade out animation
@export var fade_out_enabled: bool = true:
	set(value):
		fade_out_enabled = value
		notify_property_list_changed()
## Reverses the fade in animation values for fading out
@export var fade_out_reverse_mode: bool = false:
	set(value):
		fade_out_reverse_mode = value
		notify_property_list_changed()
## Easing type for the fade out animation
@export var fade_out_ease_type: Tween.EaseType = Tween.EASE_OUT
## Transition type for the fade out animation
@export var fade_out_trans_type: Tween.TransitionType = Tween.TRANS_QUAD
## Duration of the fade out animation
@export var fade_out_duration: float = 0.5
## Initial delay before the fade out animation starts
@export var fade_out_initial_delay: float = 0.0

@export_group("Shake In")
## Enables the shake in animation
@export var shake_in_enabled: bool = false:
	set(value):
		shake_in_enabled = value
		notify_property_list_changed()
## Intensity of the shake in animation
@export var shake_in_intensity: float = 10.0
## Frequency of the shake in animation
@export var shake_in_frequency: float = 20.0
## Duration of the shake in animation
@export var shake_in_duration: float = 0.5
## Initial delay before the shake in animation starts
@export var shake_in_initial_delay: float = 0.0

@export_group("Shake Out")
## Enables the shake out animation
@export var shake_out_enabled: bool = false:
	set(value):
		shake_out_enabled = value
		notify_property_list_changed()
## Reverses the shake in animation values for shaking out
@export var shake_out_reverse_mode: bool = false:
	set(value):
		shake_out_reverse_mode = value
		notify_property_list_changed()
## Intensity of the shake out animation
@export var shake_out_intensity: float = 10.0
## Frequency of the shake out animation
@export var shake_out_frequency: float = 20.0
## Duration of the shake out animation
@export var shake_out_duration: float = 0.5
## Initial delay before the shake out animation starts
@export var shake_out_initial_delay: float = 0.0

@export_group("Animation")
## Automatically plays the starting animation when ready
@export var auto_play_on_start: bool = false
## Initial delay before emitting the animation_in_finished signal
## (Leave at 0 to use the completion of the initial tween as the delay)
@export var ready_to_process_delay: float = 0.0

var _original_position: Vector2
var _tween: Tween
var _shake_offset: Vector2 = Vector2.ZERO
var _current_shake_intensity: float = 0.0
var _current_shake_frequency: float = 0.0
var _is_shaking: bool = false
var _base_position: Vector2 = Vector2.ZERO
var running_starting_animation: bool = false

var is_sub_menu = false
var exit_tree_when_end = false


#region Lifecycle & Engine
## Initializes the node and sets up initial configuration
func _ready() -> void:
	if not Engine.is_editor_hint():
		GameManager.set_text_config(self, true)
	
	_original_position = position
	pivot_offset = size / 2
	
	if not Engine.is_editor_hint() and auto_play_on_start:
		animate_in()


## Sets the scene title and updates the container if ready
func _set_scene_title(value: String) -> void:
	scene_title = value
	var main_scene = get_node_or_null("%TitleContainer")
	if main_scene:
		main_scene.title = value


## Retrieves the main scene from the container
func get_main_scene() -> Node:
	var main_scene = get_node_or_null("%MainSceneContainer")
	if main_scene and main_scene.get_child_count() > 0:
		return main_scene.get_child(0)
	
	return null
#endregion


#region Public Methods
## Starts the animate in process
func start() -> void:
	running_starting_animation = false
	animate_in()


## Destroys the window by playing the out animation
func destroy() -> void:
	animate_out()
#endregion


#region Signals
## Emits the end signal
func emit_signal_end() -> void:
	end.emit()


## Emits the started signal
func emit_signal_start() -> void:
	started.emit()


## Emits the early tree exited signal
func emit_signal_early_tree_exited() -> void:
	early_tree_exited.emit()


## Emits the starting end signal
func emit_signal_starting_end() -> void:
	starting_end.emit()
#endregion


#region Presets Management
## Returns the dictionary containing all saved presets
func _get_all_presets() -> Dictionary:
	if not FileAccess.file_exists("user://window_presets.json"):
		return {}

	var file = FileAccess.open("user://window_presets.json", FileAccess.READ)
	var content = file.get_as_text()
	var data = JSON.parse_string(content)

	if typeof(data) == TYPE_DICTIONARY:
		return data

	return {}


## Saves the current variable configuration as a new preset
func _save_current_preset() -> void:
	if new_preset_name.strip_edges() == "":
		printerr("Preset name cannot be empty.")
		return

	var presets = _get_all_presets()
	var current_data = {}

	for prop in get_property_list():
		var p_name = prop["name"]
		if p_name.begins_with("move_") or p_name.begins_with("zoom_") or p_name.begins_with("fade_") or p_name.begins_with("shake_") or p_name in ["auto_play_on_start", "ready_to_process_delay", "no_destroy_on_hide", "timer_to_emit_started_signal", "timer_to_emit_end_signal"]:
			current_data[p_name] = get(p_name)

	presets[new_preset_name] = current_data

	var file = FileAccess.open("user://window_presets.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(presets, "\t"))

	new_preset_name = ""
	notify_property_list_changed()


## Applies the currently selected preset properties
func _apply_selected_preset() -> void:
	var presets = _get_all_presets()

	if presets.has(selected_preset):
		var data = presets[selected_preset]
		for key in data.keys():
			set(key, data[key])
		notify_property_list_changed()


## Deletes the selected preset from the saved configuration
func _delete_selected_preset() -> void:
	if selected_preset == "":
		return

	var presets = _get_all_presets()

	if presets.has(selected_preset):
		presets.erase(selected_preset)
		
		var file = FileAccess.open("user://window_presets.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(presets, "\t"))
		
		selected_preset = ""
		notify_property_list_changed()
#endregion


#region Property Validation
## Validates and modifies properties in the inspector dynamically
func _validate_property(property: Dictionary) -> void:
	if property.name == "selected_preset":
		property.hint = PROPERTY_HINT_ENUM
		var presets = _get_all_presets()
		if presets.size() > 0:
			property.hint_string = ",".join(PackedStringArray(presets.keys()))
		else:
			property.hint_string = "No Presets Saved"
		return

	var property_name = property.name

	var move_in_members = [
		"move_in_direction",
		"move_in_ease_type",
		"move_in_trans_type",
		"move_in_duration",
		"move_in_initial_delay"
	]
	
	if property_name in move_in_members:
		if not move_in_enabled:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	var zoom_in_members = [
		"zoom_in_start",
		"zoom_in_end",
		"zoom_in_ease_type",
		"zoom_in_trans_type",
		"zoom_in_duration",
		"zoom_in_initial_delay"
	]
	
	if property_name in zoom_in_members:
		if not zoom_in_enabled:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	var fade_in_members = [
		"fade_in_ease_type",
		"fade_in_trans_type",
		"fade_in_duration",
		"fade_in_initial_delay"
	]
	
	if property_name in fade_in_members:
		if not fade_in_enabled:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	var shake_in_members = [
		"shake_in_intensity",
		"shake_in_frequency",
		"shake_in_duration",
		"shake_in_initial_delay"
	]
	
	if property_name in shake_in_members:
		if not shake_in_enabled:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	var move_out_members = [
		"move_out_reverse_mode",
		"move_out_direction",
		"move_out_ease_type",
		"move_out_trans_type",
		"move_out_duration",
		"move_out_initial_delay"
	]
	
	if property_name in move_out_members:
		if not move_out_enabled:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property_name == "move_out_reverse_mode":
				pass
			elif move_out_reverse_mode:
				property.usage = PROPERTY_USAGE_NO_EDITOR

	var zoom_out_members = [
		"zoom_out_reverse_mode",
		"zoom_out_start",
		"zoom_out_end",
		"zoom_out_ease_type",
		"zoom_out_trans_type",
		"zoom_out_duration",
		"zoom_out_initial_delay"
	]
	
	if property_name in zoom_out_members:
		if not zoom_out_enabled:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property_name == "zoom_out_reverse_mode":
				pass
			elif zoom_out_reverse_mode:
				property.usage = PROPERTY_USAGE_NO_EDITOR

	var fade_out_members = [
		"fade_out_reverse_mode",
		"fade_out_ease_type",
		"fade_out_trans_type",
		"fade_out_duration",
		"fade_out_initial_delay"
	]
	
	if property_name in fade_out_members:
		if not fade_out_enabled:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property_name == "fade_out_reverse_mode":
				pass
			elif fade_out_reverse_mode:
				property.usage = PROPERTY_USAGE_NO_EDITOR

	var shake_out_members = [
		"shake_out_reverse_mode",
		"shake_out_intensity",
		"shake_out_frequency",
		"shake_out_duration",
		"shake_out_initial_delay"
	]
	
	if property_name in shake_out_members:
		if not shake_out_enabled:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			if property_name == "shake_out_reverse_mode":
				pass
			elif shake_out_reverse_mode:
				property.usage = PROPERTY_USAGE_NO_EDITOR
#endregion


#region Animation Internals
## Calculates the offset position based on the given direction
func _get_offset_position(direction: int) -> Vector2:
	var viewport_size = get_viewport_rect().size
	var offset = Vector2.ZERO
	
	match direction:
		0:
			offset = Vector2(0, -viewport_size.y - size.y)
		1:
			offset = Vector2(0, viewport_size.y)
		2:
			offset = Vector2(-viewport_size.x - size.x, 0)
		3:
			offset = Vector2(viewport_size.x, 0)
		4:
			offset = Vector2(-viewport_size.x - size.x, -viewport_size.y - size.y)
		5:
			offset = Vector2(viewport_size.x, -viewport_size.y - size.y)
		6:
			offset = Vector2(-viewport_size.x - size.x, viewport_size.y)
		7:
			offset = Vector2(viewport_size.x, viewport_size.y)
			
	return _original_position + offset


## Updates the base position variable
func _update_base_position(new_pos: Vector2) -> void:
	_base_position = new_pos


## Applies the shake offset based on the current progress
func _apply_shake_progress(progress: float) -> void:
	if progress >= 1.0:
		_shake_offset = Vector2.ZERO
		_is_shaking = false
		return

	var shake_amount = _current_shake_intensity * (1.0 - progress)
	var time_factor = progress * _current_shake_frequency * TAU

	_shake_offset = Vector2(
		sin(time_factor) * randf_range(-shake_amount, shake_amount),
		cos(time_factor * 1.3) * randf_range(-shake_amount, shake_amount)
	)

	_apply_shake_offset()


## Applies the calculated shake offset to the window
func _apply_shake_offset() -> void:
	position = _base_position + _shake_offset
#endregion


#region Animations
## Plays the initialization animation for the window
func animate_in() -> void:
	if _tween:
		_tween.kill()
	
	if timer_to_emit_started_signal > 0.0:
		var t = create_tween()
		t.tween_interval(timer_to_emit_started_signal)
		t.tween_callback(emit_signal_start)

	_shake_offset = Vector2.ZERO
	_is_shaking = false
	running_starting_animation = true

	_tween = create_tween()
	_tween.set_parallel(true)

	if move_in_enabled:
		var start_pos = _get_offset_position(move_in_direction)
		var end_pos = _original_position
		position = start_pos
		_base_position = start_pos

		_tween.tween_property(self, "position", end_pos, move_in_duration)\
			.set_ease(move_in_ease_type)\
			.set_trans(move_in_trans_type)\
			.set_delay(move_in_initial_delay)

		_tween.parallel().tween_method(_update_base_position, start_pos, end_pos, move_in_duration)\
			.set_ease(move_in_ease_type)\
			.set_trans(move_in_trans_type)\
			.set_delay(move_in_initial_delay)
	else:
		_base_position = position

	if zoom_in_enabled:
		scale = Vector2(zoom_in_start, zoom_in_start)
		_tween.tween_property(self, "scale", Vector2(zoom_in_end, zoom_in_end), zoom_in_duration)\
			.set_ease(zoom_in_ease_type)\
			.set_trans(zoom_in_trans_type)\
			.set_delay(zoom_in_initial_delay)

	if fade_in_enabled:
		modulate.a = 0.0
		_tween.tween_property(self, "modulate:a", 1.0, fade_in_duration)\
			.set_ease(fade_in_ease_type)\
			.set_trans(fade_in_trans_type)\
			.set_delay(fade_in_initial_delay)

	if shake_in_enabled:
		_current_shake_intensity = shake_in_intensity
		_current_shake_frequency = shake_in_frequency
		_is_shaking = true
		_tween.tween_method(_apply_shake_progress, 0.0, 1.0, shake_in_duration)\
			.set_delay(shake_in_initial_delay)

	if ready_to_process_delay > 0.0:
		_tween.tween_callback(
			func():
				if not Engine.is_editor_hint():
					animation_in_finished.emit()
		).set_delay(ready_to_process_delay)
	
	_tween.tween_interval(0.0001)
	_tween.set_parallel(false)
	_tween.tween_callback(
		func():
			_shake_offset = Vector2.ZERO
			_is_shaking = false
			running_starting_animation = false
			if not Engine.is_editor_hint() and not ready_to_process_delay > 0.0:
				animation_in_finished.emit()
	)


## Plays the exiting animation for the window
func animate_out() -> void:
	if _tween:
		_tween.kill()
	
	if timer_to_emit_end_signal > 0.0:
		var t = create_tween()
		t.tween_interval(timer_to_emit_end_signal)
		t.tween_callback(emit_signal_end)
		
	_shake_offset = Vector2.ZERO
	_is_shaking = false

	_tween = create_tween()
	_tween.set_parallel(true)

	if move_out_enabled:
		var direction = move_in_direction if move_out_reverse_mode else move_out_direction
		var ease_type = move_in_ease_type if move_out_reverse_mode else move_out_ease_type
		var trans = move_in_trans_type if move_out_reverse_mode else move_out_trans_type
		var duration = move_in_duration if move_out_reverse_mode else move_out_duration
		var delay = move_in_initial_delay if move_out_reverse_mode else move_out_initial_delay

		var start_pos = position
		var end_pos = _get_offset_position(direction)
		_base_position = start_pos

		_tween.tween_property(self, "position", end_pos, duration)\
			.set_ease(ease_type)\
			.set_trans(trans)\
			.set_delay(delay)

		_tween.parallel().tween_method(_update_base_position, start_pos, end_pos, duration)\
			.set_ease(ease_type)\
			.set_trans(trans)\
			.set_delay(delay)
	else:
		_base_position = position

	if zoom_out_enabled:
		var end_scale = zoom_in_start if zoom_out_reverse_mode else zoom_out_end
		var ease_type = zoom_in_ease_type if zoom_out_reverse_mode else zoom_out_ease_type
		var trans = zoom_in_trans_type if zoom_out_reverse_mode else zoom_out_trans_type
		var duration = zoom_in_duration if zoom_out_reverse_mode else zoom_out_duration
		var delay = zoom_in_initial_delay if zoom_out_reverse_mode else zoom_out_initial_delay

		_tween.tween_property(self, "scale", Vector2(end_scale, end_scale), duration)\
			.set_ease(ease_type)\
			.set_trans(trans)\
			.set_delay(delay)

	if fade_out_enabled:
		var ease_type = fade_in_ease_type if fade_out_reverse_mode else fade_out_ease_type
		var trans = fade_in_trans_type if fade_out_reverse_mode else fade_out_trans_type
		var duration = fade_in_duration if fade_out_reverse_mode else fade_out_duration
		var delay = fade_in_initial_delay if fade_out_reverse_mode else fade_out_initial_delay

		_tween.tween_property(self, "modulate:a", 0.0, duration)\
			.set_ease(ease_type)\
			.set_trans(trans)\
			.set_delay(delay)

	if shake_out_enabled:
		var intensity = shake_in_intensity if shake_out_reverse_mode else shake_out_intensity
		var frequency = shake_in_frequency if shake_out_reverse_mode else shake_out_frequency
		var duration = shake_in_duration if shake_out_reverse_mode else shake_out_duration
		var delay = shake_in_initial_delay if shake_out_reverse_mode else shake_out_initial_delay

		_current_shake_intensity = intensity
		_current_shake_frequency = frequency
		_is_shaking = true
		_tween.tween_method(_apply_shake_progress, 0.0, 1.0, duration)\
			.set_delay(delay)

	_tween.tween_interval(0.0001)
	_tween.set_parallel(false)
	_tween.tween_callback(
		func():
			_shake_offset = Vector2.ZERO
			_is_shaking = false
			if not Engine.is_editor_hint():
				animation_out_finished.emit()
				if not no_destroy_on_hide:
					queue_free()
				else:
					visible = false
					if timer_to_emit_end_signal <= 0.0:
						emit_signal_end()
	)
	
	emit_signal_starting_end()
#endregion
