@tool
extends DialogBase


func set_initial_config(config: Dictionary) -> void:
	super(config)
	
	if is_floating:
		%BackgroundContainer.set("theme_override_constants/margin_left", 0)
		%BackgroundContainer.set("theme_override_constants/margin_top", 0)
		%BackgroundContainer.set("theme_override_constants/margin_right", 0)
		%BackgroundContainer.set("theme_override_constants/margin_bottom", 0)
		%DialogMainContainer.set("theme_override_constants/margin_left", 28)
		%DialogMainContainer.set("theme_override_constants/margin_top", 10)
		%DialogMainContainer.set("theme_override_constants/margin_right", 28)
		%DialogMainContainer.set("theme_override_constants/margin_bottom", 2)
