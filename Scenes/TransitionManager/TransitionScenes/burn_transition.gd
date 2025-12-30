@tool
extends GameTransition


func start() -> void:
	if main_tween:
		main_tween.kill()
	
	var mat: ShaderMaterial = %Effect.get_material()
	
	mat.set_shader_parameter("dissolve_value", 0.0)
	mat.set_shader_parameter("final_color", transition_color)
	
	main_tween = create_tween()
	main_tween.tween_property(mat, "shader_parameter/dissolve_value", 1.0, transition_time)
	main_tween.tween_callback(end_animation)


func end() -> void:
	if main_tween:
		main_tween.kill()
	
	var mat: ShaderMaterial = %Effect.get_material()
	
	main_tween = create_tween()
	main_tween.tween_property(mat, "shader_parameter/dissolve_value", 0.0, transition_time)
	main_tween.tween_callback(end_animation)
	
	await get_tree().create_timer(transition_time).timeout # Wait to finish animation before remeve scene
	if not is_instance_valid(self) or not is_inside_tree(): return
	
	super() # queue free
