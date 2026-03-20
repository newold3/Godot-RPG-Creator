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
	var tex = %FinalBalloon.texture
	if not tex: return {}
	if not has_meta("_cached_balloon_rect"):
		var img = tex.get_image()
		if not img or img.get_used_rect().get_area() == 0: return {}
		set_meta("_cached_balloon_rect", img.get_used_rect())
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = get_meta("_cached_balloon_rect")
		set_meta("_cached_balloon_atlas", atlas)
		var basket_tex = %Vehicle.texture
		if basket_tex:
			var b_img = basket_tex.get_image()
			if b_img:
				var b_rect = b_img.get_used_rect()
				set_meta("_cached_basket_rect", b_rect)
				var m_atlas = AtlasTexture.new()
				m_atlas.atlas = basket_tex
				m_atlas.region = b_rect
				set_meta("_cached_mask_atlas", m_atlas)
	var used_rect: Rect2 = get_meta("_cached_balloon_rect")
	var atlas: AtlasTexture = get_meta("_cached_balloon_atlas")
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
	var quad_points = [p_bl, p_br, p_tr, p_tl]
	quad_points[0].y -= 1
	quad_points[1].y -= 1
	var basket_node = %Vehicle
	var basket_tex = basket_node.texture
	if not basket_tex or not has_meta("_cached_basket_rect"): return {}
	var used_rect_basket: Rect2 = get_meta("_cached_basket_rect")
	var mask_atlas: AtlasTexture = get_meta("_cached_mask_atlas")
	var tex_origin_basket = basket_node.offset - (basket_tex.get_size() / 2.0)
	var basket_l_x_min = tex_origin_basket.x + used_rect_basket.position.x
	var basket_l_x_max = tex_origin_basket.x + used_rect_basket.position.x + used_rect_basket.size.x
	var basket_l_y_min = tex_origin_basket.y + used_rect_basket.position.y
	var basket_l_y_max = tex_origin_basket.y + used_rect_basket.position.y + used_rect_basket.size.y
	var m_bl = basket_node.to_global(Vector2(basket_l_x_min, basket_l_y_max))
	var m_br = basket_node.to_global(Vector2(basket_l_x_max, basket_l_y_max))
	var m_tr = basket_node.to_global(Vector2(basket_l_x_max, basket_l_y_min))
	var m_tl = basket_node.to_global(Vector2(basket_l_x_min, basket_l_y_min))
	var mask_points = PackedVector2Array([m_tl, m_tr, m_br, m_bl])
	var mask_uvs = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	@warning_ignore("incompatible_ternary")
	var tile_size: Vector2 = GameManager.get_map_tile_size() if GameManager.current_map else Vector2(32, 32)
	return {
		"main_node": self,
		"texture": atlas,
		"quad_points": quad_points,
		"mask_points": mask_points,
		"mask_texture": mask_atlas,
		"mask_uvs": mask_uvs,
		"position": global_position,
		"mask_offset": Vector2.ZERO,
		"cell": Vector2i(global_position / tile_size) if GameManager.current_map else Vector2i()
	}
