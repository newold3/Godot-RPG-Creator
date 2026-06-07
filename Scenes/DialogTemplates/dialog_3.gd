@tool
extends DialogBase

@export_category("Colors For This Dialog")

## Color used for the panel
@export var foreground_color: Color = Color(1.584, 1.584, 0.311):
	set(value):
		foreground_color = value
		if is_node_ready():
			%Background.self_modulate = value
			%NameLeftBackground.self_modulate = value
			%NameRightBackground.self_modulate = value
			%FaceLeftFrame.get_theme_stylebox("panel").modulate_color = value
			%FaceRightFrame.get_theme_stylebox("panel").modulate_color = value

## Color used for the shadow of the panel
@export var shadow_color: Color = Color(1.584, 0.317, 0.311):
	set(value):
		shadow_color = value
		if is_node_ready():
			%BackgroundShadow.self_modulate = value
			%NameLeftBackgroundShadow.self_modulate = value
			%NameRightBackgroundShadow.self_modulate = value


## Color used for the cursor
@export var cursor_color: Color = Color(1.584, 1.584, 0.311):
	set(value):
		cursor_color = value
		if is_node_ready():
			%Cursor.self_modulate = value


## Color used for the decoration of the next paragraph button
@export var next_paragraph_decoration_color: Color = Color.WHITE:
	set(value):
		next_paragraph_decoration_color = value
		if is_node_ready():
			%Decoration.self_modulate = value


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
