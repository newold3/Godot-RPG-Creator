@tool
extends CommandBaseDialog


static var last_color_used: Color = Color.WHITE


func _ready() -> void:
	parameter_code = 65
	super()


func set_data() -> void:
	var current_color = parameters[0].parameters.get("color", last_color_used)
	%Color.set_color(current_color)
	var current_duration = parameters[0].parameters.get("duration", 0.5)
	%Duration.value = current_duration
	%Wait.set_pressed(parameters[0].parameters.get("wait", false))
	%RemoveTint.set_pressed(parameters[0].parameters.get("remove", false))


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.color = %Color.get_color()
	commands[-1].parameters.duration = %Duration.value
	commands[-1].parameters.wait = %Wait.is_pressed()
	commands[-1].parameters.remove = %RemoveTint.is_pressed()
	
	return commands


func _on_color_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if parameter_code == 65:
		dialog.title = TranslationManager.tr("Select Tint Screen Color")
	else:
		dialog.title = TranslationManager.tr("Select Flash Color")
	dialog.color_selected.connect(_on_color_selected)
	dialog.set_color(%Color.get_color())


func _on_color_selected(color: Color) -> void:
	%Color.set_color(color)
	last_color_used = color
