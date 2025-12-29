@tool
class_name TeleportTransitions
extends Node


# Script to handle different teleport transitions with parallel Tweens
# Animations use two phases: fade out (exit) and fade in (entry)
# Focused on "Squeeze" and "Elastic" feel with correct parallel delay logic.

var a: Dictionary
enum ExitAnimation {
	INSTANT,
	FADE_OUT,
	STRETCH_UP,
	SQUASH_DOWN,
	IMPLODE,
	SPIN_IMPLODE,
	ELASTIC_SNAP,
	FLATTEN_H,
	FLATTEN_V
}


enum EntryAnimation {
	INSTANT,
	FADE_IN,
	POP_IN,
	DROP_SQUASH,
	EXPLODE,
	SPIN_POP,
	ELASTIC_WOBBLE,
	UNFLATTEN_H,
	UNFLATTEN_V
}


@export var sprite_node: Node
@export var exit_animation: ExitAnimation = ExitAnimation.FADE_OUT
@export var entry_animation: EntryAnimation = EntryAnimation.FADE_IN


@export var preview_exit: bool = false:
	set(value):
		if value and sprite_node:
			preview_exit = false
			_preview_exit_animation()


@export var preview_entry: bool = false:
	set(value):
		if value and sprite_node:
			preview_entry = false
			_preview_entry_animation()


var player: Node
var tween: Tween
# Internal variables to store original transforms for restoration
var _final_scale: Vector2 = Vector2.ONE
var _final_rotation: float = 0.0
var _final_alpha: float = 1.0


signal animation_finished


func _instant_animation() -> void:
	if tween:
		tween.kill()

	tween = null


func _calculate_time_scale(original_duration: float, max_time: float) -> float:
	if original_duration <= 0:
		return 1.0
	return max_time / original_duration


# ============= EXIT ANIMATIONS =============


func play_exit_animation(target_node: Node, type: ExitAnimation, max_time: float = 0.5) -> void:
	player = target_node
	
	# Save original state to metadata for restoration during entry
	var original_state = {
		"scale": player.scale,
		"rotation": player.rotation,
		"alpha": player.modulate.a
	}
	player.set_meta("teleport_restore_data", original_state)

	match type:
		ExitAnimation.INSTANT:
			_instant_animation()
		ExitAnimation.FADE_OUT:
			_exit_fade_out(max_time)
		ExitAnimation.SQUASH_DOWN:
			_exit_squash_down(max_time)
		ExitAnimation.STRETCH_UP:
			_exit_stretch_up(max_time)
		ExitAnimation.IMPLODE:
			_exit_implode(max_time)
		ExitAnimation.SPIN_IMPLODE:
			_exit_spin_implode(max_time)
		ExitAnimation.ELASTIC_SNAP:
			_exit_elastic_snap(max_time)
		ExitAnimation.FLATTEN_H:
			_exit_flatten_h(max_time)
		ExitAnimation.FLATTEN_V:
			_exit_flatten_v(max_time)

	if tween:
		await tween.finished
	else:
		await target_node.get_tree().process_frame

	animation_finished.emit()


func _exit_fade_out(max_time: float) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(player, "modulate:a", 0.0, max_time)


func _exit_squash_down(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	var scale = _calculate_time_scale(0.25, max_time)
	tween.tween_property(player, "scale", Vector2(1.5, 0.1), 0.25 * scale)
	tween.tween_property(player, "modulate:a", 0.0, 0.25 * scale)


func _exit_stretch_up(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	var scale = _calculate_time_scale(0.25, max_time)
	tween.tween_property(player, "scale", Vector2(0.1, 2.0), 0.25 * scale)
	tween.tween_property(player, "modulate:a", 0.0, 0.25 * scale)


func _exit_implode(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	var scale = _calculate_time_scale(0.3, max_time)
	tween.tween_property(player, "scale", Vector2(0.5, 1.2), 0.1 * scale).set_trans(Tween.TRANS_BACK)
	tween.tween_property(player, "scale", Vector2(0.0, 0.0), 0.2 * scale).set_delay(0.1 * scale)
	tween.tween_property(player, "modulate:a", 0.8, 0.3 * scale)


func _exit_spin_implode(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	var scale = _calculate_time_scale(0.3, max_time)
	tween.tween_property(player, "scale", Vector2(0.0, 0.0), 0.3 * scale)
	tween.tween_property(player, "rotation", TAU, 0.3 * scale).from(0.0)
	tween.tween_property(player, "modulate:a", 0.0, 0.3 * scale)


func _exit_elastic_snap(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	var scale = _calculate_time_scale(0.45, max_time)
	tween.tween_property(player, "scale", Vector2(0.9, 1.1), 0.15 * scale).set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "scale", Vector2(1.2, 0.8), 0.15 * scale).set_delay(0.15 * scale).set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "scale", Vector2(0.0, 0.0), 0.15 * scale).set_delay(0.30 * scale).set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "modulate:a", 0.8, 0.1 * scale).set_delay(0.30 * scale)


func _exit_flatten_h(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	var scale = _calculate_time_scale(0.25, max_time)
	tween.tween_property(player, "scale", Vector2(0.0, 1.2), 0.25 * scale)
	tween.tween_property(player, "modulate:a", 0.0, 0.25 * scale)


func _exit_flatten_v(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	var scale = _calculate_time_scale(0.25, max_time)
	tween.tween_property(player, "scale", Vector2(1.2, 0.0), 0.25 * scale)
	tween.tween_property(player, "modulate:a", 0.0, 0.25 * scale)


## Returns a Dictionary with the final expected state (scale, modulate_a, rotation)
## for the given exit animation type. Useful for logic checks.
func get_exit_final_values(type: ExitAnimation) -> Dictionary:
	var result: Dictionary = {
		"scale": Vector2.ONE,
		"modulate_a": 0.0,
		"rotation": 0.0
	}

	match type:
		ExitAnimation.INSTANT:
			result.modulate_a = 1.0
		ExitAnimation.FADE_OUT:
			pass
		ExitAnimation.SQUASH_DOWN:
			result.scale = Vector2(1.5, 0.1)
		ExitAnimation.STRETCH_UP:
			result.scale = Vector2(0.1, 2.0)
		ExitAnimation.IMPLODE:
			result.scale = Vector2.ZERO
			result.modulate_a = 0.8
		ExitAnimation.SPIN_IMPLODE:
			result.scale = Vector2.ZERO
			result.rotation = TAU
		ExitAnimation.ELASTIC_SNAP:
			result.scale = Vector2.ZERO
			result.modulate_a = 0.8
		ExitAnimation.FLATTEN_H:
			result.scale = Vector2(0.0, 1.2)
		ExitAnimation.FLATTEN_V:
			result.scale = Vector2(1.2, 0.0)

	return result


# ============= ENTRY ANIMATIONS =============


func play_entry_animation(target_node: Node, type: EntryAnimation, max_time: float = 0.5) -> void:
	player = target_node
	
	# Retrieve original state from metadata if available, otherwise use defaults
	if player.has_meta("teleport_restore_data"):
		var original_state = player.get_meta("teleport_restore_data")
		_final_scale = original_state.scale
		_final_rotation = original_state.rotation
		_final_alpha = original_state.alpha
		player.remove_meta("teleport_restore_data")
	else:
		_final_scale = Vector2.ONE
		_final_rotation = 0.0
		_final_alpha = 1.0

	match type:
		EntryAnimation.INSTANT:
			_instant_animation()
		EntryAnimation.FADE_IN:
			_entry_fade_in(max_time)
		EntryAnimation.POP_IN:
			_entry_pop_in(max_time)
		EntryAnimation.DROP_SQUASH:
			_entry_drop_squash(max_time)
		EntryAnimation.SPIN_POP:
			_entry_spin_pop(max_time)
		EntryAnimation.EXPLODE:
			_entry_explode(max_time)
		EntryAnimation.UNFLATTEN_H:
			_entry_unflatten_h(max_time)
		EntryAnimation.UNFLATTEN_V:
			_entry_unflatten_v(max_time)
		EntryAnimation.ELASTIC_WOBBLE:
			_entry_elastic_wobble(max_time)

	if tween:
		await tween.finished
	else:
		await target_node.get_tree().process_frame

	animation_finished.emit()


func _entry_fade_in(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(player, "modulate:a", _final_alpha, max_time)


func _entry_pop_in(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	var scale = _calculate_time_scale(0.35, max_time)
	tween.tween_property(player, "scale", _final_scale, 0.35 * scale)
	tween.tween_property(player, "modulate:a", _final_alpha, 0.2 * scale)


func _entry_drop_squash(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	var scale = _calculate_time_scale(0.35, max_time)
	# Apply relative scaling based on original scale
	tween.tween_property(player, "scale", Vector2(0.6, 1.4) * _final_scale, 0.1 * scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "modulate:a", _final_alpha, 0.1 * scale)
	tween.tween_property(player, "scale", Vector2(1.4, 0.6) * _final_scale, 0.1 * scale).set_delay(0.1 * scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "scale", _final_scale, 0.15 * scale).set_delay(0.2 * scale).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _entry_spin_pop(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	var scale = _calculate_time_scale(0.35, max_time)
	tween.tween_property(player, "scale", _final_scale, 0.35 * scale)
	# Spin one full circle ending at the original rotation
	tween.tween_property(player, "rotation", _final_rotation, 0.35 * scale).from(_final_rotation - TAU)
	tween.tween_property(player, "modulate:a", _final_alpha, 0.2 * scale)


func _entry_explode(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	var scale = _calculate_time_scale(0.3, max_time)
	tween.tween_property(player, "scale", Vector2(0.3, 1.2) * _final_scale, 0.2 * scale).set_trans(Tween.TRANS_BACK)
	tween.tween_property(player, "scale", _final_scale, 0.1 * scale).set_delay(0.2 * scale)
	tween.tween_property(player, "modulate:a", _final_alpha, 0.3 * scale)


func _entry_unflatten_h(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	var scale = _calculate_time_scale(0.4, max_time)
	tween.tween_property(player, "scale", _final_scale, 0.4 * scale)
	tween.tween_property(player, "modulate:a", _final_alpha, 0.2 * scale)


func _entry_unflatten_v(max_time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	var scale = _calculate_time_scale(0.4, max_time)
	tween.tween_property(player, "scale", _final_scale, 0.4 * scale)
	tween.tween_property(player, "modulate:a", _final_alpha, 0.2 * scale)


func _entry_elastic_wobble(max_time: float) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	var scale = _calculate_time_scale(0.45, max_time)
	tween.tween_property(player, "scale", Vector2(1.2, 0.8) * _final_scale, 0.15 * scale).set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "modulate:a", _final_alpha, 0.1 * scale)
	tween.tween_property(player, "scale", Vector2(0.9, 1.1) * _final_scale, 0.15 * scale).set_delay(0.15 * scale).set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "scale", _final_scale, 0.15 * scale).set_delay(0.30 * scale).set_trans(Tween.TRANS_SINE)


# ============= PREVIEW FUNCTIONS =============


func _preview_exit_animation() -> void:
	if not sprite_node:
		return

	sprite_node.scale = Vector2(1, 1)
	sprite_node.rotation = 0
	sprite_node.modulate.a = 1.0
	play_exit_animation(sprite_node, exit_animation, 0.5)


func _preview_entry_animation() -> void:
	if not sprite_node:
		return

	sprite_node.rotation = 0
	sprite_node.modulate.a = 0.0
	match entry_animation:
		EntryAnimation.FADE_IN:
			sprite_node.scale = Vector2(1, 1)
		EntryAnimation.POP_IN:
			sprite_node.scale = Vector2(0, 0)
		EntryAnimation.DROP_SQUASH:
			sprite_node.scale = Vector2(0.1, 2.0)
		EntryAnimation.SPIN_POP:
			sprite_node.scale = Vector2(0, 0)
			sprite_node.rotation = 0
		EntryAnimation.EXPLODE:
			sprite_node.scale = Vector2(0, 0)
		EntryAnimation.UNFLATTEN_H:
			sprite_node.scale = Vector2(0, 1.2)
		EntryAnimation.UNFLATTEN_V:
			sprite_node.scale = Vector2(1.2, 0)

		EntryAnimation.ELASTIC_WOBBLE:
			sprite_node.scale = Vector2(0, 0)

	await get_tree().process_frame

	play_entry_animation(sprite_node, entry_animation, 0.5)
