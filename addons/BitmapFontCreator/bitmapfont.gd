extends Node
class_name BITMAPFONT

var textures: Array[String] = []
var textures_img: Array[Texture2D] = []
var image_rects: Dictionary = {}
var chars: Dictionary = {}
var kernings: Dictionary = {}
var align: Vector2 = Vector2.ZERO
var height: int = 0



## Adds a new character to the font data
func add_char(character: int, texture: int, rect: int, advance: float = 0.0, _align: Vector2 = Vector2.ZERO) -> void:
	chars[character] = {
		"texture": texture,
		"rect": rect,
		"advance": advance,
		"align": _align
	}



## Adds a texture and its path to the font data
func add_texture(path: String, texture: Texture2D) -> void:
	textures.append(path)
	textures_img.append(texture)



## Returns a string representation of the font data
func get_data() -> String:
	var data: String = ""
	
	data += "Height: %s, Chars count: %s, Kernings count: %s\n" % [height, chars.size(), kernings.size()]
	data += "textures:\n%s\n--------\n" % textures
	data += "chars:\n%s\n--------\n" % chars
	data += "kernings:\n%s\n--------\n" % kernings
	
	return data
