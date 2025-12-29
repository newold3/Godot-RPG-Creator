@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 79


func set_data() -> void:
	var image_id = parameters[0].parameters.get("index", 1)
	var image_modulate = parameters[0].parameters.get("modulate", Color.WHITE)
	var duration = parameters[0].parameters.get("duration", 0)
	var wait = parameters[0].parameters.get("wait", true)
	
	%ImageID.value = image_id
	%Modulate.set_color(image_modulate)
	%Duration.value = duration
	%Wait.set_pressed(wait)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.index = %ImageID.value
	commands[-1].parameters.modulate = %Modulate.get_color()
	commands[-1].parameters.duration = %Duration.value
	commands[-1].parameters.wait = %Wait.is_pressed()
	
	return commands


func _on_modulate_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Image Modulation Color")
	dialog.color_selected.connect(_on_modulate_color_selected)
	dialog.set_color(%Modulate.get_color())


func _on_modulate_color_selected(color: Color) -> void:
	%Modulate.set_color(color)
