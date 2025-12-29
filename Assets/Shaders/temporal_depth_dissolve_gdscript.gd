extends Sprite2D

@export var max_delay: float = 0.01
# Distancia mínima entre puntos (cuadrado para evitar cálculos de raíz cuadrada)
@export var min_distance_squared: float = 25.0  # 5 píxeles de distancia

var shader_material: ShaderMaterial
var delay: float = 0.0
var targets: Array[Node2D] = []

# Utilizamos arrays directamente en lugar de objetos DepthPoint
var point_positions: PackedVector2Array = PackedVector2Array()
var point_owners: Array[Node2D] = []
var point_modes: PackedInt32Array = PackedInt32Array()
var point_start_times: PackedFloat32Array = PackedFloat32Array()
var point_fade_times: PackedFloat32Array = PackedFloat32Array()
var point_lifespans: PackedFloat32Array = PackedFloat32Array()
var point_fading: Array = []

# Array para búsqueda rápida de puntos por región
var spatial_grid: Dictionary = {}
var grid_cell_size: float = 20.0  # Tamaño de celda para agrupar puntos cercanos

const MAX_POINTS = 500

func _ready():
	texture = %TrailViewport.get_texture()
	shader_material = %MainSprite.material as ShaderMaterial
	
	# Inicializar arrays con capacidad suficiente
	point_positions.resize(MAX_POINTS)
	point_modes.resize(MAX_POINTS)
	point_start_times.resize(MAX_POINTS)
	point_fade_times.resize(MAX_POINTS)
	point_lifespans.resize(MAX_POINTS)
	point_fading.resize(MAX_POINTS)
	point_owners.resize(MAX_POINTS)

	# Inicializar valores en arrays
	for i in range(MAX_POINTS):
		point_positions[i] = Vector2.ZERO
		point_modes[i] = 0
		point_start_times[i] = 0.0
		point_fade_times[i] = 0.0
		point_lifespans[i] = 0.0
		point_fading[i] = false
		point_owners.push_back(null)
	
	# Inicializar shader con valores vacíos
	shader_material.set_shader_parameter("depth_points", point_positions)
	shader_material.set_shader_parameter("start_times", point_start_times)
	shader_material.set_shader_parameter("fade_times", point_fade_times)
	
	call_deferred("setup")

func setup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	adjust_to_the_map()
	add_targets()

func adjust_to_the_map() -> void:
	var map: RPGMap = get_tree().get_first_node_in_group("rpgmap")
	if map:
		var map_rect = map.get_used_rect(false)
		global_position = map_rect.position
		global_scale = Vector2(map_rect.size) / texture.get_size()

func add_targets() -> void:
	targets.clear()
	
	# Agregar jugador
	var player: LPCCharacter = get_tree().get_first_node_in_group("player")
	if player:
		targets.append(player)
	
	# Agregar vehículos
	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		targets.append(vehicle)
	
	# Agregar eventos del juego
	if GameManager.current_map:
		for ev in GameManager.current_map.current_ingame_events.values():
			if ev.lpc_event and ev.lpc_event is not EmptyLPCEvent:
				targets.append(ev.lpc_event)

func add_target(node: Node2D) -> void:
	if node and not targets.has(node):
		targets.append(node)

func remove_target(node: Node2D) -> void:
	targets.erase(node)

func clear_targets() -> void:
	targets.clear()

func is_in_viewport(pos: Vector2) -> bool:
	var player: LPCCharacter = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	
	var viewport_rect = Rect2(player.global_position - Vector2(200, 200), Vector2(400, 400))
	return viewport_rect.has_point(pos)

# Obtener la celda de cuadrícula para una posición
func get_grid_cell(pos: Vector2) -> String:
	var cell_x = floor(pos.x / grid_cell_size)
	var cell_y = floor(pos.y / grid_cell_size)
	return str(cell_x) + "_" + str(cell_y)

# Verificar si hay puntos cercanos en la cuadrícula espacial
func has_nearby_point(pos: Vector2, mode: int) -> bool:
	var cell = get_grid_cell(pos)
	
	# Verificar la celda actual y las 8 celdas vecinas
	var cells_to_check = [
		cell,
		get_grid_cell(pos + Vector2(grid_cell_size, 0)),
		get_grid_cell(pos + Vector2(-grid_cell_size, 0)),
		get_grid_cell(pos + Vector2(0, grid_cell_size)),
		get_grid_cell(pos + Vector2(0, -grid_cell_size)),
		get_grid_cell(pos + Vector2(grid_cell_size, grid_cell_size)),
		get_grid_cell(pos + Vector2(-grid_cell_size, grid_cell_size)),
		get_grid_cell(pos + Vector2(grid_cell_size, -grid_cell_size)),
		get_grid_cell(pos + Vector2(-grid_cell_size, -grid_cell_size))
	]
	
	for c in cells_to_check:
		if spatial_grid.has(c):
			var points_in_cell = spatial_grid[c]
			for point_idx in points_in_cell:
				# Solo comparar con puntos del mismo modo
				if point_modes[point_idx] != mode:
					continue
					
				# Verificar si está a una distancia menor que min_distance
				var distance_squared = pos.distance_squared_to(point_positions[point_idx])
				if distance_squared < min_distance_squared:
					return true
	
	return false

func create_depth_point(pos: Vector2, _owner: Node2D, mode: int):
	pos = pos.floor()
	
	# Comprobar si existe un punto cercano antes de agregar uno nuevo
	if has_nearby_point(pos, mode):
		return
	
	# Buscar un slot libre o reemplazar el punto más antiguo
	var insert_idx = -1
	
	# Primero buscar un slot vacío (con tiempo 0)
	for i in range(MAX_POINTS):
		if point_start_times[i] == 0.0:
			insert_idx = i
			break
	
	# Si no hay slots vacíos, siempre reemplazar el más antiguo
	if insert_idx == -1:
		var oldest_time = INF
		for i in range(MAX_POINTS):
			if point_start_times[i] < oldest_time:
				oldest_time = point_start_times[i]
				insert_idx = i
		
		# Eliminar el punto anterior de la cuadrícula espacial
		var old_cell = get_grid_cell(point_positions[insert_idx])
		if spatial_grid.has(old_cell) and spatial_grid[old_cell].has(insert_idx):
			spatial_grid[old_cell].erase(insert_idx)
	
	# Agregar el punto nuevo (siempre se ejecuta esta parte)
	var current_time = Time.get_ticks_msec() / 1000.0
	var lifespan = randf_range(1.0, 2.0)
	
	point_positions[insert_idx] = pos
	point_owners[insert_idx] = _owner
	point_modes[insert_idx] = mode
	point_start_times[insert_idx] = current_time
	point_fade_times[insert_idx] = 0.0
	point_lifespans[insert_idx] = lifespan
	point_fading[insert_idx] = false
	
	# Agregar a la cuadrícula espacial
	var cell = get_grid_cell(pos)
	if not spatial_grid.has(cell):
		spatial_grid[cell] = []
	spatial_grid[cell].append(insert_idx)

func _process(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Actualizar puntos existentes y eliminar los que expiraron
	for i in range(MAX_POINTS):
		if point_start_times[i] == 0.0:
			continue  # Slot vacío
			
		var should_remove = false
		
		if point_fading[i]:
			# Si está en fade, verificar si ya terminó
			if current_time - point_fade_times[i] > point_lifespans[i]:
				should_remove = true
		else:
			# Verificar si pasó su tiempo de vida
			if current_time - point_start_times[i] > point_lifespans[i]:
				var _owner = point_owners[i]
				if not is_instance_valid(_owner) or _owner.global_position != point_positions[i]:
					point_fading[i] = true
					point_fade_times[i] = current_time
		
		if should_remove:
			# Eliminar de la cuadrícula espacial
			var cell = get_grid_cell(point_positions[i])
			if spatial_grid.has(cell):
				spatial_grid[cell].erase(i)
			
			# Resetear el punto
			point_positions[i] = Vector2.ZERO
			point_owners[i] = null
			point_modes[i] = 0
			point_start_times[i] = 0.0
			point_fade_times[i] = 0.0
			point_lifespans[i] = 0.0
			point_fading[i] = false
	
	# Actualizar shader params
	shader_material.set_shader_parameter("depth_points", point_positions)
	shader_material.set_shader_parameter("start_times", point_start_times)
	shader_material.set_shader_parameter("fade_times", point_fade_times)


func _physics_process(delta: float) -> void:
	# Procesar la creación de nuevos puntos
	delay -= delta
	if delay <= 0.0:
		_add_new_points()
		delay = max_delay


func _add_new_points():
	var screen_rect = get_viewport_rect().grow(1.25)
	var map: RPGMap = get_tree().get_first_node_in_group("rpgmap")
	
	for target in targets:
		if not is_instance_valid(target):
			continue
			
		# Omitir personajes en vehículos o vehículos voladores
		if (target is LPCCharacter and target.is_on_vehicle) or \
		   (target is RPGVehicle and "is_flying" in target and target.is_flying) or \
			(target is CharacterBase and target.is_jumping):
			continue
		
		var trans = target.get_global_transform_with_canvas()
		if not screen_rect.has_point(trans.origin):
			continue
		
		var p1 = (target.global_position - global_position)
		var p2 = GameManager.current_map.get_wrapped_position(p1)
		
		var point_pos = p2
		var mode = 0
		
		var scaled_pos = point_pos / global_scale
		
		# Verificar dimensiones extras
		if map and "extra_dimensions" in target and target.get("extra_dimensions") is RPGDimension:
			mode = 1
			var extra_dim = target.get("extra_dimensions")
			
			var left = point_pos.x - (extra_dim.grow_left) * map.tile_size.x
			var right = point_pos.x + (extra_dim.grow_right + 1) * map.tile_size.x
			var up = point_pos.y - (extra_dim.grow_up) * map.tile_size.y
			var down = point_pos.y + (extra_dim.grow_down + 1) * map.tile_size.y
			
			# Optimización: calcular el incremento una sola vez
			var tile_x = map.tile_size.x
			var tile_y = map.tile_size.y
			var scale_factor = global_scale
			
			# Reducir la cantidad de puntos - incrementar el paso
			var step_x = max(tile_x, 5)
			var step_y = max(tile_y, 5)
			
			for x in range(left, right, step_x):
				for y in range(up, down, step_y):
					create_depth_point(Vector2(x, y) / scale_factor, target, mode)
		else:
			create_depth_point(scaled_pos, target, mode)
