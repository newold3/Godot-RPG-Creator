extends EditorProperty


#region VARIABLES
var option_button: OptionButton
var single_btn: Button
var use_single_check: CheckBox
var base_prop: String
var updating: bool = false
#endregion


## Initializes the property editor with the required UI layout
func _init(prop_name: String) -> void:
	base_prop = prop_name
	
	var vbox: VBoxContainer = VBoxContainer.new()
	add_child(vbox)
	
	if base_prop in ["terrain_floor", "terrain_wall", "terrain_roof"]:
		use_single_check = CheckBox.new()
		use_single_check.text = "Use Single Tile"
		use_single_check.toggled.connect(_on_check_toggled)
		use_single_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		vbox.add_child(use_single_check)
		
	var hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(hbox)
	
	option_button = OptionButton.new()
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_button.item_selected.connect(_on_option_selected)
	hbox.add_child(option_button)
	
	single_btn = Button.new()
	single_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	single_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	single_btn.pressed.connect(_on_single_btn_pressed)
	hbox.add_child(single_btn)
	
	if base_prop in ["large_tile_shadow", "small_tile_shadow"]:
		option_button.visible = false
		single_btn.visible = true
	else:
		single_btn.visible = false
		
	add_focusable(option_button)
	add_focusable(single_btn)


## Updates the UI state to match the current property values of the MapGenerator
func _update_property() -> void:
	updating = true
	var obj: Object = get_edited_object()
	
	if base_prop in ["large_tile_shadow", "small_tile_shadow"]:
		var tile_data: Dictionary = obj[base_prop]
		var prefix: String = _get_button_prefix()
		
		if tile_data["atlas_id"] == -1:
			single_btn.text = prefix + "None"
			single_btn.icon = null
		else:
			single_btn.text = prefix + str(tile_data["tile_id"])
			single_btn.icon = _get_tile_icon(tile_data["atlas_id"], tile_data["tile_id"])
	else:
		var current_val: int = obj[base_prop]
		var is_single: bool = false
		
		if use_single_check:
			var use_single_prop: String = _get_use_single_prop()
			is_single = obj[use_single_prop]
			use_single_check.set_pressed_no_signal(is_single)
			
		if is_single:
			option_button.visible = false
			single_btn.visible = true
			var tile_data: Dictionary = obj[_get_single_tile_prop()]
			var prefix: String = _get_button_prefix()
			
			if tile_data["atlas_id"] == -1:
				single_btn.text = prefix + "None"
				single_btn.icon = null
			else:
				single_btn.text = prefix + str(tile_data["tile_id"])
				single_btn.icon = _get_tile_icon(tile_data["atlas_id"], tile_data["tile_id"])
		else:
			option_button.visible = true
			single_btn.visible = false
			_populate_options()
			
			for i in range(option_button.get_item_count()):
				if option_button.get_item_metadata(i) == current_val:
					option_button.select(i)
					break
					
	updating = false


#region HELPERS


## Returns the appropriate prefix string based on the current property type
func _get_button_prefix() -> String:
	if base_prop == "terrain_floor": return "Floor Tile: "
	if base_prop == "terrain_wall": return "Wall Tile: "
	if base_prop == "large_tile_shadow": return "Large Tile Shadow: "
	if base_prop == "small_tile_shadow": return "Small Tile Shadow: "
	return "Roof Tile: "


## Extracts an AtlasTexture directly from the TileSet for the given atlas and tile coordinates
func _get_tile_icon(atlas_id: int, tile_coords: Vector2i) -> AtlasTexture:
	var map_generator: Object = get_edited_object()
	var tm: TileMapLayer = map_generator.layer_walls
	
	if base_prop == "terrain_floor":
		tm = map_generator.layer_ground_base
	elif base_prop in ["large_tile_shadow", "small_tile_shadow"]:
		tm = map_generator.layer_shadows
		
	if not tm or not tm.tile_set or atlas_id == -1:
		return null
		
	var ts: TileSet = tm.tile_set
	
	if not ts.has_source(atlas_id):
		return null
		
	var source: TileSetSource = ts.get_source(atlas_id)
	
	if source is TileSetAtlasSource and source.has_tile(tile_coords):
		var icon: AtlasTexture = AtlasTexture.new()
		icon.atlas = source.texture
		icon.region = source.get_tile_texture_region(tile_coords)
		return icon
		
	return null


## Retrieves the correct boolean property name for single tile usage
func _get_use_single_prop() -> String:
	if base_prop == "terrain_floor": return "use_single_floor"
	if base_prop == "terrain_wall": return "use_single_wall"
	return "use_single_roof"


## Retrieves the correct dictionary property name for single tile data
func _get_single_tile_prop() -> String:
	if base_prop == "terrain_floor": return "single_floor_tile"
	if base_prop == "terrain_wall": return "single_wall_tile"
	return "single_roof_tile"
#endregion


#region SIGNALS


## Handles the toggle of the single tile mode and refreshes the property view
func _on_check_toggled(pressed: bool) -> void:
	if updating: return
	emit_changed(_get_use_single_prop(), pressed)
	_update_property()


## Updates the terrain ID when a new option is selected in the dropdown
func _on_option_selected(index: int) -> void:
	if updating: return
	var selected_id: int = option_button.get_item_id(index)
	emit_changed(base_prop, selected_id)


## Opens the tile selection dialog and connects the result signal
func _on_single_btn_pressed() -> void:
	var path: String = "res://addons/CustomControls/Dialogs/select_tile_from_tileset_dialog.tscn"
	var dialog: Window = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if dialog:
		dialog.set_single_mode(true)
		var map_gen: Node = get_edited_object()
		var tm: TileMapLayer = map_gen.layer_walls
		var current_tile: Dictionary = {}
		
		if base_prop == "terrain_floor":
			tm = map_gen.layer_ground_base
			current_tile = map_gen[_get_single_tile_prop()]
		elif base_prop in ["large_tile_shadow", "small_tile_shadow"]:
			tm = map_gen.layer_shadows
			current_tile = map_gen[base_prop]
		else:
			current_tile = map_gen[_get_single_tile_prop()]
			
		if tm and tm.tile_set:
			dialog.set_data(tm.tile_set, [], current_tile)
			
		dialog.tile_selected.connect(_on_dialog_tile_selected)


## Updates the tile data and visual icon after selection in the dialog
func _on_dialog_tile_selected(atlas_id: int, tile_id: Vector2i) -> void:
	var new_data: Dictionary = {"atlas_id": atlas_id, "tile_id": tile_id}
	var prop_to_emit: String = base_prop
	
	if not base_prop in ["large_tile_shadow", "small_tile_shadow"]:
		prop_to_emit = _get_single_tile_prop()
	
	emit_changed(prop_to_emit, new_data)
	single_btn.text = _get_button_prefix() + str(tile_id)
	single_btn.icon = _get_tile_icon(atlas_id, tile_id)


## Populates the OptionButton with available terrains from the TileMapLayer
func _populate_options() -> void:
	option_button.clear()
	option_button.add_item("None", -1)
	var map_generator: Object = get_edited_object()
	
	var tm: TileMapLayer = map_generator.layer_ground_base if base_prop == "terrain_floor" else map_generator.layer_walls
	if not tm or not tm.tile_set: return
	
	var ts: TileSet = tm.tile_set
	var terrain_set: int = 0
	
	if ts.get_terrain_sets_count() <= 0: 
		return
		
	for terrain_id in range(ts.get_terrains_count(terrain_set)):
		var t_name: String = ts.get_terrain_name(terrain_set, terrain_id)
		var icon: AtlasTexture = null
		
		for source_idx in ts.get_source_count():
			var source_id: int = ts.get_source_id(source_idx)
			var source: TileSetSource = ts.get_source(source_id)
			
			if source is TileSetAtlasSource:
				for tile_idx in range(source.get_tiles_count()):
					var coord: Vector2i = source.get_tile_id(tile_idx)
					var tile_data: TileData = source.get_tile_data(coord, 0)
					
					if tile_data and tile_data.terrain_set == terrain_set and tile_data.terrain == terrain_id:
						icon = AtlasTexture.new()
						icon.atlas = source.texture
						icon.region = source.get_tile_texture_region(coord)
						break
						
				if icon: break
				
		var final_name: String = t_name if not t_name.is_empty() else "Terrain " + str(terrain_id)
		option_button.add_item(final_name, terrain_id)
		option_button.set_item_metadata(option_button.item_count - 1, terrain_id)
		
		if icon: 
			option_button.set_item_icon(option_button.item_count - 1, icon)
#endregion
