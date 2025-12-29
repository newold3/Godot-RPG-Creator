@tool
extends Control

# 0 = Instant
# 1 = Fade Out to Black, Fade In to New Scene
# 2 = Fade Out to Color, Fade In to New Scene
# 3 = Shader Transition to Black, Shader Transition to New Scene
var default_transition: Texture = load("res://Assets/Images/Transitions/trans0.png")
var transition_type: int = 1
var transition_color: Color = Color.BLACK
var transition_texture: Texture = preload("res://Assets/Images/Transitions/trans9.png")
var transition_time: float = 0.5
var transition_scene: String
var current_transition_scene: GameTransition

var in_editor_texture_in: Texture
var in_editor_texture_out: Texture

var invert_fade_out: bool = true

var current_transition_mode: int = 0
var current_timer: Timer

var main_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint() and RPGDialogFunctions.there_are_any_dialog_open():
		await get_tree().process_frame
		_start_in_editor_mode()
	visible = false


func set_config(config: Dictionary) -> void:
	transition_scene = ""
	transition_texture = null
	transition_type = config.get("type", 1)
	transition_time = config.get("duration", 0.5)
	transition_color = config.get("transition_color", Color.BLACK)
	invert_fade_out = config.get("invert", true)
	if transition_type == 4:
		transition_scene = config.get("scene_image", "")
	elif transition_type == 3:
		var tex_path = config.get("transition_image", "")
		if ResourceLoader.exists(tex_path):
			transition_texture = load(tex_path)
	
	current_transition_mode = -1
	
	if current_transition_scene and is_instance_valid(current_transition_scene):
		current_transition_scene.finish.emit()
		current_transition_scene.queue_free()
		current_transition_scene = null


func _start_in_editor_mode() -> void:
	if not in_editor_texture_in:
		in_editor_texture_in = load("res://Scenes/TransitionManager/TransitionScenes/preview_transition.png")
	if not in_editor_texture_out:
		in_editor_texture_out = load("res://Scenes/TransitionManager/TransitionScenes/preview_transition2.png")
	
	current_timer = Timer.new()
	current_timer.one_shot = true
	current_timer.wait_time = 0.1
	current_timer.timeout.connect(_on_timer_timeout)
	add_child(current_timer)
	
	_on_timer_timeout()


func _on_timer_timeout() -> void:
	if not is_inside_tree(): return
	if get_tree() == null:
		return
	if current_transition_mode != -1:
		if current_transition_mode == 0:
			await get_tree().create_timer(0.5).timeout
			await start(in_editor_texture_in)
		else:
			await end(in_editor_texture_out)
	else:
		await get_tree().process_frame
	
	await get_tree().create_timer(0.15).timeout
	
	current_transition_mode = wrapi(current_transition_mode + 1, 0, 2)
	if is_instance_valid(current_timer) and current_timer.is_inside_tree():
		current_timer.start()
	else:
		prints(is_instance_valid(current_timer), current_timer.is_inside_tree())


func start(start_texture: Texture) -> void:
	if GameManager.game_state and GameManager.game_state.current_transition:
		set_config(GameManager.game_state.current_transition)
		
	visible = true
	
	var mat: ShaderMaterial = %ShaderEffect.get_material()
	mat.set_shader_parameter("fill", -0.01)
	mat.set_shader_parameter("reverse", false)
	
	if transition_type <= 3:
		%Background.texture = start_texture
		match transition_type:
			0:
				return
			1:
				mat.set_shader_parameter("color", Color.BLACK)
				mat.set_shader_parameter("use_simple_fade", true)
			2:
				mat.set_shader_parameter("color", transition_color)
				mat.set_shader_parameter("use_simple_fade", true)
			3:
				mat.set_shader_parameter("color", transition_color)
				mat.set_shader_parameter("use_simple_fade", false)
				mat.set_shader_parameter("height_map", transition_texture)
	else:
		%Background.texture = null
		if current_transition_scene and is_instance_valid(current_transition_scene):
			current_transition_scene.queue_free()
		current_transition_scene = null
		if ResourceLoader.exists(transition_scene):
			var scn = load(transition_scene).instantiate()
			if scn is GameTransition:
				current_transition_scene = scn
			else:
				scn.queue_free()
			
			if current_transition_scene:
				current_transition_scene.background_image = start_texture
				current_transition_scene.transition_time = transition_time
				current_transition_scene.transition_color = transition_color
				add_child(current_transition_scene)
				current_transition_scene.start()
	
	if main_tween:
		main_tween.kill()
	
	if transition_type <= 3:
		main_tween = create_tween()
		main_tween.tween_property(mat, "shader_parameter/fill", 1.0, transition_time)
		await main_tween.finished
	elif current_transition_scene:
		await current_transition_scene.finish


func end(final_texture: Texture = null):
	var mat: ShaderMaterial = %ShaderEffect.get_material()
	
	if transition_type <= 3:
		if transition_type == 0:
			mat.set_shader_parameter("fill", -0.01)

			return
	else:
		if current_transition_scene:
			@warning_ignore("redundant_await")
			await current_transition_scene.end()

		return
		
	%Background.texture = final_texture

	if invert_fade_out:
		mat.set_shader_parameter("reverse", true)
	
	if main_tween:
		main_tween.kill()

	if transition_type <= 3:
		if transition_type < 3:
			mat.set_shader_parameter("use_simple_fade", true)
		else:
			mat.set_shader_parameter("use_simple_fade", false)
		main_tween = create_tween()
		
		main_tween.tween_property(mat, "shader_parameter/fill", 0.0, transition_time)
		if not Engine.is_editor_hint():
			main_tween.tween_callback(
				func():
					%Background.texture = null
			)
		await main_tween.finished
	else:
		await current_transition_scene.finish
	
	if not Engine.is_editor_hint():
		visible = false
	
	
