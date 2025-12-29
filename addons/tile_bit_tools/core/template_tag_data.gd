extends RefCounted

const SEPARATOR := 0

const TemplateBitData := preload("res://addons/tile_bit_tools/core/template_bit_data.gd")

enum Tags {
	BUILT_IN,
	USER,
	ONE_OR_TWO_TERRAINS,
	THREE_PLUS_TERRAINS,
	MATCH_CORNERS_AND_SIDES,
	MATCH_CORNERS,
	MATCH_SIDES,
}


class TemplateTag:
	var test_func : Callable
	var text : String
	var color : Color
	var icon := ""
	var custom_tag := false

	var id : int

	var custom_tag_icons := {
		"Godot 3": "Godot",
		"Incomplete Autotile": "NodeWarning",
		"Plugin Required": "NodeWarning",
		"TilePipe2": "TileSet",
		"Tilesetter": "TileSet",

	}

	func _init(p_text : String, p_test_func = null, p_icon = null, p_color = null):
		text = p_text
		if p_test_func:
			test_func = p_test_func
		if p_icon:
			icon = p_icon
		if p_color:
			color = p_color

		if icon == "":
			icon = custom_tag_icons.get(text, "")


	func get_template_has_tag(bit_data : TemplateBitData) -> bool:
		if test_func:
			return test_func.call(bit_data)
		else:
			return text in bit_data._custom_tags

	func get_test_result(bit_data : TemplateBitData) -> bool:
		return test_func.call(bit_data)

	func get_icon(base_control : Control) -> Texture2D:
		if icon == "":
			return null
		if icon.is_absolute_path():
			return load(icon)
		return base_control.get_theme_icon(icon, "EditorIcons")

	func has_test() -> bool:
		if test_func:
			return true
		return false



var tags := {
	Tags.BUILT_IN: TemplateTag.new(
		"Type: Built-In",
		func(bit_data: TemplateBitData):
			return bit_data.built_in,
		"Tools",
		null,
	),
	Tags.USER: TemplateTag.new(
		"Type: User",
		func(bit_data: TemplateBitData):
			return !bit_data.built_in,
		"File",
		Color.YELLOW,
	),
#	Tags.ONE_OR_TWO_TERRAINS: TemplateTag.new(
#		"Terrains: 1-2",
#		func(bit_data: TemplateBitData):
#			return bit_data.template_terrain_count <= 2,
#		null,
#		null,
#	),
#	Tags.THREE_PLUS_TERRAINS: TemplateTag.new(
#		"Terrains: 3+",
#		func(bit_data: TemplateBitData):
#			return bit_data.template_terrain_count >= 3,
#		null,
#		null,
#	),
	Tags.MATCH_CORNERS_AND_SIDES: TemplateTag.new(
		"Mode: Corners and Sides",
		func(bit_data: TemplateBitData):
			return bit_data.terrain_mode == TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES,
		"TerrainMatchCornersAndSides",
		null,
	),
	Tags.MATCH_CORNERS: TemplateTag.new(
		"Mode: Corners",
		func(bit_data: TemplateBitData):
			return bit_data.terrain_mode == TileSet.TERRAIN_MODE_MATCH_CORNERS,
		"TerrainMatchCorners",
		null,
	),
	Tags.MATCH_SIDES: TemplateTag.new(
		"Mode: Sides",
		func(bit_data: TemplateBitData):
			return bit_data.terrain_mode == TileSet.TERRAIN_MODE_MATCH_SIDES,
		"TerrainMatchSides",
		null,
	),
}

var tag_display := [
	Tags.BUILT_IN,
	Tags.USER,
	Tags.MATCH_CORNERS_AND_SIDES,
	Tags.MATCH_CORNERS,
	Tags.MATCH_SIDES,
#	Tags.ONE_OR_TWO_TERRAINS,
#	Tags.THREE_PLUS_TERRAINS,
]


