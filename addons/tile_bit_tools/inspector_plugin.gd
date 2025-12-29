@tool
extends EditorInspectorPlugin

# Do not use Vector2i(-INF/-INF) - will evaluate as equal to Vector2i(0,0)
const INVALID_COORDINATES := Vector2i(-1, -1)

const G := preload("res://addons/tile_bit_tools/core/globals.gd")
const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")

var TBTPluginControl := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.tscn")

var Context := preload("res://addons/tile_bit_tools/core/context.gd")
var TilesInspector := preload("res://addons/tile_bit_tools/controls/tiles_inspector/tiles_inspector.tscn")
var TilesPreview := preload("res://addons/tile_bit_tools/controls/tiles_preview/tiles_preview.tscn")

var output := preload("res://addons/tile_bit_tools/core/output.gd").new()

var controls := {}
var current_controls := []


# Editor nodes
var interface : EditorInterface
var base_control : Control
var tile_set_editor : Node
var atlas_source_editor : Node
var tile_atlas_view : Node

# Proxy objects
# can get current source and selected tiles from their incoming connections
var atlas_source_proxy : Object
var atlas_tile_proxy : Object

var tbt_plugin_control : TBTPlugin

var context : Node
var tiles_inspector : Control
var tiles_preview : Control



# --------------------------------------
# 			SETUP
# --------------------------------------

func setup(p_interface : EditorInterface) -> G.Errors:
	interface = p_interface
	base_control = interface.get_base_control()

	tile_set_editor = _get_first_node_by_class(interface.get_base_control(), "TileSetEditor")
	#output.debug("tile_set_editor=%s" % tile_set_editor)
	if !tile_set_editor:
		return G.Errors.FAILED


	atlas_source_editor = _get_first_node_by_class(tile_set_editor, "TileSetAtlasSourceEditor")
	#output.debug("atlas_source_editor=%s" % atlas_source_editor)
	if !atlas_source_editor:
		return G.Errors.FAILED


	tile_atlas_view = _get_first_node_by_class(tile_set_editor, "TileAtlasView")
	#output.debug("tile_atlas_view=%s" % tile_atlas_view)
	if !tile_atlas_view:
		return G.Errors.FAILED

	atlas_source_proxy = _get_first_connected_object_by_class(atlas_source_editor, "TileSetAtlasSourceProxyObject")
	#output.debug("atlas_source_proxy=%s" % atlas_source_proxy)
	if !atlas_source_proxy:
		return G.Errors.FAILED

	atlas_tile_proxy = _get_first_connected_object_by_class(atlas_source_editor, "AtlasTileProxyObject")
	#output.debug("atlas_tile_proxy=%s" % atlas_tile_proxy)
	if !atlas_tile_proxy:
		return G.Errors.FAILED

#	_print_signals_and_connections(tile_atlas_view)

	_setup_tiles_preview()

	var shared_node_result := _setup_tbt_plugin_control()
	if shared_node_result != OK:
		return shared_node_result

	return G.Errors.OK


func _reset() -> void:
	clean_up()
	setup.call_deferred(interface)



# Finds "Setup", "Select", "Paint" buttons and
# connects pressed to resetting inspector controls
func _setup_source_editor_button_connections() -> G.Errors:
	var vbox := atlas_source_editor.get_child(0)
	if !vbox.is_class("VBoxContainer"):
		return G.Errors.FAILED

	var hbox := vbox.get_child(0)
	if !hbox.is_class("HBoxContainer"):
		return G.Errors.FAILED

	var buttons := hbox.get_children()
	for button in buttons:
		if !button.is_class("Button"):
			return G.Errors.FAILED
		button.pressed.connect(_clear_tiles_inspector)

	return G.Errors.OK


func _setup_tiles_preview() -> void:
	tiles_preview = TilesPreview.instantiate()
	tile_atlas_view.add_child(tiles_preview)
	tiles_preview.hide()


func _setup_tbt_plugin_control() -> G.Errors:
	tbt_plugin_control = TBTPluginControl.instantiate()
	base_control.add_child(tbt_plugin_control)
	tbt_plugin_control.setup(interface, atlas_source_editor, tiles_preview)
	output.debug("TBTPluginControl added")
	return G.Errors.OK





# --------------------------------------
# 			MAIN LOOP
# --------------------------------------

func _can_handle(object: Object) -> bool:
	var _err := _clear_tiles_inspector()

	if object.is_class("AtlasTileProxyObject"):
		output.debug("_can_handle() => AtlasTileProxyObject")
		return true

	return false


func _parse_end(object: Object) -> void:
	if !object.is_class("AtlasTileProxyObject"):
		output.warning("_parse_end(): object is not AtlasTileProxyObject, instead it is %s" % object)
		return

	var result := await _add_inspector()
	if result != OK:
		output.user("TilesInspector not added", result)
		var _err := _clear_tiles_inspector()
		return
	output.debug("TilesInspector added", result)




# --------------------------------------
# 		ADD INSPECTOR
# --------------------------------------


func _add_inspector() -> G.Errors:
	output.debug("_add_inspector()")

	# partial fix for issue #34
	if !is_instance_valid(tbt_plugin_control):
		output.error("tbt_plugin_control invalid")
		_reset()
		return G.Errors.INVALID_TBT_PLUGIN_CONTROL

	# tiles preview has sometimes been invalid too
	if !is_instance_valid(tiles_preview):
		output.error("tiles_preview invalid")
		_reset()
		return G.Errors.INVALID_TILES_PREVIEW

	var result := await _add_context()
	if result != OK:
		return result

	_add_tiles_inspector()
	_notify_tiles_inspector_added()

	return G.Errors.OK





func _add_context() -> G.Errors:
	context = Context.new()

	context.base_control = base_control

	# Refresh to ensure not using stale references
	context.tile_set = _get_current_tile_set()
	if !context.tile_set:
		return G.Errors.MISSING_TILE_SET

	context.source = _get_current_source()
	if !context.source:
		return G.Errors.MISSING_SOURCE

	context.tiles = _get_current_tiles(context.source)
	if context.tiles.is_empty():
		return G.Errors.MISSING_TILES

	tbt_plugin_control.add_child(context)
	if !context.ready_complete:
		await context.ready

	return context.finish_setup()


func _add_tiles_inspector() -> void:
	tiles_inspector = TilesInspector.instantiate()
	add_custom_control(tiles_inspector)



func _wait_for_tree_exit(node) -> void:
	if is_instance_valid(node):
		if node.is_queued_for_deletion():
			output.debug("waiting for %s to leave tree" % node)
			await node.tree_exited
		else:
			output.warning("%s not queued for deletion" % node)
			var _err := _clear_tiles_inspector()
			await node.tree_exited


# --------------------------------------
# 			CLEAN UP
# --------------------------------------

# Called from parent plugin when addon unloaded
func clean_up() -> void:
	_remove_shared_editor_nodes()
	var _err := _clear_tiles_inspector()




# Called when inspector data changed or focus moved away
func _clear_tiles_inspector() -> G.Errors:
	output.debug("_clear_tiles_inspector()")
	if is_instance_valid(context):
		context.queue_free()
		_notify_tiles_inspector_removed()
	if is_instance_valid(tiles_inspector):
		tiles_inspector.queue_free()

	return G.Errors.OK


func _remove_shared_editor_nodes() -> void:
	if is_instance_valid(tbt_plugin_control):
		tbt_plugin_control.queue_free()
	if is_instance_valid(tiles_preview):
		tiles_preview.queue_free()
	output.debug("shared editor nodes removed")






# --------------------------------------
# 	Helper functions
# --------------------------------------

func _get_current_tile_set() -> TileSet:
	return _get_first_connected_object_by_class(tile_set_editor, "TileSet")


func _get_current_source() -> TileSetAtlasSource:
	return _get_first_connected_object_by_class(atlas_source_proxy, "TileSetAtlasSource")


func _get_current_tiles(source : TileSetAtlasSource) -> Dictionary:
	var tiles := {}

	var tile_data_objects := _get_connected_objects_by_class(atlas_tile_proxy, "TileData")
	for tile_data in tile_data_objects:
		var coords := _find_coordinates_in_source(tile_data, source)
		if coords == INVALID_COORDINATES:
			output.error("Unable to find tile in source")
			return {}
		tiles[coords] = tile_data

	return tiles


func _find_coordinates_in_source(tile_data : TileData, source : TileSetAtlasSource) -> Vector2i:
	for i in range(source.get_tiles_count()):
		var coords := source.get_tile_id(i)
		if tile_data == source.get_tile_data(coords, 0):
			return coords
	return INVALID_COORDINATES


func _get_first_node_by_class(parent_node : Node, p_class_name : String) -> Node:
	var nodes := parent_node.find_children("*", p_class_name, true, false)
	if !nodes.size():
		return null
	return nodes[0]


func _get_first_connected_object_by_class(object : Object, p_class_name : String) -> Object:
	var objects := _get_connected_objects_by_class(object, p_class_name)
	if !objects.size():
		return null
	return objects[0]


func _get_connected_objects_by_class(object : Object, p_class_name : String) -> Array:
	var objects := []
	for connection in object.get_incoming_connections():
		var connected_object = connection["signal"].get_object()
		if connected_object.is_class(p_class_name):
			objects.append(connected_object)
	return objects


func _notify_tiles_inspector_added() -> void:
	if !tiles_inspector.ready_complete:
		output.debug("awaiting tiles_inspector.ready")
		await tiles_inspector.ready
	if !tiles_preview.ready_complete:
		output.debug("awaiting tiles_preview.ready")
		await tiles_preview.ready

	if is_instance_valid(tbt_plugin_control):
		tbt_plugin_control.notify_tiles_inspector_added(tiles_inspector)


func _notify_tiles_inspector_removed() -> void:
	if is_instance_valid(tbt_plugin_control):
		tbt_plugin_control.notify_tiles_inspector_removed()


func _print_signals_and_connections(object : Object) -> void:
	output.debug("object: %s" % object)
	output.debug("incoming connections:")
	for connection in object.get_incoming_connections():
		output.debug("\n%s" % connection)
	for signal_data in object.get_signal_list():
		output.debug(signal_data.name)
		for connection in object.get_signal_connection_list(signal_data.name):
			output.debug("\n%s" % connection)
