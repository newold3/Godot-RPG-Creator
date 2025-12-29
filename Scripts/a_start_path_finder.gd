class_name AStarPathfinder
extends Node

var game_map: RPGMap
var node_data: Dictionary = {}  # {nodo_id: {target: Vector2i, history: Array[Vector2i], last_pos: Vector2i, stuck_frames: int}}
var MAX_HISTORY: int = 15
var STUCK_THRESHOLD: int = 30  # frames sin moverse antes de considerar atascado

func _init(map: Object) -> void:
	game_map = map

## Retorna el mejor tile vecino hacia el objetivo, o null si no debe moverse
func get_next_tile(moving_node: Node, current_pos: Vector2i, target_pos: Vector2i) -> Variant:
	if not game_map:
		return Vector2i.ZERO
	
	var node_id = moving_node.get_instance_id()
	
	# Si el target cambió, limpia el historial
	if node_id in node_data and node_data[node_id]["target"] != target_pos:
		node_data[node_id]["history"].clear()
	
	# Inicializa los datos del nodo si no existen
	if not node_id in node_data:
		node_data[node_id] = {
			"target": target_pos,
			"history": [],
			"last_pos": current_pos,
			"stuck_frames": 0
		}
	else:
		node_data[node_id]["target"] = target_pos
	
	# Si ya está adyacente al objetivo, limpia el historial y no se mueve
	if _is_adjacent(current_pos, target_pos):
		node_data[node_id]["history"].clear()
		return null
	
	var history = node_data[node_id]["history"]
	var is_stuck = false
	
	# Detecta si el nodo está atascado
	if current_pos == node_data[node_id]["last_pos"]:
		node_data[node_id]["stuck_frames"] += 1
		# Si está atascado demasiado tiempo, limpia el historial para forzar otro camino
		if node_data[node_id]["stuck_frames"] > STUCK_THRESHOLD:
			history.clear()
			node_data[node_id]["stuck_frames"] = 0
			is_stuck = true
	else:
		node_data[node_id]["stuck_frames"] = 0
	
	node_data[node_id]["last_pos"] = current_pos
	
	# Obtiene los 8 vecinos
	var neighbors = _get_8_neighbors(current_pos)
	var valid_neighbors: Array = []
	
	# Filtra vecinos válidos
	for neighbor_pos in neighbors:
		# Si no está atascado, evita el historial
		if not is_stuck and neighbor_pos in history:
			continue
		
		# Verifica si es caminable
		if not _is_valid_move(moving_node, neighbor_pos):
			continue
		
		valid_neighbors.append(neighbor_pos)
	
	# Si no hay vecinos válidos
	if valid_neighbors.is_empty():
		return null
	
	# Ordena por distancia al objetivo (menor distancia = mejor)
	valid_neighbors.sort_custom(func(a, b): 
		return _manhattan(a, target_pos) < _manhattan(b, target_pos)
	)
	
	# Retorna el mejor (primero en la lista ordenada)
	var best_tile = valid_neighbors[0]
	
	# Añade la posición actual al historial
	history.append(current_pos)
	
	# Limita el tamaño del historial
	if history.size() > MAX_HISTORY:
		history.pop_front()
	
	return best_tile

func _get_8_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		pos + Vector2i.RIGHT,
		pos + Vector2i.LEFT,
		pos + Vector2i.DOWN,
		pos + Vector2i.UP,
		pos + Vector2i(1, 1),
		pos + Vector2i(1, -1),
		pos + Vector2i(-1, 1),
		pos + Vector2i(-1, -1)
	]

func _is_adjacent(pos: Vector2i, target: Vector2i) -> bool:
	if not game_map:
		return false
	
	pos = game_map.get_wrapped_tile(pos)
	target = game_map.get_wrapped_tile(target)
	
	var distance = abs(pos.x - target.x) + abs(pos.y - target.y)
	return distance <= 1

func _is_valid_move(moving_node: Node, tile_pos: Vector2i) -> bool:
	if not game_map:
		return true
	
	tile_pos = game_map.get_wrapped_position(tile_pos)
	
	# Verifica si es pasable según la dirección del nodo
	if not game_map.is_passable(tile_pos, moving_node.current_direction, moving_node, true):
		return false
	
	# Verifica si el nodo puede caminar sobre el terreno
	if not game_map.can_move_over_terrain(tile_pos, moving_node.can_move_on_terrains):
		return false
	
	return true

func _manhattan(a: Vector2i, b: Vector2i) -> float:
	if not game_map:
		return float(abs(a.x - b.x) + abs(a.y - b.y))
	
	var dx = abs(a.x - b.x)
	var dy = abs(a.y - b.y)
	var map_size = game_map.get_used_rect(false).size
	
	if dx > map_size.x / 2:
		dx = map_size.x - dx
	if dy > map_size.y / 2:
		dy = map_size.y - dy
	
	return float(dx + dy)


func vector2_to_direction(vec: Vector2i) -> int:
	# Convierte un Vector2i a una dirección de 4 direcciones
	if vec == Vector2i(0, -1): return 4    # Norte
	if vec == Vector2i(1, 0): return 2     # Este
	if vec == Vector2i(0, 1): return 8     # Sur
	if vec == Vector2i(-1, 0): return 1    # Oeste
	return 0  # Desconocido
