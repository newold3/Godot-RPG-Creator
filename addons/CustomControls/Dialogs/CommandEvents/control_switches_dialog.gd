@tool
extends CommandBaseDialog


var current_data: Dictionary
var current_variable_id: int = 1
var busy: bool = false


func _ready() -> void:
	super()
	parameter_code = 17


func set_data() -> void:
	var data: Dictionary = parameters[0].parameters
	current_data = data.duplicate()
	busy = true
	var operation = data.get("operation_type", 0)
	current_data.operation_type = operation
	var from = data.get("from", 1)
	var to = data.get("to", 1)
	if from != to:
		%Random.set_pressed(true)
		%From.value = from
		%To.value = to
	else:
		%Single.set_pressed(false)
		%Single.set_pressed(true)
		%From.value = from
		%To.value = from
	current_data.from = %From.value
	current_data.to = %To.value
	if operation == 0:
		%OperationON.set_pressed(false)
		%OperationON.set_pressed(true)
	else:
		%OperationOFF.set_pressed(true)
	_set_switch_name()
	busy = false


func _on_item_id_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_switch_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 1
	dialog.target = null
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_set_switch_name)
	dialog.setup(current_data.from)


func _on_switch_changed(index: int, target: Node) -> void:
	current_data.from = index
	current_data.to = index
	_set_switch_name()


func _set_switch_name() -> void:
	var switches = RPGSYSTEM.system.switches
	var index = current_data.from
	var switch_name = "%s: %s" % [
		str(index).pad_zeros(4),
		switches.get_item_name(index)
	]
	%ItemID.text = switch_name


func _on_from_value_changed(value: float) -> void:
	if busy: return
	if value > current_data.to:
		%From.value = current_data.to
	else:
		current_data.from = value


func _on_to_value_changed(value: float) -> void:
	if busy: return
	if value < current_data.from:
		%To.value = current_data.from
	else:
		current_data.to = value


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()
	commands[-1].parameters = current_data
	
	return commands


func _on_single_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%From.set_disabled(true)
		%To.set_disabled(true)
		%ItemID.set_disabled(false)


func _on_random_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%From.set_disabled(false)
		%To.set_disabled(false)
		%ItemID.set_disabled(true)


func _on_operation_on_toggled(toggled_on: bool, operation_type: int) -> void:
	if toggled_on: current_data.operation_type = operation_type


func _on_operation_off_toggled(toggled_on: bool, operation_type: int) -> void:
	if toggled_on: current_data.operation_type = operation_type
