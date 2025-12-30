@tool
extends GameTransition


var all_polygons: Array = []

const BROKEN_GLASS = preload("res://Assets/Sounds/SE/broken_glass.ogg")
const CRACK_GLASS = preload("res://Assets/Sounds/SE/crack_glass.ogg")

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


#func _ready() -> void:
	#background_image = preload("res://Assets/Images/SceneTitle/background.png")
	#start()


func create_glass_shards():
	var parent_polygon = %BrokenCrystal
	var container = %ShatterContainer
	
	parent_polygon.visible = false
	var parent_vertices = parent_polygon.polygon
	var parent_uvs = parent_polygon.uv
	var parent_polygons = parent_polygon.polygons
	var parent_position = parent_polygon.position
	var screen_center = get_viewport_rect().size / 2.0
	var closest_distance = INF
	var closest_index = 0
	
	# Crear un nuevo Polygon2D para cada subpolígono definido en polygons
	for n in parent_polygons.size():
		var polygon_indices = parent_polygons[n]
		var new_polygon = Polygon2D.new()
		container.add_child(new_polygon)
		
		# Copiar propiedades básicas del padre
		new_polygon.texture = background_image
		
		# Crear el nuevo array de vértices basado en los índices
		var new_vertices = PackedVector2Array()
		var new_uvs = PackedVector2Array()
		
		# Convertir los índices en vértices y UVs reales
		for index in polygon_indices:
			# Añadir el vértice correspondiente
			new_vertices.push_back(parent_vertices[index])
			
			# Añadir el UV correspondiente si existe
			if parent_uvs.size() > index:
				new_uvs.push_back(parent_uvs[index])
		
		# Asignar los vértices y UVs al nuevo polígono
		new_polygon.polygon = new_vertices
		if new_uvs.size() > 0:
			new_polygon.uv = new_uvs
		
		# Como este es un fragmento individual, su propiedad polygons
		# debe contener solo un array con los índices secuenciales
		var new_polygon_indices = PackedInt32Array()
		for i in range(new_vertices.size()):
			new_polygon_indices.push_back(i)
		new_polygon.polygons = [new_polygon_indices]
		
		# Calcular y establecer la posición correcta
		var local_center = calculate_polygon_center(new_vertices)
		var global_center = parent_position + local_center
		new_polygon.position = parent_position + local_center
		
		# Ajustar los vértices relativos al nuevo centro
		var adjusted_vertices = PackedVector2Array()
		for vertex in new_vertices:
			adjusted_vertices.push_back(vertex - local_center)
		new_polygon.polygon = adjusted_vertices
		
		all_polygons.append(new_polygon)
		
		var distance_to_screen_center = global_center.distance_to(screen_center)
		if distance_to_screen_center < closest_distance:
			closest_distance = distance_to_screen_center
			closest_index = n
	
	# move center polygon to position 0 to animate first
	var closest_polygon = all_polygons[closest_index]
	all_polygons.remove_at(closest_index)
	all_polygons.insert(0, closest_polygon)


# Calcula el centro de un polígono
func calculate_polygon_center(vertices: PackedVector2Array) -> Vector2:
	var center = Vector2.ZERO
	for vertex in vertices:
		center += vertex
	return center / vertices.size() if vertices.size() > 0 else Vector2.ZERO


func start() -> void:
	%Effect.get_material().set_shader_parameter("reflection_viewport", background_image)
	create_glass_shards()
	
	await get_tree().create_timer(0.06).timeout # Allow time for the scene to load viewports
	if not is_instance_valid(self) or not is_inside_tree(): return

	%Background.color = transition_color
	$FinalTexture.texture = %Pass2.get_texture()
	
	if main_tween:
		main_tween.kill()
	
	audio_stream_player.stream = CRACK_GLASS
	audio_stream_player.play()
	
	main_tween = create_tween()
	main_tween.tween_property(%FinalTexture, "modulate", Color(1.5, 1.5, 1.5, 1), 0.2)
	main_tween.tween_property(%FinalTexture, "modulate", Color(1.0, 1.0, 1.0, 1), 0.4)
	main_tween.tween_interval(0.01)
	main_tween.set_parallel(true)
	main_tween.set_ease(Tween.EASE_IN_OUT)
	main_tween.set_trans(Tween.TRANS_CUBIC)
	
	var screen_center = get_viewport_rect().size / 2.0
	var explosion_radius: float = 200.0
	var fall_distance: float = 1000.0
	var rotation_max: float = PI * 6.0
	var scale_min: float = 0.3
	var scale_max: float = 3.2
	
	for i in range(all_polygons.size()):
		var polygon = all_polygons[i]
		var random_delay = randf_range(0, 0.3)
		var explosion_duration = randf_range(0.2, 0.4)
		var fall_duration = randf_range(transition_time * 0.5, transition_time)
		
		# Calculate vector from screen center to polygon
		var center_vector = (polygon.position - screen_center).normalized()
		
		# Initial explosion outward movement
		var initial_explosion_position = polygon.position + center_vector * explosion_radius
		
		# Final fall position with randomness
		var final_position = initial_explosion_position + Vector2(
			randf_range(-fall_distance * 0.5, fall_distance * 0.5),
			fall_distance
		)
		
		var final_rotation = randf_range(-rotation_max, rotation_max)
		var final_scale = Vector2.ONE * randf_range(scale_min, scale_max)
		
		# Explosion phase
		main_tween.tween_property(polygon, "position", 
			initial_explosion_position, 
			explosion_duration
		).set_delay(random_delay)
		
		# Fall phase
		main_tween.tween_property(polygon, "position", 
			final_position, 
			fall_duration
		).set_delay(random_delay + explosion_duration)
		
		# Rotation
		main_tween.tween_property(polygon, "rotation", 
			final_rotation, 
			fall_duration
		).set_delay(random_delay + explosion_duration)
		
		# Scale
		main_tween.tween_property(polygon, "scale", 
			final_scale, 
			fall_duration
		).set_delay(random_delay + explosion_duration)
		
		# Fade out
		main_tween.tween_property(polygon, "modulate:a",
			0.0,  # Final transparency
			fall_duration * 0.5  # Half the animation time
		).set_delay(random_delay + explosion_duration + fall_duration * 0.5)
	
	main_tween.tween_callback(
		func():
			audio_stream_player.stream = BROKEN_GLASS
			audio_stream_player.play()
	)
	
	main_tween.set_parallel(false)
	main_tween.tween_interval(0.01)
	main_tween.tween_callback(end_animation)


func end() -> void:
	if main_tween:
		main_tween.kill()
	
	main_tween = create_tween()
	main_tween.tween_property(self, "modulate:a", 0.0, transition_time)
	main_tween.tween_callback(end_animation)
	
	await main_tween.finished # Wait to finish animation before remove scene
	
	super() # queue free
