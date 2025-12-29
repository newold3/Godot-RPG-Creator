@tool
extends CommandBaseDialog


func _ready() -> void:
	super()
	parameter_code = 98
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
	var data = parameters[0].parameters
	var actor_id = data.get("actor_id", 0) - 1
	%ActorOptions.select(actor_id if actor_id < %ActorOptions.get_item_count() and actor_id > -1 else 0)
	var max_letters = data.get("max_letters", 0)
	%MaxLetters.value = max_letters


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.actor_id = %ActorOptions.get_selected_id() + 1
	commands[-1].parameters.max_letters = %MaxLetters.value
	return commands


func _on_actor_options_item_selected(index: int) -> void:
	%MaxLetters.get_line_edit().grab_focus()
