class_name GameActor
extends Resource

## Represents a playable or non-playable character instance within the game.
##
## This class holds all mutable game-time data for an actor, including stats, class,
## gear, traits, skills, and states. It handles the application of traits and states from
## the database, equipment, and class definitions. It also manages equipment restrictions,
## skill learning, parameter calculations, and level/experience progression logic.
##
## Used during runtime to represent the evolving state of an actor across battles, exploration,
## and character progression systems.

## Actor's unique ID in the database (-1 = invalid or unassigned).
@export var id: int = -1

@export_category("Stats")
## ID of the actor’s class from the database (-1 = invalid).
@export var current_class: int = -1
## Array of currently equipped gear (index 0 = weapon, others = armor slots).
## Weapon = [GameWeapon], Armor = [GameArmor]
@export var current_gear: Array = []
## Current name of the actor (can be changed during gameplay).
@export var current_name: String = ""
## Actor’s nickname or title (used in menus or dialog).
@export var current_nickname: String = ""
## Actor’s biography or profile description.
@export var current_profile: String = ""
## Actor’s total experience points (used for leveling).
@export var current_experience: int = 0
## Actor’s current level.
@export var current_level: int = 0
## Actor’s current facing direction [enum CharacterBase.DIRECTIONS] (used for animations/movement).
@export var current_direction: LPCCharacter.DIRECTIONS = LPCCharacter.DIRECTIONS.DOWN
## Full list of traits currently applied to the actor (from actor, class, gear, and states).
@export var trait_list: Array[RPGTrait] = []
## Stores all parameters (HP, MP, stats, modifiers).
@export var params: GameParams = GameParams.new()
## Stores all user parameters.
@export var user_params: PackedInt32Array = []
## List of active GameState instances currently affecting the actor.
@export var current_states: Array[GameState] = []


var is_valid: bool = true


enum TraitCode {
	PARAM_BASE = 5,
	PARAM_EXTRA = 6,
	PARAM_SPECIAL = 7,
	ADD_STATE = 28,
	EQUIP_WEAPON = 17,
	EQUIP_ARMOR = 18,
	LOCK_EQUIP = 19,
	SEAL_EQUIP = 20,
	ADD_SKILL_TYPE = 13,
	SEAL_SKILL_TYPE = 14,
	ADD_SKILL = 15,
	SEAL_SKILL = 16,
	ELEMENT_ATTACK = 1,
	ELEMENT_DEFENSE = 27,
	USER_PARAMETER = 101
}


## Default values for extra parameters [enum RPGActor.ExtraParamType]
const DEFAULT_EXTRA_PARAMS = {
	RPGActor.ExtraParamType.HIT: 1.0,    ## Hit Rate: Default value for  this param = 100%
	RPGActor.ExtraParamType.EVA: 0.05,   ## Evasion Rate: Default value for  this param = 5%
	RPGActor.ExtraParamType.CRI: 0.04,   ## Critical Rate: Default value for  this param = 4%
	RPGActor.ExtraParamType.CEV: 0.01,   ## Critical Evasion: Default value for this param = 1%
	RPGActor.ExtraParamType.MEV: 0.0,    ## Magic Evasion: Default value for  this param = 0%
	RPGActor.ExtraParamType.MRF: 0.0,    ## Magic Reflection: Default value for  this param = 0%
	RPGActor.ExtraParamType.CNT: 0.0,    ## Counter Attack : Default value for  this param = 0%
	RPGActor.ExtraParamType.HRG: 0.0,    ## HP Regeneration : Default value for  this param = 0%
	RPGActor.ExtraParamType.MRG: 0.0,    ## MP Regeneration : Default value for  this param = 0%
	RPGActor.ExtraParamType.TRG: 0.0     ## TP Regeneration : Default value for  this param = 0%
}

## Default values for special parameters [enum RPGActor.SpecialParamType]
const DEFAULT_SPECIAL_PARAMS = {
	RPGActor.SpecialParamType.TGR: 1.0,  ## Target Rate : Default value for this param = 100%
	RPGActor.SpecialParamType.GRD: 1.0,  ## Guard Rate : Default value for this param = 100%
	RPGActor.SpecialParamType.REC: 1.0,  ## Recovery Effect : Default value for this param = 100%
	RPGActor.SpecialParamType.HM: 1.0,   ## Healing Master : Default value for this param = 100%
	RPGActor.SpecialParamType.MCR: 1.0,  ## MP Cost Rate : Default value for this param = 100%
	RPGActor.SpecialParamType.TCR: 1.0,  ## TP Charge Rate : Default value for this param = 100%
	RPGActor.SpecialParamType.PDR: 1.0,  ## Physical Damage Rate : Default value for this param = 100%
	RPGActor.SpecialParamType.MDR: 1.0,  ## Magic Damage Rate : Default value for this param = 100%
	RPGActor.SpecialParamType.FDR: 1.0,  ## Floor Damage Rate : Default value for this param = 100%
	RPGActor.SpecialParamType.EXR: 1.0,  ## Experience Rate : Default value for this param = 100%
	RPGActor.SpecialParamType.GDR: 1.0   ## Gold Rate : Default value for this param = 100%
}

## Constant used to identify traits that enable ticking behavior on states.
const TICKS_ENABLED = {
	CODE = 6,
	DATA_IDS = [7, 8, 9]
}

## Maximum multiplier achieved when stacking traits.
var MAX_MULTIPLIER = 10000.0     # 1.000,000%
## Maximum value that can be reached after calculating traits applied to a value.
var MAX_RESULT     = 1_000_000_000.0

## Cache used in some costly operations that involve successive calls to retrieve the list of traits.
var _temp_trait_cache: Array = []

var is_comparation_enabled: bool = false

## Emitted whenever a change in actor parameters occurs (e.g., due to states or gear).
signal parameter_changed()


## Initializes the actor using its ID and loads its data from the database.
func initialize() -> void:
	# Initialize the character
	_init()


## Internal initializer. Loads actor base data, stats, class, and gear.
func _init(_id: int = 1) -> void:
	if GameManager.cancel_actors_initialize:
		return
	
	if RPGSYSTEM.database.actors.size() > _id:
		id = _id
		var actor_data: RPGActor = RPGSYSTEM.database.actors[_id]

		current_name = actor_data.name
		current_nickname = actor_data.nickname
		current_profile = actor_data.profile
		current_class = actor_data.class_id
		current_level = max(1, min(actor_data.initial_level, actor_data.max_level))
		current_experience = max(get_parameter("experience"), current_experience)
		
		if user_params.size() != RPGSYSTEM.database.types.user_parameters.size():
			user_params.resize(RPGSYSTEM.database.types.user_parameters.size())
		
		for i in RPGSYSTEM.database.types.user_parameters.size():
			user_params[i] = RPGSYSTEM.database.types.user_parameters[i].default_value
			
		_change_class(actor_data.class_id, false, true)
		_init_equipment(actor_data)
		_validate_equipment()
		recover_all()


## Refreshes the actor data against the current database.
## Should be called after loading a save file to ensure the actor's properties
## (traits, parameter limits, class definitions) match the current game version.
func refresh_actor_data() -> void:
	# 1. Validate Basic Database Existence
	if id <= 0 or id >= RPGSYSTEM.database.actors.size():
		printerr("GameActor: ID %d not found in database during refresh." % id)
		is_valid = false
		return
	
	var actor_data: RPGActor = RPGSYSTEM.database.actors[id]
	var class_data: RPGClass = null
	
	if current_class > 0 and current_class < RPGSYSTEM.database.classes.size():
		class_data = RPGSYSTEM.database.classes[current_class]
	
	# 2. Resize User Parameters if the database has added new ones
	var db_params_size = RPGSYSTEM.database.types.user_parameters.size()
	if user_params.size() != db_params_size:
		var old_size = user_params.size()
		user_params.resize(db_params_size)
		# Initialize new parameters with default values
		for i in range(old_size, db_params_size):
			user_params[i] = RPGSYSTEM.database.types.user_parameters[i].default_value

	# 3. Rebuild Traits (Actor + Class)
	# This ensures if you changed a Class or Actor trait in the editor, the save file updates.
	trait_list.clear()
	
	# Re-add Actor Traits
	for tr: RPGTrait in actor_data.traits:
		trait_list.append(tr.clone(true))
		
	# Re-add Class Traits
	if class_data:
		for tr: RPGTrait in class_data.traits:
			trait_list.append(tr.clone(true))

	# 4. Refresh Permanent States
	# We want to keep temporary battle states (like poison), but refresh permanent ones
	# derived from Class/Gear in case the DB changed which states are passive.
	
	# Step A: Remove all currently active permanent states from the list
	var temp_states: Array[GameState] = []
	for state in current_states:
		if not state.is_permanent():
			temp_states.append(state)
	current_states = temp_states
	
	# Step B: Re-apply permanent states from the fresh Actor/Class data
	if class_data:
		var static_traits = actor_data.traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_STATE)
		static_traits += class_data.traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_STATE)
		for state_trait: RPGTrait in static_traits:
			add_trait_state(state_trait) # This logic automatically handles the permanent flag inside add_state/trait

	# Step C: Re-apply permanent states from currently equipped Gear
	for item in current_gear:
		if item and item.id > 0:
			var real_item = item.get_real_data()
			if real_item:
				_add_permanent_states_from_gear(real_item)

	# 5. Validate Equipment and Params
	# Check if equipped items are still valid for this class/level in the new DB version
	_validate_equipment()
	
	# Recalculate derived parameters
	params.hp = min(params.hp, get_parameter("hp"))
	params.mp = min(params.mp, get_parameter("mp"))
	
	parameter_changed.emit()

# ------------------------------------------------------------------------------

## Fully restores the actor’s HP and MP based on current parameters.
## Removes all non-permanent states.
func recover_all() -> void:
	params.hp = get_parameter("hp")
	params.mp = get_parameter("mp")
	# Clear all states that are not permanent
	current_states = current_states.filter(
		func(t: GameState):
			return t.is_permanent()
	)

## Changes the actor’s class and reinitializes traits, level, and skills.
func _change_class(class_id: int, keep_level: bool = false, clear_traits: bool = true) -> void:
	if id > 0 and RPGSYSTEM.database.actors.size() > id:
		var actor_data = RPGSYSTEM.database.actors[id]
		
		if clear_traits:
			trait_list.clear()
			for tr: RPGTrait in actor_data.traits:
				trait_list.append(tr.clone(true))
			
		if RPGSYSTEM.database.classes.size() > class_id:
			current_class = class_id
			var class_data: RPGClass = RPGSYSTEM.database.classes[current_class]
			
			if not keep_level:
				current_level = max(1, min(actor_data.initial_level, class_data.max_level))
				current_experience = max(class_data.get_parameter("experience", current_level), current_experience)
			else:
				current_level = max(1, min(current_level, class_data.max_level))
				current_experience = class_data.get_parameter("experience", current_level)
			
			for tr: RPGTrait in class_data.traits:
				trait_list.append(tr.clone(true))

			params = GameParams.new()
			
			# set Base parameters
			for param in ["hp", "mp"]:
				params.set(param, get_parameter(param))
			
			# Set initial states
			_init_states(actor_data, class_data)
			
			if clear_traits:
				for item in current_gear:
					_add_permanent_states_from_gear(item)

## Sets the actor’s class by calling [method _change_class].
func set_class(class_id: int, keep_level: bool) -> void:
	_change_class(class_id, keep_level)


## Obtains the actual [class RPGActor] or null if the character does not exist in the database.
func get_real_actor() -> RPGActor:
	var actor_data = RPGSYSTEM.database.actors
	if id > 0 and actor_data.size() > id:
		return actor_data[id]
		
	return null


## Obtains the actual [class RPGClass] or null if the class does not exist in the database.
func get_real_class() -> RPGClass:
	var class_data = RPGSYSTEM.database.classes
	if current_class > 0 and class_data.size() > current_class:
		return class_data[current_class]
		
	return null


func get_real_skill(skill_id: int) -> RPGSkill:
	var skills_data = RPGSYSTEM.database.skills
	if skill_id > 0 and skills_data.size() > skill_id:
		return skills_data[skill_id]
		
	return null


## Initializes the actor’s equipment based on their default loadout in the database.
func _init_equipment(actor_data: RPGActor) -> void:
	# Equip weapon
	if not GameManager.game_state: return

	current_gear.clear()
	current_gear.resize(RPGSYSTEM.database.types.equipment_types.size())
	
	var weapon_id = actor_data.equipment[0]
	var weapon_level = actor_data.equipment_level[0]
	if weapon_id > 0 and RPGSYSTEM.database.weapons.size() > weapon_id:
		var real_weapon: RPGWeapon = RPGSYSTEM.database.weapons[weapon_id]
		_add_permanent_states_from_gear(real_weapon)
		var new_weapon: GameWeapon = GameWeapon.new(weapon_id, 1, 1)
		new_weapon.current_level = weapon_level
		new_weapon.equipped = true
		new_weapon.total_equipped += 1
		current_gear[0] = new_weapon
		if not GameManager.game_state.weapons.has(weapon_id):
			GameManager.game_state.weapons[weapon_id] = []
		GameManager.game_state.weapons[weapon_id].append(new_weapon)
	
	# Equip armors
	for i in range(1, actor_data.equipment.size()):
		var armor_id = actor_data.equipment[i]
		var armor_level = actor_data.equipment_level[i]
		if armor_id > 0 and RPGSYSTEM.database.armors.size() > armor_id:
			var real_armor: RPGArmor = RPGSYSTEM.database.armors[armor_id]
			_add_permanent_states_from_gear(real_armor)
			var new_armor: GameArmor = GameArmor.new(armor_id, 1, 2)
			new_armor.current_level = armor_level
			new_armor.equipped = true
			new_armor.total_equipped += 1
			current_gear[i] = new_armor
			if not GameManager.game_state.armors.has(armor_id):
				GameManager.game_state.armors[armor_id] = []
			GameManager.game_state.armors[armor_id].append(new_armor)


## Attempts to change an equipment slot to a new item (used to preview equipment, avoid using directly).
func _set_equip(equipment_type_id: int, item_id: int, item_level) -> void:
	# Remove old equipment bonuses
	var current_equipment = current_gear[equipment_type_id]
	if current_equipment:
		var is_weapon = equipment_type_id == 0
		var database_items = RPGSYSTEM.database.weapons if is_weapon else RPGSYSTEM.database.armors
		var real_item = database_items[current_equipment.id]
		_remove_permanent_states_from_gear(real_item)
	
	# Set new equipment
	if item_id != -1:
		var is_weapon = equipment_type_id == 0
		var new_equipment = _create_new_equipment(equipment_type_id, item_id, item_level, is_weapon)
		current_gear[equipment_type_id] = new_equipment
		
		# Add new equipment bonuses
		var database_items = RPGSYSTEM.database.weapons if is_weapon else RPGSYSTEM.database.armors
		var real_item = database_items[item_id]
		_add_permanent_states_from_gear(real_item)
	else:
		current_gear[equipment_type_id] = null


## Attempts to change an equipment slot to a new item.
func change_equipment(equipment_type_id: int, item_id: int, item_level: int, is_new_item: bool = true) -> void:
	if not can_equip(equipment_type_id, item_id):
		print("🚫 ",  self, " cannot equip the ", "Weapon" if equipment_type_id == 0 else "Armor", " with ID ", item_id, ". The item will be discarded")
		return
	
	var is_weapon = equipment_type_id == 0
	var database_items = RPGSYSTEM.database.weapons if is_weapon else RPGSYSTEM.database.armors
	var game_state_items = GameManager.game_state.weapons if is_weapon else GameManager.game_state.armors
	
	if item_id <= 0 or database_items.size() <= item_id:
		return
	
	# Remove old equipment
	remove_current_equipment(equipment_type_id)
	
	# Equip new item
	var new_equipment = _create_new_equipment(equipment_type_id, item_id, item_level, is_weapon)
	current_gear[equipment_type_id] = new_equipment
	
	# Add permanent states from new equipment
	var real_item = database_items[item_id]
	_add_permanent_states_from_gear(real_item)
	
	# Add to inventory if it's a new item
	if is_new_item:
		_add_equipment_to_inventory(item_id, new_equipment, real_item, game_state_items)
	
	_validate_equipment()


## Attempts to change an equipment slot to a item in the inventory.
func equip_equipment_from_inventory(slot_id: int, item: Variant) -> void:
	var equipment_type_id = slot_id
	var item_id = item.id
	
	if not can_equip(equipment_type_id, item_id):
		return
	
	var is_weapon = equipment_type_id == 0
	var database_items = RPGSYSTEM.database.weapons if is_weapon else RPGSYSTEM.database.armors
	var game_state_items = GameManager.game_state.weapons if is_weapon else GameManager.game_state.armors
	
	if item_id <= 0 or database_items.size() <= item_id:
		return
	
	# Remove old equipment
	remove_current_equipment(equipment_type_id)
	
	# Equip new item
	var new_equipment = item
	if not is_comparation_enabled:
		new_equipment.total_equipped += 1
		new_equipment.equipped = true
	current_gear[equipment_type_id] = new_equipment
	
	# Add permanent states from new equipment
	var real_item = database_items[item_id]
	_add_permanent_states_from_gear(real_item)
	
	_validate_equipment()


## Return the equip (GameWeapon or GameArmor) in the slot selected or null if not  exists
func get_equip_in_slot(slot_id: int) -> Variant:
	if current_gear.size() > slot_id:
		return current_gear[slot_id]
	
	return null


## Removes the currently equipped item from the specified equipment slot.
func remove_current_equipment(equipment_type_id: int) -> void:
	var current_equipment = current_gear[equipment_type_id]
	if not current_equipment:
		return
	
	var is_weapon = equipment_type_id == 0
	var database_items = RPGSYSTEM.database.weapons if is_weapon else RPGSYSTEM.database.armors
	var real_item = database_items[current_equipment.id]
	
	_remove_permanent_states_from_gear(real_item)

	if not is_comparation_enabled:
		current_equipment.total_equipped = max(0, current_equipment.total_equipped - 1)
		current_equipment.equipped = current_equipment.total_equipped > 0
	
	current_gear[equipment_type_id] = null


## Creates a new [GameItem] instance from the given item ID.
func _create_new_equipment(equipment_type_id: int, item_id: int, level: int, is_weapon: bool):
	var new_equipment
	if is_weapon:
		new_equipment = GameWeapon.new()
	else:
		new_equipment = GameArmor.new()
	
	new_equipment.type = equipment_type_id
	new_equipment.id = item_id
	new_equipment.quantity = 1
	new_equipment.equipped = true
	new_equipment.total_equipped += 1
	new_equipment.current_level = level
	
	return new_equipment


## Adds a given item back into the inventory.
func _add_equipment_to_inventory(item_id: int, new_equipment, real_item, game_state_items: Dictionary) -> void:
	if not game_state_items.has(item_id):
		game_state_items[item_id] = []
	
	var item_array = game_state_items[item_id]
	
	if real_item.upgrades.max_levels > 1 or item_array.is_empty():
		item_array.append(new_equipment)
	elif real_item.upgrades.max_levels == 1:
		item_array[0].quantity += 1


## Removes any permanent states that were granted by the currently equipped gear.
func _remove_permanent_states_from_gear(gear: Variant) -> void:
	# filter states to remove
	var trait_states = gear.traits.filter(
		func(t: RPGTrait):
			return t.code == TraitCode.ADD_STATE
	)

	# get states to remove
	var states_to_remove = []
	for state: GameState in current_states:
		if state.is_permanent() and trait_states.any(
			func(t: RPGTrait):
				return t.data_id == state.id
		):
			state.usage_count -= 1
			if state.usage_count <= 0:
				# remove state
				states_to_remove.append(state)
	
	# remove states (only the first state found must be removed)
	for state: GameState in states_to_remove:
		for i in range(current_states.size()):
			if current_states[i].id == state.id:
				current_states.remove_at(i)
				break

	parameter_changed.emit()


## Adds any permanent states granted by the currently equipped gear.
func _add_permanent_states_from_gear(gear: Variant) -> void:
	var trait_states = gear.traits.filter(
		func(t: RPGTrait):
			return t.code == TraitCode.ADD_STATE
	)
	for state: RPGTrait in trait_states:
		add_trait_state(state, true)

	parameter_changed.emit()


## Check if there is new equipment in the inventory that can be equipped by this actor.
func _has_new_equipment_available() -> bool:
	# Inicializar cache temporal para este actor
	_temp_trait_cache = _get_trait_list()
	
	var has_new = false
	for slot_id in range(0, 8, 1):
		if _has_new_items_in_slot(slot_id):
			has_new = true
			break
	
	# Limpiar cache temporal
	_temp_trait_cache.clear()
	
	return has_new


## Check if there are items in the inventory that can be equipped in the selected slot.
func _has_new_items_in_slot(slot_id: int) -> bool:
	var data = GameManager.game_state.weapons if slot_id == 0 else GameManager.game_state.armors
	
	for item_arr: Array in data.values():
		var item = item_arr[0]
		
		if item is GameArmor:
			if item.id <= 0 or RPGSYSTEM.database.armors.size() <= item.id:
				continue
			var real_armor = RPGSYSTEM.database.armors[item.id]
			if real_armor.equipment_type != 0 and real_armor.equipment_type != slot_id:
				continue
		elif item.id <= 0 or RPGSYSTEM.database.weapons.size() <= item.id:
			continue
			
		if not can_equip(slot_id, item.id):
			continue
			
		for obj in item_arr:
			if obj.newly_added:
				return true
	return false


## Helper function to check if any trait with given codes affects a slot
func _has_trait_affecting_slot(codes: Array, slot_id: int) -> bool:
	var traits = _get_trait_list()
	return traits.any(func(t): return t.code in codes and t.data_id == slot_id)


## Determines whether an equipment slot is sealed
func is_slot_sealed(slot_id: int) -> bool:
	return _has_trait_affecting_slot([TraitCode.SEAL_EQUIP], slot_id)


## Determines whether an equipment slot is locked
func is_slot_locked(slot_id: int) -> bool:
	return _has_trait_affecting_slot([TraitCode.LOCK_EQUIP], slot_id)


## Determines whether an equipment slot is available
func is_slot_available(slot_id: int) -> bool:
	return not _has_trait_affecting_slot([TraitCode.SEAL_EQUIP, TraitCode.LOCK_EQUIP], slot_id)


## Determines whether the actor can equip the item with the given ID in the specified slot.
func can_equip(equipment_type_id: int, item_id: int) -> bool:
	# Check if gear is locked or sealed
	if not is_slot_available(equipment_type_id):
		return false

	var is_weapon := equipment_type_id == 0
	var database = RPGSYSTEM.database.weapons if is_weapon else RPGSYSTEM.database.armors
	var trait_code = TraitCode.EQUIP_WEAPON if is_weapon else TraitCode.EQUIP_ARMOR

	# No exists this item
	if item_id <= 0 or item_id >= database.size():
		return false

	var item_data = database[item_id]
	
	# Armor validate (valid = equipment_type == 0 or == equipment_type_id)
	if equipment_type_id > 0:
		if item_data.equipment_type != 0 and item_data.equipment_type != equipment_type_id:
			return false
	
	# Level restriction validate
	if item_data.level_restriction > current_level:
		return false

	var type_id = item_data.weapon_type if is_weapon else item_data.armor_type
	var general_type_id = item_data.weapon_type if is_weapon else item_data.equipment_type

	# Items of type "none" can be equipped by anyone
	if type_id == 0:
		return true

	var allowed_traits = trait_list.filter(
		func(t: RPGTrait) -> bool:
			return t.code == trait_code and (t.data_id == general_type_id or t.data_id == 0)
	)

	# validate traits
	if not allowed_traits.is_empty():
		return true

	# Check traits from currently equipped gear
	for gear in current_gear:
		if gear == null:
			continue

		if gear is GameWeapon and is_weapon:
			var gdata = RPGSYSTEM.database.weapons[gear.id]
			for t in gdata.traits:
				if t.code == TraitCode.EQUIP_WEAPON and (t.data_id == gdata.weapon_type or t.data_id == 0):
					return true

		elif gear is GameArmor and not is_weapon:
			var gdata = RPGSYSTEM.database.armors[gear.id]
			for t in gdata.traits:
				if t.code == TraitCode.EQUIP_ARMOR and (t.data_id == gdata.equipment_type or t.data_id == 0):
					return true
	
	# cannot equip
	return false


## Validates all equipped gear, removing any that are now sealed or invalid.
func _validate_equipment() -> void:
	# Validate the equipment
	for i in range(current_gear.size()):
		if is_slot_sealed(i):
			remove_current_equipment(i)
			continue
		if current_gear[i] and current_gear[i].id > 0:
			if not can_equip(i, current_gear[i].id):
				remove_current_equipment(i)


## Initializes the actor's states.
func _init_states(actor_data: RPGActor, class_data: RPGClass) -> void:
	var states = actor_data.traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_STATE)
	states += class_data.traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_STATE)
	var equipment_states: Array = []
	var other_data: Variant
	for gear: GameGearBase in current_gear:
		if gear.id <= 0: continue
		if gear.type == 0: # weapon type
			other_data = RPGSYSTEM.database.weapons
		else: # armor type
			other_data = RPGSYSTEM.database.armors
		if other_data.size() > gear.id:
			equipment_states += other_data[gear.id].traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_STATE)

	current_states.clear()
	
	for state: RPGTrait in states:
		add_trait_state(state)
	
	for state: RPGTrait in equipment_states:
		add_trait_state(state, true)


## Initializes the actor's extra parameters.
func _init_extra_params() -> void:
	for param in RPGActor.ExtraParamType.keys():
		if RPGActor.ExtraParamType[param] % 2 == 0:  # Only process short keys
			params.set(param.to_lower(), DEFAULT_EXTRA_PARAMS[RPGActor.ExtraParamType[param]])


## Initializes the actor's special parameters.
func _init_special_params() -> void:
	for param in RPGActor.SpecialParamType.keys():
		if RPGActor.SpecialParamType[param] % 2 == 0:  # Only process short keys
			params.set(param.to_lower(), DEFAULT_SPECIAL_PARAMS[RPGActor.SpecialParamType[param]])


## Adds a [GameState] to the actor based on a trait definition.
func add_trait_state(state: RPGTrait, usage_count: bool = false) -> void:
	var states_data = RPGSYSTEM.database.states
	if state.data_id > 0 and states_data.size() > state.data_id:
		var real_state = states_data[state.data_id]
		add_state(real_state, true, usage_count)


## Adds a full [GameState] instance to the actor.
func add_state(state: RPGState, is_permanent: bool = false, usage_count: bool = false) -> void:
	var enable_ticks = state.traits.filter(
		func(t: RPGTrait):
			return t.code == TICKS_ENABLED.CODE and TICKS_ENABLED.DATA_IDS.has(t.id)
	)

	var count = 0
	if usage_count:
		var old_states = current_states.filter(
			func(t: GameState):
				return t.id == state.id
		)
		if old_states.size() > 0:
			count = old_states[0].usage_count + 1
		else:
			count = 1

	var state_mode: GameState.STATE_MODE = GameState.STATE_MODE.STATE_CONTEXT_GLOBAL
	if is_permanent:
		state_mode |= GameState.STATE_MODE.STATE_DURATION_PERMANENT
	if enable_ticks:
		state_mode |= GameState.STATE_MODE.STATE_TICKS_ENABLED
	
	var is_new_state = true
	var game_state: GameState
	
	if state.is_cumulative:
		var search_state: Array = current_states.filter(func(t: GameState): return t.id == state.id)
		if search_state:
			var own_state: GameState = search_state[0]
			own_state.cumulative_effect += 1
			own_state.duration += state.max_time
			own_state.usage_count = count
			game_state = own_state
			is_new_state = false
		else:
			game_state = GameState.new(state.id, state.max_time, state.tick_interval, state_mode)
			game_state.usage_count = count
			current_states.append(game_state)
	else:
		var search_state: Array = current_states.filter(func(t: GameState): return t.id == state.id)
		if search_state:
			current_states.erase(search_state[0])
		game_state = GameState.new(state.id, state.max_time, state.tick_interval, state_mode)
		game_state.usage_count = count
		current_states.append(game_state)
	
	if is_new_state:
		game_state.state_ended.connect(_remove_state)
		game_state.state_tick.connect(_on_state_tick)
		

	parameter_changed.emit()


## Out of battle, this function is called when the state has regeneration traits and a tick is triggered.
func _on_state_tick(state: GameState) -> void:
	pass


## Remove stat form the [member current_states] list
func _remove_state(state: GameState) -> void:
	if state in current_states:
		current_states.erase(state)


## Update all statuses added to this character.
func update_states(delta: float) -> void:
	for state: GameState in current_states:
		state.update_lifetime(delta)


## Returns true if a given skill ID is currently sealed by traits, gear, or states.
func is_skill_sealed(skill_id: int) -> bool:
	var trait_code = TraitCode.SEAL_SKILL
	
	# Helper function
	var has_sealed_trait = func(_trait_array: Array) -> bool:
		for t: RPGTrait in _trait_array:
			if t.code == trait_code and t.data_id == skill_id:
				return true
		return false
	
	if has_sealed_trait.call(trait_list):
		return true
	
	# Check gear traits
	for gear in current_gear:
		if not gear: continue
		var real_data = RPGSYSTEM.database.weapons if gear.type == 1 else RPGSYSTEM.database.armors
		if gear.id > 0 and real_data.size() > gear.id:
			if has_sealed_trait.call(real_data[gear.id].traits):
				return true
	
	# Check states traits
	var real_data = RPGSYSTEM.database.states
	for state in current_states:
		if state.id > 0 and real_data.size() > state.id:
			if has_sealed_trait.call(real_data[state.id].traits):
				return true
	
	return false


func get_skills() -> Dictionary:
	var sill_traits = _get_trait_list()
	var skill_add_traits = sill_traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_SKILL)
	var current_skill_types = sill_traits.filter(func(t: RPGTrait): return t.code == TraitCode.ADD_SKILL_TYPE)
	var skill_types_sealed = sill_traits.filter(func(t: RPGTrait): return t.code == TraitCode.SEAL_SKILL_TYPE)
	
	var current_types_added = current_skill_types.map(func(t: RPGTrait): return t.data_id + 1)
	var current_types_sealed = skill_types_sealed.map(func(t: RPGTrait): return t.data_id + 1)
	var all_skill_ids: Array[int] = []
	
	for t: RPGTrait in skill_add_traits:
		if not all_skill_ids.has(t.data_id):
			all_skill_ids.append(t.data_id)
	
	var real_class: RPGClass = get_real_class()
	if real_class:
		for skill_data: RPGLearnableSkill in real_class.learnable_skills:
			if skill_data.level <= current_level and not all_skill_ids.has(skill_data.skill_id):
				all_skill_ids.append(skill_data.skill_id)
	
	
	var skills: Dictionary = {} # Skill ID = {"id": int, "name": String, "sealed": bool, "icon": String,  "description": String}
	for skill_id: int in all_skill_ids:
		var skill = get_real_skill(skill_id)
		if skill:
			if skill.skill_type == 0 or skill.skill_type in current_types_added:
				var is_sealed = (
					(skill.skill_type != 0 and skill.skill_type in current_types_sealed) or
					is_skill_sealed(skill.id)
				)
				skills[skill.id] = {"id": skill.id, "name": skill.name, "sealed": is_sealed, "icon": skill.icon, "description": skill.description}
	return skills

	
	
	
	#for t: RPGTrait in skill_add_traits:
		#if not t.value in skills:
			#var skill = get_real_skill(t.value)
			#if skill and not skill.id in skills:
				#if skill.skill_type == 0 or skill.skill_type == current_types_added:
					#var is_sealed = (
						#(skill.skill_type != 0 and not skill.skill_type in current_types_added) or
						#(skill.skill_type != 0 and skill.skill_type in current_types_sealed) or
						#is_skill_sealed(skill.id)
					#)
					#skills[skill.id] = is_sealed
	#
	#var real_class: RPGClass = get_real_class()
	#if real_class:
		#for skill_data: RPGLearnableSkill in real_class.learnable_skills:
			#if skill_data.level <= current_level:
				#var skill = get_real_skill(skill_data.skill_id)
				#if skill and not skill.id in skills:
					#if skill.skill_type == 0 or skill.skill_type == current_types_added:
						#var is_sealed = (
							#(skill.skill_type != 0 and not skill.skill_type in current_types_added) or
							#(skill.skill_type != 0 and skill.skill_type in current_types_sealed) or
							#is_skill_sealed(skill.id)
						#)
						#skills[skill.id] = is_sealed


func _get_trait_list() ->  Array:
	if _temp_trait_cache:
		return _temp_trait_cache
	
	var traits: Array = []
	
	if id > 0 and RPGSYSTEM.database.actors.size() > id:
		var actor_data = RPGSYSTEM.database.actors[id]
		if actor_data.class_id > 0 and RPGSYSTEM.database.classes.size() > actor_data.class_id:
			var class_data = RPGSYSTEM.database.classes[actor_data.class_id]
			var state_data = RPGSYSTEM.database.states
		
			# state traits
			for state: GameState in current_states:
				if state.id > 0 and state_data.size() > state.id:
					if state.cumulative_effect <= 1:
						traits.append_array(state_data[state.id].traits)
					else:
						var new_traits = []
						for old_trait in state_data[state.id].traits:
							var new_trait = old_trait.clone(true)
							new_trait.value *= state.cumulative_effect
							new_traits.append(new_trait)
						if new_traits:
							traits.append_array(new_traits)
	
			# equipment traits
			for equipment: Variant in current_gear:
				if equipment:
					var equipment_real_data = RPGSYSTEM.database.weapons if equipment is GameWeapon else RPGSYSTEM.database.armors
					if equipment.id > 0 and equipment_real_data.size() > equipment.id:
						traits.append_array(equipment_real_data[equipment.id].traits)
			
			# actor and class traits
			traits.append_array(trait_list)

	return traits


## Calculates a specific parameter value by combining base stats + gear.
func get_user_parameter(param_id: int) -> float:
	var current_value: float = 0
	
	if user_params.size() > param_id and param_id >= 0:
		current_value += user_params[param_id]
		
		# add mods
		var real_param_id = "USER_PARAM_" + str(param_id)
		if params.mods.has(real_param_id):
			var mod_value = params.mods[real_param_id]
			current_value += mod_value

		# Apply gear modifiers
		for gear in current_gear:
			if not gear: continue
			var real_data = gear.get_real_data()
			if real_data:
				current_value += real_data.get_user_parameter(param_id, gear.current_level)
		
		# Apply traits
		var traits = _get_trait_list()
		var trait_code = TraitCode.USER_PARAMETER
		current_value = _add_traits_to_value(
			traits,
			current_value,
			trait_code,
			param_id,
			false
		)
	
	return current_value


## Calculates a specific parameter value by combining base stats, traits, gear, and state effects.
func get_parameter(param_id: String) -> float:
	var value: float = 0.0
	
	var search_param = param_id.strip_edges().to_upper()
	var is_rate_parameter: bool = true
	var traits = _get_trait_list()
	
	if id > 0 and RPGSYSTEM.database.actors.size() > id:
		var actor_data = RPGSYSTEM.database.actors[id]
		if actor_data.class_id > 0 and RPGSYSTEM.database.classes.size() > actor_data.class_id:
			var class_data = RPGSYSTEM.database.classes[actor_data.class_id]
			var state_data = RPGSYSTEM.database.states
			
			# Determine parameter type and get base value
			if search_param in RPGActor.BaseParamType.keys():
				value = float(_get_base_parameter(class_data, RPGActor.BaseParamType[search_param]))
				is_rate_parameter = false
			elif search_param in RPGActor.ExtraParamType.keys():
				value = DEFAULT_EXTRA_PARAMS[RPGActor.ExtraParamType[search_param]] * 100.0
			elif search_param in RPGActor.SpecialParamType.keys():
				value = DEFAULT_SPECIAL_PARAMS[RPGActor.SpecialParamType[search_param]] * 100.0
			
			# add mods
			var real_param_id = _find_real_param(search_param)
			if real_param_id != "" and params.mods.has(real_param_id):
				var mod_value = params.mods[real_param_id]
				value += mod_value

			# Apply traits and modifiers
			value = _add_equipment_bonuses(value, search_param)
			
			var trait_code = _get_trait_code(search_param)
			if trait_code > 0:
				value = _add_traits_to_value(
					traits,
					value,
					trait_code,
					_get_param_type_id(search_param),
					is_rate_parameter
				)
		
	return value


func _get_element_rate(trait_code: int, element_id: Variant) -> float:
	if not (id > 0 and RPGSYSTEM.database.actors.size() > id): return 1
	
	var elements = RPGSYSTEM.database.types.element_types
	var data_id: int = 0
	
	if element_id is int and elements.size() > element_id:
		data_id = element_id
	elif element_id is String:
		var search_element = element_id.to_lower()
		for i in elements.size():
			var t = elements[i]
			if t.to_lower() == search_element:
				data_id = i
				break
	
	var value: float = 100.0
	var traits: Array = _get_trait_list()
	
	value = _add_traits_to_value(
		traits,
		value,
		trait_code,
		data_id,
		true
	)
	
	return value


func get_element_attack_rate(element_id: Variant) -> float:
	return _get_element_rate(TraitCode.ELEMENT_ATTACK, element_id)


func get_element_defense_rate(element_id: Variant) -> float:
	return _get_element_rate(TraitCode.ELEMENT_DEFENSE, element_id)


## Modifies a given parameter by adding or subtracting a value.
func set_parameter(param_id: String, value: float, operation: int) -> void:
	var search_param = param_id.strip_edges().to_upper()
	var real_param_id = _find_real_param(search_param)
	if real_param_id != "":
		var current_value = params.mods.get(real_param_id, 0)
		if operation == 0: # Add
			params.mods[real_param_id] = current_value + value
		else: # Subtract
			params.mods[real_param_id] = current_value - value
		
		if "base" in real_param_id:
			match int(real_param_id):
				0: params.hp = params.hp + (value if operation == 0 else -value)
				1: params.mp = params.mp + (value if operation == 0 else -value)

		parameter_changed.emit()


## Adds a [RPGTrait] to the actor.
func add_trait(tr: RPGTrait) -> void:
	if !tr: return
	trait_list.append(tr)

	parameter_changed.emit()


## Removes a [RPGTrait] from the actor.
func remove_trait(tr: RPGTrait) -> void:
	if !tr: return
	var ids_to_remove = []
	for i in range(trait_list.size() - 1, -1, -1):
		if trait_list[i].code == tr.code and trait_list[i].data_id == tr.data_id:
			ids_to_remove.append(i)

	for i in range(ids_to_remove.size()):
		trait_list.remove_at(ids_to_remove[i])
	
	if ids_to_remove.size() > 0: parameter_changed.emit()


## Finds the real parameter value considering all modifiers.
func _find_real_param(param: String) -> String:
	if param in RPGActor.BaseParamType.keys():
		return "base" + str(RPGActor.BaseParamType[param])
	elif param in RPGActor.ExtraParamType.keys():
		return "extra" + str(RPGActor.ExtraParamType[param])
	elif param in RPGActor.SpecialParamType.keys():
		return "special" + str(RPGActor.SpecialParamType[param])
	elif param == "LEVEL":
		return "level"
	elif param == "EXPERIENCE":
		return "experience"
	elif param == "TP":
		return "tp"
	
	return ""


## Returns the remaining experience points needed to reach the next level.
func get_remaining_exp_to_level() -> String:
	if current_class > 0 and RPGSYSTEM.database.classes.size() > current_class:
		var class_data: RPGClass = RPGSYSTEM.database.classes[current_class]
		var current_level_experience = class_data.get_parameter("experience", current_level)
		var next_level_experience = class_data.get_parameter("experience", current_level + 1)
		if next_level_experience != 0:
			return str(next_level_experience - current_level_experience)
	
	return "0"


## Returns the current experience points of the actor at the current level.
func get_current_level_experience() -> int:
	if current_class > 0 and RPGSYSTEM.database.classes.size() > current_class:
		var class_data: RPGClass = RPGSYSTEM.database.classes[current_class]
		return class_data.get_parameter("experience", current_level)
	
	return 0


## Gets the trait code from a [RPGTrait].
func _get_trait_code(param: String) -> int:
	if param in RPGActor.BaseParamType.keys():
		return TraitCode.PARAM_BASE
	elif param in RPGActor.ExtraParamType.keys():
		return TraitCode.PARAM_EXTRA
	elif param in RPGActor.SpecialParamType.keys():
		return TraitCode.PARAM_SPECIAL
	return 0


## Gets the parameter type ID.
func _get_param_type_id(param: String) -> int:
	if param in RPGActor.BaseParamType.keys():
		return RPGActor.BaseParamType[param]
	elif param in RPGActor.ExtraParamType.keys():
		return RPGActor.ExtraParamType[param]
	elif param in RPGActor.SpecialParamType.keys():
		return RPGActor.SpecialParamType[param]
	return -1


## Returns the base value of the specified parameter.
func _get_base_parameter(class_data: RPGClass, parameter_id: int) -> int:
	var value: int = 0
	if class_data.params[parameter_id].data.size() > current_level and current_level > 0:
		value = class_data.params[parameter_id].data[current_level]
	return value


## Applies RPGTrait modifiers to a parameter value using multiplicative scaling.
##
## All traits are treated as multiplicative modifiers that are applied sequentially.
## Each trait value represents a percentage multiplier (e.g., 150% = 1.5x multiplier).
##
## Behavior depends on parameter type and base value:
##
## 1. For absolute parameters (HP, Attack, Defense, etc.):
##    - Traits multiply the current value directly
##    - If current_value is 0, result is 0 (can't multiply nothing)
##    - Example: base 100, traits 50% and 200% → 100 × 0.5 × 2.0 = 100
##    - Example: base 0, traits 50% and 200% → 0 × 0.5 × 2.0 = 0
##
## 2. For rate parameters (HP Regen, MP Regen, rates, etc.):
##    - When base is 0, traits establish the final rate/percentage value
##    - The combined multiplier represents the final percentage
##    - Example: base 0%, traits 50% and 200% → 0.5 × 2.0 = 100% (returned as 100.0)
##    - Example: base 5%, traits 50% and 200% → 5 × 0.5 × 2.0 = 5%
func _add_traits_to_value(traits: Array, current_value: float, code_id: int, data_id: int, is_rate_parameter: bool = false) -> float:
	var multiplier := 1.0
	
	for traits_data in traits:
		if traits_data is Array:
			for t in traits_data:
				if t is RPGTrait and t.code == code_id and t.data_id == data_id:
					multiplier *= t.value / 100.0
		elif traits_data is RPGTrait and traits_data.code == code_id and traits_data.data_id == data_id:
			multiplier *= traits_data.value / 100.0
	
	multiplier = clamp(multiplier, -MAX_RESULT, MAX_RESULT) # min / max -100,000% / 100,000%
	
	var result: int
	if current_value == 0.0 and is_rate_parameter:
		result =  multiplier * 100.0
	else:
		result =  current_value * multiplier
	
	return clamp(result, -MAX_RESULT, MAX_RESULT)


## Adds equipment bonuses to the actor's parameters.
func _add_equipment_bonuses(current_value: float, param_id: String) -> float:
	for gear: GameGearBase in current_gear:
		if gear and gear.id > 0:
			if gear is GameWeapon and RPGSYSTEM.database.weapons.size() > gear.id:
				var weapon: RPGWeapon = RPGSYSTEM.database.weapons[gear.id]
				if weapon:
					current_value += weapon.get_parameter(param_id, gear.current_level)
			elif gear is GameArmor and RPGSYSTEM.database.armors.size() > gear.id:
				var armor: RPGArmor = RPGSYSTEM.database.armors[gear.id]
				if armor:
					current_value += armor.get_parameter(param_id, gear.current_level)
	
	return current_value


## Changes the actor's level and adjusts experience accordingly.
func change_level(level: int) -> void:
	if level <= 0:
		return
	
	current_level = level
	current_experience = 0
	
	if current_class > 0 and RPGSYSTEM.database.classes.size() > current_class:
		var class_data: RPGClass = RPGSYSTEM.database.classes[current_class]
		current_experience = class_data.get_parameter("experience", current_level)


## Adds experience points and levels up the actor if needed.
func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	
	current_experience += amount
	
	while current_class > 0 and RPGSYSTEM.database.classes.size() > current_class:
		var class_data: RPGClass = RPGSYSTEM.database.classes[current_class]
		var next_level_experience = class_data.get_parameter("experience", current_level + 1)
		
		if next_level_experience > 0 and current_experience >= next_level_experience:
			current_experience -= next_level_experience
			current_level += 1
		else:
			break


func _to_string() -> String:
	return "<GameActor name=%s id=%s>" % [current_name, id]
