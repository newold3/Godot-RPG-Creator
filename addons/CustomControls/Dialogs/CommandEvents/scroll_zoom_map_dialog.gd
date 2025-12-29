@tool
extends CommandBaseDialog


var current_type: int


func _ready() -> void:
	super()
	parameter_code = 54
	set_chexkbox_connections()


func set_chexkbox_connections() -> void:
	var nodes = [%ScrollMap, %ZoomMap, %ResetScrollAndZoom]
	var button_group = ButtonGroup.new()
	for i: int in nodes.size():
		var node: CheckBox = nodes[i]
		node.button_group = button_group
		node.toggled.connect(
			func(toggled_on: bool):
				node.get_parent().propagate_call("set_disabled", [!toggled_on])
				node.set_disabled(false)
				if toggled_on:
					current_type = i
					
		)
	
	nodes[0].set_pressed(true)


func set_data() -> void:
	current_type = parameters[0].parameters.get("type", 0)

	if current_type == 0:
		%ScrollMap.set_pressed(true)
		var direction = parameters[0].parameters.get("direction", 0)
		direction = max(0, min(direction, %Direction.get_item_count() - 1))
		%Direction.select(direction)
		var amount = parameters[0].parameters.get("amount", 1)
		%Amount.value = amount
	elif current_type == 1:
		%ZoomMap.set_pressed(true)
		var zoom = parameters[0].parameters.get("zoom", 2)
		%Zoom.value = zoom
	elif current_type == 2:
		%ResetScrollAndZoom.set_pressed(true)
		
	var duration = parameters[0].parameters.get("duration", 0.5)
	%Duration.value = duration
	var wait = parameters[0].parameters.get("wait", true)
	%Wait.set_pressed(wait)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.type = current_type
	commands[-1].parameters.duration = %Duration.value
	commands[-1].parameters.wait = %Wait.is_pressed()

	if current_type == 0:
		commands[-1].parameters.direction = %Direction.get_selected_id()
		commands[-1].parameters.amount = %Amount.value
	elif current_type == 1:
		commands[-1].parameters.zoom = %Zoom.value
	
	return commands
