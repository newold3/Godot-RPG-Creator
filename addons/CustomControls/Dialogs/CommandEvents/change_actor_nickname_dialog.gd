@tool
extends CommandBaseDialog

#region Lifecycle & Setup
## Initializes the Change Nickname dialog
func _ready() -> void:
	super()
	parameter_code = 49
	fill_actors()



## Populates Actor list injecting UID metadata
func fill_actors() -> void:
	var node = %ActorOptions
	node.clear()
	for i: int in range(1, RPGSYSTEM.database.actors.size(), 1):
		var actor: RPGActor = RPGSYSTEM.database.actors[i]
		var item_name = "%s: %s" % [i, actor.name]
		node.add_item(item_name)
		node.set_item_metadata(node.get_item_count() - 1, RPGSYSTEM.id_to_uid("actors", i))
	node.select(0)



## Parses the raw command securely
func set_data() -> void:
	var data = parameters[0].parameters
	
	var uid_actor = data.get("actor_id", 0)
	var classic_actor_id = RPGSYSTEM.uid_to_id("actors", uid_actor) if uid_actor > 0 else 1
	var actor_index = classic_actor_id - 1
	
	%ActorOptions.select(actor_index if actor_index < %ActorOptions.get_item_count() and actor_index > -1 else 0)
	
	var actor_name = data.get("nickname", "")
	%ActorNickname.text = actor_name
	%ActorNickname.grab_focus()



## Compiles the UI state back extracting UIDs
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	var idx = %ActorOptions.get_selected_id()
	commands[-1].parameters.actor_id = %ActorOptions.get_item_metadata(idx)
	commands[-1].parameters.nickname = %ActorNickname.text
	return commands
#endregion



#region UI Interaction
## Redirects focus to text field automatically
func _on_actor_options_item_selected(index: int) -> void:
	%ActorNickname.grab_focus()
#endregion
