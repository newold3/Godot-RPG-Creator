@tool
extends CommandBaseDialog

var current_data: Dictionary
var current_event: RPGEvent


func _ready() -> void:
	super()
	parameter_code = 19
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene is RPGMap:
		current_event = edited_scene.current_event
		_fill_events((edited_scene.events.get_events()))
	_fill_switches()


func _fill_switches() -> void:
	var node = %SelfSwitch
	node.clear()
	var switches = RPGSYSTEM.system.self_switches.get_switch_names()
	for sw in switches:
		node.add_item("Switch " + sw)


func _fill_events(events: Array) -> void:
	var node = %Event
	node.clear()
	
	node.add_item("This Event")
	node.set_item_metadata(-1, 0)
	
	for event: RPGEvent in events:
		if event.name:
			node.add_item(event.name)
		else:
			node.add_item("Event #%s" % event.id)
		node.set_item_metadata(-1, event._uniq_id)
		if current_event and event._uniq_id == current_event._uniq_id:
			node.select(-1)


func set_data() -> void:
	var data = parameters[0].parameters
	current_data = data.duplicate()
	var operation = data.get("operation_type", 0)
	current_data.operation_type = operation
	%SelfSwitch.select(data.get("switch_id", 0))
	current_data.switch_id = %SelfSwitch.get_selected_id()
	if operation == 0:
		%OperationON.set_pressed(false)
		%OperationON.set_pressed(true)
	else:
		%OperationOFF.set_pressed(true)
		
	var event_id = current_data.get("event_id", 0)
	%Event.select(0)
	for i in range(1, %Event.get_item_count()):
		if event_id == %Event.get_item_metadata(i):
			%Event.select(i)
			break


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters = current_data
	return commands


func _on_operation_on_toggled(toggled_on: bool, operation_type: int) -> void:
	if toggled_on: current_data.operation_type = operation_type


func _on_operation_off_toggled(toggled_on: bool, operation_type: int) -> void:
	if toggled_on: current_data.operation_type = operation_type


func _on_self_switch_item_selected(index: int) -> void:
	current_data.switch_id = index


func _on_event_item_selected(index: int) -> void:
	current_data.event_id = %Event.get_item_metadata(index)
