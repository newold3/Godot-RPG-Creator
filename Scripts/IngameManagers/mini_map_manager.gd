extends CanvasLayer
class_name RPGMinimap

## Reference to the SubViewport that renders the minimap.
@export var minimap_viewport: SubViewport

## Internal camera of the minimap.
@export var camera: Camera2D

## Container for the duplicated TileMapLayers.
@export var tilemap_container: Node2D

## Node used to draw dynamic entities via _draw().
@export var entities_drawer: Node2D

## Controls camera zoom: 0.0 fits the map to the viewport, 1.0 focuses on a close area.
@export_range(0.0, 1.0, 0.01) var zoom_factor: float = 0.0

## If your SubViewport is larger than your UI mask, define the real visible size here (e.g. 250x250) to fix zoom math.
@export var visible_area_size: Vector2 = Vector2.ZERO

## If true, the camera will stop at map edges. If false, it stays centered on player.
@export var limit_camera_to_map: bool = false

## Defines the minimum visual size (in viewport pixels) for entities on the minimap to prevent them from disappearing.
@export var min_entity_icon_size: float = 16.0

## Default icon used for events if they don't provide a specific one.
@export var default_event_icon: Texture

## Default icon used for extraction events if they don't provide a specific one.
@export var default_extraction_event_icon: Texture

## Default icon used for the player if they don't provide a specific one.
@export var default_player_icon: Texture

## Default icon used for followers if they don't provide a specific one.
@export var default_follower_icon: Texture

## Default icon used for land vehicles (type 0) if they don't provide a specific one.
@export var default_vehicle_land_icon: Texture

## Default icon used for sea vehicles (type 1) if they don't provide a specific one.
@export var default_vehicle_sea_icon: Texture

## Default icon used for air vehicles (type 2) if they don't provide a specific one.
@export var default_vehicle_air_icon: Texture

## If true, displays a passability overlay using the map's pathfinder data.
@export var show_passability: bool = false:
	set(value):
		show_passability = value
		_update_tilemaps()
		_update_passability_cache()
		if is_instance_valid(entities_drawer):
			entities_drawer.queue_redraw()

## Color for passable tiles in the overlay.
@export var passable_color: Color = Color(0.0, 1.0, 0.0, 0.3):
	set(value):
		passable_color = value
		if show_passability:
			_update_passability_cache()
			if is_instance_valid(entities_drawer):
				entities_drawer.queue_redraw()

## Color for impassable tiles in the overlay.
@export var impassable_color: Color = Color(1.0, 0.0, 0.0, 0.5):
	set(value):
		impassable_color = value
		if show_passability:
			_update_passability_cache()
			if is_instance_valid(entities_drawer):
				entities_drawer.queue_redraw()

var target_map: RPGMap
var map_rect: Rect2
var _icon_texture_cache: Dictionary = {}
var _passability_texture: ImageTexture



## Initializes the minimap, connects signals and prepares the camera limits and zoom.
func setup(map: RPGMap) -> void:
	target_map = map
	map_rect = target_map.get_used_rect(false)
	
	if minimap_viewport:
		minimap_viewport.transparent_bg = true
		
	_update_tilemaps()
	_update_passability_cache()
	
	if not entities_drawer.draw.is_connected(_on_entities_drawer_draw):
		entities_drawer.draw.connect(_on_entities_drawer_draw)



## Clears existing layers and duplicates current TileMapLayers from the target map.
func _update_tilemaps() -> void:
	if not is_instance_valid(tilemap_container):
		return
		
	for child in tilemap_container.get_children():
		child.queue_free()
		
	if show_passability or not is_instance_valid(target_map):
		return
		
	for child in target_map.get_children():
		if child is TileMapLayer:
			var copy = child.duplicate()
			copy.position = child.global_position
			tilemap_container.add_child(copy)
			
			if not child.changed.is_connected(_update_tilemaps):
				child.changed.connect(_update_tilemaps)



## Calculates camera zoom and limits. Maps 0.0 to full map, 0.5 to half, and 1.0 to close-up.
func _calculate_camera_settings() -> void:
	if not minimap_viewport or not target_map or minimap_viewport.size.x <= 1:
		return
		
	var calc_size = visible_area_size if visible_area_size.x > 0 and visible_area_size.y > 0 else Vector2(minimap_viewport.size)
	var world_size = Vector2(map_rect.size)
	
	if world_size.x <= 0 or world_size.y <= 0:
		return
		
	var z_min_x = calc_size.x / world_size.x
	var z_min_y = calc_size.y / world_size.y
	var z_min = Vector2(min(z_min_x, z_min_y), min(z_min_x, z_min_y))
	var z_max_val = (min(calc_size.x, calc_size.y) * 0.5) / 64.0
	var z_max = Vector2(z_max_val, z_max_val)
	var final_zoom: Vector2
	
	if zoom_factor <= 0.5:
		var t = zoom_factor / 0.5
		final_zoom = z_min.lerp(z_min * 2.0, t)
	else:
		var t = (zoom_factor - 0.5) / 0.5
		final_zoom = (z_min * 2.0).lerp(z_max, t)
		
	camera.zoom = final_zoom
	
	if not limit_camera_to_map:
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000
		return
		
	if target_map.infinite_horizontal_scroll:
		camera.limit_left = -10000000
		camera.limit_right = 10000000
	else:
		camera.limit_left = int(map_rect.position.x)
		camera.limit_right = int(map_rect.end.x)
		
	if target_map.infinite_vertical_scroll:
		camera.limit_top = -10000000
		camera.limit_bottom = 10000000
	else:
		camera.limit_top = int(map_rect.position.y)
		camera.limit_bottom = int(map_rect.end.y)



## Updates camera position and requests a redraw for dynamic entities.
func _physics_process(_delta: float) -> void:
	if not target_map:
		return
		
	_calculate_camera_settings()
	
	var follow_target: Node2D = null
	var players = get_tree().get_nodes_in_group("player")
	
	if players.size() > 0:
		var p = players[0]
		if p.get("is_on_vehicle") and is_instance_valid(p.get("current_vehicle")):
			follow_target = p.current_vehicle
		else:
			follow_target = p
			
	if is_instance_valid(follow_target):
		camera.global_position = follow_target.global_position
		
	if is_instance_valid(entities_drawer):
		entities_drawer.queue_redraw()



## Resolves the icon data into a valid Texture2D, caching the results to ensure high performance on repeated calls.
func _resolve_icon_texture(icon_data: Variant) -> Texture2D:
	if not icon_data:
		return null
		
	if icon_data is Texture2D:
		return icon_data
		
	if _icon_texture_cache.has(icon_data):
		return _icon_texture_cache[icon_data]
		
	var tex: Texture2D = null
	
	if icon_data is RPGIcon:
		tex = icon_data.get_texture()
	elif typeof(icon_data) == TYPE_STRING and not icon_data.is_empty():
		if ResourceLoader.exists(icon_data):
			var res = load(icon_data)
			if res is Texture2D:
				tex = res
				
	if tex:
		_icon_texture_cache[icon_data] = tex
		
	return tex



## Generates a highly optimized texture mapping the passability grid directly from the AStar graph.
func _update_passability_cache() -> void:
	_passability_texture = null
	
	if not show_passability or not is_instance_valid(target_map):
		return
		
	if not target_map.get("pathfinder") or not target_map.pathfinder.has_method("_get_id_from_tile"):
		return
		
	var pathfinder = target_map.pathfinder
	var map_size = target_map.get_map_size_in_tiles()
	
	if map_size.x <= 0 or map_size.y <= 0:
		return
		
	var img = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	
	for x in range(map_size.x):
		for y in range(map_size.y):
			var tile = Vector2i(x, y)
			var id = pathfinder._get_id_from_tile(tile)
			
			if pathfinder.has_point(id):
				if pathfinder.is_point_disabled(id):
					img.set_pixel(x, y, impassable_color)
				else:
					img.set_pixel(x, y, passable_color)
			else:
				img.set_pixel(x, y, impassable_color)
				
	_passability_texture = ImageTexture.create_from_image(img)



## Draws the passability overlay and entities as unified icons, ensuring consistent size and visibility.
func _on_entities_drawer_draw() -> void:
	if not is_instance_valid(target_map) or not is_instance_valid(camera):
		return
		
	if show_passability and _passability_texture:
		var map_px_size = Vector2(target_map.get_map_size_in_tiles()) * Vector2(target_map.tile_size)
		entities_drawer.draw_texture_rect(_passability_texture, Rect2(Vector2.ZERO, map_px_size), false)
		
	var current_zoom = camera.zoom.x
	var tile_size = Vector2(target_map.tile_size)
	var min_world_size = Vector2.ONE * (min_entity_icon_size / current_zoom)
	var base_size = Vector2(max(tile_size.x, min_world_size.x), max(tile_size.y, min_world_size.y))
	var followers = get_tree().get_nodes_in_group("follower")
	
	var events = get_tree().get_nodes_in_group("event")
	
	events.sort_custom(func(a, b):
		if a.global_position.y == b.global_position.y:
			return a.global_position.x < b.global_position.x
		return a.global_position.y < b.global_position.y
	)
	
	followers.reverse()
	
	var ordered_groups = [
		{"name": "event", "nodes": events},
		{"name": "extraction_event", "nodes": get_tree().get_nodes_in_group("extraction_event")},
		{"name": "vehicle", "nodes": get_tree().get_nodes_in_group("vehicle")},
		{"name": "follower", "nodes": followers},
		{"name": "player", "nodes": get_tree().get_nodes_in_group("player")}
	]
	
	for group_data in ordered_groups:
		var group_name = group_data["name"]
		
		for node in group_data["nodes"]:
			if not is_instance_valid(node) or not node.is_visible():
				continue
				
			var icon_data = node.get_icon() if node.has_method("get_icon") else null
			var tex = _resolve_icon_texture(icon_data)
			
			if not tex:
				var fallback_data = null
				
				if group_name == "event":
					fallback_data = default_event_icon
				elif group_name == "extraction_event":
					fallback_data = default_extraction_event_icon
				elif group_name == "player":
					fallback_data = default_player_icon
				elif group_name == "follower":
					fallback_data = default_follower_icon
				elif group_name == "vehicle":
					var v_type = node.get("vehicle_type") if node.get("vehicle_type") != null else 0
					
					if v_type == 1:
						fallback_data = default_vehicle_sea_icon
					elif v_type == 2:
						fallback_data = default_vehicle_air_icon
					else:
						fallback_data = default_vehicle_land_icon
						
				tex = _resolve_icon_texture(fallback_data)
				
			if tex:
				var draw_pos = node.global_position - (base_size / 2.0)
				entities_drawer.draw_texture_rect(tex, Rect2(draw_pos, base_size), false)
