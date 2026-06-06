@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 9999


func set_data() -> void:
	var image_id = parameters[0].parameters.get("index", 1)
	
	var default_colors = FileCache.options.get("command_separator_colors", {})
	%Text.text = parameters[0].parameters.get("text", "")
	%TextColor.color = parameters[0].parameters.get("text_color",
		default_colors.get("text_color", Color("#d83039")))
	%BackgroundColor.color = parameters[0].parameters.get("background_color",
		default_colors.get("background_color", Color("#3c0508")))
	
	%Text.grab_focus.call_deferred()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters.text = %Text.text
	commands[-1].parameters.text_color = %TextColor.color
	commands[-1].parameters.background_color = %BackgroundColor.color
	FileCache.options.command_separator_colors = {
		"text_color": %TextColor.color,
		"background_color": %BackgroundColor.color
	}
	return commands


func _on_reset_text_color_pressed() -> void:
	%TextColor.color = Color.WHITE


func _on_reset_background_color_pressed() -> void:
	%BackgroundColor.color = Color("4e363eff")
