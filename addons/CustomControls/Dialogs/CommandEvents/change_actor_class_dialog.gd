@tool
extends CommandBaseDialog

#region Lifecycle & Setup
## Initializes the Change Class dialog
func _ready() -> void:
	super()
	parameter_code = 48
	fill_all()



## Populates Actor and Class dropdowns injecting UID metadata
func fill_all() -> void:
	var node = %ActorOptions
	node.clear()
	for i: int in range(1, RPGSYSTEM.database.actors.size(), 1):
		var actor: RPGActor = RPGSYSTEM.database.actors[i]
		var item_name = "%s: %s" % [i, actor.name]
		node.add_item(item_name)
		node.set_item_metadata(node.get_item_count() - 1, RPGSYSTEM.id_to_uid("actors", i))
	node.select(0)
	
	node = %ClassOptions
	node.clear()
	for i: int in range(1, RPGSYSTEM.database.classes.size(), 1):
		var rol: RPGClass = RPGSYSTEM.database.classes[i]
		var item_name = "%s: %s" % [i, rol.name]
		node.add_item(item_name)
		node.set_item_metadata(node.get_item_count() - 1, RPGSYSTEM.id_to_uid("classes", i))
	node.select(0)



## Parses the raw command securely
func set_data() -> void:
	var data = parameters[0].parameters
	
	var uid_actor = data.get("actor_id", 0)
	var classic_actor_id = RPGSYSTEM.uid_to_id("actors", uid_actor) if uid_actor > 0 else 1
	var actor_index = classic_actor_id - 1
	%ActorOptions.select(actor_index if actor_index < %ActorOptions.get_item_count() and actor_index > -1 else 0)
	
	var uid_class = data.get("class_id", 0)
	var classic_class_id = RPGSYSTEM.uid_to_id("classes", uid_class) if uid_class > 0 else 1
	var class_index = classic_class_id - 1
	%ClassOptions.select(class_index if class_index < %ClassOptions.get_item_count() and class_index > -1 else 0)
	
	var keep_level = data.get("keep_level", false)
	%KeepLevel.set_pressed(keep_level)



## Compiles the UI state back extracting UIDs
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	
	var idx_actor = %ActorOptions.get_selected_id()
	commands[-1].parameters.actor_id = %ActorOptions.get_item_metadata(idx_actor)
	
	var idx_class = %ClassOptions.get_selected_id()
	commands[-1].parameters.class_id = %ClassOptions.get_item_metadata(idx_class)
	
	commands[-1].parameters.keep_level = %KeepLevel.is_pressed()
	
	return commands
#endregion
