@tool
extends Node



enum TerrainChanges {NONE, ERASE, FILL, BITS, TEMPLATE}

const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")

# TODO: move to texts; currently unused
var terrain_changes_texts := {
	TerrainChanges.NONE: "",
	TerrainChanges.ERASE: "Erase terrain",
	TerrainChanges.FILL: "Fill terrain",
	TerrainChanges.BITS: "Set terrain bits",
	TerrainChanges.TEMPLATE: "Apply terrain template",
}


var preview_bit_data : TBTPlugin.EditorBitData = null
var current_terrain_change := TerrainChanges.NONE

var tbt : TBTPlugin



func _tbt_ready() -> void:
	var _err := tbt.reset_requested.connect(_on_reset_requested)
	_err = tbt.apply_changes_requested.connect(_on_apply_changes_requested)


func get_preview_terrain_set() -> int:
	if preview_bit_data == null:
		return TBTPlugin.BitData.NULL_TERRAIN_SET
	return preview_bit_data.terrain_set

func has_preview() -> bool:
	return preview_bit_data != null


func has_preview_terrain_set() -> bool:
	if preview_bit_data == null:
		return false
	return preview_bit_data.terrain_set != preview_bit_data.NULL_TERRAIN_SET


func clear_preview() -> void:
	preview_bit_data = null
	_emit_preview_updated()


func erase_terrains() -> void:
	preview_bit_data = _get_new_preview_data()
	preview_bit_data.clear_all_tile_terrains()
	current_terrain_change = TerrainChanges.ERASE
	_emit_preview_updated()


func fill_terrain(terrain_set : int, terrain_id : int) -> void:
	preview_bit_data = _get_new_preview_data()
	var terrain_mode : int = tbt.context.tile_set.get_terrain_set_mode(terrain_set)
	preview_bit_data.fill_all_tile_terrains(terrain_set, terrain_mode, terrain_id)
	current_terrain_change = TerrainChanges.FILL
	_emit_preview_updated()


# sets specific terrain bit of all selected tiles
# adds on to any changes already made
func set_terrain_bits(terrain_bit : int, terrain_id : int) -> void:
	if !preview_bit_data:
		preview_bit_data = _get_new_preview_data()
	preview_bit_data.set_all_bit_terrains(terrain_bit, terrain_id)
	current_terrain_change = TerrainChanges.BITS
	_emit_preview_updated()


func apply_template_terrains(template : TBTPlugin.TemplateBitData, terrain_set : int, terrain_mapping : Dictionary) -> void:
	if terrain_mapping.is_empty():
		preview_bit_data = null
		_emit_preview_updated()
		return

	preview_bit_data = _get_new_preview_data()
	var result := preview_bit_data.apply_template_bit_data(template, terrain_set, terrain_mapping)
	if result != OK:
		preview_bit_data = null
		current_terrain_change = TerrainChanges.NONE
		tbt.output.error("Unable to apply template data", result)
		_emit_preview_updated()
		return

	current_terrain_change = TerrainChanges.TEMPLATE
	_emit_preview_updated()


## Applies the changes to TileData object
## including terrain_set, terrain and terrain peering bits
## There is no undo
func apply_bit_data() -> void:
	if !preview_bit_data:
		return

	tbt.output.info(terrain_changes_texts[current_terrain_change])

	if current_terrain_change == TerrainChanges.ERASE:
		tbt.output.user("Erasing terrain set assignments may cause error spam of Condition 'terrain_set < 0' is true. Data should save without corruption. Please ignore.")

	for coords in tbt.context.tiles.keys():
		var tile_data : TileData = tbt.context.tiles[coords]
		tile_data.terrain_set = preview_bit_data.terrain_set
		tile_data.terrain = preview_bit_data.get_tile_terrain(coords)
		for cell_neighbor in preview_bit_data.get_terrain_bits_list():
			var terrain := preview_bit_data.get_bit_terrain(coords, cell_neighbor)
			tile_data.set_terrain_peering_bit(cell_neighbor, terrain)



func _emit_preview_updated() -> void:
	tbt.preview_updated.emit(preview_bit_data)


func _get_new_preview_data() -> TBTPlugin.EditorBitData:
	var copy : TBTPlugin.EditorBitData = tbt.context.bit_data.make_copy()
	return copy


func _on_reset_requested() -> void:
	tbt.output.debug("reset requested from tiles manager")
	clear_preview()


func _on_apply_changes_requested() -> void:
	apply_bit_data()
