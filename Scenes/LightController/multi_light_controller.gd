class_name MultiLightController
extends ColorRect

## Multi-point light system for creating dark maps with light spots
## Optimized to only send the closest lights to the visible screen area

# Light point data structure
class LightPoint:
	var position: Vector2
	var world_position: Vector2  # Store world position separately
	var radius: float
	var world_radius: float  # Store world radius for distance calculations
	var intensity: float
	var target_node: Node2D = null  # Optional: follow a specific node
	var offset: Vector2 = Vector2.ZERO
	var distance_to_screen: float = 0.0  # Distance to visible screen area
	
	func _init(pos: Vector2, r: float, i: float = 1.0, node: Node2D = null, off: Vector2 = Vector2.ZERO):
		world_position = pos
		world_radius = r
		position = Vector2.ZERO  # Will be calculated later
		radius = r
		intensity = i
		target_node = node
		offset = off

var light_points: Array[LightPoint] = []
var max_lights: int = 16
var screen_margin: float = 200.0  # Margin around screen to include lights that might cast visible shadows
var camera: Camera2D = null

func _ready() -> void:
	# Try to find the camera automatically
	find_camera()
	update_shader_lights()

func _process(_delta: float) -> void:
	update_light_positions()
	update_closest_lights()
	update_shader_lights()

# Find the active camera in the scene
func find_camera():
	camera = get_viewport().get_camera_2d()
	if not camera:
		# Try to find camera in the scene tree
		var cameras = get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			camera = cameras[0] as Camera2D

# Set camera manually if needed
func set_camera(cam: Camera2D):
	camera = cam

# Get current visible screen bounds in world coordinates
func get_screen_bounds() -> Rect2:
	if not camera:
		find_camera()
	
	var viewport_size = get_viewport().get_visible_rect().size
	var world_center = Vector2.ZERO
	var world_size = viewport_size
	
	if camera:
		world_center = camera.get_screen_center_position()
		world_size = viewport_size / camera.get_zoom()
	
	# Add margin to include lights that might affect the visible area
	var margin_vector = Vector2(screen_margin, screen_margin)
	return Rect2(
		world_center - world_size * 0.5 - margin_vector,
		world_size + margin_vector * 2
	)

# Calculate distance from light to visible screen area
func calculate_distance_to_screen(light: LightPoint) -> float:
	var screen_bounds = get_screen_bounds()
	var light_pos = light.world_position
	
	# If light is inside the screen bounds (including margin), distance is 0
	if screen_bounds.has_point(light_pos):
		return 0.0
	
	# Calculate distance to closest edge of screen bounds
	var closest_point = Vector2(
		clamp(light_pos.x, screen_bounds.position.x, screen_bounds.end.x),
		clamp(light_pos.y, screen_bounds.position.y, screen_bounds.end.y)
	)
	
	var distance = light_pos.distance_to(closest_point)
	
	# Subtract light radius so lights that could affect the screen are prioritized
	return max(0.0, distance - light.world_radius)

# Update which lights are closest to the screen
func update_closest_lights():
	# Calculate distances for all lights
	for light in light_points:
		light.distance_to_screen = calculate_distance_to_screen(light)
	
	# Sort lights by distance to screen (closest first)
	light_points.sort_custom(func(a: LightPoint, b: LightPoint): return a.distance_to_screen < b.distance_to_screen)

# Add a static light point at a specific position
func add_light_point(world_position: Vector2, world_radius: float, intensity: float = 1.0) -> int:
	var light = LightPoint.new(world_position, world_radius, intensity)
	light_points.append(light)
	return light_points.size() - 1

# Add a light that follows a specific node
func add_following_light(target_node: Node2D, world_radius: float, intensity: float = 1.0, offset: Vector2 = Vector2.ZERO) -> int:
	var current_pos = Vector2.ZERO
	if target_node:
		current_pos = target_node.get_global_transform_with_canvas().origin + offset
	
	var light = LightPoint.new(current_pos, world_radius, intensity, target_node, offset)
	light_points.append(light)
	return light_points.size() - 1

# Remove a light point by index
func remove_light(index: int) -> bool:
	if index >= 0 and index < light_points.size():
		light_points.remove_at(index)
		return true
	return false

# Remove all lights
func clear_lights():
	light_points.clear()

# Update light properties
func set_light_radius(index: int, world_radius: float):
	if index >= 0 and index < light_points.size():
		light_points[index].world_radius = world_radius

func set_light_intensity(index: int, intensity: float):
	if index >= 0 and index < light_points.size():
		light_points[index].intensity = intensity

func set_light_position(index: int, world_position: Vector2):
	if index >= 0 and index < light_points.size():
		light_points[index].world_position = world_position
		light_points[index].target_node = null  # Stop following node

# Set the margin around the screen for including lights
func set_screen_margin(margin: float):
	screen_margin = margin

# Set maximum number of lights to send to shader
func set_max_lights(max_count: int):
	max_lights = max_count

# Animate light properties
func animate_light_radius(index: int, target_radius: float, duration: float = 1.0) -> Tween:
	if index < 0 or index >= light_points.size():
		return null
	
	var tween = create_tween()
	var light = light_points[index]
	tween.tween_method(
		func(value): light.world_radius = value,
		light.world_radius,
		target_radius,
		duration
	)
	return tween

func animate_light_intensity(index: int, target_intensity: float, duration: float = 1.0) -> Tween:
	if index < 0 or index >= light_points.size():
		return null
	
	var tween = create_tween()
	var light = light_points[index]
	tween.tween_method(
		func(value): light.intensity = value,
		light.intensity,
		target_intensity,
		duration
	)
	return tween

# Animate global progress (fade in/out all lights)
func fade_in(duration: float = 1.0) -> Tween:
	var tween = create_tween()
	tween.tween_property(material, "shader_parameter/global_progress", 1.0, duration)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

func fade_out(duration: float = 1.0) -> Tween:
	var tween = create_tween()
	tween.tween_property(material, "shader_parameter/global_progress", 0.0, duration)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return tween

# Helper functions
func get_normalized_position(world_pos: Vector2) -> Vector2:
	var base_resolution = Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	
	var normalized_pos = Vector2(
		world_pos.x / base_resolution.x,
		world_pos.y / base_resolution.y
	)
	
	return normalized_pos.clamp(Vector2.ZERO, Vector2.ONE)

func get_normalized_radius(world_radius: float) -> float:
	var base_resolution = Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	# Use the average of width and height for radius normalization
	var base_size = (base_resolution.x + base_resolution.y) * 0.5
	return world_radius / base_size

func update_light_positions():
	for light in light_points:
		if light.target_node and is_instance_valid(light.target_node):
			light.world_position = light.target_node.get_global_transform_with_canvas().origin + light.offset

func update_shader_lights():
	if not material:
		return
	
	# Only send the closest lights to the shader (up to max_lights)
	var lights_to_send = min(light_points.size(), max_lights)
	material.set_shader_parameter("num_lights", lights_to_send)
	
	# Prepare arrays for shader
	var positions: Array[Vector2] = []
	var radii: Array[float] = []
	var intensities: Array[float] = []
	
	# Fill arrays with the closest light data
	for i in range(max_lights):
		if i < lights_to_send:
			var light = light_points[i]  # Already sorted by distance
			positions.append(get_normalized_position(light.world_position))
			radii.append(get_normalized_radius(light.world_radius))
			intensities.append(light.intensity)
		else:
			# Fill remaining slots with dummy data
			positions.append(Vector2.ZERO)
			radii.append(0.0)
			intensities.append(0.0)
	
	# Set shader parameters
	material.set_shader_parameter("light_positions", positions)
	material.set_shader_parameter("light_radii", radii)
	material.set_shader_parameter("light_intensities", intensities)

# Debug function to get info about current lights
func get_lights_info() -> Dictionary:
	return {
		"total_lights": light_points.size(),
		"lights_sent_to_shader": min(light_points.size(), max_lights),
		"screen_bounds": get_screen_bounds(),
		"camera": camera.name if camera else "No camera found"
	}

# Convenience methods for common use cases

# Add light following the player
func add_player_light(radius: float = 200.0, intensity: float = 1.0, offset: Vector2 = Vector2.ZERO) -> int:
	if GameManager.current_player:
		return add_following_light(GameManager.current_player, radius, intensity, offset)
	return -1

# Add lights for an array of nodes (useful for torches, lanterns, etc.)
func add_lights_for_nodes(nodes: Array[Node2D], radius: float = 150.0, intensity: float = 0.8) -> Array[int]:
	var indices: Array[int] = []
	for node in nodes:
		var index = add_following_light(node, radius, intensity)
		if index >= 0:
			indices.append(index)
	return indices

# Create a flickering effect for a specific light
func make_light_flicker(index: int, min_intensity: float = 0.3, max_intensity: float = 1.0, speed: float = 2.0):
	if index < 0 or index >= light_points.size():
		return
	
	var light = light_points[index]
	var tween = create_tween()
	tween.set_loops()
	tween.tween_method(
		func(value): light.intensity = value,
		max_intensity,
		min_intensity,
		1.0 / speed
	).set_trans(Tween.TRANS_SINE)
	tween.tween_method(
		func(value): light.intensity = value,
		min_intensity,
		max_intensity,
		1.0 / speed
	).set_trans(Tween.TRANS_SINE)
