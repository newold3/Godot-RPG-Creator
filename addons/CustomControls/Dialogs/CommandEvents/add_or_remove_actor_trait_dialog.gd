@tool
extends CommandBaseDialog

var current_trait: RPGTrait


func _ready() -> void:
	super()
	parameter_code = 62
	fill_actor_list()


func set_data() -> void:
	var data = parameters[0].parameters
	var actor_selected = data.get("actor_id", 0)
	
	if actor_selected >= 0 and %ActorID.get_item_count() > actor_selected:
		%ActorID.select(actor_selected)
	else:
		%ActorID.select(0)
	
	%Type.select(data.get("type", 0))
	current_trait = data.get("trait", null)
	
	if !current_trait:
		var new_trait = RPGTrait.new()
		new_trait.code = 1
		new_trait.value = 100
		current_trait = new_trait
	
	_set_trait_name()


func _set_trait_name() -> void:
	var trait_str = str(current_trait)
	var trait_name = [
		"Element Rate (damage recevied)", "Debuff Rate", "State Rate", "State Resist",
		"Parameter", "Ex-Parameter", "Sp-Parameter",
		"Attack Element", "Attack State", "Attack Speed", "Attack Times +", "Attack Skill",
		"Add Skill Type", "Seal Skill Type", "Add Skill", "Seal Skill",
		"Equip Weapon", "Equip Armor", "Lock Equip", "Seal Equip", "Slot Type",
		"Action Times +", "Special Flag", "Collapse Effect", "Party Ability", "Skill Special Flag",
		"Element Rate (damage done)", "Add Permanent State"
	][current_trait.code - 1]
	%Trait.text = trait_name + trait_str.get_slice(",", 1) + trait_str.get_slice(",", 2).replace(">", "")


func fill_actor_list() -> void:
	var items = RPGSYSTEM.database.actors
	var list = %ActorID
	list.clear()
	
	list.add_item("Entire Party")
	for i in range(1, items.size(), 1):
		var actor = items[i]
		var item_name = "%s: %s" % [
			str(i).pad_zeros(str(items.size()).length()),
			actor.name
		]
		list.add_item(item_name)


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	
	commands[-1].parameters.actor_id = %ActorID.get_selected_id()
	commands[-1].parameters.type = %Type.get_selected_id()
	commands[-1].parameters.trait = current_trait
	
	return commands


func _on_trait_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_trait_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	dialog.fill_all()
	dialog.target_callable = _on_trait_selected
	dialog.set_data(current_trait, -1)


func _on_trait_selected(_trait: RPGTrait, _no_use) -> void:
	current_trait = _trait
	_set_trait_name()
