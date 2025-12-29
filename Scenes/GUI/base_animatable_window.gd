@tool
class_name BaseAnimatableWindow
extends Control

signal animation_in_finished
signal animation_out_finished
signal started()
signal end()
signal early_tree_exited()
signal starting_end()


@export_group("Testing")
@export var test_animate_in: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			animate_in()
@export var test_animate_out: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			animate_out()

@export_group("Behavior Settings")
@export var scene_title: String = "" : set = _set_scene_title
@export var no_destroy_on_hide: bool = false
@export var timer_to_emit_started_signal: float = 0.0
@export var timer_to_emit_end_signal: float = 0.0

@export_group("Movement In")
@export var move_in_enabled: bool = true:
	set(value):
		move_in_enabled = value
		notify_property_list_changed()
@export_enum("Top", "Bottom", "Left", "Right", "Top Left", "Top Right", "Bottom Left", "Bottom Right") var move_in_direction: int = 0
@export var move_in_ease_type: Tween.EaseType = Tween.EASE_OUT
@export var move_in_trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var move_in_duration: float = 0.5
@export var move_in_initial_delay: float = 0.0

@export_group("Movement Out")
@export var move_out_enabled: bool = true:
	set(value):
		move_out_enabled = value
		notify_property_list_changed()
@export var move_out_reverse_mode: bool = false:
	set(value):
		move_out_reverse_mode = value
		notify_property_list_changed()
@export_enum("Top", "Bottom", "Left", "Right", "Top Left", "Top Right", "Bottom Left", "Bottom Right") var move_out_direction: int = 0
@export var move_out_ease_type: Tween.EaseType = Tween.EASE_OUT
@export var move_out_trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var move_out_duration: float = 0.5
@export var move_out_initial_delay: float = 0.0

@export_group("Zoom In")
@export var zoom_in_enabled: bool = true:
	set(value):
		zoom_in_enabled = value
		notify_property_list_changed()
@export var zoom_in_start: float = 0.0
@export var zoom_in_end: float = 1.0
@export var zoom_in_ease_type: Tween.EaseType = Tween.EASE_OUT
@export var zoom_in_trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var zoom_in_duration: float = 0.5
@export var zoom_in_initial_delay: float = 0.0

@export_group("Zoom Out")
@export var zoom_out_enabled: bool = true:
	set(value):
		zoom_out_enabled = value
		notify_property_list_changed()
@export var zoom_out_reverse_mode: bool = false:
	set(value):
		zoom_out_reverse_mode = value
		notify_property_list_changed()
@export var zoom_out_start: float = 1.0
@export var zoom_out_end: float = 0.0
@export var zoom_out_ease_type: Tween.EaseType = Tween.EASE_OUT
@export var zoom_out_trans_type: Tween.TransitionType = Tween.TRANS_BACK
@export var zoom_out_duration: float = 0.5
@export var zoom_out_initial_delay: float = 0.0

@export_group("Fade In")
@export var fade_in_enabled: bool = true:
	set(value):
		fade_in_enabled = value
		notify_property_list_changed()
@export var fade_in_ease_type: Tween.EaseType = Tween.EASE_OUT
@export var fade_in_trans_type: Tween.TransitionType = Tween.TRANS_QUAD
@export var fade_in_duration: float = 0.5
@export var fade_in_initial_delay: float = 0.0

@export_group("Fade Out")
@export var fade_out_enabled: bool = true:
	set(value):
		fade_out_enabled = value
		notify_property_list_changed()
@export var fade_out_reverse_mode: bool = false:
	set(value):
		fade_out_reverse_mode = value
		notify_property_list_changed()
@export var fade_out_ease_type: Tween.EaseType = Tween.EASE_OUT
@export var fade_out_trans_type: Tween.TransitionType = Tween.TRANS_QUAD
@export var fade_out_duration: float = 0.5
@export var fade_out_initial_delay: float = 0.0

@export_group("Shake In")
@export var shake_in_enabled: bool = false:
	set(value):
		shake_in_enabled = value
		notify_property_list_changed()
@export var shake_in_intensity: float = 10.0
@export var shake_in_frequency: float = 20.0
@export var shake_in_duration: float = 0.5
@export var shake_in_initial_delay: float = 0.0

@export_group("Shake Out")
@export var shake_out_enabled: bool = false:
	set(value):
		shake_out_enabled = value
		notify_property_list_changed()
@export var shake_out_reverse_mode: bool = false:
	set(value):
		shake_out_reverse_mode = value
		notify_property_list_changed()
@export var shake_out_intensity: float = 10.0
@export var shake_out_frequency: float = 20.0
@export var shake_out_duration: float = 0.5
@export var shake_out_initial_delay: float = 0.0

@export_group("Animation")
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


func _ready() -> void:
	GameManager.set_text_config(self, true)
	
	_original_position = position
	pivot_offset = size / 2
	
	if not Engine.is_editor_hint() and auto_play_on_start:
		animate_in()


func _set_scene_title(value: String) -> void:
	scene_title = value
	if is_node_ready():
		%TitleContainer.title = value


func get_main_scene() -> Node:
	if %MainSceneContainer.get_child_count() > 0:
		return %MainSceneContainer.get_child(0)
	
	return null


func start() -> void:
	running_starting_animation = false
	animate_in()


func emit_signal_end() -> void:
	end.emit()


func emit_signal_start() -> void:
	started.emit()


func emit_signal_early_tree_exited() -> void:
	early_tree_exited.emit()


func emit_signal_starting_end() -> void:
	starting_end.emit()


func _apply_shake_offset() -> void:
	position = _base_position + _shake_offset

func _validate_property(property: Dictionary) -> void:
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

func _update_base_position(new_pos: Vector2) -> void:
	_base_position = new_pos

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


func destroy() -> void:
	animate_out()
