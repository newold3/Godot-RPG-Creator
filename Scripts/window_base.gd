class_name WindowBase
extends Control

enum StartAnimations {
	FADE_IN,
	SCALE_UP,
	FADE_IN_SCALE,
	MOVE_FROM_RIGHT,
	MOVE_FROM_LEFT,
	MOVE_FROM_TOP,
	MOVE_FROM_BOTTOM,
	INSTANT
}

enum EndAnimations {
	FADE_OUT,
	SCALE_DOWN,
	FADE_OUT_SCALE,
	MOVE_TO_RIGHT,
	MOVE_TO_LEFT,
	MOVE_TO_TOP,
	MOVE_TO_BOTTOM,
	INSTANT
}

class AnimationData:
	var target_node: Node
	var property: String
	var initial_value: Variant
	var final_value: Variant
	var duration: float
	var delay: float
	var trans_ease: Tween.EaseType
	var trans_type: Tween.TransitionType

	func _init(
		p_target_node: Node,
		p_property: String,
		p_initial_value: Variant,
		p_final_value: Variant,
		p_duration: float,
		p_delay: float = 0.0,
		p_trans_ease: Tween.EaseType = Tween.EaseType.EASE_OUT,
		p_trans_type: Tween.TransitionType = Tween.TransitionType.TRANS_CIRC
	):
		target_node = p_target_node
		property = p_property
		initial_value = p_initial_value
		final_value = p_final_value
		duration = p_duration
		delay = p_delay
		trans_ease = p_trans_ease
		trans_type = p_trans_type
	
	func _to_string() -> String:
		return str({
			target_node = target_node,
			property = property,
			initial_value = initial_value,
			final_value = final_value,
			duration = duration,
			delay = delay,
			trans_ease = trans_ease,
			trans_type = trans_type
		})

@export var start_animation: StartAnimations = StartAnimations.FADE_IN_SCALE
@export var end_animation: EndAnimations = EndAnimations.FADE_OUT_SCALE

@export var start_animation_time: float = 0.6
@export var end_animation_time: float = 0.6

@export var background_opacity: float = 0.85

@export var tween_speed_scale: float = 1.0

@export var scene_manipulator: String

var busy: bool = false
var busy2: bool = false
var main_tween: Tween
var free_when_end: bool = true
var exit_tree_when_end: bool = false
var scene_started: bool = false
var is_sub_menu: bool = false

const SAFE_MARGIN = 100

signal started()
signal ended()
signal start_started()
signal start_ended()


func _run_animation(animations: Array, on_complete: Callable) -> void:
	if main_tween and main_tween.is_running():
		main_tween.kill()

	main_tween = create_tween().set_parallel(true).set_speed_scale(tween_speed_scale)
	busy = true

	for anim_data in animations:
		anim_data.target_node.set(anim_data.property, anim_data.initial_value)
		main_tween.tween_property(
			anim_data.target_node,
			anim_data.property,
			anim_data.final_value,
			anim_data.duration
		).set_delay(anim_data.delay).set_trans(anim_data.trans_type).set_ease(anim_data.trans_ease)

	main_tween.set_parallel(false)
	if on_complete:
		main_tween.tween_callback(on_complete)


func _reset() -> void:
	var node1 = %Main

	node1.modulate = Color.WHITE

	node1.scale = Vector2.ONE
	node1.position = Vector2.ZERO
	
	scene_started = false


func hide_background() -> void:
	pass


func show_background() -> void:
	pass


func start() -> void:
	_reset()
	
	start_started.emit()
	
	var node1 = %Main
	var center = size * 0.5 - node1.size * 0.5
	node1.pivot_offset = node1.size / 2
	pivot_offset = size / 2
	var animations: Array[AnimationData] = []

	match start_animation:
		StartAnimations.FADE_IN:
			node1.modulate.a = 0.0
			node1.position = center
			animations.append(
				AnimationData.new(node1, "modulate:a", 0.0, 1.0, start_animation_time)
			)

		StartAnimations.SCALE_UP:
			node1.scale = Vector2(0.1, 0.1)
			node1.modulate.a = 1.0
			node1.position = center
			animations.append(
				AnimationData.new(node1, "scale", node1.scale, Vector2(1, 1), start_animation_time, 0.0, Tween.EASE_OUT, Tween.TRANS_BOUNCE)
			)

		StartAnimations.FADE_IN_SCALE:
			node1.scale = Vector2(0.1, 0.1)
			node1.modulate.a = 0.0
			node1.position = center
			animations += [
				AnimationData.new(node1, "scale", node1.scale, Vector2(1, 1), start_animation_time, 0.0, Tween.EASE_OUT, Tween.TRANS_BACK),
				AnimationData.new(node1, "modulate:a", 0.0, 1.0, start_animation_time)
			]

		StartAnimations.MOVE_FROM_RIGHT:
			node1.position = Vector2(size.x + SAFE_MARGIN, center.y)
			node1.modulate.a = 1.0
			animations.append(
				AnimationData.new(node1, "position", node1.position, center, start_animation_time)
			)

		StartAnimations.MOVE_FROM_LEFT:
			node1.position = Vector2(-node1.size.x - SAFE_MARGIN, center.y)
			node1.modulate.a = 1.0
			animations.append(
				AnimationData.new(node1, "position", node1.position, center, start_animation_time)
			)

		StartAnimations.MOVE_FROM_TOP:
			node1.position = Vector2(center.x, -node1.size.y - SAFE_MARGIN)
			node1.modulate.a = 1.0
			animations.append(
				AnimationData.new(node1, "position", node1.position, center, start_animation_time)
			)

		StartAnimations.MOVE_FROM_BOTTOM:
			node1.position = Vector2(center.x, size.y + SAFE_MARGIN)
			node1.modulate.a = 1.0
			animations.append(
				AnimationData.new(node1, "position", node1.position, center, start_animation_time)
			)

		StartAnimations.INSTANT:
			node1.position = center
			node1.scale = Vector2.ONE
			node1.modulate.a = 1.0
			started.emit()
			return


	_run_animation(animations, func():
		busy = false
		scene_started = true
		started.emit()
	)

func end() -> void:
	if main_tween and main_tween.is_running():
		main_tween.kill()

	busy = true
	
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.RESET)
	GameManager.hide_cursor()

	var back_button = get_node_or_null("%BackButton")
	if back_button:
		back_button.visible = false
	
	start_ended.emit()

	var node1 = %Main
	node1.pivot_offset = node1.size / 2
	pivot_offset = size / 2
	var center = size * 0.5 - node1.size * 0.5
	var animations: Array[AnimationData] = []

	match end_animation:
		EndAnimations.FADE_OUT:
			animations.append(
				AnimationData.new(node1, "modulate:a", node1.modulate.a, 0.0, end_animation_time)
			)

		EndAnimations.SCALE_DOWN:
			animations.append(
				AnimationData.new(node1, "scale", Vector2(1, 1), Vector2(0.05, 0.05), end_animation_time, 0.0, Tween.EASE_IN, Tween.TRANS_BACK)
			)

		EndAnimations.FADE_OUT_SCALE:
			animations += [
				AnimationData.new(node1, "modulate:a", 1.0, 0.0, end_animation_time),
				AnimationData.new(node1, "scale", Vector2(1, 1), Vector2(0.05, 0.05), end_animation_time, 0.0, Tween.EASE_IN, Tween.TRANS_BACK)
			]

		EndAnimations.MOVE_TO_RIGHT:
			animations.append(
				AnimationData.new(node1, "position", node1.position, Vector2(size.x + 200, center.y), end_animation_time)
			)

		EndAnimations.MOVE_TO_LEFT:
			animations.append(
				AnimationData.new(node1, "position", node1.position, Vector2(-node1.size.x - 200, center.y), end_animation_time)
			)

		EndAnimations.MOVE_TO_TOP:
			animations.append(
				AnimationData.new(node1, "position", node1.position, Vector2(center.x, -node1.size.y - 200), end_animation_time)
			)

		EndAnimations.MOVE_TO_BOTTOM:
			animations.append(
				AnimationData.new(node1, "position", node1.position, Vector2(center.x, size.y + 200), end_animation_time)
			)

		EndAnimations.INSTANT:
			queue_free() if free_when_end else hide()
			ended.emit()
			return


	if not is_sub_menu:
		GameManager.busy = false
		
	_run_animation(animations, func():
		ended.emit()
		if free_when_end:
			queue_free()
		else:
			hide()
			if exit_tree_when_end:
				get_parent().remove_child(self)
	)
	
