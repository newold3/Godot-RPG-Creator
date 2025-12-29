@tool
extends Control

const NULL_TERRAIN_SET_INDEX := 0

const NULL_OPTION_ID := 999

const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")


var TerrainPicker := preload("res://addons/tile_bit_tools/controls/tiles_inspector/template_section/terrain_picker.tscn")
var SelectedTag := preload("res://addons/tile_bit_tools/controls/tiles_inspector/template_section/selected_tag.tscn")

var templates := {}

var terrain_pickers := []
var terrain_sets := {}

var selected_tags := []
var selected_template_id := -1
var selected_template : TBTPlugin.TemplateBitData
var selected_terrain_set := -1

var tbt : TBTPlugin

@onready var tags_menu_button: MenuButton = %TagsMenuButton
@onready var tags_popup := tags_menu_button.get_popup()

@onready var tags_container: HFlowContainer = %TagsContainer

@onready var templates_option_button: OptionButton = %TemplatesOptionButton
@onready var template_info_panel: PanelContainer = %TemplateInfoPanel
@onready var terrain_set_option_button: OptionButton = %TerrainSetOptionButton
@onready var terrain_pickers_container: VBoxContainer = %TerrainPickersContainer

@onready var terrain_container: PanelContainer = %TerrainContainer

@onready var template_section_panel: PanelContainer = $TemplateSectionPanel



func _tbt_ready() -> void:

	var _err := tbt.templates_updated.connect(_on_templates_updated)
	_err = tbt.reset_requested.connect(_on_reset_requested)

	_err = templates_option_button.item_selected.connect(_on_template_selected)
	_err = terrain_set_option_button.item_selected.connect(_on_terrain_set_selected)

	_err = tags_popup.id_pressed.connect(_add_tag)
	_reset_tags()


# --------------------------------------
# 		TAGS
# --------------------------------------

func _reset_tags() -> void:
	for child in tags_container.get_children():
		child.queue_free()

	selected_tags.clear()
	_update_tags_popup()


func _update_tags_popup() -> void:
	tags_popup.clear()
	var item_list := tbt.template_manager.template_loader.get_tags_item_list(true, true, selected_tags)

	if item_list.size() == 0:
		tags_menu_button.disabled = true
		tags_menu_button.tooltip_text = "No additional filters available"
		return

	tags_menu_button.disabled = false
	tags_menu_button.tooltip_text = ""

	for item in item_list:
		var item_text : String = item.text + " (Templates: %s)" % item.count
		var icon = item.tag.get_icon(tbt.base_control)
		if icon:
			tags_popup.add_icon_item(icon, item_text, item.id)
		else:
			tags_popup.add_item(item_text, item.id)

	_update_templates_option_button()


func _add_tag(tag_id : int) -> void:
	selected_tags.append(tag_id)
	var tag_control := SelectedTag.instantiate()
	var tag := tbt.template_manager.template_loader.get_tag(tag_id)
	tags_container.add_child(tag_control)
	tag_control.setup(tag, tbt.base_control)
	tag_control.tag_removed.connect(_on_tag_removed.bind(tag_id))
	_update_tags_popup()


func _on_tag_removed(tag_id : int) -> void:
	selected_tags.erase(tag_id)
	_update_tags_popup()



# --------------------------------------
# 		TEMPLATES
# --------------------------------------

func _clear_templates_option_button() -> void:
	templates_option_button.clear()
	selected_template_id = -1


func _update_templates_option_button() -> void:
	templates_option_button.clear()
	templates_option_button.add_item("", NULL_OPTION_ID)

	var templates_list := tbt.template_manager.template_loader.get_templates_item_list(selected_tags)
	for item in templates_list:
		templates_option_button.add_item(item.text, item.id)

	_force_select_template(NULL_OPTION_ID)


func _force_select_template(id : int) -> void:
	var index := templates_option_button.get_item_index(id)
	templates_option_button.select(index)
	_on_template_selected(index) # selecting via script does not emit signal


func _on_template_selected(index : int) -> void:
	selected_template_id = templates_option_button.get_item_id(index)
	selected_template = tbt.template_manager.template_loader.get_template(selected_template_id)
	_update_template_panel()
	_update_terrain_sets()
	_update_terrain_pickers_from_template()
	_update_template_info_panel()
	tbt.tiles_manager.clear_preview()


func _update_template_info_panel() -> void:
	template_info_panel.update(selected_template)


func _update_template_panel() -> void:
	if selected_template:
		template_section_panel.add_to_group("TBTSubinspectorPanel")
		tbt.theme_update_requested.emit(template_section_panel)
	else:
		template_section_panel.remove_from_group("TBTSubinspectorPanel")
		template_section_panel.set("theme_override_styles/panel", StyleBoxEmpty.new())






# --------------------------------------
# 		TERRAIN SET
# --------------------------------------


func _update_terrain_sets() -> void:
	if selected_template_id == NULL_OPTION_ID:
		terrain_container.hide()
	else:
		terrain_container.show()
	_update_terrain_set_option_button()


func _update_terrain_set_option_button() -> void:
	var item_list := []
	if selected_template:
		item_list = tbt.context.get_terrain_sets_item_list(selected_template.terrain_mode)

	_update_option_button(terrain_set_option_button, item_list, false)

	if item_list.size() == 0:
		terrain_set_option_button.disabled = true
		terrain_set_option_button.tooltip_text = "No terrain sets found matching template mode. Create a new one in the TileSet."
	else:
		terrain_set_option_button.disabled = false
		terrain_set_option_button.tooltip_text = ""
		_force_select_terrain_set(item_list[0].id)


func _force_select_terrain_set(id : int) -> void:
	var index := terrain_set_option_button.get_item_index(id)
	terrain_set_option_button.select(index)
	_on_terrain_set_selected(index) # selecting via script does not emit signal


func _on_terrain_set_selected(index : int) -> void:
	selected_terrain_set = terrain_set_option_button.get_item_id(index)
	_update_terrain_pickers_from_terrain_set()


# --------------------------------------
# 		TERRAINS
# --------------------------------------


func _update_terrain_pickers_from_template() -> void:
	for child in terrain_pickers_container.get_children():
		terrain_pickers_container.remove_child(child)

	if !selected_template:
		return

	for i in range(selected_template.get_terrain_count()):
		terrain_pickers.append(_add_terrain_picker(i))


func _update_terrain_pickers_from_terrain_set() -> void:
	for terrain_picker in terrain_pickers:
		terrain_picker.terrain_set = selected_terrain_set


func _add_terrain_picker(index : int) -> Control:
	var terrain_picker := TerrainPicker.instantiate()
	terrain_pickers_container.add_child(terrain_picker)
	terrain_picker.setup(tbt, index, selected_template.get_terrain_color(index), selected_template.terrain_mode)
	var _err := terrain_set_option_button.item_selected.connect(terrain_picker._on_terrain_set_changed)
	terrain_picker.item_selected.connect(_request_preview)
	terrain_picker.terrain_set = selected_terrain_set
	return terrain_picker



func _request_preview() -> void:
	var terrain_mapping := _get_terrain_mapping()
	tbt.tiles_manager.apply_template_terrains(selected_template, selected_terrain_set, terrain_mapping)



func _update_option_button(option_button : OptionButton, item_list : Array, add_empty_item := false) -> void:

	option_button.clear()
	if add_empty_item:
		option_button.add_item("", NULL_OPTION_ID)

	for item in item_list:
		if item.has("icon"):
			option_button.add_icon_item(item.icon, item.text, item.id)
		else:
			option_button.add_item(item.text, item.id)



## Returns a dictionary
## 	key = template terrain id
## 	value = tileset terrain id
func _get_terrain_mapping() -> Dictionary:
	var mapping := {}
	var has_data := false

	for picker in terrain_pickers:
		var terrain_id : int = picker.get_selected_item_id()
		if terrain_id != -1:
			has_data = true
		mapping[picker.index] = picker.get_selected_item_id()

	if has_data:
		return mapping
	else:
		return {}



func _on_templates_updated() -> void:
	_reset_tags()


func _on_reset_requested() -> void:
	_reset_tags()

