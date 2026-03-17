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
	%FinalShadow.texture = %Ballon.get_texture()
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


func get_shadow_data() -> Dictionary:
	var tex = %Ballon.get_texture()
	if not tex: return {}
	var img = tex.get_image()
	if not img: return {}
	var used_rect = img.get_used_rect()
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = used_rect
	var tex_size = tex.get_size()
	var tex_top_left_offset = -(Vector2(tex_size) / 2.0)
	var center_x_local = tex_top_left_offset.x + used_rect.position.x + (used_rect.size.x / 2.0)
	var shadow_flattening_factor = 0.6
	var half_w = (used_rect.size.x / 2.0) * shadow_scale_factor
	var half_h = (used_rect.size.y / 2.0) * shadow_scale_factor * shadow_flattening_factor
	var shadow_center_world = global_position + Vector2(center_x_local, -half_h)
	var p_bl = shadow_center_world + Vector2(-half_w, half_h)
	var p_br = shadow_center_world + Vector2(half_w, half_h)
	var p_tr = shadow_center_world + Vector2(half_w, -half_h)
	var p_tl = shadow_center_world + Vector2(-half_w, -half_h)
	var quad_points = [
		p_bl,
		p_br,
		p_tr,
		p_tl
	]
	quad_points[0].y -= 1
	quad_points[1].y -= 1
	var tile_size: Vector2 = GameManager.get_map_tile_size() if GameManager.current_map else Vector2(32, 32)
	var sprite_visual = %FinalShadow
	var current_mask_offset = sprite_visual.global_position - global_position
	return {
		"main_node": self,
		"texture": atlas,
		"quad_points": quad_points,
		"position": global_position,
		"mask_offset": current_mask_offset,
		"cell": Vector2i(global_position / tile_size) if GameManager.current_map else Vector2i()
	}
