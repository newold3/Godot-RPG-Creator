extends PanelContainer


func set_image(image_path: String, region: Rect2 = Rect2()) -> void:
	if AssetManager.exists(image_path):
		if region.has_area():
			var atlas = AtlasTexture.new()
			atlas.atlas = load(image_path)
			atlas.region = region
			%Icon.texture = atlas
		else:
			%Icon.texture = load(image_path)
