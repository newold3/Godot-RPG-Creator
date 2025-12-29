extends ResourceFormatLoader


@export var algo: RPGActor


func _get_recognized_extensions() -> PackedStringArray:
	var extensions: PackedStringArray = PackedStringArray(
		["pcdata", "npcdata", "anidata"]
	)
	
	return extensions


func _load(path, original_path, options, _recurse):
	print([path, original_path, options, _recurse])
