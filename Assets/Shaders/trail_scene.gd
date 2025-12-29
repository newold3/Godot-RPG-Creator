extends Node2D

var shader_material: ShaderMaterial
var current_point_index: int = 0
var delay: float = 0.0
var max_delay: float = 0.01
var targets: Array = []


func _ready():
	add_target(%Marker2D)
	add_target($Character2/JuanBattler/Marker2D)
	shader_material = $TileableSnow.material as ShaderMaterial
	# Inicializamos los arrays
	var initial_points = []
	var initial_times = []
	var initial_fades = []
	for i in range(200):
		initial_points.append(Vector2.ZERO)
		initial_times.append(0.0)
		initial_fades.append(0.0)
	
	shader_material.set_shader_parameter("depth_points", initial_points)
	shader_material.set_shader_parameter("start_times", initial_times)
	shader_material.set_shader_parameter("fade_times", initial_fades)


func add_target(node: Node2D) -> void:
	targets.append(node)


func remove_target(node: Node2D) -> void:
	targets.erase(node)


func clear_targets() -> void:
	targets.clear()


func set_depth_point(index: int, position: Vector2):
	var points = shader_material.get_shader_parameter("depth_points")
	var start_times = shader_material.get_shader_parameter("start_times")
	var fade_times = shader_material.get_shader_parameter("fade_times")
	
	points[index] = position
	start_times[index] = Time.get_ticks_msec() / 1000.0
	fade_times[index] = 0.0
	
	shader_material.set_shader_parameter("depth_points", points)
	shader_material.set_shader_parameter("start_times", start_times)
	shader_material.set_shader_parameter("fade_times", fade_times)

func clear_depth_point(index: int):
	var fade_times = shader_material.get_shader_parameter("fade_times")
	fade_times[index] = Time.get_ticks_msec() / 1000.0
	shader_material.set_shader_parameter("fade_times", fade_times)

func _process(delta):
	shader_material.set_shader_parameter("current_time", Time.get_ticks_msec() / 1000.0)
	
	# Limpiamos los puntos que han terminado de desaparecer
	var current_time = Time.get_ticks_msec() / 1000.0
	var points = shader_material.get_shader_parameter("depth_points")
	var start_times = shader_material.get_shader_parameter("start_times")
	var fade_times = shader_material.get_shader_parameter("fade_times")
	var updated = false
	
	for i in range(points.size()):
		if fade_times[i] > 0.0:
			if current_time - fade_times[i] > shader_material.get_shader_parameter("disappear_duration"):
				points[i] = Vector2.ZERO
				start_times[i] = 0.0
				fade_times[i] = 0.0
				updated = true
	
	if updated:
		shader_material.set_shader_parameter("depth_points", points)
		shader_material.set_shader_parameter("start_times", start_times)
		shader_material.set_shader_parameter("fade_times", fade_times)
	
	if delay > 0.0:
		delay -= delta
	else:
		for target in targets:
			var point = target.global_position
			set_depth_point(current_point_index, point)
			current_point_index = wrapi(current_point_index + 1, 0, 200)
		delay = max_delay
