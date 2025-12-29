@tool
extends Control

signal item_selected


const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")

var EMPTY_ITEM_ID := -99

var terrain_label_text := "Terrain %s"

var index : int
var color : Color

var terrain_set : int :
	set(value):
		terrain_set = value
		_update_picker()

var tbt : TBTPlugin
var template_mode : TileSet.TerrainMode

@onready var terrain_label: Label = %TerrainLabel
@onready var terrain_color_rect: ColorRect = %TerrainColorRect
@onready var terrain_option_button: OptionButton = %TerrainOptionButton


func setup(p_tbt : TBTPlugin, p_index : int, p_color : Color, p_mode : TileSet.TerrainMode) -> void:
	tbt = p_tbt
	index = p_index
	color = p_color
	template_mode = p_mode
	_update_label()


func _ready() -> void:
	var _err := terrain_option_button.item_selected.connect(_emit_item_selected)


func get_selected_item_id() -> int:
	var id := terrain_option_button.get_selected_id()
	# id cannot be -1 in optionlist, so must be converted
	if id == EMPTY_ITEM_ID:
		return -1
	return id


func disable_picker(value : bool) -> void:
	if value:
		terrain_option_button.disabled = true
	else:
		terrain_option_button.disabled = false


func _update_label() -> void:
	terrain_label.text = terrain_label_text % index
	terrain_color_rect.color = color


func _update_picker() -> void:
	terrain_option_button.clear()
	terrain_option_button.add_item(tbt.texts.EMPTY_ITEM, EMPTY_ITEM_ID)

	if terrain_set == -1:
		disable_picker(true)
		return

	var terrain_set_mode := tbt.context.tile_set.get_terrain_set_mode(terrain_set)
	if terrain_set_mode != template_mode:
		disable_picker(true)
		return

	disable_picker(false)

	var terrains_count := tbt.context.tile_set.get_terrains_count(terrain_set)

	for i in range(terrains_count):
		var terrain_name := tbt.context.tile_set.get_terrain_name(terrain_set, i)
		var terrain_color := tbt.context.tile_set.get_terrain_color(terrain_set, i)
		var icon : ImageTexture = tbt.context.get_terrain_icon(terrain_color)
		terrain_option_button.add_icon_item(icon, terrain_name, i)


func _emit_item_selected(_index := -1) -> void:
	item_selected.emit()


func _on_terrain_set_changed(id : int) -> void:
	terrain_set = id

