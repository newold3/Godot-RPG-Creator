class_name IngameMapShadowManager
extends RefCounted


var map: RPGMap
var cached_environment_textures: Dictionary = {}
var shadows: Dictionary = {
	"tiles": {},
	"vehicles": {},
	"events": {},
	"players": {}
}

var editor_shadow_canvas: Node2D
var shadow_need_refresh: bool = false
var force_update_shadow: float = 0.0
var force_update_shadow_timer: float = 15.0
var _editor_timer: Timer


func _init(p_map: RPGMap) -> void:
	map = p_map
	_setup_editor_timer()


func _setup_editor_timer() -> void:
	if Engine.is_editor_hint():
		_editor_timer = Timer.new()
		_editor_timer.wait_time = 0.1
		_editor_timer.timeout.connect(_on_editor_timer_timeout)
		map.add_child(_editor_timer)
		_editor_timer.start()


func _on_editor_timer_timeout() -> void:
	if shadow_need_refresh:
		shadow_need_refresh = false
		create_shadows()
	elif force_update_shadow > 0:
		force_update_shadow -= 1
		if force_update_shadow <= 0:
			force_update_shadow = force_update_shadow_timer
			create_shadows()


func set_force_update_shadow(enable_force_update_timer: bool) -> void:
	if enable_force_update_timer:
		force_update_shadow = force_update_shadow_timer
	else:
		force_update_shadow = 0
	shadow_need_refresh = !enable_force_update_timer


func update_shadows() -> void:
	if map.draw_shadows:
		if Engine.is_editor_hint() and map.is_node_ready() and map.preview_shadows_in_editor:
			shadow_need_refresh = true
		elif not Engine.is_editor_hint() and map.is_node_ready():
			create_shadows()
		elif editor_shadow_canvas:
			editor_shadow_canvas.queue_free()
			editor_shadow_canvas = null
	else:
		if editor_shadow_canvas:
			editor_shadow_canvas.queue_free()
			editor_shadow_canvas = null


func create_shadows() -> void:
	if Engine.is_editor_hint() and (not map.preview_shadows_in_editor or not map.draw_shadows):
		if editor_shadow_canvas:
			editor_shadow_canvas.queue_free()
			editor_shadow_canvas = null
		return
	create_cell_shadows()
	create_dynamic_shadows()
	perform_shadow_update()


func perform_shadow_update() -> void:
	if map.has_meta("_disable_shadow"):
		return
	
	if Engine.is_editor_hint():
		DayNightManager.day_night_config = RPGSYSTEM.database.system.day_night_config.clone(true)
		
	var all_shadows = []
	for item in shadows.values():
		for shadow_data in item.values():
			if "main_node" in shadow_data and "visible" in shadow_data.main_node:
				if not shadow_data.main_node.visible:
					continue
			all_shadows.append(shadow_data)
			
	var used_rect = map.get_used_rect(false)
	
	var shadow_canvas = GameManager.get_dynamic_shadows_from_main_scene()
	if not shadow_canvas:
		if not editor_shadow_canvas:
			var scn = preload("res://Scenes/ShadowCompose/shadow_compose.tscn")
			var ins = scn.instantiate()
			editor_shadow_canvas = ins
			editor_shadow_canvas.z_as_relative = false
			editor_shadow_canvas.z_index = 4000
			editor_shadow_canvas.in_editor_map = map
			map.add_child(editor_shadow_canvas)
		
		shadow_canvas = editor_shadow_canvas
	
	if shadow_canvas:
		shadow_canvas.call_deferred("set_current_map_rect", used_rect)
		shadow_canvas.set_deferred("shadow_data", all_shadows)


func create_cell_shadows() -> void:
	var original_layer: TileMapLayer = map.MAP_LAYERS.environment
	var used_cells = original_layer.get_used_cells()
	shadows.tiles.clear()
	for cell in used_cells:
		var source_id = original_layer.get_cell_source_id(cell)
		if source_id != -1:
			var atlas_coord = original_layer.get_cell_atlas_coords(cell)
			var source: TileSetSource = original_layer.tile_set.get_source(source_id)
			if source:
				var tile_data: TileData = source.get_tile_data(atlas_coord, 0)
				if tile_data and tile_data.has_custom_data("Cast Shadow"):
					var cast_shadow = tile_data.get_custom_data("Cast Shadow")
					if cast_shadow:
						var shadow_data = draw_shadow(original_layer, cell, cast_shadow, tile_data.texture_origin)
						shadows.tiles[cell] = shadow_data


func create_dynamic_shadows() -> void:
	# vehicle shadows
	shadows.vehicles.clear()
	for vehicle in map.entity_manager.current_ingame_vehicles:
		if vehicle.has_method("get_shadow_data"):
			var vehicle_shadow_data = vehicle.get_shadow_data()
			if vehicle_shadow_data:
				shadows.vehicles[vehicle.get_rid().get_id()] = vehicle_shadow_data
	
	# Player/s shadows
	shadows.players.clear()
	var nodes = map.get_tree().get_nodes_in_group("player")
	nodes.append_array(map.get_tree().get_nodes_in_group("follower"))
	for node in nodes:
		if node.has_method("get_shadow_data"):
			var node_shadow_data = node.get_shadow_data()
			if node_shadow_data and node.visible and node.modulate.a > 0:
				shadows.players[node.get_rid().get_id()] = node_shadow_data
	
	# Event/s shadows
	shadows.events.clear()
	for ev in map.entity_manager.current_ingame_events.values():
		if not ev or not ev.lpc_event: continue
		var node = ev.lpc_event
		if node.is_queued_for_deletion() or node.has_meta("_disable_shadow"): continue
		if node.has_method("get_shadow_data"):
			var node_shadow_data = node.get_shadow_data()
			if node_shadow_data and node.visible and node.modulate.a > 0:
				shadows.events[node.get_rid()] = node_shadow_data
	
	# Extraction Event/s shadows
	for ev in map.entity_manager.current_ingame_extraction_events.values():
		if not ev.scene: continue
		var node = ev.scene
		if node.is_queued_for_deletion() or node.has_meta("_disable_shadow"): continue
		if node.has_method("get_shadow_data"):
			var node_shadow_data = node.get_shadow_data()
			if node_shadow_data and node.visible and node.modulate.a > 0:
				shadows.events[node.get_rid()] = node_shadow_data


func draw_shadow(layer: TileMapLayer, cell: Vector2i, shadow_info, offset: Vector2) -> Dictionary:
	var atlas_source = layer.tile_set.get_source(layer.get_cell_source_id(cell))
	var atlas_coords = layer.get_cell_atlas_coords(cell)
	var texture_region = atlas_source.get_tile_texture_region(atlas_coords)
	if shadow_info:
		texture_region.size *= Vector2i(shadow_info.width, shadow_info.height)

	var tile_position = layer.map_to_local(cell) - map.tile_size * 0.5 - offset + Vector2(0, 2)

	var key = "%s_%s" % [atlas_source.texture.get_rid().get_id(), texture_region]
	var shadow
	if not cached_environment_textures.has(key):
		var tex = ImageTexture.create_from_image(atlas_source.texture.get_image().get_region(texture_region))
		shadow = {
			"texture": tex,
			"position": tile_position,
			"cell": cell,
			"feet_offset": shadow_info.feet_offset,
			"is_tileset": true,
			"width": shadow_info.width - 1
		}
		cached_environment_textures[key] = tex
	else:
		shadow = {
			"texture": cached_environment_textures[key],
			"position": tile_position,
			"cell": cell,
			"feet_offset": shadow_info.feet_offset,
			"is_tileset": true,
			"width": shadow_info.width - 1
		}

	return shadow


func process_editor_physics() -> void:
	if map.draw_shadows:
		if Engine.is_editor_hint():
			if map.preview_shadows_in_editor:
				if force_update_shadow <= 0:
					force_update_shadow = 2


func process_ingame_physics() -> void:
	if map.draw_shadows and not Engine.is_editor_hint():
		create_dynamic_shadows()
		perform_shadow_update()


func get_editor_shadow_canvas() -> Node2D:
	return editor_shadow_canvas
