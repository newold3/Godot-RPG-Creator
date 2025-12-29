@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 48
	fill_all()


func fill_all() -> void:
	var node = %ActorOptions
	node.clear()
	for i: int in range(1, RPGSYSTEM.database.actors.size(), 1):
		var actor: RPGActor = RPGSYSTEM.database.actors[i]
		var item_name = "%s: %s" % [i, actor.name]
		node.add_item(item_name)
	node.select(0)
	
	node = %ClassOptions
	node.clear()
	for i: int in range(1, RPGSYSTEM.database.classes.size(), 1):
		var rol: RPGClass = RPGSYSTEM.database.classes[i]
		var item_name = "%s: %s" % [i, rol.name]
		node.add_item(item_name)
	node.select(0)


func set_data() -> void:
	var data = parameters[0].parameters
	var actor_id = data.get("actor_id", 0) - 1
	%ActorOptions.select(actor_id if actor_id < %ActorOptions.get_item_count() and actor_id > -1 else 0)
	
	var class_id = data.get("class_id", 0)
	%ClassOptions.select(class_id if class_id < %ClassOptions.get_item_count() and class_id > -1 else 0)
	
	var keep_level = data.get("keep_level", false)
	%KeepLevel.set_pressed(keep_level)


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	
	commands[-1].parameters.actor_id = %ActorOptions.get_selected_id() + 1
	commands[-1].parameters.class_id = %ClassOptions.get_selected_id() + 1
	commands[-1].parameters.keep_level = %KeepLevel.is_pressed()
	
	return commands
