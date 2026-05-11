@tool
extends CommandBaseDialog

#region Lifecycle & Setup
## Initializes the equipment dialog
func _ready() -> void:
	super()
	parameter_code = 46
	fill_all()



## Populates Actor and Equipment dropdowns tracking UIDs secretly
func fill_all() -> void:
	var node = %ActorOptions
	node.clear()
	for i: int in range(1, RPGSYSTEM.database.actors.size(), 1):
		var actor: RPGActor = RPGSYSTEM.database.actors[i]
		var item_name = "%s: %s" % [i, actor.name]
		node.add_item(item_name)
		node.set_item_metadata(node.get_item_count() - 1, RPGSYSTEM.id_to_uid("actors", i))
	node.select(0)

	node = %EquipmentTypeOptions
	node.clear()
	for i: int in range(0, RPGSYSTEM.database.types.equipment_types.size(), 1):
		var equipment_type: String = RPGSYSTEM.database.types.equipment_types[i]
		var equipment_name = "%s: %s" % [i + 1, equipment_type]
		node.add_item(equipment_name)
	node.select(0)

	fill_items()



## Populates target Item dropdown resolving UIDs based on Type selected
func fill_items() -> void:
	var selected_id = %EquipmentTypeOptions.get_selected_id()

	var node = %ItemOptions
	node.clear()

	node.add_item("none")
	node.set_item_metadata(0, 0)

	if selected_id == 0:
		for i: int in range(1, RPGSYSTEM.database.weapons.size(), 1):
			var weapon: RPGWeapon = RPGSYSTEM.database.weapons[i]
			var weapon_name = weapon.name
			node.add_item(weapon_name)
			node.set_item_metadata(node.get_item_count() - 1, RPGSYSTEM.id_to_uid("weapons", i))
	else:
		for i: int in range(1, RPGSYSTEM.database.armors.size(), 1):
			var armor: RPGArmor = RPGSYSTEM.database.armors[i]
			if armor.equipment_type == 0 or armor.equipment_type == selected_id:
				var armor_name = armor.name
				node.add_item(armor_name)
				node.set_item_metadata(node.get_item_count() - 1, RPGSYSTEM.id_to_uid("armors", i))

	node.select(0)



## Parses the raw command safely matching UIDs to list indexes
func set_data() -> void:
	var uid_actor = parameters[0].parameters.get("actor_id", 0)
	var classic_actor_id = RPGSYSTEM.uid_to_id("actors", uid_actor) if uid_actor > 0 else 1
	var actor_index = classic_actor_id - 1
	
	%ActorOptions.select(actor_index if actor_index < %ActorOptions.get_item_count() and actor_index > -1 else 0)
	
	var equipment_type_id = parameters[0].parameters.get("equipment_type_id", 0)
	%EquipmentTypeOptions.select(equipment_type_id if equipment_type_id < %EquipmentTypeOptions.get_item_count() else 0)
	
	fill_items()
	
	var item_uid = parameters[0].parameters.get("item_id", 0)
	for i in %ItemOptions.get_item_count():
		if %ItemOptions.get_item_metadata(i) == item_uid:
			%ItemOptions.select(i)
			break



## Restructures current memory variables back into an Event Command
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	
	var actor_idx = %ActorOptions.get_selected_id()
	commands[-1].parameters.actor_id = %ActorOptions.get_item_metadata(actor_idx)
	
	commands[-1].parameters.equipment_type_id = %EquipmentTypeOptions.get_selected_id()
	
	var item_idx = %ItemOptions.get_selected_id()
	commands[-1].parameters.item_id = %ItemOptions.get_item_metadata(item_idx)
	
	return commands
#endregion



#region Event Hooks
## Recalculates available equipment list dynamically
func _on_equipment_type_options_item_selected(index: int) -> void:
	fill_items()
	%ItemOptions.select(0)
#endregion
