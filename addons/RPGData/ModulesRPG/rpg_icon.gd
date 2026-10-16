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
		var base_tex: Texture = null
		if t is Texture:
			base_tex = t
		elif t is PackedScene:
			var ins = t.instantiate()
			if ins is Sprite2D or ins is TextureRect:
				base_tex = ins.texture
			else:
				var spr = ins.find_child("*", true, false)
				if spr is Sprite2D or spr is TextureRect:
					base_tex = spr.texture
			ins.queue_free()
			if not base_tex:
				var preview_path = path.get_basename() + "_preview.png"
				if ResourceLoader.exists(preview_path):
					var p = ResourceLoader.load(preview_path)
					if p is Texture:
						base_tex = p
		
		if base_tex:
			if region.has_area():
				if _cached_texture:
					return _cached_texture
				
				tex = ImageTexture.create_from_image(base_tex.get_image().get_region(region))
				_cached_texture = tex
			else:
				tex = base_tex
	
	return tex


## Returns a string representation of the icon.
## @return String - The string representation.
func _to_string() -> String:
	return "<RPGIcon %s, %s>" % [path, region]
