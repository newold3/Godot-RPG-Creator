@tool
extends Control

const TERRAIN_POPUP := "TerrainPopup"

const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")

var EMPTY_TERRAIN_ID := 99

var fill_menu_items := {}

var bit_button_bit_id : int
var bit_button_terrain_id : int

var tbt : TBTPlugin


@onready var fill_button: MenuButton = %FillButton
@onready var bit_button: MenuButton = %BitButton
@onready var bit_button_popup := bit_button.get_popup()
@onready var clear_button: Button = %ClearButton


func _tbt_ready() -> void:
	var _err := tbt.preview_updated.connect(_on_preview_updated)
	bit_button_popup.submenu_popup_delay = 0.0
	_setup_fill_button()
	_update_buttons()


func _setup_fill_button() -> void:
	var _err := fill_button.get_popup().id_pressed.connect(_on_fill_button_popup_id_pressed)
	fill_button.custom_minimum_size.x = fill_button.size.x + 22
	_populate_fill_menu()


func _update_buttons() -> void:
	_update_bit_button()
	_update_clear_button()


func _update_clear_button() -> void:
	if tbt.tiles_manager.has_preview():
		if tbt.tiles_manager.has_preview_terrain_set():
			_enable_clear_button()
		else:
			_disable_clear_button()
	elif tbt.context.bit_data.has_terrain_set():
		_enable_clear_button()
	else:
		_disable_clear_button()



func _disable_clear_button() -> void:
	clear_button.disabled = true
	clear_button.tooltip_text = "No terrain data to clear"


func _enable_clear_button() -> void:
	clear_button.disabled = false
	clear_button.tooltip_text = "Clears all terrain data from selected tiles"

# Creating individual sub-menus, as cannot tell which item is selected in PopupMenu()
# PopupMenu.get_current_index() does not appear to exist in 4.0
# https://github.com/godotengine/godot/pull/38520
func _update_bit_button() -> void:
	bit_button_popup.clear()
	for child in bit_button_popup.get_children():
		child.queue_free()

	var terrain_bits_list : Array
	var terrain_set := tbt.BitData.NULL_TERRAIN_SET

	if tbt.tiles_manager.has_preview_terrain_set():
		terrain_set = tbt.tiles_manager.get_preview_terrain_set()
		terrain_bits_list = tbt.tiles_manager.preview_bit_data.get_terrain_bits_list(true)
	elif tbt.context.bit_data.has_terrain_set():
		terrain_set = tbt.context.bit_data.terrain_set
		terrain_bits_list = tbt.context.bit_data.get_terrain_bits_list(true)
	else:
		_disable_bit_button()
		return

	_enable_bit_button()

	var terrains_item_list := tbt.context.get_terrains_item_list(terrain_set)

	for terrain_bit in terrain_bits_list:
		var terrain_bit_name : String = tbt.texts.TERRAIN_BIT_TEXTS[terrain_bit]
		bit_button_popup.add_item(terrain_bit_name, terrain_bit)
		var idx := bit_button_popup.get_item_index(terrain_bit)

		var terrain_popup_name := _create_terrain_popup(terrain_bit, terrains_item_list)

		bit_button_popup.set_item_submenu(idx, terrain_popup_name)


func _disable_bit_button() -> void:
	bit_button.disabled = true
	bit_button.tooltip_text = "Tiles must have a Terrain Set assigned"


func _enable_bit_button() -> void:
	bit_button.disabled = false
	bit_button.tooltip_text = "Set a single terrain bit in selected tiles"


func _create_terrain_popup(terrain_bit : int, item_list : Array) -> String:
	var terrain_popup := PopupMenu.new()
	terrain_popup.name = TERRAIN_POPUP + str(terrain_bit)
	bit_button_popup.add_child(terrain_popup)
	var _err := terrain_popup.id_pressed.connect(_on_bit_button_terrain_id_pressed.bind(terrain_bit))

	for item in item_list:
		terrain_popup.add_icon_item(item.icon, item.text, item.id)
	terrain_popup.add_item("<empty>", EMPTY_TERRAIN_ID)

	return terrain_popup.name






func _populate_fill_menu() -> void:
	fill_button.get_popup().clear()

	var terrain_sets_count := tbt.context.tile_set.get_terrain_sets_count()
	if terrain_sets_count == 1:
		_populate_fill_menu_terrains(0)
	else:
		for i in range(terrain_sets_count):
			var id := fill_menu_items.size()
			fill_button.get_popup().add_item("Terrain Set [%s]" % i, id)
			fill_button.get_popup().set_item_disabled(id, true)
			fill_menu_items[id] = null
			_populate_fill_menu_terrains(i)


func _populate_fill_menu_terrains(terrain_set : int) -> void:
	for i in range(tbt.context.tile_set.get_terrains_count(terrain_set)):
		var terrain_name := tbt.context.tile_set.get_terrain_name(terrain_set, i)
		var terrain_color := tbt.context.tile_set.get_terrain_color(terrain_set, i)
		var icon := _get_icon(terrain_color)
		var id := fill_menu_items.size()
		fill_button.get_popup().add_icon_item(icon, terrain_name, id)
		fill_menu_items[id] = {"terrain_set": terrain_set, "terrain": i}


func _get_icon(p_color : Color) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	image.fill(p_color)
	return ImageTexture.create_from_image(image)



func _on_fill_button_popup_id_pressed(id : int) -> void:
	if fill_menu_items[id] == null:
		return
	var terrain_set : int = fill_menu_items[id].terrain_set
	var terrain : int = fill_menu_items[id].terrain
	tbt.tiles_manager.fill_terrain(terrain_set, terrain)


func _on_bit_button_terrain_id_pressed(terrain_id : int, terrain_bit : int) -> void:
#	print("terrain_bit=%s, terrain_id=%s" % [terrain_bit, terrain_id])
	if terrain_id == EMPTY_TERRAIN_ID:
		terrain_id = -1
	tbt.tiles_manager.set_terrain_bits(terrain_bit, terrain_id)


func _on_erase_button_pressed() -> void:
	tbt.tiles_manager.erase_terrains()

func _on_preview_updated(_arg) -> void:
	_update_buttons()
