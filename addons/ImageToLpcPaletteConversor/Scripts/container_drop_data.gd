@tool
extends MarginContainer

const IMAGE_EXTENSIONS = [
	"png", "jpg", "jpeg", "bmp", "tga", "webp", 
	"svg", "exr", "hdr", "dds", "ktx", "astc"
]

signal dropped_image(image)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return is_visible()


func _drop_data(at_position: Vector2, data: Variant) -> void:
	for file: String in data.files:
		if file.get_extension().to_lower() in IMAGE_EXTENSIONS:
			_update_image(file)
			break


func _update_image(file: String) -> void:
	var tex = load(file)
	dropped_image.emit(tex)
