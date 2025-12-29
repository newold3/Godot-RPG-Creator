@tool
extends GameTransition

@export_enum("Move to Left", "Move to Up", "Move to Right", "Move to Down") var movement_direction = 0
@export var movement_smooth_curve: Curve = Curve.new()


@onready var main_texture: TextureRect = %MainTexture
@onready var target_texture: TextureRect = %TargetTexture


func start() -> void:
	main_texture.position = Vector2.ZERO
	main_texture.texture = background_image
	
	await get_tree().process_frame
	
	end_animation()


func end() -> void:
	if main_tween:
		main_tween.kill()
	
	main_tween = create_tween()
	main_tween.set_ease(Tween.EASE_OUT)
	main_tween.set_trans(Tween.TRANS_SINE)
	
	target_texture.texture = GameManager.get_main_scene_texture()
		
	main_texture.position = Vector2.ZERO
	target_texture.position = Vector2.ZERO
	
	match movement_direction:
		0: # MOVE to LEFT
			target_texture.position.x = main_texture.size.x
		1: # MOVE to UP
			target_texture.position.y = main_texture.size.y
		2: # MOVE to RIGHT
			target_texture.position.x = -main_texture.size.x
		3: # MOVE to DOWN
			target_texture.position.y = -main_texture.size.y
	
	main_tween.tween_method(_smooth_movement, 0.0, 1.0, transition_time)

	main_tween.tween_interval(0.01)
	
	main_tween.tween_callback(end_animation)
	
	await get_tree().create_timer(transition_time).timeout # Wait to finish animation before remeve scene

	super() # queue free


func _smooth_movement(delta: float) -> void:
	var value = movement_smooth_curve.sample(delta)
	match movement_direction:
		0: # MOVE to LEFT
			var x = remap(value, 0.0, 1.0, 0.0, target_texture.size.x)
			target_texture.position.x = target_texture.size.x - x
			main_texture.position.x = target_texture.position.x - main_texture.size.x
		1: # MOVE to UP
			var y = remap(value, 0.0, 1.0, 0.0, target_texture.size.y)
			target_texture.position.y = target_texture.size.y - y
			main_texture.position.y = target_texture.position.y - main_texture.size.y
		2: # MOVE to RIGHT
			var x = remap(value, 0.0, 1.0, 0.0, target_texture.size.x)
			target_texture.position.x = -target_texture.size.x + x
			main_texture.position.x = target_texture.position.x + target_texture.size.x
		3: # MOVE to DOWN
			var y = remap(value, 0.0, 1.0, 0.0, target_texture.size.y)
			target_texture.position.y = -target_texture.size.y + y
			main_texture.position.y = target_texture.position.y + target_texture.size.y
