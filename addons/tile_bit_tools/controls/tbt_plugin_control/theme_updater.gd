@tool
extends Control


const UNASSIGNED := -1

const CATEGORY_EDITOR_CLASS := "EditorInspectorCategory"
const SECTION_EDITOR_CLASS := "EditorInspectorSection"
const CATEGORY_PANEL_GROUP := "TBTCategoryPanel"
const SECTION_BUTTON_GROUP := "TBTSectionButton"
const DEFAULT_MINIMUM_HEIGHT := 16
const DEFAULT_MAXIMUM_HEIGHT := 64


const TBTPlugin := preload("res://addons/tile_bit_tools/controls/tbt_plugin_control/tbt_plugin_control.gd")




enum Overrides {
	FONT, FONT_SIZE, FONT_COLOR, # Label
	NORMAL_FONT, NORMAL_FONT_SIZE, DEFAULT_COLOR, # RichTextLabel
	PANEL, WINDOW_PANEL,  # Panel
	BUTTON_NORMAL, BUTTON_HOVER, BUTTON_PRESSED, BUTTON_DISABLED, BUTTON_FOCUS, # Button
}

var override_properties := {
	Overrides.FONT: "theme_override_fonts/font",
	Overrides.FONT_SIZE: "theme_override_font_sizes/font_size",
	Overrides.FONT_COLOR: "theme_override_colors/font_color",
	Overrides.NORMAL_FONT: "theme_override_fonts/normal_font",
	Overrides.NORMAL_FONT_SIZE: "theme_override_font_sizes/normal_font_size",
	Overrides.DEFAULT_COLOR: "theme_override_colors/default_color",
	Overrides.PANEL: "theme_override_styles/panel",
	Overrides.WINDOW_PANEL: "theme_override_styles/embedded_border",
	Overrides.BUTTON_NORMAL: "theme_override_styles/normal",
	Overrides.BUTTON_HOVER: "theme_override_styles/hover",
	Overrides.BUTTON_PRESSED: "theme_override_styles/pressed",
	Overrides.BUTTON_DISABLED: "theme_override_styles/disabled",
	Overrides.BUTTON_FOCUS: "theme_override_styles/focus",
}

var override_methods := {
	Overrides.FONT: "get_theme_font",
	Overrides.FONT_SIZE: "get_theme_font_size",
	Overrides.FONT_COLOR: "get_theme_color",
	Overrides.NORMAL_FONT: "get_theme_font",
	Overrides.NORMAL_FONT_SIZE: "get_theme_font_size",
	Overrides.DEFAULT_COLOR: "get_theme_color",
	Overrides.PANEL: "get_theme_stylebox",
	Overrides.WINDOW_PANEL: "get_theme_stylebox",
	Overrides.BUTTON_NORMAL: "get_theme_stylebox",
	Overrides.BUTTON_HOVER: "get_theme_stylebox",
	Overrides.BUTTON_PRESSED: "get_theme_stylebox",
	Overrides.BUTTON_DISABLED: "get_theme_stylebox",
	Overrides.BUTTON_FOCUS: "get_theme_stylebox",
}

var overrides_dict := {
	# ----------------------------------------------------
	#			FONTS
	# ----------------------------------------------------
	"TBTCategoryLabel": {
		Overrides.FONT: ["bold", "EditorFonts"],
		Overrides.FONT_SIZE: ["bold_size", "EditorFonts"],
		Overrides.FONT_COLOR: ["font_color", "Editor"],
	},
	"TBTSectionLabel": {
		Overrides.FONT: ["bold", "EditorFonts"],
		Overrides.FONT_SIZE: ["bold_size", "EditorFonts"],
		Overrides.FONT_COLOR: ["font_color", "Editor"],
	},
	"TBTPropertyLabel": {
		Overrides.FONT: ["main", "EditorFonts"],
		Overrides.FONT_SIZE: ["main_size", "EditorFonts"],
		Overrides.FONT_COLOR: ["property_color", "Editor"],
	},
	"TBTSubPropertyLabel": {
		Overrides.FONT: ["main", "EditorFonts"],
		Overrides.FONT_SIZE: ["main_size", "EditorFonts"],
		Overrides.FONT_COLOR: ["sub_inspector_property_color", "Editor"],
	},


	# ----------------------------------------------------
	#			PANELS
	# ----------------------------------------------------
	# TILES INSPECTOR
	"TBTCategoryPanel": {
		Overrides.PANEL: ["bg", "EditorInspectorCategory"],
	},
	"TBTSubinspectorPanel": {
		Overrides.PANEL: ["sub_inspector_property_bg0", "Editor"],
	},
	"TBTSubinspectorOverlayPanel": {
		Overrides.PANEL: ["sub_inspector_bg0", "Editor"],
	},
	"TBTSubinspectorPropertiesPanel": {
		Overrides.PANEL: ["panel", "Tree"],
	},
	"TBTInspectorMessagePanel": {
		Overrides.PANEL: ["bg_group_note", "EditorProperty"],
	},


	# TILES PREVIEW
	"TBTPreviewPanelBackground": {
		Overrides.PANEL: ["panel", "TabContainer"],
	},
	"TBTPreviewPanelForeground": {
		Overrides.PANEL: ["bg", "GraphEdit"],
	},
	"TBTPreviewHBoxPanel": {
		Overrides.PANEL: ["MenuHover", "EditorStyles"],
	},
	"TBTPlaceholderLabel": {
		Overrides.NORMAL_FONT: ["font", "Label"],
		Overrides.NORMAL_FONT_SIZE: ["main_size", "EditorFonts"],
		Overrides.DEFAULT_COLOR: ["property_color", "Editor"],
	},


	# SAVE/EDIT DIALOGS
	"TBTDialogWindow": {
		Overrides.WINDOW_PANEL: ["panel", "ProjectSettingsEditor"],
	},
	"TBTDialogPanelBackground": {
		Overrides.PANEL: ["Background", "EditorStyles"],
	},
	"TBTDialogPanelForeground": {
		Overrides.PANEL: ["PanelForeground", "EditorStyles"],
	},
	"TBTDialogPanelSection": {
		Overrides.PANEL: ["panel", "Tree"],
	},


	# BUTTONS
	"TBTTextButton": {
		Overrides.FONT_COLOR: ["font_color", "Editor"],
		Overrides.FONT: ["main_button_font", "EditorFonts"],
		Overrides.FONT_SIZE: ["main_button_font_size", "EditorFonts"],
#		Overrides.FONT: ["bold", "EditorFonts"],
#		Overrides.FONT_SIZE: ["bold_size", "EditorFonts"],

		Overrides.BUTTON_NORMAL: ["normal", "OptionButton"],
		Overrides.BUTTON_HOVER: ["hover", "OptionButton"],
		Overrides.BUTTON_PRESSED: ["pressed", "OptionButton"],
		Overrides.BUTTON_DISABLED: ["disabled", "OptionButton"],
		Overrides.BUTTON_FOCUS: ["focus", "OptionButton"],
	},
	"TBTToolButton": {
		Overrides.FONT_COLOR: ["font_color", "Editor"],
		Overrides.FONT: ["main", "EditorFonts"],
		Overrides.FONT_SIZE: ["main_size", "EditorFonts"],

		Overrides.BUTTON_NORMAL: ["normal", "OptionButton"],
		Overrides.BUTTON_HOVER: ["hover", "OptionButton"],
		Overrides.BUTTON_PRESSED: ["pressed", "OptionButton"],
		Overrides.BUTTON_DISABLED: ["disabled", "OptionButton"],
		Overrides.BUTTON_FOCUS: ["focus", "OptionButton"],
	},

}


var category_panel_height := UNASSIGNED
var section_button_height := UNASSIGNED

var height_setup_complete := false


var tbt : TBTPlugin


func _tbt_ready() -> void:
	var _err := tbt.theme_update_requested.connect(_on_theme_update_requested)
	_setup_themes()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if !is_instance_valid(tbt):
			return
		_setup_themes()



func _tiles_inspector_added() -> void:
	if !height_setup_complete:
		# only needs to be done once
		_setup_custom_heights()
	await get_tree().process_frame
	_update_themes()


func _setup_themes() -> void:
	# remove from here to avoid pause when activating plugin
	_setup_custom_heights()
	_update_themes()


func _update_themes() -> void:
	tbt.output.debug("_update_themes()")
	_update_groups()
	_update_custom_heights()



func _update_groups() -> void:
	for group in overrides_dict.keys():
		for override in overrides_dict[group].keys():
			var method : String = override_methods[override]
			var args : Array = overrides_dict[group][override]
			var property : String = override_properties[override]
			var value = tbt.base_control.callv(method, args)
			get_tree().set_group(group, property, value)


func _update_node(node : Node) -> void:
	for group in overrides_dict.keys():
		if node.is_in_group(group):
			for override in overrides_dict[group].keys():
				var method : String = override_methods[override]
				var args : Array = overrides_dict[group][override]
				var property : String = override_properties[override]
				var value = tbt.base_control.callv(method, args)
				node.set(property, value)


func _setup_custom_heights() -> void:
	height_setup_complete = true
	category_panel_height = _get_height_by_class(CATEGORY_EDITOR_CLASS)
	tbt.output.debug("category_panel_height=%s" % category_panel_height)
	if not category_panel_height in range(DEFAULT_MINIMUM_HEIGHT, DEFAULT_MAXIMUM_HEIGHT):
		category_panel_height = DEFAULT_MINIMUM_HEIGHT
		height_setup_complete = false
	section_button_height = _get_height_by_class(SECTION_EDITOR_CLASS)
	tbt.output.debug("section_button_height=%s" % section_button_height)
	if not section_button_height in range(DEFAULT_MINIMUM_HEIGHT, DEFAULT_MAXIMUM_HEIGHT):
		section_button_height = DEFAULT_MINIMUM_HEIGHT
		height_setup_complete = false
	tbt.output.debug("_setup_custom_heights() success=%s" % str(height_setup_complete))


func _update_custom_heights() -> void:
	get_tree().set_group(CATEGORY_PANEL_GROUP, "custom_minimum_size", Vector2i(0, category_panel_height))
	get_tree().set_group(SECTION_BUTTON_GROUP, "custom_minimum_size", Vector2i(0, section_button_height))


func _on_theme_update_requested(node : Node) -> void:
	await get_tree().process_frame
	_update_node(node)
	for child in node.find_children("*", "", true, false):
		_update_node(child)

# finds first control of class that has a height > 0
# returns height
func _get_height_by_class(p_class_name : String) -> int:
	var controls := tbt.atlas_source_editor.find_children("*", p_class_name, true, false)
	if controls.size() == 0:
		return 0

	return controls[0].size.y
