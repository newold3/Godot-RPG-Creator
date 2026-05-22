@tool
extends EditorPlugin


#region VARIABLES

var active_layer: TileMapLayer
var cached_cells: Dictionary = {}
var drag_path: Array[Vector2i] = []
var was_pressed: bool = false

#endregion



## Binds the plugin to the active TileMapLayer in the editor
func _handles(object: Object) -> bool:
	return object is TileMapLayer



## Activates the supervisor and caches the initial state of the map
func _edit(object: Object) -> void:
	active_layer = object
	_cache_layer()



## Cleans up references when the user deselects the layer
func _make_visible(visible: bool) -> void:
	if not visible:
		active_layer = null
		cached_cells.clear()
		drag_path.clear()



## Spies on the global mouse state to detect drag operations and tracks the exact path of the brush
func _process(_delta: float) -> void:
	if not is_instance_valid(active_layer) or active_layer.tile_set == null:
		return
		
	var is_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	if is_pressed and not was_pressed:
		was_pressed = true
		_cache_layer()
		drag_path.clear()
		var map_pos: Vector2i = active_layer.local_to_map(active_layer.get_local_mouse_position())
		drag_path.append(map_pos)
	elif is_pressed and was_pressed:
		var map_pos: Vector2i = active_layer.local_to_map(active_layer.get_local_mouse_position())
		if drag_path.is_empty() or drag_path.back() != map_pos:
			drag_path.append(map_pos)
	elif not is_pressed and was_pressed:
		was_pressed = false
		_apply_surgical_cleanup()



## Caches the current state of the TileMapLayer cells to use as a clean background reference
func _cache_layer() -> void:
	cached_cells.clear()
	if not is_instance_valid(active_layer) or active_layer.tile_set == null:
		return
		
	for pos in active_layer.get_used_cells():
		var source: int = active_layer.get_cell_source_id(pos)
		var coord: Vector2i = active_layer.get_cell_atlas_coords(pos)
		var alt: int = active_layer.get_cell_alternative_tile(pos)
		cached_cells[pos] = {"source": source, "coord": coord, "alt": alt}



## Reconstructs the stroke filtering overlapping giant tiles while respecting the exact drag path
func _apply_surgical_cleanup() -> void:
	if not is_instance_valid(active_layer) or active_layer.tile_set == null or drag_path.is_empty():
		return
		
	var tileset: TileSet = active_layer.tile_set
	var brush_data: Dictionary = {}
	
	for pos in drag_path:
		var current_source: int = active_layer.get_cell_source_id(pos)
		var current_coord: Vector2i = active_layer.get_cell_atlas_coords(pos)
		
		if not cached_cells.has(pos) or cached_cells[pos]["coord"] != current_coord:
			if current_source != -1:
				var source: TileSetSource = tileset.get_source(current_source)
				if source is TileSetAtlasSource:
					var size: Vector2i = source.get_tile_size_in_atlas(current_coord)
					if size.x > 1 or size.y > 1:
						brush_data = {
							"source": current_source,
							"coord": current_coord,
							"alt": active_layer.get_cell_alternative_tile(pos),
							"size": size
						}
						break
						
	if brush_data.is_empty():
		return
		
	var valid_anchors: Dictionary = {}
	var size: Vector2i = brush_data["size"]
	
	for pos in drag_path:
		var overlaps: bool = false
		for v_pos in valid_anchors.keys():
			var rect1: Rect2i = Rect2i(pos, size)
			var rect2: Rect2i = Rect2i(v_pos, size)
			if rect1.intersects(rect2):
				overlaps = true
				break
				
		if not overlaps:
			valid_anchors[pos] = true
			
	var current_cells: Array[Vector2i] = active_layer.get_used_cells()
	var smudge_cells: Dictionary = {}
	
	for pos in current_cells:
		if not cached_cells.has(pos) or cached_cells[pos]["coord"] != active_layer.get_cell_atlas_coords(pos):
			var c_source: int = active_layer.get_cell_source_id(pos)
			var c_coord: Vector2i = active_layer.get_cell_atlas_coords(pos)
			var c_alt: int = active_layer.get_cell_alternative_tile(pos)
			smudge_cells[pos] = {"source": c_source, "coord": c_coord, "alt": c_alt}
			
	for pos in cached_cells.keys():
		if not current_cells.has(pos):
			smudge_cells[pos] = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
			
	var all_affected: Dictionary = {}
	for pos in smudge_cells.keys():
		all_affected[pos] = true
	for pos in valid_anchors.keys():
		all_affected[pos] = true
		
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Surgical Giant Tile Clean")
	
	for pos in all_affected.keys():
		var do_data: Dictionary = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
		if valid_anchors.has(pos):
			do_data = {"source": brush_data["source"], "coord": brush_data["coord"], "alt": brush_data["alt"]}
		elif cached_cells.has(pos):
			do_data = cached_cells[pos]
			
		undo_redo.add_do_method(active_layer, "set_cell", pos, do_data["source"], do_data["coord"], do_data["alt"])
		
		var undo_data: Dictionary = {"source": -1, "coord": Vector2i(-1, -1), "alt": -1}
		if smudge_cells.has(pos):
			undo_data = smudge_cells[pos]
		elif cached_cells.has(pos):
			undo_data = cached_cells[pos]
			
		undo_redo.add_undo_method(active_layer, "set_cell", pos, undo_data["source"], undo_data["coord"], undo_data["alt"])
		
	undo_redo.commit_action()
	print("Godot RPG Creator: Trazado corregido y desolapado. Tiles estampados: " + str(valid_anchors.size()))
	_cache_layer()
