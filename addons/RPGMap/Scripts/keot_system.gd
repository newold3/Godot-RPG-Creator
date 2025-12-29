class_name KeotSystem
extends Area2D

# -------------------------------------------------------------------------
# VARIABLES DE GESTIÓN
# -------------------------------------------------------------------------
# Mapea: Owner ID (Shape) -> { "target_z": int }
# Nos dice a qué altura debe subir el personaje si toca esta forma.
var _shape_data: Dictionary = {}

# Mapea: Coordenadas -> Owner ID
# Permite buscar qué shape corresponde a una coordenada para desactivarla con eventos.
# Nota: Varios tiles apuntarán al mismo Owner ID si fueron fusionados.
var _coords_to_owner: Dictionary = {}

# Factor de expansión: 0.5 significa medio tile extra por CADA lado.
# (Arriba, Abajo, Izquierda, Derecha).
var expansion_factor: float = 0.65

# -------------------------------------------------------------------------
# DEBUG
# -------------------------------------------------------------------------
var debug_draw: bool = false
var _debug_shapes_info: Array = [] # Almacena info de shapes para dibujar

# -------------------------------------------------------------------------
# INICIALIZACIÓN
# -------------------------------------------------------------------------
func _ready() -> void:
	# Configuración de Físicas
	# Layer 0: El Area en sí no necesita ser detectada, es un sensor.
	collision_layer = 0 
	
	# Mask: Define qué objetos activan este sistema.
	# Bit 1 (Player) + Bit 2 (Eventos) + Bit 3 (Vehículos). Ajusta a tu proyecto.
	collision_mask = 1 + 2 + 4 
	
	# Optimizaciones de Godot
	monitorable = false # Nadie nos puede detectar a nosotros (ahorra CPU)
	monitoring = true   # Nosotros detectamos a otros
	
	# Conexión de señales específicas de Shape (para saber QUÉ tile se tocó)
	body_shape_entered.connect(_on_shape_entered)
	body_shape_exited.connect(_on_shape_exited)

# -------------------------------------------------------------------------
# CONSTRUCCIÓN (BUILDER)
# -------------------------------------------------------------------------
# Llama a esto desde RPGMap._ready() pasándole los datos bakeados
func build_from_cache(map: RPGMap, baked_data: Dictionary) -> void:
	_clear_shapes()
	_debug_shapes_info.clear()
	
	if baked_data.is_empty():
		return
		
	var tile_size = Vector2(map.tile_size)
	
	# PASO 1: Agrupar coordenadas por altura (Target Z)
	# Solo podemos fusionar tiles que lleven a la misma altura.
	var groups: Dictionary = {} # { int_z: [Vector2i, ...] }
	
	for coords in baked_data:
		var z = baked_data[coords]
		if not groups.has(z):
			groups[z] = []
		groups[z].append(coords)

	# PASO 2: Procesar cada grupo con Greedy Meshing
	for z in groups:
		var tiles_list = groups[z]
		var rects = _apply_greedy_meshing(tiles_list)
		
		# PASO 3: Crear colisiones físicas para los rectángulos resultantes
		for rect in rects:
			_create_physics_shape(map, rect, z, tile_size)

# Algoritmo de Fusión Voraz (Greedy Meshing)
func _apply_greedy_meshing(tiles: Array) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var lookup: Dictionary = {} # { coords: existe_y_no_visitado }
	
	for t in tiles:
		lookup[t] = true
		
	# Ordenamos para barrer de Arriba-Izquierda a Abajo-Derecha
	tiles.sort_custom(func(a, b):
		if a.y != b.y: return a.y < b.y
		return a.x < b.x
	)
	
	for t in tiles:
		if not lookup[t]: continue # Ya fue fusionado
		
		var width = 1
		var height = 1
		var start = t
		
		# Expandir Derecha
		while lookup.has(start + Vector2i(width, 0)) and lookup[start + Vector2i(width, 0)]:
			width += 1
		
		# Expandir Abajo (Verificando el ancho completo)
		while true:
			var next_y = start.y + height
			var row_valid = true
			for x in range(width):
				var check = Vector2i(start.x + x, next_y)
				if not lookup.has(check) or not lookup[check]:
					row_valid = false
					break
			if row_valid:
				height += 1
			else:
				break
		
		# Marcar como visitados
		for y in range(height):
			for x in range(width):
				lookup[start + Vector2i(x, y)] = false
				
		result.append(Rect2i(start, Vector2i(width, height)))
		
	return result

func _create_physics_shape(map: RPGMap, rect: Rect2i, z_target: int, tile_size: Vector2) -> void:
	# Crear forma geométrica
	var shape = RectangleShape2D.new()
	var base_size = Vector2(rect.size) * tile_size
	var rect_size_px = Vector2(rect.size) * tile_size
	var size_padding = (tile_size * expansion_factor) * 2.0
	shape.size = base_size + size_padding
	
	# Añadir al PhysicsServer usando Owners (API rápida)
	var owner_id = create_shape_owner(self)
	shape_owner_add_shape(owner_id, shape)
	
	# Calcular posición del centro
	# map_to_local(rect.position) devuelve la Esquina Top-Left del primer tile
	var top_left_local = map.map_to_local(rect.position)
	var center_local = top_left_local + Vector2i(base_size / 2.0) # Usamos base_size para hallar el centro original
	var center_global = map.to_global(center_local)
	
	shape_owner_set_transform(owner_id, Transform2D(0, center_global))
	
	# Guardar Datos
	_shape_data[owner_id] = { "target_z": z_target }
	
	# Guardar info de debug
	if debug_draw:
		_debug_shapes_info.append({
			"pos": center_global,
			"size": shape.size,
			"z_target": z_target,
			"enabled": true
		})
	
	# Mapeo Inverso (Para eventos)
	for y in range(rect.size.y):
		for x in range(rect.size.x):
			var tile_pos = rect.position + Vector2i(x, y)
			_coords_to_owner[tile_pos] = owner_id


func _clear_shapes() -> void:
	for owner_id in _shape_data.keys():
		remove_shape_owner(owner_id)
	_shape_data.clear()
	_coords_to_owner.clear()
	_debug_shapes_info.clear()

# -------------------------------------------------------------------------
# LÓGICA RUNTIME (Detección y Z-Indexing)
# -------------------------------------------------------------------------

func _on_shape_entered(_rid: RID, body: Node2D, _body_index: int, local_shape_index: int) -> void:
	var owner_id = shape_find_owner(local_shape_index)
	if _shape_data.has(owner_id):
		var z_target = _shape_data[owner_id].target_z
		_add_shape_reference(body, owner_id, z_target)

func _on_shape_exited(_rid: RID, body: Node2D, _body_index: int, local_shape_index: int) -> void:
	var owner_id = shape_find_owner(local_shape_index)
	if _shape_data.has(owner_id):
		_remove_shape_reference(body, owner_id)

# --- SISTEMA DE CONTEO DE REFERENCIAS POR SHAPE (Anti-Parpadeo Mejorado) ---

func _add_shape_reference(body: Node2D, owner_id: int, z_level: int) -> void:
	# 1. Guardar backup natural si es la primera vez
	if not body.has_meta("_backup_z_index"):
		body.set_meta("_backup_z_index", body.z_index)
	
	# 2. Obtener diccionario de shapes activos
	var active_shapes: Dictionary = {}
	if body.has_meta("_keot_active_shapes"):
		active_shapes = body.get_meta("_keot_active_shapes")
	
	# 3. Registrar este shape específico
	if not active_shapes.has(owner_id):
		active_shapes[owner_id] = z_level
	
	body.set_meta("_keot_active_shapes", active_shapes)
	
	_apply_max_z(body)

func _remove_shape_reference(body: Node2D, owner_id: int) -> void:
	if not body.has_meta("_keot_active_shapes"): 
		return
	
	var active_shapes: Dictionary = body.get_meta("_keot_active_shapes")
	
	# Eliminar este shape específico
	if active_shapes.has(owner_id):
		active_shapes.erase(owner_id)
	
	body.set_meta("_keot_active_shapes", active_shapes)
	
	_apply_max_z(body)

func _apply_max_z(body: Node2D) -> void:
	if not body.has_meta("_backup_z_index"): return
	
	var natural_z = body.get_meta("_backup_z_index")
	var active_shapes = body.get_meta("_keot_active_shapes")
	
	if not natural_z: 
		return
	
	if active_shapes.is_empty():
		# Restaurar natural y limpiar
		if body.z_index != natural_z:
			body.z_index = natural_z
		# body.remove_meta("_backup_z_index") # Opcional: limpiar meta si quieres
		# body.remove_meta("_on_keot_surface")
	else:
		# Buscar la mayor altura entre todos los shapes activos
		var max_keot_z = -9999
		for owner_id in active_shapes.keys():
			var z_val = active_shapes[owner_id]
			if z_val > max_keot_z: 
				max_keot_z = z_val
		
		# Regla del Pájaro: Usar el mayor entre (Natural vs KEOT)
		var final_z = max(natural_z, max_keot_z)
		
		if body.z_index != final_z:
			body.z_index = final_z
			body.set_meta("_on_keot_surface", true) # Útil para tu lógica de movimiento

# -------------------------------------------------------------------------
# API PARA EVENTOS (Enable/Disable Tiles)
# -------------------------------------------------------------------------
# Llama a esto desde tus eventos: KeotSystem.set_tile_active(Vector2i(5,5), true/false)
func set_tile_active(coords: Vector2i, active: bool) -> void:
	if _coords_to_owner.has(coords):
		var owner_id = _coords_to_owner[coords]
		# Desactiva la colisión física. Si es un shape fusionado, se desactiva todo el bloque.
		shape_owner_set_disabled(owner_id, not active)
		
		# Actualizar estado en debug si está activo
		if debug_draw:
			for shape_info in _debug_shapes_info:
				if shape_info.get("owner_id") == owner_id:
					shape_info["enabled"] = active

# -------------------------------------------------------------------------
# DEBUG DRAW
# -------------------------------------------------------------------------
func _draw() -> void:
	if not debug_draw:
		return
	
	for shape_info in _debug_shapes_info:
		var pos = to_local(shape_info["pos"])
		var size = shape_info["size"]
		var z_target = shape_info["z_target"]
		var enabled = shape_info.get("enabled", true)
		
		# Color según estado
		var color = Color.GREEN if enabled else Color.RED
		color.a = 0.3
		
		# Dibujar rectángulo
		var rect = Rect2(pos - size / 2.0, size)
		draw_rect(rect, color)
		
		# Dibujar borde
		var border_color = Color.GREEN if enabled else Color.RED
		draw_rect(rect, border_color, false, 2.0)
		
		# Dibujar Z target
		draw_string(ThemeDB.fallback_font, pos, "Z: %d" % z_target, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)
