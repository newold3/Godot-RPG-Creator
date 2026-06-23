@tool
class_name RPGDATA
extends Resource

## The main container that stores all game data: characters,
## classes, items, enemies, etc. The central structure where everything is organized.


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGDATA"


@export var _id_version: int

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

## List of armors.
@export var costumes: Array[RPGCostume] = []

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
	# costumes
	costumes.clear()
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
		"item_rarity_colors" = [Color.WHITE, Color("#32CD32"), Color("#4169E1"), Color("#FFD700")],
		"enemy_rarity_names" = ["Common", "Elite", "Boss"],
		"enemy_rarity_colors" = [Color.WHITE, Color("25aeb9ff"), Color("f10d00ff")]
		
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
	types.enemy_rarity_types = PackedStringArray(type_data.enemy_rarity_names)
	types.enemy_rarity_color_types = PackedColorArray(type_data.enemy_rarity_colors)
	types.equipment_types = PackedStringArray(type_data.equipment)
	types.gender_types = PackedStringArray(["None", "Male", "Female"])
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
	types.gender_types = PackedStringArray(["None", "Male", "Female"])

## Clones the RPG data.
## @param value bool - Whether to perform a deep clone.
## @return RPGDATA - The cloned RPG data.
func clone(value: bool = true) -> RPGDATA:
	var new_data = RPGDATA.new()

	var arrs = [
		"actors", "classes", "professions", "skills", "items", "weapons", "armors", "costumes",
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
	new_data._id_version = _id_version

	return new_data

## Updates the RPG data with another database.
## @param other RPGDATA - The other database to update with.
func update_with_other_db(other: RPGDATA) -> void:
	var arrs = [
		"actors", "classes", "professions", "skills", "items", "weapons", "armors",
		"costumes", "enemies", "troops", "states", "animations", "common_events",
		"system", "types", "terms", "speakers", "quests", "_id_version"
	]

	for id in arrs:
		set(id, other.get(id))

## Checks if the RPG data is equal to another database.
## @param other RPGDATA - The other database to compare with.
## @return bool - Whether the RPG data is equal to the other database.
## Compares this instance with another RPGDATA instance to check if they are functionally equivalent.
## It performs a deep recursive search converting nested objects to dictionaries.
func is_equal_to(other: RPGDATA) -> bool:
	if not other:
		return false

	return _recursive_diff_search(self, other)


func _recursive_diff_search(val_a: Variant, val_b: Variant) -> bool:
	if typeof(val_a) != typeof(val_b):
		return false

	match typeof(val_a):
		TYPE_OBJECT:
			if val_a == val_b:
				return true
			
			if val_a == null or val_b == null:
				return false
			
			if val_a is Resource and val_b is Resource:
				if val_a.resource_path != "" and val_a.resource_path == val_b.resource_path:
					return true
			
			var props = val_a.get_property_list()
			for prop in props:
				var usage = prop["usage"]
				if (usage & PROPERTY_USAGE_STORAGE) == 0:
					continue
				
				var p_name = prop["name"]
				if p_name in ["resource_path", "resource_local_to_scene", "resource_scene_unique_id", "resource_name", "script"]:
					continue
					
				if not _recursive_diff_search(val_a.get(p_name), val_b.get(p_name)):
					return false
			
			return true

		TYPE_DICTIONARY:
			if val_a.size() != val_b.size():
				return false
			
			var keys_a = val_a.keys()
			for key in keys_a:
				if not val_b.has(key):
					return false
				if not _recursive_diff_search(val_a[key], val_b[key]):
					return false
			
			return true

		TYPE_ARRAY:
			if val_a.size() != val_b.size():
				return false
			
			for i in range(val_a.size()):
				if not _recursive_diff_search(val_a[i], val_b[i]):
					return false
			
			return true

		_:
			return val_a == val_b


## Migrates the database to a target version, applying upgrades sequentially.
## @param target_version int - The version to upgrade to.
func migrate_to_version(target_version: int) -> void:
	if _id_version >= target_version:
		return
	
	print("The user database needs to be updated to the latest version.")
	print("Migrating RPGDATA from version %s to %s..." % [_id_version, target_version])
	
	# Apply upgrades sequentially:
	# If current is 3 and target is 5, it runs: 4, then 5.
	for i in range(_id_version + 1, target_version + 1):
		_apply_upgrade(i)
		_id_version = i
		print(" - Upgraded to version %s" % _id_version)
	
	print("Migration complete.")


## Internal logic to apply specific changes for a single version step.
## @param version_index int - The version number currently being installed.
func _apply_upgrade(version_index: int) -> void:
	match version_index:
		10:
			# Fix Items recipes
			for item in items:
				if not item: continue
				var new_list: Array[RPGRecipe] = []
				item.recipes = new_list
				var _disassemble_materials: Array[RPGGearUpgradeComponent] = []
				item.disassemble_materials = _disassemble_materials
		11:
			if types.tool_types == null or types.tool_types.size() == 0:
				types.tool_types = []
				types.icons.tool_icons = []
			for weapon: RPGWeapon in weapons:
				if weapon.tools_family == null:
					weapon.tools_family = []
			costumes = []
		12:
			var old_messages = terms.messages.filter(func(message: RPGTerm): return message.is_user_message == true)
			terms.messages.clear()
			var terms = FileAccess.open("res://addons/RPGData/default_terms_list.txt", FileAccess.READ).get_as_text().split("\n")
			
			for term: String in terms:
				var new_term: RPGTerm
				if term.find(",") != -1:
					var id = term.get_slice(", ", 0)
					var message = term.get_slice(", ", 1)
					new_term = RPGTerm.new(id, message, false)
				else:
					new_term = RPGTerm.new(term, "", true)
			
				terms.messages.append(new_term)
				
			if terms.messages.size() > 0:
				terms.messages.append(RPGTerm.new("User Messages", "", true))
				terms.messages.append_array(old_messages)
		13:
			system.game_scenes["Show Map Name"] = "res://Scenes/OtherScenes/default_animate_map_name.tscn"
		_:
			pass
