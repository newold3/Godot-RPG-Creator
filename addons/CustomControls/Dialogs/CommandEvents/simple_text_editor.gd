@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 31


func set_data() -> void:
	var text: String = parameters[0].parameters.get("first_line", "")
	for i in range(1, parameters.size()):
		var t = parameters[i].parameters.get("line", "")
		text += "\n" + t
				
	set_text(text)


func set_text(text: String) -> void:
	%TextEdit.text = text
	%TextEdit.grab_focus()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = []
	
	var text = %TextEdit.text.strip_edges()
	var lines = text.split("\n")
	# Comment lines command
	for i in range(lines.size() - 1, 0, -1):
		var line = lines[i]
		var command = RPGEventCommand.new()
		command.code = 32
		command.indent = parameters[0].indent
		command.parameters = {"line": line}
		commands.append(command)
	# Comment command
	var main_command = super()
	main_command[-1].parameters.first_line = lines[0]
	commands.append(main_command[-1])
	
	return commands
