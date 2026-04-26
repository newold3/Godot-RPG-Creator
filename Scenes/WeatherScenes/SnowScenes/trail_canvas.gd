class_name TrailCanvas
extends Node2D

## Array of texture paths to use for the snow holes
@export_file("*.png", "*.jpg", "*.webp") var hole_texture_paths: Array[String] = []
## Texture path to use for the recovering snow cover
@export_file("*.png", "*.jpg", "*.webp") var snow_cover_texture_path: String
## Common delay between draw passes for both snow and holes
@export var update_delay: float = 0.05
## Alpha value applied to the snow cover each pass (minimum safe value is 0.007)
@export var snow_alpha: float = 0.08
## Alpha value applied to the holes each pass
@export var hole_alpha: float = 0.8
## The scale factor to map global positions to the 1152x640 viewport
@export var map_scale: Vector2 = Vector2.ONE
## The top-left global position of the map
@export var map_origin: Vector2 = Vector2.ZERO
## Margin in pixels to consider an entity visible off-screen
@export var visibility_margin: float = 100.0

var _entities_data: Dictionary = {}
var _loaded_hole_textures: Array[Texture2D] = []
var _loaded_snow_texture: Texture2D
var _timer: float = 0.0
var _is_first_frame: bool = true
var _should_draw_snow: bool = false
var _should_draw_holes: bool = false
var _scale_setted: bool = false


## Initializes the snow system, loading textures from paths
func _ready() -> void:
	if not snow_cover_texture_path.is_empty() and ResourceLoader.exists(snow_cover_texture_path):
		_loaded_snow_texture = load(snow_cover_texture_path)
		
	for path in hole_texture_paths:
		if not path.is_empty() and ResourceLoader.exists(path):
			_loaded_hole_textures.append(load(path))
			
	_timer = update_delay


## Updates timers and the entities dictionary, triggering a single viewport update
func _physics_process(delta: float) -> void:
	var map: RPGMap = GameManager.current_map
	if not map: return
	
	if not _scale_setted and map:
		var map_rect = Vector2(map.get_used_rect(false).size)
		map_scale = map_rect / Vector2(1152, 640)
		_scale_setted = true
		
	if _is_first_frame:
		queue_redraw()
		get_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE
		return
		
	_timer -= delta
	
	if _timer <= 0.0:
		_timer = update_delay
		var dice = randi() % 100
		
		if dice <= 12:
			_should_draw_snow = true
			
		if dice <= 85:
			_should_draw_holes = true
			
			var current_entities = get_tree().get_nodes_in_group("player")
			current_entities += get_tree().get_nodes_in_group("follower")
			current_entities += get_tree().get_nodes_in_group("event")
			current_entities += get_tree().get_nodes_in_group("vehicle")
			
			var current_entities_set = {}
			var visible_rect = get_canvas_transform().affine_inverse() * get_viewport_rect()
			visible_rect = visible_rect.grow(visibility_margin)
			
			for entity in current_entities:
				if "is_invalid_event" in entity and entity.is_invalid_event: continue
				if not visible_rect.has_point(entity.global_position):
					continue
				current_entities_set[entity] = true
				if not _entities_data.has(entity):
					_entities_data[entity] = {
						"last_position": entity.global_position,
						"last_texture": _get_random_texture()
					}
				else:
					var data = _entities_data[entity]
					if entity.global_position != data.last_position:
						data.last_position = entity.global_position
						data.last_texture = _get_random_texture()
						
			var keys_to_remove = []
			for entity in _entities_data.keys():
				if not current_entities_set.has(entity) or not is_instance_valid(entity):
					keys_to_remove.append(entity)
					
			for key in keys_to_remove:
				_entities_data.erase(key)
				
		if _should_draw_snow or _should_draw_holes:
			queue_redraw()
			get_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE


## Draws the snow overlay and the scaled holes exactly once per triggered update
func _draw() -> void:
	var bg_rect = Rect2(0, 0, 1152, 640)
	
	if _is_first_frame:
		_is_first_frame = false
		draw_rect(bg_rect, Color.WHITE)
		return
		
	if _should_draw_snow:
		if _loaded_snow_texture:
			draw_texture_rect(_loaded_snow_texture, bg_rect, false, Color(1.0, 1.0, 1.0, snow_alpha))
		else:
			draw_rect(bg_rect, Color(1.0, 1.0, 1.0, snow_alpha))
		_should_draw_snow = false
		
	if _should_draw_holes:
		for entity in _entities_data.keys():
			if not is_instance_valid(entity): continue
			if entity == GameManager.current_player and entity.is_on_vehicle: continue
			if entity is RPGVehicle and GameManager.current_vehicle == entity and entity.flying_object and GameManager.current_player.is_on_vehicle:
				continue
			var data = _entities_data[entity]
			if data.last_texture:
				if not "extra_positions" in data:
					var mapped_pos = (data.last_position - map_origin) * map_scale
					var mapped_size = data.last_texture.get_size() * map_scale
					var draw_rect_dest = Rect2(mapped_pos - mapped_size * 0.5, mapped_size)
					draw_texture_rect(data.last_texture, draw_rect_dest, false, Color(0.0, 0.0, 0.0, hole_alpha))
				else:
					for p in data.extra_positions:
						var mapped_pos = (p - map_origin) * map_scale
						var mapped_size = data.last_texture.get_size() * map_scale
						var draw_rect_dest = Rect2(mapped_pos - mapped_size * 0.5, mapped_size)
						draw_texture_rect(data.last_texture, draw_rect_dest, false, Color(0.0, 0.0, 0.0, hole_alpha))
						data.last_texture = _get_random_texture()
		_should_draw_holes = false


## Returns a random loaded texture from the array
func _get_random_texture() -> Texture2D:
	if _loaded_hole_textures.is_empty():
		return null
	return _loaded_hole_textures[randi() % _loaded_hole_textures.size()]
