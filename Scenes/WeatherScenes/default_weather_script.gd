class_name DefaultWeatherScript
extends Sprite2D


class UserRipple:
	var position: Vector2
	var time: float
	var alpha: float
	
	signal finished()
	
	func _init(pos: Vector2, t: float = 0.0, a: float = 1.0) -> void:
		position = pos
		time = t
		alpha = a
	
	func update(delta: float) -> void:
		time += delta
		alpha = clamp(remap(time, 0.0, 1.0, 1.0, 0.0), 0.0, 1.0)
		if time >= 1.0:
			finished.emit()


@export var can_add_particle_ripples: bool = true


var extra_ripple_points: Array[UserRipple] = []

const RIPPLE_PARTICLE = preload("res://Scenes/WeatherScenes/RainScenes/ripple_particle.tscn")


func _ready() -> void:
	texture = %SubViewport.get_texture()
	setup()


#func _process(delta: float) -> void:
	#delta *= 0.5
	##for up in extra_ripple_points:
		##up.update(delta)


func _physics_process(delta: float) -> void:
	if !can_add_particle_ripples:
		return
	
	for up in extra_ripple_points:
		up.update(delta * 0.5)
		
	if GameManager.current_player and GameManager.current_map:
		var add_ripple: bool = false
		var point: Vector2
		if GameManager.current_player.is_moving:
			var p1 = (GameManager.current_player.global_position - global_position)
			var p2 = GameManager.current_map.get_wrapped_position(p1)
			point = p2
			add_ripple = true
		elif GameManager.current_vehicle:
			var vehicle_is_flaying = GameManager.current_vehicle.get("is_flying") == true
			if !vehicle_is_flaying:
				point = (GameManager.current_vehicle.global_position - global_position)
				add_ripple = true
		
		if add_ripple:
			var user_ripple = UserRipple.new(point)
			user_ripple.finished.connect(func(): extra_ripple_points.erase(user_ripple))
			var point_exist = extra_ripple_points.filter(func(t: UserRipple): return t.position == point)
			if !point_exist:
				extra_ripple_points.append(user_ripple)
				if randi() % 6 == 0:
					var particle = RIPPLE_PARTICLE.instantiate()
					particle.position = GameManager.current_player.position
					GameManager.current_player.get_parent().add_child(particle)
			
	var mat: ShaderMaterial = %MainSprite.get_material()
	if mat:
		var points: PackedVector4Array = []
		for up in extra_ripple_points:
			var user_point = Vector4(up.position.x, up.position.y, up.time, up.alpha)
			points.append(user_point)
		mat.set_shader_parameter("ripple_points", points)
		mat.set_shader_parameter("ripple_point_count", points.size())


func setup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	adjust_to_the_map()


func adjust_to_the_map() -> void:
	var map: RPGMap = get_tree().get_first_node_in_group("rpgmap")
	if map:
		var map_rect = map.get_used_rect(false)
		global_position = map_rect.position
		global_scale = Vector2(map_rect.size) / texture.get_size()
		
		var mat: ShaderMaterial = %MainSprite.get_material()
		if mat:
			mat.set_shader_parameter("scale", Vector2(1.0 / global_scale.x, 1.0 / global_scale.y))
