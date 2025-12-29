extends Camera2D

## Character to follow (backwards compatibility)
@export var target: Node2D
## Array of targets with priorities to follow (new feature)
## Each element is a dictionary: {"target": Node2D, "priority": int}
@export var targets: Array[Dictionary] = []
## Whether to use multi-target mode
@export var use_multi_target: bool = false
## Margin around targets when in multi-target mode
@export var multi_target_margin: float = 100.0

## Camera speed when moving
@export var smooth_speed: float = 14.5
## The source of random values for shake
@export var noise: FastNoiseLite
## Zoom parameters
@export var zoom_speed: float = 4.0
@export var min_zoom: float = 0.2
@export var max_zoom: float = 10.0

# Internal variables
var traumas := {} # id -> { "amount": float, "time": float }
var max_trauma_power: float = 0.0
var shake_time: float = 0.0
var _trauma_uid := 0
var target_zoom: Vector2 = Vector2.ONE

func _ready():
	randomize()
	target_zoom = zoom
	add_to_group("camera")
	
	# Auto-enable multi-target mode if targets array is not empty
	if not targets.is_empty():
		use_multi_target = true
	
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()

func set_target(_target: Node2D) -> void:
	target = _target
	use_multi_target = false
	if target:
		global_position = apply_camera_limits(get_target_closest_position(target, global_position))

func add_target_to_array(new_target: Node2D, priority: int = 5):
	if new_target:
		# Check if target already exists and update priority
		for i in range(targets.size()):
			if targets[i].has("target") and targets[i]["target"] == new_target:
				targets[i]["priority"] = priority
				return
		
		# Add new target with priority
		targets.append({"target": new_target, "priority": priority})
		use_multi_target = true


func is_following(event: Node) -> bool:
	if target == event: return true
	for obj: Dictionary in targets:
		if obj.target == event: return true
	return false


func remove_target_from_array(target_to_remove: Node2D):
	for i in range(targets.size() - 1, -1, -1):
		if targets[i].has("target") and targets[i]["target"] == target_to_remove:
			targets.remove_at(i)
			break
	
	if targets.is_empty():
		use_multi_target = false

func clear_targets():
	targets.clear()
	use_multi_target = false

func set_targets_array(new_targets: Array[Dictionary]):
	targets = new_targets
	use_multi_target = not targets.is_empty()
	target = null

func add_trauma(amount: float, time: float) -> void:
	_trauma_uid += 1
	var id := _trauma_uid
	traumas[id] = {
		"amount": amount,
		"time": time
	}

# Nueva función para obtener la posición más cercana de un target (virtual o física)
func get_target_closest_position(target_node: Node2D, reference_pos: Vector2) -> Vector2:
	"""Get the closest position of a target (virtual or physical) relative to a reference position"""
	if not target_node.has_method("get_current_virtual_tile_position"):
		return target_node.global_position
	
	var virtual_pos = target_node.get_current_virtual_tile_position()
	var physical_pos = target_node.global_position
	
	var virtual_distance = reference_pos.distance_squared_to(virtual_pos)
	var physical_distance = reference_pos.distance_squared_to(physical_pos)
	
	# Usar la posición que esté más cerca de la referencia
	if virtual_distance <= physical_distance:
		return virtual_pos
	else:
		return physical_pos

# Función auxiliar para obtener posición virtual sin comparación
func get_target_virtual_position(target_node: Node2D) -> Vector2:
	"""Get the virtual position of a target if it has the method, otherwise return global_position"""
	if target_node.has_method("get_current_virtual_tile_position"):
		return target_node.get_current_virtual_tile_position()
	else:
		return target_node.global_position

func apply_camera_limits(desired_position: Vector2) -> Vector2:
	"""Apply camera limits to a desired position"""
	var limited_position = desired_position
	
	# Apply limit_left
	if limit_left != 10000000:
		limited_position.x = max(limited_position.x, limit_left)
	
	# Apply limit_right
	if limit_right != 10000000:
		limited_position.x = min(limited_position.x, limit_right)
	
	# Apply limit_top
	if limit_top != 10000000:
		limited_position.y = max(limited_position.y, limit_top)
	
	# Apply limit_bottom
	if limit_bottom != 10000000:
		limited_position.y = min(limited_position.y, limit_bottom)
	
	return limited_position

func fast_reposition() -> void:
	"""Position camera and set zoom instantly for any mode"""
	if use_multi_target and not targets.is_empty():
		var valid_targets = get_valid_targets()
		if valid_targets.size() == 1:
			# Single target in multi-target mode: use virtual position if available
			var single_target = valid_targets[0]["target"]
			var target_pos = get_target_virtual_position(single_target)
			global_position = apply_camera_limits(target_pos)
		else:
			# Multiple targets: use weighted positioning and auto-zoom
			var current_target_pos = get_multi_target_position()
			global_position = apply_camera_limits(current_target_pos)
			handle_multi_target_zoom()
			zoom = target_zoom  # Aplicar zoom instantáneamente
	elif target:
		# Single target mode: use virtual position if available
		var target_pos = get_target_virtual_position(target)
		global_position = apply_camera_limits(target_pos)
	# Asegurar que zoom se aplica instantáneamente (si hay zoom a aplicar)
	if zoom != target_zoom:
		zoom = target_zoom

func get_target_position_and_zoom() -> Dictionary:
	var data = {}
	
	data.zoom = target_zoom
	if use_multi_target and not targets.is_empty():
		data.position = get_multi_target_position()
		handle_multi_target_zoom()
	elif target:
		data.position = get_target_closest_position(target, global_position)
	else:
		data.position = global_position
	
	return data

func _process(delta: float) -> void:
	if not enabled:
		return

	# Determine which mode to use
	var current_target_pos: Vector2
	
	if use_multi_target and not targets.is_empty():
		current_target_pos = get_multi_target_position()
		handle_multi_target_zoom()
	elif target:
		current_target_pos = get_target_closest_position(target, global_position)
	else:
		return
	
	# Handle zoom smoothing (CORREGIDO)
	if zoom.distance_to(target_zoom) > 0.01:
		var zoom_weight = 1.0 - exp(-delta * zoom_speed)
		zoom = zoom.lerp(target_zoom, zoom_weight)
	
	# Apply shake effect
	if traumas.size() > 0:
		var max_power: float = 0
		var max_trauma: Dictionary
		for key in traumas.keys():
			var trauma: Dictionary = traumas[key]
			if trauma.amount > max_power:
				max_power = trauma.amount
				max_trauma = trauma
			trauma.time -= delta
			if trauma.time <= 0.0:
				traumas.erase(key)
		
		if max_trauma: 
			max_trauma_power = lerp(max_trauma_power, max_trauma.amount, 0.2)
			shake_time = max_trauma.time
			if max_trauma_power > 0:
				offset = Vector2(
					get_noise(0),
					get_noise(1)
				)
			else:
				max_trauma_power = 0
				offset = Vector2.ZERO
		else:
			offset = Vector2.ZERO
	
	# Update camera position
	if use_multi_target and not targets.is_empty():
		var valid_targets = get_valid_targets()
		if valid_targets.size() == 1:
			# Single target in multi-target mode: use original behavior with limits
			var single_target = valid_targets[0]["target"]
			handle_single_target_movement(get_target_closest_position(single_target, global_position), single_target, delta)
		else:
			# Multiple targets: move directly to weighted center with limits applied
			var pos_weight = 1.0 - exp(-delta * smooth_speed)
			var desired_position = global_position.lerp(current_target_pos, pos_weight)
			global_position = apply_camera_limits(desired_position)
	else:
		# Original single-target behavior with margins and limits
		if target:
			handle_single_target_movement(current_target_pos, target, delta)


func get_multi_target_position() -> Vector2:
	var valid_targets = get_valid_targets()
	if valid_targets.is_empty():
		return global_position
	
	if valid_targets.size() == 1:
		return get_target_closest_position(valid_targets[0]["target"], global_position)
	
	# Calculate weighted center based on priorities using CLOSEST positions
	var total_weight: float = 0.0
	var weighted_position: Vector2 = Vector2.ZERO
	var camera_pos = global_position
	
	for target_data in valid_targets:
		var target_node = target_data["target"]
		var priority = target_data["priority"]
		
		# Use closest position (virtual or physical) relative to current camera position
		var closest_pos = get_target_closest_position(target_node, camera_pos)
		weighted_position += closest_pos * priority
		total_weight += priority
	
	if total_weight > 0:
		weighted_position /= total_weight
	
	return weighted_position

func get_targets_bounds(valid_targets: Array[Dictionary]) -> Rect2:
	if valid_targets.is_empty():
		return Rect2()
	
	# Use closest positions for bounds calculation
	var camera_pos = global_position
	var min_pos = get_target_closest_position(valid_targets[0]["target"], camera_pos)
	var max_pos = get_target_closest_position(valid_targets[0]["target"], camera_pos)
	
	for target_data in valid_targets:
		var closest_pos = get_target_closest_position(target_data["target"], camera_pos)
		var priority = target_data["priority"]
		
		# Expand bounds more for higher priority targets
		var expansion = priority * 10.0  # Adjust this multiplier as needed
		
		min_pos.x = min(min_pos.x, closest_pos.x - expansion)
		min_pos.y = min(min_pos.y, closest_pos.y - expansion)
		max_pos.x = max(max_pos.x, closest_pos.x + expansion)
		max_pos.y = max(max_pos.y, closest_pos.y + expansion)
	
	return Rect2(min_pos, max_pos - min_pos)

func handle_multi_target_zoom():
	var valid_targets = get_valid_targets()
	if valid_targets.is_empty():
		return
	
	if valid_targets.size() == 1:
		# Don't auto-zoom for single target in multi-target mode
		return
	
	# Calculate required zoom to fit all targets (only for multiple targets)
	# Now uses virtual positions through get_targets_bounds
	var bounds = get_targets_bounds(valid_targets)
	var viewport_size = get_viewport_rect().size
	
	# Consider camera limits when calculating bounds for zoom
	var limited_bounds = get_limited_bounds(bounds)
	var limited_bounds_size = limited_bounds.size + Vector2.ONE * multi_target_margin * 2
	
	if limited_bounds_size.x > 0 and limited_bounds_size.y > 0:
		var zoom_x = viewport_size.x / limited_bounds_size.x
		var zoom_y = viewport_size.y / limited_bounds_size.y
		var required_zoom = min(zoom_x, zoom_y)
		
		# Apply zoom limits
		required_zoom = clamp(required_zoom, min_zoom, max_zoom)
		target_zoom = Vector2(required_zoom, required_zoom)

func get_limited_bounds(original_bounds: Rect2) -> Rect2:
	"""Adjust bounds to respect camera limits"""
	var limited_bounds = original_bounds
	
	# Adjust bounds based on camera limits
	if limit_left != -10000000:
		limited_bounds.position.x = max(limited_bounds.position.x, limit_left)
	
	if limit_right != 10000000:
		limited_bounds.end.x = min(limited_bounds.end.x, limit_right)
	
	if limit_top != -10000000:
		limited_bounds.position.y = max(limited_bounds.position.y, limit_top)
	
	if limit_bottom != 10000000:
		limited_bounds.end.y = min(limited_bounds.end.y, limit_bottom)
	
	# Ensure bounds are still valid after limiting
	if limited_bounds.end.x < limited_bounds.position.x:
		limited_bounds.end.x = limited_bounds.position.x
	
	if limited_bounds.end.y < limited_bounds.position.y:
		limited_bounds.end.y = limited_bounds.position.y
	
	return limited_bounds

func get_valid_targets() -> Array[Dictionary]:
	var valid_targets: Array[Dictionary] = []
	
	for target_data in targets:
		if (target_data.has("target") and target_data.has("priority") and 
			is_instance_valid(target_data["target"]) and 
			target_data["target"].visible):
			valid_targets.append(target_data)
	
	return valid_targets


func handle_single_target_movement(target_pos: Vector2, target_node: Node2D, delta: float):
	var viewport_size = get_viewport_rect().size
	var margin_left = drag_left_margin * viewport_size.x
	var margin_top = drag_top_margin * viewport_size.y
	var margin_right = viewport_size.x - margin_left
	var margin_bottom = viewport_size.y - margin_top
	
	var camera_pos = global_position
	
	# For single target movement, we need to check screen position using global position
	# but move to virtual position
	var target_screen_pos = target_node.get_global_transform_with_canvas().origin
	
	var desired_position = camera_pos
	
	if (target_screen_pos.x < margin_left or 
		target_screen_pos.x > margin_right or 
		target_screen_pos.y < margin_top or 
		target_screen_pos.y > margin_bottom):
		desired_position = target_pos
	
	# Smoothly move the camera with limits applied (CORREGIDO)
	var pos_weight = 1.0 - exp(-delta * smooth_speed)
	var new_position = global_position.lerp(desired_position, pos_weight)
	global_position = apply_camera_limits(new_position)


func instantaneous_positioning() -> void:
	fast_reposition()

func get_target_priority(target_node: Node2D) -> int:
	"""Get priority of a specific target, returns -1 if not found"""
	for target_data in targets:
		if target_data.has("target") and target_data["target"] == target_node:
			return target_data.get("priority", 5)
	return -1

func update_target_priority(target_node: Node2D, new_priority: int):
	"""Update priority of an existing target"""
	for target_data in targets:
		if target_data.has("target") and target_data["target"] == target_node:
			target_data["priority"] = new_priority
			return


func get_noise(_seed: int) -> float:
	noise.seed = _seed
	return noise.get_noise_1d(randf() * shake_time) * max_trauma_power


func set_zoom_level(level: float) -> void:
	target_zoom = Vector2(clamp(level, min_zoom, max_zoom), clamp(level, min_zoom, max_zoom))

func zoom_in() -> void:
	set_zoom_level(min_zoom)

func zoom_out() -> void:
	set_zoom_level(max_zoom)
