extends RefCounted


const TERRAIN_MODE_ICONS := {
	TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES : ["TerrainMatchCornersAndSides", "EditorIcons"],
	TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS : ["TerrainMatchCorners", "EditorIcons"],
	TileSet.TerrainMode.TERRAIN_MODE_MATCH_SIDES : ["TerrainMatchSides", "EditorIcons"],
}

const EXPAND_PANEL := ["ExpandTree", "EditorIcons"]
const COLLAPSE_PANEL := ["CollapseTree", "EditorIcons"]

const ARROW_EXPANDED := ["arrow", "Tree"]
const ARROW_COLLAPSED := ["arrow_collapsed", "Tree"]


var control : Control

func _init(p_control : Control) -> void:
	control = p_control


func get_icon(icon_data : Array) -> Texture2D:
	return control.get_theme_icon(icon_data[0], icon_data[1])


func get_icon_by_name(icon_name : String) -> Texture2D:
	var icon_data = get(icon_name)
	if icon_data == null:
		return null
	return get_icon(icon_data)


func get_icon_by_editor_name(editor_name : String) -> Texture2D:
	return control.get_theme_icon(editor_name, "EditorIcons")
