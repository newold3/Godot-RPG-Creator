extends Node
class_name GameDataManager

## Emitted when the currently focused actor changes across menus.
signal actor_focus_changed(actor: Variant)

## Emitted when a menu tab or window changes view.
signal menu_view_changed(menu_id: String, state_data: Dictionary)

enum DataType { ITEM, WEAPON, ARMOR, COSTUME, SKILL }

var current_focused_actor: Variant
var active_menu_stack: Array[String] = []
var menu_context_data: Dictionary = {}



## Initializes the data system on ready.
func _ready() -> void:
	_initialize_data_system()



## Clears the navigation stack and context.
func _initialize_data_system() -> void:
	active_menu_stack.clear()
	menu_context_data.clear()



## Sets the current active actor for equipment and skill operations.
func set_focused_actor(actor: Variant) -> void:
	if current_focused_actor == actor:
		return
		
	current_focused_actor = actor
	actor_focus_changed.emit(actor)



## Registers a new menu view into the navigation stack.
func push_menu(menu_id: String, context: Dictionary = {}) -> void:
	active_menu_stack.append(menu_id)
	menu_context_data[menu_id] = context
	
	menu_view_changed.emit(menu_id, context)



## Removes the top menu view from the stack and notifies the change.
func pop_menu() -> String:
	if active_menu_stack.is_empty():
		return ""
		
	var closed_menu = active_menu_stack.pop_back()
	menu_context_data.erase(closed_menu)
	
	if not active_menu_stack.is_empty():
		var new_top = active_menu_stack.back()
		menu_view_changed.emit(new_top, menu_context_data.get(new_top, {}))
	else:
		menu_view_changed.emit("none", {})
		
	return closed_menu



## Retrieves the data corresponding to the currently active menu.
func get_current_context() -> Dictionary:
	if active_menu_stack.is_empty():
		return {}
		
	var current_top = active_menu_stack.back()
	
	return menu_context_data.get(current_top, {})



## Main fetcher that redirects the data request using a flexible Variant filter.
func get_payload(type: DataType, filter_arg: Variant = null) -> Array[Dictionary]:
	match type:
		DataType.ITEM:
			return _build_items_payload(filter_arg)
		DataType.WEAPON:
			return _build_weapons_payload(filter_arg)
		DataType.ARMOR:
			return _build_armors_payload(filter_arg)
		DataType.COSTUME:
			return _build_costumes_payload(filter_arg)
		DataType.SKILL:
			return _build_skills_payload(filter_arg)
			
	return []



## Formats regular items into a standard readable payload list.
func _build_items_payload(filter_arg: Variant) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var raw_items = GameManager.inventory_manager.get_items()
	
	for item in raw_items:
		if filter_arg != null and typeof(filter_arg) == TYPE_STRING and item.get("category", "") != filter_arg:
			continue
		elif filter_arg != null and typeof(filter_arg) == TYPE_INT and item.get("item_type", -1) != filter_arg:
			continue
			
		list.append({
			"uid": item.get("uid", ""),
			"name": item.get("name", "Unknown Item"),
			"icon": item.get("icon", null),
			"quantity": item.get("quantity", 1),
			"description": item.get("description", ""),
			"is_disabled": item.get("sealed", false),
			"raw_reference": item
		})
		
	return list



## Extracts weapons from the inventory and formats them including equipped status.
func _build_weapons_payload(filter_arg: Variant) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var raw_weapons = GameManager.inventory_manager.get_weapons()
	
	for weapon in raw_weapons:
		if filter_arg != null and typeof(filter_arg) == TYPE_STRING and weapon.get("category", "") != filter_arg:
			continue
		elif filter_arg != null and typeof(filter_arg) == TYPE_INT and weapon.get("equipment_type", -1) != filter_arg:
			continue
			
		var uid = weapon.get("uid", "")
		var equip_count = _get_equipped_count(uid, DataType.WEAPON)
		var can_equip = true
		
		if current_focused_actor and current_focused_actor.has_method("can_equip_weapon"):
			can_equip = current_focused_actor.can_equip_weapon(weapon)
			
		list.append({
			"uid": uid,
			"name": weapon.get("name", "Unknown Weapon"),
			"icon": weapon.get("icon", null),
			"quantity": weapon.get("quantity", 1),
			"description": weapon.get("description", ""),
			"is_disabled": not can_equip,
			"is_equipped": equip_count > 0,
			"equipped_count": equip_count,
			"raw_reference": weapon
		})
		
	return list



## Extracts armors from the inventory and formats them including equipped status.
func _build_armors_payload(filter_arg: Variant) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var raw_armors = GameManager.inventory_manager.get_armors()
	
	for armor in raw_armors:
		if filter_arg != null and typeof(filter_arg) == TYPE_STRING and armor.get("category", "") != filter_arg:
			continue
		elif filter_arg != null and typeof(filter_arg) == TYPE_INT and armor.get("equipment_type", -1) != filter_arg:
			continue
			
		var uid = armor.get("uid", "")
		var equip_count = _get_equipped_count(uid, DataType.ARMOR)
		var can_equip = true
		
		if current_focused_actor and current_focused_actor.has_method("can_equip_armor"):
			can_equip = current_focused_actor.can_equip_armor(armor)
			
		list.append({
			"uid": uid,
			"name": armor.get("name", "Unknown Armor"),
			"icon": armor.get("icon", null),
			"quantity": armor.get("quantity", 1),
			"description": armor.get("description", ""),
			"is_disabled": not can_equip,
			"is_equipped": equip_count > 0,
			"equipped_count": equip_count,
			"raw_reference": armor
		})
		
	return list



## Extracts costumes and sets from the inventory and formats them including equipped status.
func _build_costumes_payload(filter_arg: Variant) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var raw_costumes = []
	
	if GameManager.inventory_manager.has_method("get_costumes"):
		raw_costumes = GameManager.inventory_manager.get_costumes()
	elif GameManager.inventory_manager.has_method("get_sets"):
		raw_costumes = GameManager.inventory_manager.get_sets()
		
	for costume in raw_costumes:
		if filter_arg != null and typeof(filter_arg) == TYPE_STRING and costume.get("category", "") != filter_arg:
			continue
		elif filter_arg != null and typeof(filter_arg) == TYPE_INT and costume.get("equipment_type", -1) != filter_arg:
			continue
			
		var uid = costume.get("uid", "")
		var equip_count = _get_equipped_count(uid, DataType.COSTUME)
		var can_equip = true
		
		if current_focused_actor and current_focused_actor.has_method("can_equip_costume"):
			can_equip = current_focused_actor.can_equip_costume(costume)
			
		list.append({
			"uid": uid,
			"name": costume.get("name", "Unknown Set"),
			"icon": costume.get("icon", null),
			"quantity": costume.get("quantity", 1),
			"description": costume.get("description", ""),
			"is_disabled": not can_equip,
			"is_equipped": equip_count > 0,
			"equipped_count": equip_count,
			"raw_reference": costume
		})
		
	return list



## Gathers skills learned by the currently focused actor.
func _build_skills_payload(filter_arg: Variant) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	
	if not current_focused_actor or not current_focused_actor.has_method("get_learned_skills"):
		return list
		
	var actor_skills = current_focused_actor.get_learned_skills()
	
	for skill in actor_skills:
		if filter_arg != null and typeof(filter_arg) == TYPE_STRING and skill.get("category", "") != filter_arg:
			continue
		elif filter_arg != null and typeof(filter_arg) == TYPE_INT and skill.get("skill_type", -1) != filter_arg:
			continue
			
		var usable = true
		
		if current_focused_actor.has_method("can_use_skill"):
			usable = current_focused_actor.can_use_skill(skill)
			
		list.append({
			"uid": skill.get("uid", ""),
			"name": skill.get("name", "Unknown Skill"),
			"icon": skill.get("icon", null),
			"quantity": skill.get("mp_cost", 0),
			"description": skill.get("description", ""),
			"is_disabled": not usable,
			"raw_reference": skill
		})
		
	return list



## Calculates how many times a specific equipment piece is currently worn by all party members.
func _get_equipped_count(uid: String, type: DataType) -> int:
	var count: int = 0
	var party_members = []
	
	if GameManager.has_node("PartyManager"):
		party_members = GameManager.party_manager.get_party_members()
	elif GameManager.has_method("get_party_members"):
		party_members = GameManager.get_party_members()
		
	for actor in party_members:
		if not actor:
			continue
			
		var active_gear = []
		
		if type == DataType.WEAPON and actor.has_method("get_equipped_weapons"):
			active_gear = actor.get_equipped_weapons()
		elif type == DataType.ARMOR and actor.has_method("get_equipped_armors"):
			active_gear = actor.get_equipped_armors()
		elif type == DataType.COSTUME and actor.has_method("get_equipped_costumes"):
			active_gear = actor.get_equipped_costumes()
			
		for gear in active_gear:
			if gear and typeof(gear) == TYPE_DICTIONARY and gear.get("uid", "") == uid:
				count += 1
				
	return count
