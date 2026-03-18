@tool
class_name AssetConfig
extends RefCounted

## List of ORIGINAL folders containing the individual assets.
## IMPORTANT: Paths must always end with “/”.
const SOURCE_FOLDERS: Array[String] = [
	"res://addons/rpg_character_creator/Data/",
	"res://addons/rpg_character_creator/sounds/",
	"res://addons/rpg_character_creator/textures/",
	"res://Assets/EffekEffects/MAGICALxSPIRAL/Texture/",
	"res://Assets/EffekEffects/tktk01/Texture/",
	"res://Assets/EffekEffects/tktk02/Parts/"
]

## List of compressed OUTPUT files.
## The order must match SOURCE_FOLDERS (Folder 0 is compressed into zip 0).
const ZIPS: Array[String] = [
	"res://data/AssetsCore/lpc_db.grc",
	"res://data/AssetsCore/lpc_sounds.grc",
	"res://data/AssetsCore/lpc_textures.grc",
	"res://data/AssetsCore/effek_textures_pack1.grc",
	"res://data/AssetsCore/effek_textures_pack2.grc",
	"res://data/AssetsCore/effek_textures_pack3.grc"
]

## Only these file types will be included in the package.
## We ignore .gd, .tscn, .tres, etc. to avoid class and cache conflicts.
const ALLOWED_EXTENSIONS: Array[String] = [
	"png", "jpg", "jpeg", "bmp", "tga", "webp", # Images
	"ogg", "mp3", "wav",                        # Audio
	"lcc"                                       # Config Files
]
