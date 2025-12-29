class_name AnimationProcess
extends Node2D


var current_data: RPGAnimation
var current_frame: int = 0
var current_target: Variant
var flash_tween: Tween
var flash_total_duration: float
var shake_tween: Tween
var shake_total_duration: float

var last_shake_direction := Vector2.ZERO
var shake_seed := 0.0

var target: Node
var animation_offset: Vector2

@onready var effect_position: Marker2D = %EffectPosition
@onready var main_texture: Sprite2D = $MainTexture
@onready var effect_viewport: SubViewport = %EffectViewport



func add_effect(effect: Node, _target: Node, _animation_offset: Vector2) -> void:
	$MainTexture.texture = effect_viewport.get_texture()
	effect_position.add_child(effect)
	target = _target
	animation_offset = _animation_offset


func _recualculate_position_and_scale() -> void:
	var target_position = target.get_viewport_transform() * target.global_position + animation_offset
	position = target_position


func add_animation_data(data: RPGAnimation, _target: Variant) -> void:
	current_data = data
	current_target = _target


func _process(_delta: float) -> void:
	if not current_data: return
	
	if target: _recualculate_position_and_scale()

	for sound: RPGAnimationSound in current_data.sounds:
		if sound.frame == current_frame:
			if ResourceLoader.exists(sound.filename):
				GameManager.play_se(sound.filename, sound.volume_db, randf_range(sound.pitch_min, sound.pitch_max))
				
	if current_target:
		for flash: RPGAnimationFlash in current_data.flashes:
			if flash.frame == current_frame:
				var duration = flash.duration
				flash_total_duration = duration
				flash_tween = create_tween()
				
				if flash.target == 0: # Animation On Target
					var original_modulate = current_target.modulate
					var target_color = flash.color
					flash_tween.tween_method(_animate_flash_npc.bind(original_modulate, target_color, current_target), 0.0, 1.0, duration)
					flash_tween.tween_method(_animate_flash_npc.bind(target_color, original_modulate, current_target), 0.0, 1.0, duration)
				else: # Flash On Screen
					var original_color = Color.TRANSPARENT
					var target_color = flash.color
					var blend = flash.screen_blend_type
					flash_tween.tween_method(_animate_flash_screen.bind(original_color, target_color, blend), 0.0, 1.0, duration)
					flash_tween.tween_method(_animate_flash_screen.bind(target_color, original_color, blend), 0.0, 1.0, duration)
					
	
	for shake: RPGAnimationShake in current_data.shakes:
		if shake.frame == current_frame:
			var obj = current_target if shake.target == 0 else GameManager.main_scene.get_main_sub_viewport_container()
			var magnitude = shake.amplitude
			var frequency = shake.frequency
			var duration =  shake.duration
			shake_total_duration = duration + 0.1
			var start_position = obj.position if shake.target == 0 else Vector2.ZERO
			var callable = _animate_shake.bind(obj, magnitude, frequency, start_position)
			shake_tween = create_tween()
			shake_tween.tween_method(callable, 0.0, 1.0, duration)
			shake_tween.tween_callback(obj.set.bind("position", start_position))
			if shake.target == 1: # Screen shake, need reset position
				shake_tween.tween_property(obj, "position", Vector2.ZERO, 0.1)

	current_frame += 1


func end() -> void:
	if (flash_tween and flash_tween.is_valid() and flash_tween.is_running()):
		flash_tween.pause()
		flash_tween.custom_step(flash_total_duration)
		#flash_tween.play()
		
	if (shake_tween and shake_tween.is_valid() and shake_tween.is_running()):
		shake_tween.pause()
		shake_tween.custom_step(shake_total_duration)
		#shake_tween.play()
	
	if is_inside_tree():
		await get_tree().process_frame
	
	queue_free()


func _animate_flash_screen(step: float, original_color: Color, target_color: Color, blend: CanvasItemMaterial.BlendMode) -> void:
	GameManager.main_scene.set_flash_color(original_color.lerp(target_color, step), blend)


func _animate_flash_npc(step: float, original_color: Color, target_color: Color, obj: Variant) -> void:
	obj.set_modulate(original_color.lerp(target_color, step))


func _animate_shake(step: float, node: Node, magnitude: float, frequency: float, original_position: Vector2) -> void:
	shake_seed += 0.1
	
	var shake_amount = magnitude * (1.0 - step)
	
	var direction = Vector2.ZERO
	
	direction.x = sin(step * frequency * 15.7 + shake_seed * 3.3) * cos(step * frequency * 9.3 + shake_seed * 2.1)
	direction.y = cos(step * frequency * 12.2 + shake_seed * 4.7) * sin(step * frequency * 5.6 + shake_seed * 1.9)
	
	if direction.length() > 0.1:
		direction = direction.normalized()
	
	if last_shake_direction.dot(direction) > 0.7:
		direction = -direction
	
	var x_offset = sign(direction.x) * ceil(abs(direction.x * shake_amount))
	var y_offset = sign(direction.y) * ceil(abs(direction.y * shake_amount))
	
	var motion = Vector2(x_offset, y_offset)
	
	if "shake" in node:
		node.shake(motion)
	else:
		node.position = original_position + motion
	

	last_shake_direction = direction
