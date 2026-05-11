extends Control

#region VisualAssets
## Icon used when current_level == max_level
@export var icon_lit_texture: Texture2D

## Icon used when current_level != max_level
@export var icon_unlit_texture: Texture2D
#endregion



#region CoreLogic
func set_item(item: Dictionary) -> void:
	var current_level = item.get("current_level", 0)
	var max_level = item.get("max_level", 0)
	
	%Icon.texture = item.get("tex", null)
	%ItemName.text = item.get("item_name", "-")
	%ItemName.set("theme_override_colors/font_color", item.get("item_color", Color("#e9b169")))
	%CurrentLevel.text = str(current_level)
	
	if max_level > 1:
		%MaxLevel.text = "/" + str(max_level)
		
		%StarIcon.texture = icon_lit_texture if current_level == max_level else icon_unlit_texture
			
		%ProgressBarContainer.visible = true
		
		if current_level >= max_level:
			%MaximunLevel.visible = true
		else:
			var current_experience: float = item.get("current_experience", 0.0)
			var next_experience: float = item.get("next_experience", 1.0)
			
			if next_experience <= 0.0:
				next_experience = 1.0
				
			var progress = current_experience / next_experience
			%ProgressBar.value = progress
			%MaximunLevel.visible = false
			
	else:
		%MaxLevel.text = ""
		%StarIcon.texture = icon_lit_texture
		%ProgressBarContainer.visible = true
		%MaximunLevel.visible = true
#endregion
