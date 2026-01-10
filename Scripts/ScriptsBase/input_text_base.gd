@tool
class_name InputTextBase
extends RequestInputFromUser


func _ready() -> void:
	super()


func get_class() -> String:
	return "SelectTextsScene"


func _start_animation() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.2, 1.5)
	modulate.a = 0.0
	
	var t = create_tween()
	t.set_parallel(true)
	
	t.tween_property(self, "scale", Vector2.ONE, 0.6)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	t.tween_property(self, "position:y", position.y, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
		.from(position.y + 40)
	
	t.tween_property(self, "modulate:a", 1.0, 0.4)
	
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
	var text_result: String = "".join(buffer)
	
	return text_result
