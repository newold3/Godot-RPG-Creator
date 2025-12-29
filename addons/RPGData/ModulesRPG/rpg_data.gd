@tool
class_name RPGDATA
extends Resource

## The main container that stores all game data: characters,
## classes, items, enemies, etc. The central structure where everything is organized.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGDATA"

## List of actors.
@export var actors: Array[RPGActor] = []

## List of classes.
@export var classes: Array[RPGClass] = []

## List of Professions.
@export var professions: Array[RPGProfession] = []

## List of skills.
@export var skills: Array[RPGSkill] = []

## List of items.
@export var items: Array[RPGItem] = []

## List of weapons.
@export var weapons: Array[RPGWeapon] = []

## List of armors.
@export var armors: Array[RPGArmor] = []

## List of enemies.
@export var enemies: Array[RPGEnemy] = []

## List of troops.
@export var troops: Array[RPGTroop] = []

## List of states.
@export var states: Array[RPGState] = []

## List of animations.
@export var animations: Array[RPGAnimation] = []

## List of common events.
@export var common_events: Array[RPGCommonEvent] = []

## System settings.
@export var system: RPGSystem = RPGSystem.new()

## Types of elements, skills, weapons, etc.
@export var types: RPGTypes = RPGTypes.new()

## Terms used in the game.
@export var terms: RPGTerms = RPGTerms.new()

## List of speakers.
@export var speakers: Array[RPGSpeaker] = []

## List of quests.
@export var quests: Array[RPGQuest] = []


## Initializes the RPG data.
func initialize() -> void:
	# Initial Actors
	actors.clear()
	actors.append(null)
	var actors_data = [
		["Sirion Shadowblade", "Shadow"],
		["Lyra Frostheart", "Frost"],
		["Roland Ironshield", "Iron"],
		["Luna Moonwhisper", "Moon"],
		["Thalia Flamebringer", "Flame"]
	]
	for data in actors_data:
		var actor = RPGActor.new()
		actor.name = data[0]
		actor.nickname = data[1]
		actors.append(actor)
	# Initial classes
	var data = [
		["Hero", ],
		["Warrior", ],
		["Mage", ],
		["Priest", ],
	]
	classes.clear()
	classes.append(null)
	for item in data:
		var new_class = RPGClass.new()
		new_class.name = tr(item[0])
		classes.append(new_class)
	# Initial professions
	data = [
		"Collector"
	]
	professions.clear()
	professions.append(null)
	for item in data:
		var new_profession = RPGProfession.new()
		new_profession.name = tr(item[0])
		professions.append(new_profession)
	# Initial skills
	data = [
		["Attack", ],
		["Guard", ],
		["Dual Attack", ],
		["Double Attack", ],
		["Triple Attack", ],
		["Escape", ],
		["Heal I", ],
		["Fire I", ],
		["Ice I", ],
		["Electro I", ],
		["Earth I", ],
		["Water I", ],
		["Lightness I", ],
		["Darkness I", ],
	]
	skills.clear()
	skills.append(null)
	for item in data:
		var new_skill = RPGSkill.new()
		new_skill.name = tr(item[0])
		skills.append(new_skill)
	# Initial items
	items.clear()
	items.append(null)
	items.append(RPGItem.new())
	# Initial weapons
	weapons.clear()
	weapons.append(null)
	weapons.append(RPGWeapon.new())
	# Initial armors
	armors.clear()
	armors.append(null)
	armors.append(RPGArmor.new())
	# Enemies
	enemies.clear()
	enemies.append(null)
	enemies.append(RPGEnemy.new())
	# Troops
	troops.clear()
	troops.append(null)
	troops.append(RPGTroop.new())
	# States
	states.clear()
	states.append(null)
	var state = RPGState.new()
	var messages = [
		"If an actor is affected by a state...",
		"If an enemy is affected by a state...",
		"If the state persists...",
		"If the state is removed..."
	]
	for message in messages:
		var msg = RPGMessage.new()
		msg.id = message
		state.messages.append(msg)
	state.name = "Dead"
	state.notes = "State 1 is automatically assigned when the target's HPs are 0"
	states.append(state)
	# Animations
	animations.clear()
	animations.append(null)
	animations.append(RPGAnimation.new())
	# Common Events
	common_events.clear()
	common_events.append(null)
	common_events.append(RPGCommonEvent.new())
	# Types
	var type_data = {
		"elements" = ["Physical", "Fire", "Ice", "Thunder", "Water", "Earth", "Wind", "Light", "Darkness"],
		"skills" = ["Magic", "Special"],
		"weapons" = ["Dagger", "Sword", "Flail", "Axe", "Whip", "Staff", "Bow", "Crossbow", "Gun", "Claw", "Globe", "Spear"],
		"armors" = ["General", "Magic Armor", "Light Armor", "Heavy Armor", "Small Shield", "Large Shield"],
		"items" = ["Potions", "Scrolls", "Herbs and Medicinal Plants", "Food Rations", "Elixirs", "Ointments and Salves", "Magical Reagents", "Bandages and Medical Supplies", "Poisons", "Buffing Items", "Traps and Explosives", "Survival Kits", "Crafting Materials", "Enchanting Components", "Augmenting Crystals"],
		"equipment" = ["Weapon", "Shield", "Head", "Body", "Accesory"],
		"weapon_rarity_names" = ["Common", "Uncommon", "Rare", "Legendary"],
		"weapon_rarity_colors" = [Color.WHITE, Color("#32CD32"), Color("#4169E1"), Color("#FFD700")],
		"armor_rarity_names" = ["Common", "Uncommon", "Rare", "Legendary"],
		"armor_rarity_colors" = [Color.WHITE, Color("#32CD32"), Color("#4169E1"), Color("#FFD700")],
		"item_rarity_names" = ["Common", "Uncommon", "Rare", "Legendary"],
		"item_rarity_colors" = [Color.WHITE, Color("#32CD32"), Color("#4169E1"), Color("#FFD700")]
	}
	types.element_types = PackedStringArray(type_data.elements)
	types.skill_types = PackedStringArray(type_data.skills)
	types.weapon_types = PackedStringArray(type_data.weapons)
	types.weapon_rarity_types = PackedStringArray(type_data.weapon_rarity_names)
	types.weapon_rarity_color_types = PackedColorArray(type_data.weapon_rarity_colors)
	types.armor_types = PackedStringArray(type_data.armors)
	types.armor_rarity_types = PackedStringArray(type_data.armor_rarity_names)
	types.armor_rarity_color_types = PackedColorArray(type_data.armor_rarity_colors)
	types.item_types = PackedStringArray(type_data.items)
	types.item_rarity_types = PackedStringArray(type_data.item_rarity_names)
	types.item_rarity_color_types = PackedColorArray(type_data.item_rarity_colors)
	types.equipment_types = PackedStringArray(type_data.equipment)
	# Speakers
	speakers.clear()
	speakers.append(null)
	# Quests
	quests.clear()
	quests.append(null)
	quests.append(RPGQuest.new())


## Fills the types with default values.
func fill_types():
	types = RPGTypes.new()
	var type_data = {
		"elements" = ["Physical", "Fire", "Ice", "Thunder", "Water", "Earth", "Wind", "Light", "Darkness"],
		"skills" = ["Magic", "Special"],
		"weapons" = ["Dagger", "Sword", "Flail", "Axe", "Whip", "Staff", "Bow", "Crossbow", "Gun", "Claw", "Globe", "Spear"],
		"armors" = ["General", "Magic Armor", "Light Armor", "Heavy Armor", "Small Shield", "Large Shield"],
		"items" = ["Potions", "Scrolls", "Herbs and Medicinal Plants", "Food Rations", "Elixirs", "Ointments and Salves", "Magical Reagents", "Bandages and Medical Supplies", "Poisons", "Buffing Items", "Traps and Explosives", "Survival Kits", "Crafting Materials", "Enchanting Components", "Augmenting Crystals"],
		"equipment" = ["Weapon", "Shield", "Head", "Body", "Accesory"],
		"weapon_rarity_names" = ["Common", "Uncommon", "Rare", "Legendary"],
		"weapon_rarity_colors" = [Color.WHITE, Color("#32CD32"), Color("#4169E1"), Color("#FFD700")],
		"armor_rarity_names" = ["Common", "Uncommon", "Rare", "Legendary"],
		"armor_rarity_colors" = [Color.WHITE, Color("#32CD32"), Color("#4169E1"), Color("#FFD700")],
		"item_rarity_names" = ["Common", "Uncommon", "Rare", "Legendary"],
		"item_rarity_colors" = [Color.WHITE, Color("#32CD32"), Color("#4169E1"), Color("#FFD700")]
	}
	types.element_types = PackedStringArray(type_data.elements)
	types.skill_types = PackedStringArray(type_data.skills)
	types.weapon_types = PackedStringArray(type_data.weapons)
	types.weapon_rarity_types = PackedStringArray(type_data.weapon_rarity_names)
	types.weapon_rarity_color_types = PackedColorArray(type_data.weapon_rarity_colors)
	types.armor_types = PackedStringArray(type_data.armors)
	types.armor_rarity_types = PackedStringArray(type_data.armor_rarity_names)
	types.armor_rarity_color_types = PackedColorArray(type_data.armor_rarity_colors)
	types.item_types = PackedStringArray(type_data.items)
	types.item_rarity_types = PackedStringArray(type_data.item_rarity_names)
	types.item_rarity_color_types = PackedColorArray(type_data.item_rarity_colors)
	types.equipment_types = PackedStringArray(type_data.equipment)

## Clones the RPG data.
## @param value bool - Whether to perform a deep clone.
## @return RPGDATA - The cloned RPG data.
func clone(value: bool = true) -> RPGDATA:
	var new_data = RPGDATA.new()

	var arrs = [
		"actors", "classes", "professions", "skills", "items", "weapons", "armors",
		"enemies", "troops", "states", "animations", "common_events", "speakers", "quests"]
	for v in arrs:
		var current_data = get(v)
		var current_new_data = new_data.get(v)
		current_new_data.clear()
		current_new_data.append(null)
		for i in range(1, current_data.size(), 1):
			var obj = current_data[i].clone(true)
			current_new_data.append(obj)

	new_data.system = system.clone(true)
	new_data.types = types.clone(true)
	new_data.terms = terms.clone(true)

	return new_data

## Updates the RPG data with another database.
## @param other RPGDATA - The other database to update with.
func update_with_other_db(other: RPGDATA) -> void:
	var arrs = [
		"actors", "classes", "professions", "skills", "items", "weapons", "armors",
		"enemies", "troops", "states", "animations", "common_events",
		"system", "types", "terms", "speakers", "quests"
	]

	for id in arrs:
		set(id, other.get(id))

## Checks if the RPG data is equal to another database.
## @param other RPGDATA - The other database to compare with.
## @return bool - Whether the RPG data is equal to the other database.
func is_equal_to(other: RPGDATA) -> bool:
	if not other:
		return false

	# Compare each exported property of RPGDATA
	for property in get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue

		var prop_name = property.name
		var value_self = get(prop_name)
		var value_other = other.get(prop_name)

		if not _compare_values(value_self, value_other):
			return false

	return true

## Compares two values for equality.
## @param a - The first value to compare.
## @param b - The second value to compare.
## @return bool - Whether the two values are equal.
func _compare_values(a, b) -> bool:
	# If either is null
	if a == null or b == null:
		return a == b

	# If they are different types
	if typeof(a) != typeof(b):
		return false

	# If it's an array or packed array
	if a is Array or typeof(a) in [
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY,
		TYPE_PACKED_COLOR_ARRAY
	]:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _compare_values(a[i], b[i]):
				return false
		return true

	# If it's a dictionary
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key):
				return false
			if not _compare_values(a[key], b[key]):
				return false
		return true

	# If it's a custom object (RPGActor, RPGSkill, etc.)
	if a is Object and a.has_method("get_property_list"):
		# If they are different classes
		if a.get_class() != b.get_class():
			return false

		# Compare each exported property
		for property in a.get_property_list():
			if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue

			var prop_name = property.name
			var value_a = a.get(prop_name)
			var value_b = b.get(prop_name)

			if not _compare_values(value_a, value_b):
				return false

		return true

	# For basic types (int, float, string, bool)
	return a == b
