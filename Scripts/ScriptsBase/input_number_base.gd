@tool
class_name InputNumberBase
extends RequestInputFromUser


func _ready() -> void:
	super()


func get_class() -> String:
	return "SelectDigitsScene"


func _get_next_control() -> Control:
	var direction = ControllerManager.get_pressed_direction()
		
	if direction:
		return ControllerManager.get_closest_focusable_control(current_button, direction, true, buttons, true, true)
	
	return null


func _start_animation() -> void:
	pivot_offset = Vector2(size.x * 0.5, 0.0)
	scale = Vector2(0.2, 1.5)
	modulate.a = 0.0
	var p = position
	
	var t = create_tween()
	t.set_parallel(true)
	
	t.tween_property(self, "scale", Vector2(1.1, 0.7), 0.2).from(Vector2(0.2, 0.2))
	t.tween_property(self, "position:y", p.y, 0.4).from(p.y + 120)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.2)
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	
	await t.finished


func _modulate_opacity(color: Color) -> void:
	propagate_call("set", ["modulate", color])


func _end_animation() -> void:
	pivot_offset = size * 0.5
	
	var t = create_tween()
	t.set_parallel(true)
	
	t.tween_property(self, "scale", Vector2(1.4, 0.0), 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	t.tween_method(_modulate_opacity, Color.WHITE, Color.TRANSPARENT, 0.6)
	
	t.tween_property(self, "position:y", position.y - 20, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	await t.finished


## get Final text
func get_text() -> Variant:
	var text_result: int = int("".join(buffer))
	
	return text_result
