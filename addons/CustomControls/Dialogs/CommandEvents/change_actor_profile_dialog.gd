@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 50
	fill_actors()


func fill_actors() -> void:
	var node = %ActorOptions
	node.clear()
	for i: int in range(1, RPGSYSTEM.database.actors.size(), 1):
		var actor: RPGActor = RPGSYSTEM.database.actors[i]
		var item_name = "%s: %s" % [i, actor.name]
		node.add_item(item_name)
	node.select(0)


func set_data() -> void:
	var actor_id = parameters[0].parameters.get("actor_id", 0) - 1
	%ActorOptions.select(actor_id if actor_id < %ActorOptions.get_item_count() and actor_id > -1 else 0)
	
	var profile = ""
	for i in range(1, parameters.size(), 1):
		if profile:
			profile += "\n" + parameters[i].parameters.get("line", "")
		else:
			profile += parameters[i].parameters.get("line", "")
	%ActorProfile.text = profile
	%ActorProfile.grab_focus()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = []
	
	var profile = %ActorProfile.text.split("\n")
	var command
	
	for i in range(profile.size() - 1, -1, -1):
		command = RPGEventCommand.new()
		command.code = 51
		command.indent = parameters[0].indent
		command.parameters.line = profile[i]
		commands.append(command)
	
	var main_command = super()
	main_command[-1].parameters.actor_id = %ActorOptions.get_selected_id() + 1
	commands.append(main_command[-1])
	
	return commands


func _on_actor_options_item_selected(index: int) -> void:
	%ActorProfile.grab_focus()
