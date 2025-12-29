@tool
extends CommandBaseDialog

func _ready() -> void:
	super()
	parameter_code = 69

func set_data() -> void:
	var current_transparency = parameters[0].parameters.get("value", 1.0)
	%Slider.set_value(current_transparency)
	%PreviewTransparency.modulate.a = current_transparency

func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.value = %Slider.value
	return commands

func _on_slider_value_changed(value: float) -> void:
	%PreviewTransparency.modulate.a = value
