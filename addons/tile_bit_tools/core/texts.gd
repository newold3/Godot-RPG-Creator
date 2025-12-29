extends RefCounted

const G := preload("res://addons/tile_bit_tools/core/globals.gd")
const BitData := preload("res://addons/tile_bit_tools/core/bit_data.gd")


const ERROR_TEXTS := {
#	G.Errors.OK: "result=OK",
	G.Errors.MISSING_TILE_SET: "TileSet not found",
	G.Errors.MISSING_SOURCE: "TileSetAtlasSource not found",
	G.Errors.MISSING_TILES: "TileData not found",
	G.Errors.MISSING_BIT_DATA: "TileData failed to parse",
	G.Errors.INVALID_TBT_PLUGIN_CONTROL: "TBTPluginControl invalid",
	G.Errors.INVALID_TILES_PREVIEW: "TilesPreview invalid",
	G.Errors.MULTIPLE_TERRAIN_SETS: "Selected tiles contain more than one terrain set",
	G.Errors.UNSUPPORTED_SHAPE: "Current tile shape is not supported",
}


const TERRAIN_MODE_TEXTS := {
	TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES : "Corners and Sides",
	TileSet.TerrainMode.TERRAIN_MODE_MATCH_CORNERS : "Corners",
	TileSet.TerrainMode.TERRAIN_MODE_MATCH_SIDES : "Sides",
}

const TERRAIN_BIT_TEXTS := {
	BitData.TerrainBits.TOP_LEFT_CORNER: "Top Left Corner",
	BitData.TerrainBits.TOP_SIDE: "Top Side",
	BitData.TerrainBits.TOP_RIGHT_CORNER: "Top Right Corner",
	BitData.TerrainBits.RIGHT_SIDE: "Right Side",
	BitData.TerrainBits.BOTTOM_RIGHT_CORNER: "Bottom Right Corner",
	BitData.TerrainBits.BOTTOM_SIDE: "Bottom Side",
	BitData.TerrainBits.BOTTOM_LEFT_CORNER: "Bottom Left Corner",
	BitData.TerrainBits.LEFT_SIDE: "Left Side",
	BitData.TerrainBits.CENTER: "Tile Terrain (Center)",
}


const EMPTY_ITEM := "<empty>"

const WELCOME_MESSAGE := "Welcome to TileBitTools. Please report bugs or suggestions to github.com/dandeliondino/tile_bit_tools. To change which messages you see here, go to Project Settings -> General -> Addons -> Tile Bit Tools (make sure 'Advanced' is enabled)"
const WELCOME_MESSAGE2 := "Note: Please back up your project before applying any changes."











