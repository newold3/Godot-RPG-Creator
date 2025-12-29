@tool
extends ColorRect


func shake() -> void:
	z_index = 10
	var mat = get_material()
	var t = create_tween()
	t.tween_method(_update_shake.bind(mat, "shake_strength"), 0.5, 0.0, 0.35)


func _update_shake(value: float, mat: ShaderMaterial, property: String) -> void:
	mat.set_shader_parameter(property, value)
