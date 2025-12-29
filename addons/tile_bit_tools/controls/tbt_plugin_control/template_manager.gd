@tool
extends Node

const TEMPLATE_PREVIEW_TILE_WIDTH := 16
const TEMPLATE_PREVIEW_TILE_SPACING := 0

const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")

const TemplateLoader := preload("res://addons/tile_bit_tools/core/template_loader.gd")
const BitDataDrawNode := preload("res://addons/tile_bit_tools/controls/bit_data_draw/bit_data_draw_node.tscn")

var template_loader : TemplateLoader
var bit_data_draw_node

var tbt : TBTPlugin


@onready var template_folder_paths : Array



func _tbt_ready() -> void:
	var _err := tbt.templates_update_requested.connect(update_templates)

	_setup_bit_data_draw()

	# call deferred so editor will not pause on activating plugin
	_load_templates.call_deferred()


func _setup_bit_data_draw() -> void:
	bit_data_draw_node = BitDataDrawNode.instantiate()
	add_child(bit_data_draw_node)
	bit_data_draw_node.tile_size = TEMPLATE_PREVIEW_TILE_WIDTH
	bit_data_draw_node.tile_spacing = TEMPLATE_PREVIEW_TILE_SPACING


func _load_templates() -> void:
	_update_template_folder_paths()

	for folder_path in template_folder_paths:
		tbt.output.debug("Loading templates in %s: %s" % [folder_path.name, folder_path.path])
		if !DirAccess.dir_exists_absolute(folder_path.path):
			tbt.output.debug("making path to template folder: %s" % folder_path.path)
			var _err := DirAccess.make_dir_recursive_absolute(folder_path.path)

	template_loader = TemplateLoader.new(template_folder_paths)
	_create_template_textures.call_deferred()
	tbt.output.info("%s templates loaded" % template_loader.get_templates().size())


func _create_template_textures() -> void:
	for template in template_loader.get_templates():
		template.preview_texture = await bit_data_draw_node.get_bit_texture(template)
#		tbt.output.debug("Created preview texture for %s" % template.template_name)


func update_templates() -> void:
	_load_templates()
	tbt.templates_updated.emit()


func get_bit_data_draw() -> SubViewport:
	return bit_data_draw_node


func get_user_templates_path() -> String:
	var path : String = ProjectSettings.get_setting(TBTPlugin.G.Settings.user_templates_path.path)
	var dir := DirAccess.open(path)
	if dir:
		return dir.get_current_dir()
	return ""


func _update_template_folder_paths() -> void:
	template_folder_paths = [
		{
			"type": TBTPlugin.G.TemplateTypes.BUILT_IN,
			"name": "Built-in Templates Folder",
			"path": TBTPlugin.G.BUILTIN_TEMPLATES_PATH,
		},
		{
			"type": TBTPlugin.G.TemplateTypes.USER,
			"name": "Project Templates Folder",
			"tooltip": "Templates saved here will only be available to this project",
			"path": TBTPlugin.G.PROJECT_TEMPLATES_PATH,
		},
		{
			"type": TBTPlugin.G.TemplateTypes.USER,
			"name": "Shared Templates Folder",
			"tooltip": "Templates saved here will be available to all projects on this computer",
			"path": OS.get_data_dir() + TBTPlugin.G.GODOT_TEMPLATES_FOLDER,
		},
		# default is the same as project templates folder
		{
			"type": TBTPlugin.G.TemplateTypes.USER,
			"name": "User Templates Folder",
			"tooltip": "Template will be saved to the folder set in Project Settings -> Tile Bit Tools",
			"path": get_user_templates_path(),
		},
	]

	for i in range(template_folder_paths.size()-1, -1, -1):
		if template_folder_paths[i].path == "":
			template_folder_paths.remove_at(i)




