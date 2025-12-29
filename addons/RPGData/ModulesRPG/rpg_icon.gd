@tool
class_name RPGIcon
extends Resource

## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGIcon"

## Path to the icon image.
@export var path: String = ""

## Region of the icon image.
@export var region: Rect2 = Rect2()

var _cached_texture: Texture


func _init(p_path: String = "", p_region: Rect2 = Rect2()) -> void:
	path = p_path
	region = p_region


func is_empty() -> bool:
	return path.is_empty() or not ResourceLoader.exists(path)

## Clears the properties of the icon.
func clear() -> void:
	path = ""
	region = Rect2()

## Clones the icon.
## @param value bool - Whether to perform a deep clone.
## @return RPGIcon - The cloned icon.
func clone(value: bool = true) -> RPGIcon:
	return duplicate(value)


## Return texture for this icon
func get_texture() -> Texture:
	var tex = null
	if ResourceLoader.exists(path):
		var t = ResourceLoader.load(path)
		
		if region:
			if _cached_texture:
				return _cached_texture
			
			tex = ImageTexture.create_from_image(t.get_image().get_region(region))
			_cached_texture = tex
		else:
			tex = t
	
	return tex


## Returns a string representation of the icon.
## @return String - The string representation.
func _to_string() -> String:
	return "<RPGIcon %s, %s>" % [path, region]
