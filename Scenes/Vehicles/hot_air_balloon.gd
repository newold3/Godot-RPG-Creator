@tool
extends RPGVehicle


var old_zoom: Vector2
var current_scale: Vector2 = Vector2.ONE
var is_flying: bool = false

var shadow_scale_factor: float = 1.0
var original_collision_layer: int
var original_collision_mask: int


func _ready() -> void:
	super()
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	starting.connect(_on_board)
	ending.connect(_on_disembark)
	%FinalBalloon.texture = %Ballon.get_texture()
	%Vehicle.texture = %Ballon.get_texture()
	%VehicleTop.texture = %Ballon.get_texture()


func launch() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		old_zoom = camera.zoom
		camera.target_zoom = camera.zoom * 0.8
	var t = create_tween()
	t.tween_property(self, "shadow_scale_factor", 0.4, 1.0)
	%AnimationPlayer.play("Launch")


func exit() -> void:
	var t = create_tween()
	t.tween_callback(set.bind("is_flying", false)).set_delay(0.7)
	var t2 = create_tween()
	t2.tween_property(self, "shadow_scale_factor", 1.0, 1.0)
	is_enabled = false
	%AnimationPlayer.play("land")
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.target_zoom = old_zoom
	await %AnimationPlayer.animation_finished


func start_flying_animation() -> void:
	%AnimationPlayer.play("Flying")
	is_enabled = true
	is_passable = true
	collision_layer = 0
	collision_mask = 0


func end_flying_animation() -> void:
	is_passable = false
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask


func start(passenger: LPCCharacter) -> void:
	super(passenger)
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.target = %VehicleContainer


func end() -> void:
	if busy:
		return
	busy = true
	await exit()
	busy = false
	await super()


func _on_board() -> void:
	is_flying = true
	is_enabled = false
	%Vehicle.z_index = 101
	%VehicleTop.z_index = 101
	launch()


func _on_disembark() -> void:
	is_enabled = false
	%Vehicle.z_index = 1
	%VehicleTop.z_index = 101


func get_images() -> Array:
	var sprites_to_check = [%Vehicle, %VehicleTop]
	
	var images = []
	
	for s in sprites_to_check:
		if s and is_instance_valid(s) and s.visible and s.texture:
			images.append(s)
	
	return images


func get_shadow_data() -> Dictionary:
	var balloon_sprite = get_node_or_null("%FinalBalloon")
	var basket_sprite = get_node_or_null("%Vehicle")
	var top_sprite = get_node_or_null("%VehicleTop")
	if not balloon_sprite or not balloon_sprite.texture or not basket_sprite or not basket_sprite.texture:
		return {}

	var tex = balloon_sprite.texture
	var ground_pos = global_position
	var w_top = top_sprite.region_rect.size.x
	var w_balloon = balloon_sprite.region_rect.size.x
	ground_pos.x += (w_top / 2.0) - (w_balloon / 2.0)

	var container = basket_sprite.get_parent()
	var current_height = 0.0
	var elevated_pos = ground_pos

	if container:
		current_height = abs(container.position.y)
		elevated_pos.y -= current_height

	var max_flight_height = 250.0
	var scale_reduction = (current_height / max_flight_height) * 0.6
	var dynamic_scale_factor = clamp(1.0 - scale_reduction, 0.4, 1.0)
	var balloon_region = balloon_sprite.region_rect
	var final_scale = balloon_sprite.scale * dynamic_scale_factor

	var base_feet_y = balloon_region.size.y / 2.0
	var h_half = balloon_region.size.y / 2.0
	var adjusted_feet_y = base_feet_y
	
	var base_elongation = Vector2(1.0, 0.6)
	var final_elongation = base_elongation

	if final_scale.y > 0.0 and current_height > 0.0:
		adjusted_feet_y += (current_height / final_scale.y)
		
		var old_diff_y = (base_feet_y + h_half) * final_scale.y
		var new_diff_y = old_diff_y + current_height
		
		if new_diff_y > 0.0:
			final_elongation.y = base_elongation.y * (old_diff_y / new_diff_y)

	var shadow_dict = {
		"position": ground_pos,
		"textures": [tex],
		"positions": [elevated_pos],
		"regions": [balloon_region],
		"feet_offsets": [[8.0, 8.0, adjusted_feet_y]],
		"mask_offsets": [Vector2(0.0, -balloon_region.size.y / 2.0)],
		"alpha": balloon_sprite.modulate.a,
		"scale": final_scale,
		"rotation": balloon_sprite.rotation,
		"flip_h": balloon_sprite.flip_h,
		"elongation": final_elongation
	}

	return shadow_dict
