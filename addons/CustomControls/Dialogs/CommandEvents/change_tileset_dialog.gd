@tool
extends CommandBaseDialog

@onready var layer_options: OptionButton = %Layers
@onready var tileset: Control = %Tileset

var default_path: String


func _ready() -> void:
	super()
	parameter_code = 202
	if RPGDialogFunctions.there_are_any_dialog_open():
		fill_layers()


func fill_layers() -> void:
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	var layers = []
	if edited_scene and edited_scene is RPGMap:
		for node in edited_scene.get_children():
			if node is TileMapLayer:
				layers.append(node)

	if layers.size() > 0:
		layer_options.set_disabled(false)
		tileset.set_disabled(false)
		layer_options.clear()
		for node in layers:
			layer_options.add_item(node.name)
	else:
		layer_options.set_disabled(true)
		tileset.set_disabled(true)
		printerr("This command can only be edited if the scene currently being edited in the editor is a RPGMap.")
		_on_cancel_button_pressed()


func set_data() -> void:
	default_path = parameters[0].parameters.get("path", "")
	var layer = parameters[0].parameters.get("layer", 0)
	if layer_options.get_item_count() > layer:
		layer_options.select(layer)
	elif layer_options.get_item_count() > 0:
		layer_options.select(0)
	if default_path:
		tileset.text = default_path.get_file()
	else:
		tileset.text = tr("Click To Select Tileset")


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.path = default_path
	commands[-1].parameters.layer = layer_options.get_selected_id()
	return commands


func _on_tileset_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	dialog.destroy_on_hide = true
	dialog.set_dialog_mode(0)
	dialog.target_callable = _on_obj_selected
	dialog.set_file_selected(default_path)
	dialog.fill_files("tilesets")


func _on_obj_selected(path: String) -> void:
	default_path = path
	tileset.text = path.get_file()
