@tool
extends Window

const MIN_WIDTH_PROPORTION := 0.3
const MIN_HEIGHT_PROPORTION := 0.3


# class extended by SaveTemplateDialog and EditTemplateDialog

const DEFAULT_TEMPLATE_NAME := "User Template"
const DEFAULT_TEMPLATE_DESCRIPTION := ""
const DEFAULT_TEMPLATE_TAGS := ""

var INFO_LABEL_TEXT := "Tiles: {tile_count}\nTerrains: {terrain_count}"


const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")

const BitDataDrawNode := preload("res://addons/tile_bit_tools/controls/bit_data_draw/bit_data_draw_node.gd")

var template_bit_data : TBTPlugin.TemplateBitData


var tbt : TBTPlugin

@onready var name_edit: LineEdit = %NameEdit
@onready var description_edit: TextEdit = %DescriptionEdit
@onready var tags_edit: LineEdit = %TagsEdit


@onready var preview_rect: TextureRect = %PreviewRect

@onready var folder_option_button: OptionButton = %FolderOptionButton
@onready var template_info_list: ItemList = %TemplateInfoList


func _ready() -> void:
	hide()
	var _err := close_requested.connect(close_dialog)
	template_info_list.show_custom_tags = false


func _tbt_ready() -> void:
	_setup_connections()


func _setup_connections() -> void:
	# override this
	pass


# call after get template_bit_data
func show_dialog() -> void:
	_setup_dialog()
	popup_centered()


# connected to buttons/closing dialog,
# do not need to call
func close_dialog() -> void:
	template_bit_data = null
	hide()


# ----------------------------------
# 		COMMON SETUP
# ----------------------------------

func _setup_dialog() -> void:
	_set_size()
	_setup_texture()
	template_info_list.update(template_bit_data)
	_setup_folders_button()
	_setup_initial_values()


func _set_size() -> void:
	set("min_size", Vector2i(Vector2(get_tree().root.size) * Vector2(MIN_WIDTH_PROPORTION, MIN_HEIGHT_PROPORTION)))
#	set("max_size", get_tree().root.size * 0.75)


func _setup_texture() -> void:
	var bit_data_draw_node : BitDataDrawNode = tbt.template_manager.get_bit_data_draw()
	preview_rect.texture = await bit_data_draw_node.get_bit_texture(template_bit_data)



func _setup_folders_button() -> void:
	folder_option_button.clear()

	for i in range(tbt.template_manager.template_folder_paths.size()):
		var folder_path : Dictionary = tbt.template_manager.template_folder_paths[i]
		if folder_path.type != tbt.G.TemplateTypes.USER:
			continue
		if !folder_path.has("name"):
			continue
		folder_option_button.add_item(folder_path.name, i)

		var tooltip : String = folder_path.tooltip + "\n" + folder_path.path
		var idx := folder_option_button.get_item_index(i)
		folder_option_button.set_item_tooltip(idx, tooltip)

	folder_option_button.get_popup().add_to_group("TBTPopupMenu")




func _setup_initial_values() -> void:
	# override this
	# name
	# description
	# tags
	# save path label
	pass


# ---------------------------
# 	SAVE FUNCTIONS
# ---------------------------

func _save() -> void:
	_update_template_bit_data()

	var path := _get_save_path()
	var result := ResourceSaver.save(template_bit_data, path)

	if result != OK:
		tbt.output.user("Error saving template", tbt.G.Errors.FAILED)
		tbt.output.debug("ResourceSaver error: %s" % result)
		close_dialog()
		return

	tbt.output.user("Saved user template '%s' to %s " % [template_bit_data.template_name, path])
	tbt.templates_update_requested.emit()
	close_dialog()


func _update_template_bit_data() -> void:
	if name_edit.text == "":
		template_bit_data.template_name = DEFAULT_TEMPLATE_NAME
	else:
		template_bit_data.template_name = name_edit.text
	template_bit_data.template_description = description_edit.text
	template_bit_data._custom_tags = _get_custom_tags()
	template_bit_data.version = tbt.G.VERSION


func _get_custom_tags() -> Array:
	var tags := []
	var tag_texts := tags_edit.text.split(",")
	for text in tag_texts:
		text = text.strip_edges()
		if text == "":
			continue
		tags.append(text)
	return tags


func _get_save_path() -> String:
	# override this function
	return ""






func _on_save_button_pressed() -> void:
	_save()


func _on_cancel_button_pressed() -> void:
	close_dialog()
