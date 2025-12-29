extends Control


func set_item(item: Dictionary) -> void:
	var current_level = item.get("current_level", 0)
	var max_level = item.get("max_level", 0)
	
	%Icon.texture = item.get("tex", null)
	%ItemName.text = item.get("item_name", "-")
	%ItemName.set("theme_override_colors/font_color", item.get("item_color", Color("#e9b169")))
	%CurrentLevel.text = str(current_level)
	%MaxLevel.text = str(max_level)
	
	if max_level > 1:
		var current_experience: float = item.get("current_experience", 0.0)
		var next_experience: float = item.get("next_experience", 0.0)
		var progress = current_experience / next_experience
		%ProgressBarContainer.visible = true
		%ProgressBar.value = progress
		%MaximunLevel.visible = current_level == max_level
	else:
		%ProgressBarContainer.visible = false
