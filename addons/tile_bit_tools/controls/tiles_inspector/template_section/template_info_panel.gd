@tool
extends PanelContainer

const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")


var info_label_text := "Type: {type}\nMode: {terrain_mode}\nTiles: {tile_count}\nTerrains: {terrain_count}"

var texts := preload("res://addons/tile_bit_tools/core/texts.gd").new()
var example_folder_path : String

var template_bit_data : TBTPlugin.TemplateBitData

var tbt : TBTPlugin


@onready var template_info_list: ItemList = $MarginContainer/VBoxContainer/HBoxContainer/TemplateInfoList


@onready var template_rect: TextureRect = %TemplateRect

@onready var description_container: PanelContainer = %DescriptionContainer
@onready var expand_button: Button = %ExpandButton
@onready var description_label: RichTextLabel = %DescriptionLabel

@onready var example_button: Button = %ExampleButton
@onready var edit_button: Button = %EditButton
@onready var remove_button: Button = %RemoveButton


func _ready() -> void:
	hide()


func _tbt_ready() -> void:
	_toggle_description_expand_button(false)


func update(p_template_bit_data : TBTPlugin.TemplateBitData) -> void:
	template_bit_data = p_template_bit_data

	if !template_bit_data:
		hide()
		return

	show()

	if template_bit_data.template_description == "":
		description_container.hide()
	else:
		description_container.show()

	description_label.text = template_bit_data.template_description

	template_info_list.update(template_bit_data)


	if template_bit_data.built_in:
		edit_button.hide()
		remove_button.hide()
	else:
		edit_button.show()
		remove_button.show()

	if template_bit_data.example_folder_path != "" && DirAccess.dir_exists_absolute(template_bit_data.example_folder_path):
		example_folder_path = template_bit_data.example_folder_path
		example_button.show()
	else:
		example_folder_path = ""
		example_button.hide()

	template_rect.texture = template_bit_data.preview_texture






func _toggle_description_expand_button(value : bool) -> void:
	if value:
		expand_button.icon = tbt.icons.get_icon(tbt.icons.ARROW_EXPANDED)
		description_label.fit_content = true
	else:
		expand_button.icon = tbt.icons.get_icon(tbt.icons.ARROW_COLLAPSED)
		description_label.fit_content = false




func _open_example_folder() -> void:
	var path := ProjectSettings.globalize_path(example_folder_path)
	var _err := OS.shell_open(path)


# TODO: move to template_manager? make more generalized?
func _remove_template() -> void:
	var confirm_dialog := ConfirmationDialog.new()
	confirm_dialog.title = "Confirm Delete Template"
	confirm_dialog.dialog_text = "Really delete template '%s'?" % template_bit_data.template_name
	confirm_dialog.ok_button_text = "Delete (no undo)"
	var _err := confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	var path := template_bit_data.resource_path
	var _err := DirAccess.remove_absolute(path)
	tbt.output.user("Deleted user template '%s'" % template_bit_data.template_name)
	tbt.templates_update_requested.emit()


func _on_remove_button_pressed() -> void:
	_remove_template()


func _on_edit_button_pressed() -> void:
	tbt.edit_template_requested.emit(template_bit_data)


func _on_example_button_pressed() -> void:
	_open_example_folder()


func _on_expand_button_toggled(button_pressed: bool) -> void:
	_toggle_description_expand_button(button_pressed)
