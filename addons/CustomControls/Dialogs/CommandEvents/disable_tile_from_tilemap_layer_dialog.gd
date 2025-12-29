@tool
extends CommandBaseDialog

@onready var layer_options: OptionButton = %Layers
@onready var tileset_selected: Control = %TileSelected


var default_path: String
var current_tiles: Array[Vector2i] = []


func _ready() -> void:
	super()
	parameter_code = 125
	if RPGDialogFunctions.there_are_any_dialog_open():
		fill_layers()


func fill_layers() -> void:
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	var layers = []
	if edited_scene and edited_scene is RPGMap:
		default_path = edited_scene.get_scene_file_path()
		for node in edited_scene.get_children():
			if node is TileMapLayer:
				layers.append(node)

	if layers.size() > 0:
		layer_options.set_disabled(false)
		tileset_selected.set_disabled(false)
		layer_options.clear()
		for node in layers:
			layer_options.add_item(node.name)
	else:
		layer_options.set_disabled(true)
		tileset_selected.set_disabled(true)
		printerr("This command can only be edited if the scene currently being edited in the editor is a RPGMap.")
		_on_cancel_button_pressed()


func set_data() -> void:
	var layer = parameters[0].parameters.get("layer", 0)
	if layer_options.get_item_count() > layer:
		layer_options.select(layer)
	elif layer_options.get_item_count() > 0:
		layer_options.select(0)
	%UseAllLayers.set_pressed(parameters[0].parameters.get("use_all_layers", false))
	if parameters[0].parameters.get("state", false):
		%TileStateEnabled.set_pressed(true)
	else:
		%TileStateDisabled.set_pressed(true)
	var empty_tiles: Array[Vector2i] = []
	current_tiles = parameters[0].parameters.get("tiles", empty_tiles)
	_update_current_tiles_text()


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.layer = layer_options.get_selected_id()
	commands[-1].parameters.use_all_layers = %UseAllLayers.is_pressed()
	commands[-1].parameters.tiles = current_tiles
	commands[-1].parameters.state = true if %TileStateEnabled.is_pressed() else false
	return commands


func _on_tile_selected_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/select_map_position_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var start_position = current_tiles
	
	dialog.restrict_position_to_terrain.clear()
	dialog.set_terrain_restrictions(PackedStringArray([]))
	
	if default_path:
		var map_path = default_path
		dialog.set_start_map(map_path, Vector2i.ZERO)
	else:
		dialog.select_initial_map()
	
	dialog.hide_map_list()
	
	var layer_id = -1 if %UseAllLayers.is_pressed() else %Layers.get_selected_id()
	await dialog.set_layer_mode(layer_id)

	dialog.set_tiles_selected(current_tiles)
	dialog.cells_selected.connect(_on_manual_map_position_selected)


func _on_manual_map_position_selected(_map_id: int, start_position: Array[Vector2i]) -> void:
	current_tiles = start_position
	_update_current_tiles_text()


func _update_current_tiles_text() -> void:
	if current_tiles.size() > 0:
		if current_tiles.size() == 1:
			%TileSelected.text = "Tile Selected = %s" % current_tiles
		else:
			%TileSelected.text = "From %s To %s" % [current_tiles[0], current_tiles[-1]]


func _on_use_all_layers_toggled(toggled_on: bool) -> void:
	%Layers.disabled = toggled_on
