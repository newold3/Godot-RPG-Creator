class_name GuiCoreSelectedEquipmentCard
extends Control

#region SignalsAndHooks
signal item_updated(data: Dictionary)
#endregion

#region CoreLogic
func set_item(item: Dictionary) -> void:
	var item_name: String = item.get("item_name", item.get("name", ""))
	var is_empty_item = item.is_empty() or (not item.has("item_name") and not item.has("name") and not item.has("tex") and not item.has("icon")) or item_name == "-"

	if is_empty_item:
		_display_empty_item()
		item_updated.emit({})
		return

	var icon_raw = item.get("icon", null)
	var tex = _resolve_icon(icon_raw)
	if not tex:
		tex = _resolve_icon(item.get("tex", null))

	var current_level: int = item.get("current_level", item.get("level", 0))
	var max_level: int = item.get("max_level", 0)
	var current_experience: float = item.get("current_experience", 0.0)
	var next_experience: float = item.get("next_experience", 1.0)
	if next_experience <= 0.0:
		next_experience = 1.0
	var progress = current_experience / next_experience
	var is_max_level = current_level >= max_level and max_level > 1

	var display_data = {
		"name": item_name,
		"color": item.get("item_color", item.get("color", Color("#e9b169"))),
		"texture": tex,
		"current_level": current_level,
		"max_level": max_level,
		"progress": progress,
		"is_max_level": is_max_level
	}

	_display_item(display_data)
	item_updated.emit(display_data)


func _display_empty_item() -> void:
	pass


func _display_item(_data: Dictionary) -> void:
	pass


func _resolve_icon(icon_data: Variant) -> Texture2D:
	if not icon_data:
		return null
	if icon_data is Texture2D:
		return icon_data
	if icon_data is RPGIcon:
		var path: String = icon_data.path
		if not path.is_empty():
			var tex_base: Texture2D = null
			if ResourceLoader.exists(path):
				tex_base = ResourceLoader.load(path)
			elif AssetManager.exists(path):
				tex_base = ResourceLoader.load(path)
			if tex_base:
				if icon_data.region.size.x > 0 and icon_data.region.size.y > 0:
					var atlas = AtlasTexture.new()
					atlas.atlas = tex_base
					atlas.region = icon_data.region
					return atlas
				else:
					return tex_base
		if icon_data.has_method("get_texture"):
			return icon_data.get_texture()
	elif icon_data is String and not icon_data.is_empty():
		if ResourceLoader.exists(icon_data):
			return ResourceLoader.load(icon_data)
		elif AssetManager.exists(icon_data):
			return ResourceLoader.load(icon_data)
	return null
#endregion
