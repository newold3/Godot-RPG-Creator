class_name TextManager
extends Node



func get_font_data() -> Dictionary:
	var config: Dictionary
	var font_data: Dictionary = {}
	
	if GameManager.game_state:
		config = GameManager.game_state.current_message_config
	else:
		config = RPGSYSTEM.database.system.default_message_config
		
	var font_path = config.get("font", "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf")
	if AssetManager.exists(font_path):
		font_data.font = load(font_path)
	else:
		font_data.font = null
		
	font_data.text_size = config.get("text_size", 22)
	font_data.outline_size = config.get("outline", 8)
	font_data.outline_color = config.get("outline_color", Color.BLACK)
	font_data.shadow_offset = config.get("shadow_offset", Vector2.ZERO)
	font_data.shadow_color = config.get("shadow_color", Color(0, 0, 0, 0.5765))
	
	return font_data


func set_text_config(node: Node, set_outline: bool = true, set_shadow: bool = true) -> void:
	var config = get_font_data()
	
	if config.font:
		node.propagate_call("set", ["theme_override_fonts/font", config.font])
		node.propagate_call("set", ["theme_override_fonts/normal_font", config.font])
		
	if set_outline:
		node.propagate_call("set", ["theme_override_constants/outline_size", config.outline_size])
		node.propagate_call("set", ["theme_override_colors/font_outline_color", config.outline_color])
		
	if set_shadow:
		node.propagate_call("set", ["theme_override_constants/shadow_offset_x", config.shadow_offset.x])
		node.propagate_call("set", ["theme_override_constants/shadow_offset_y", config.shadow_offset.y])
		node.propagate_call("set", ["theme_override_colors/font_shadow_color", config.shadow_color])
