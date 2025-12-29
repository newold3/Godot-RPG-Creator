@tool
extends CommandBaseDialog

func _ready() -> void:
	super()
	parameter_code = 46
	fill_all()

func fill_all() -> void:
	var node = %ActorOptions
	node.clear()
	for i: int in range(1, RPGSYSTEM.database.actors.size(), 1):
		var actor: RPGActor = RPGSYSTEM.database.actors[i]
		var item_name = "%s: %s" % [i, actor.name]
		node.add_item(item_name)
	node.select(0)

	node = %EquipmentTypeOptions
	node.clear()
	for i: int in range(0, RPGSYSTEM.database.types.equipment_types.size(), 1):
		var equipment_type: String = RPGSYSTEM.database.types.equipment_types[i]
		var equipment_name = "%s: %s" % [i + 1, equipment_type]
		node.add_item(equipment_name)
	node.select(0)

	fill_items()

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
			node.set_item_metadata(-1, i)
	else:
		for i: int in range(1, RPGSYSTEM.database.armors.size(), 1):
			var armor: RPGArmor = RPGSYSTEM.database.armors[i]
			if armor.equipment_type == 0 or armor.equipment_type == selected_id:
				var armor_name = armor.name
				node.add_item(armor_name)
				node.set_item_metadata(-1, i)

	node.select(0)

func set_data() -> void:
	var actor_id = parameters[0].parameters.get("actor_id", 0) - 1
	%ActorOptions.select(actor_id if actor_id < %ActorOptions.get_item_count() and actor_id > -1 else 0)
	var equipment_type_id = parameters[0].parameters.get("equipment_type_id", 0)
	%EquipmentTypeOptions.select(equipment_type_id if equipment_type_id < %EquipmentTypeOptions.get_item_count() else 0)
	fill_items()
	var item_id = parameters[0].parameters.get("item_id", 0)
	for i in %ItemOptions.get_item_count():
		if %ItemOptions.get_item_metadata(i) == item_id:
			%ItemOptions.select(i)
			break

func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.actor_id = %ActorOptions.get_selected_id() + 1
	commands[-1].parameters.equipment_type_id = %EquipmentTypeOptions.get_selected_id()
	commands[-1].parameters.item_id = %ItemOptions.get_item_metadata(%ItemOptions.get_selected_id())
	return commands

func _on_equipment_type_options_item_selected(index: int) -> void:
	fill_items()
	%ItemOptions.select(0)
