extends RefCounted

const VERSION := "1.1.0"

# ------------------------
# 	ENUMS
# ------------------------

enum Errors {
	NULL_ERROR = -999,
	OK = Error.OK,
	FAILED = Error.FAILED,
	MISSING_TILE_SET = 900,
	MISSING_SOURCE = 901,
	MISSING_TILES = 902,
	MISSING_BIT_DATA = 903,
	INVALID_TBT_PLUGIN_CONTROL=904,
	INVALID_TILES_PREVIEW=905,
	MULTIPLE_TERRAIN_SETS = 910,
	UNSUPPORTED_SHAPE = 911,

}


enum TemplateTypes {BUILT_IN, USER}



# ------------------------
# 	PATHS
# ------------------------

const BUILTIN_TEMPLATES_PATH := "res://addons/tile_bit_tools/templates/"
const GODOT_TEMPLATES_FOLDER := "/Godot/tile_bit_tools_templates/"
const PROJECT_TEMPLATES_PATH := "user://addons/tile_bit_tools/templates/"

# ------------------------
# 	USER SETTINGS
# ------------------------

const PROJECT_SETTINGS_PATH := "addons/tile_bit_tools/"

const Settings := {
	"user_templates_path": {
		"path": PROJECT_SETTINGS_PATH + "paths/user_templates_path",
		"default": "",
		"type": TYPE_STRING,
		"hint_string": PROPERTY_HINT_DIR,
	},
	"output_show_user": {
		"path": PROJECT_SETTINGS_PATH + "output/show_user_messages",
		"default": true,
		"type": TYPE_BOOL,
	},
	"output_show_info": {
		"path": PROJECT_SETTINGS_PATH + "output/show_info_messages",
		"default": false,
		"type": TYPE_BOOL,
	},
	"output_show_debug": {
		"path": PROJECT_SETTINGS_PATH + "output/show_debug_messages",
		"default": false,
		"type": TYPE_BOOL,
	},
	# Default colors from the "bright" color scheme at
	# https://personal.sron.nl/~pault/
	"colors_terrain_01": {
		"path": PROJECT_SETTINGS_PATH + "colors/template_terrain_1",
		"default": Color("AA3377"), # pink
		"type": TYPE_COLOR,
	},
	"colors_terrain_02": {
		"path": PROJECT_SETTINGS_PATH + "colors/template_terrain_2",
		"default":  Color("CCBB44"), # yellow
		"type": TYPE_COLOR,
	},
	"colors_terrain_03": {
		"path": PROJECT_SETTINGS_PATH + "colors/template_terrain_3",
		"default": Color("228833"), # green
		"type": TYPE_COLOR,
	},
	"colors_terrain_04": {
		"path": PROJECT_SETTINGS_PATH + "colors/template_terrain_4",
		"default": Color("66ccee"), # cyan
		"type": TYPE_COLOR,
	},
}


# ------------------------
# 	GROUPS
# ------------------------


const GROUP_DYNAMIC_CONTAINER := "TBTDynamicContainer"
