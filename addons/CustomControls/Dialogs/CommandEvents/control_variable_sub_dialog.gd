@tool
extends Window

var data = {
	"option_selected": 8,
	"item_id": 1,
	"weapon_id": 1,
	"armor_id": 1,
	"profession_id": 1,
	"actor_id": 1,
	"enemy_id": 1,
	"character_id": 0,
	"party_id": 0,
	"last_id": 0,
	"other_id": 0,
	"actor_parameter": 0,
	"enemy_parameter": 0,
	"character_parameter": 0,
	"stat_id": 0,
	"stat_item_id": 1,
	"stat_weapon_id": 1,
	"stat_armor_id": 1,
	"stat_skill_id": 1,
	"stat_enemy_id": 1,
	"stat_extraction_profession_id": 1,
	"global_user_parameter": 0
}

var busy: bool = false

signal option_selected(value1: int, value2: int, value3: int)


func _ready() -> void:
	close_requested.connect(queue_free)
	_fill_stats()
	_fill_actor_parameters()
	_fill_global_user_parameters()
	update_items()


func _fill_stats() -> void:
	var stats = [
		"steps", "play_time", "enemy_kills", "skills",
		"items_sold", "items_purchased", "items_found",
		"weapons_sold", "weapons_purchased", "weapons_found",
		"armors_sold", "armors_purchased", "armors_found",
		"battles/won", "battles/lost", "battles/drawn", "battles/escaped", "battles/total_played",
		"battles/current_win_streak", "battles/longest_win_streak", "battles/current_lose_streak",
		"battles/longest_lose_streak", "battles/longest_battle_time", "battles/shortest_battle_time",
		"battles/total_combat_turns", "battles/total_time_in_battle", "battles/total_experience_earned",
		"battles/total_damage_received", "battles/total_damage_done",
		"battles/total_used_skills", "battles/total_critiques_performed",
		"extractions/total_items_found", "extractions/total_success", "extractions/total_failure",
		"extractions/total_finished", "extractions/total_unfinished", "extractions/critical_performs",
		"extractions/super_critical_performs", "extractions/resources_interactions",
		"save_count", "game_progress", "total_money_earned", "total_money_spent", "player_deaths", "chests_opened", "secrets_found", "max_level_reached", "dialogues_completed", "rare_items_found",
		"missions/completed", "missions/in_progress", "missions/failed", "missions/total_found",
	]
	var sort_stats = stats.duplicate(true)
	sort_stats.sort()
	var node = %StatID
	node.clear()
	
	for i in sort_stats.size():
		var current_stat = sort_stats[i]
		node.add_item(current_stat)
		node.set_item_metadata(-1, stats.find(current_stat))
	
	node.add_separator("user Stats")
	
	var user_stats = RPGSYSTEM.database.types.user_stats
	var user_stats_sort = user_stats.duplicate()
	user_stats_sort.sort()
	var extra_id = stats.size() + 1
	
	for i in user_stats_sort.size():
		var current_stat = user_stats_sort[i]
		node.add_item(current_stat)
		node.set_item_metadata(-1, user_stats.find(current_stat) + extra_id)


func _fill_actor_parameters() -> void:
	var items = PackedStringArray(["Level", "Experience"]) + RPGSYSTEM.database.types.main_parameters
	
	var node = %ActorParameter
	node.clear()
	
	for item in items:
		node.add_item(item)
	
	var user_parameters = RPGSYSTEM.database.types.user_parameters
	
	if user_parameters.size() > 0:
		node.add_separator()
		
		for param in user_parameters:
			node.add_item("User Parameter: " + param.name)


func _fill_global_user_parameters() -> void:
	var node = %GlobalUserParameter
	node.clear()
	
	var user_parameters = RPGSYSTEM.database.types.user_parameters
	
	if user_parameters.size() > 0:
		for param in user_parameters:
			node.add_item("User Parameter: " + param.name)


func set_data(value1: Variant, value2: int, value3: int) -> void:
	%GlobalUserParameterContainer.visible = false
	%GlobalUserParameter.set_disabled(true)
	busy = true
	var nodes = [%Item, %Weapon, %Armor, %Actor, %Enemy, %Character, %Party, %Last, %Other, %Profession, %Stat]
	for node in nodes:
		node.get_parent().propagate_call("set_disabled", [true])
		node.set_disabled(false)
		node.set_pressed_no_signal(false)
	nodes[value1].set_pressed(true)
	
	match value1:
		0: data.item_id = value2
		1: data.weapon_id = value2
		2: data.armor_id = value2
		3:
			data.actor_id = value2
			data.actor_parameter = value3
			%ActorParameter.select(value3)
		4:
			data.enemy_id = value2
			data.enemy_parameter = value3
			%EnemyID.select(value2)
			%EnemyParameter.select(value3)
		5:
			data.character_id = value2
			data.character_parameter = value3
			%CharacterID.select(value2)
			if %CharacterParameter.get_item_count() > value3:
				%CharacterParameter.select(value3)
			else:
				%CharacterParameter.select(0)
		6:
			data.party_id = value2
			%PartyID.select(value2)
		7:
			data.last_id = value2
			%LastID.select(value2)
		8:
			data.other_id = value2
			data.global_user_parameter = value3
			%OtherID.select(value2)
			%GlobalUserParameterContainer.visible = value2 == 19
			%GlobalUserParameter.set_disabled(value2 != 19)
			if %GlobalUserParameter.get_item_count() > value3:
				%GlobalUserParameter.select(value3)
			else:
				%GlobalUserParameter.select(0)
		9: data.profession_id = value2
		10:
			data.stat_id = value2
			match value2:
				2: # enemy:
					data.stat_enemy_id = value3
				3: # skill
					data.stat_skill_id = value3
				4, 5, 6: # items
					data.stat_item_id = value3
				7, 8, 9: # weapons
					data.stat_weapon_id = value3
				10, 11, 12: # armor
					data.stat_armor_id = value3
				31: # Extaction
					data.stat_extraction_profession_id = value3
			for i in %StatID.get_item_count():
				if %StatID.get_item_metadata(i) == value2:
					%StatID.select(i)
					_on_stat_id_item_selected(i)
					break
	
	update_items()
	set_deferred("size",  Vector2i(size.x, 0))
	busy = false


func _on_type_selected(toggled_on: bool, type: int) -> void:
	var nodes = [%Item, %Weapon, %Armor, %Actor, %Enemy, %Character, %Party, %Last, %Other, %Profession, %Stat]
	nodes[type].get_parent().propagate_call("set_disabled", [!toggled_on])
	nodes[type].set_disabled(false)
	if toggled_on:
		data.option_selected = type
	propagate_call("release_focus")
	
	if type == 10:
		match data.stat_id:
			2: # enemy:
				%StatItemID.set_disabled(false)
				%StatItemID.text = "ID = " + str(data.stat_enemy_id)
			3: # skill
				%StatItemID.set_disabled(false)
				%StatItemID.text = "ID = " + str(data.stat_skill_id)
			4, 5, 6: # items
				%StatItemID.set_disabled(false)
				%StatItemID.text = "ID = " + str(data.stat_item_id)
			7, 8, 9: # weapons
				%StatItemID.set_disabled(false)
				%StatItemID.text = "ID = " + str(data.stat_weapon_id)
			10, 11, 12: # armor
				%StatItemID.set_disabled(false)
				%StatItemID.text = "ID = " + str(data.stat_armor_id)
			31: # Extraction
				%StatItemID.set_disabled(false)
				%StatItemID.text = "ID = " + str(data.stat_extraction_profession_id)
			_:
				%StatItemID.set_disabled(true)
				%StatItemID.text = " "
	else:
		%StatItemID.set_disabled(true)
		%StatItemID.text = " "


func _open_select_any_data_dialog(current_data, id_selected: int, title: String, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_any_data_selected, CONNECT_ONE_SHOT)
	
	dialog.setup(current_data, id_selected, title, target)


func _on_any_data_selected(id: int, target: int) -> void:
	match target:
		0: data.item_id = id
		1: data.weapon_id = id
		2: data.armor_id = id
		3: data.actor_id = id
		4: data.enemy_id = id
		9: data.profession_id = id
		10: data.stat_snemy_id = id
		11: data.stat_skill_id = id
		12: data.stat_item_id = id
		13: data.stat_weapon_id = id
		14: data.stat_armor_id = id
		31: data.stat_extraction_profession_id = id
	
	update_items()


func _on_item_id_pressed() -> void:
	var current_data = RPGSYSTEM.database.items
	var id_selected = max(1, min(data.item_id, current_data.size()))
	_open_select_any_data_dialog(current_data, id_selected, "Item", 0)


func _on_weapon_id_pressed() -> void:
	var current_data = RPGSYSTEM.database.weapons
	var id_selected = max(1, min(data.weapon_id, current_data.size()))
	_open_select_any_data_dialog(current_data, id_selected, "Weapon", 1)


func _on_armor_id_pressed() -> void:
	var current_data = RPGSYSTEM.database.armors
	var id_selected = max(1, min(data.armor_id, current_data.size()))
	_open_select_any_data_dialog(current_data, id_selected, "Armor", 2)


func _on_actor_id_pressed() -> void:
	var current_data = RPGSYSTEM.database.actors
	var id_selected = max(1, min(data.actor_id, current_data.size()))
	_open_select_any_data_dialog(current_data, id_selected, "Actor", 3)


func _on_enemy_id_pressed() -> void:
	var current_data = RPGSYSTEM.database.enemies
	var id_selected = max(1, min(data.enemy_id, current_data.size()))
	_open_select_any_data_dialog(current_data, id_selected, "Enemy", 4)


func update_items() -> void:
	var obj = [
		[%ItemID, "items", "item_id"],
		[%WeaponID, "weapons", "weapon_id"],
		[%ArmorID, "armors", "armor_id"],
		[%ActorID, "actors", "actor_id"],
		[%EnemyID, "enemies", "enemy_id"],
		[%ProfessionID, "professions", "profession_id"],
	]
	for o in obj:
		var items = RPGSYSTEM.database[o[1]]
		var index = max(1, data[o[2]])
		if items.size() > index:
			var item_name = "%s:%s" % [
				str(index).pad_zeros(str(items.size()).length()),
				items[index].name
			]
			o[0].text = item_name
		else:
			o[0].text = "⚠ Invalid Data"
	
	match data.stat_id:
		2: # enemy:
			%StatItemID.text = "ID = " + str(data.stat_enemy_id)
		3: # skill
			%StatItemID.text = "ID = " + str(data.stat_skill_id)
		4, 5, 6: # items
			%StatItemID.text = "ID = " + str(data.stat_item_id)
		7, 8, 9: # weapons
			%StatItemID.text = "ID = " + str(data.stat_weapon_id)
		10, 11, 12: # armor
			%StatItemID.text = "ID = " + str(data.stat_armor_id)
		31: # Extraction
			%StatItemID.text = "ID = " + str(data.stat_extraction_profession_id)
		_:
			%StatItemID.text = " "


func _on_ok_button_pressed() -> void:
	var value1 = data.option_selected
	var value2 = -1
	var value3 = -1
	match value1:
		0: value2 = data.item_id
		1: value2 = data.weapon_id
		2: value2 = data.armor_id
		3:
			value2 = data.actor_id
			value3 = data.actor_parameter
		4:
			value2 = data.enemy_id
			value3 = data.enemy_parameter
		5:
			value2 = data.character_id
			value3 = data.character_parameter
		6: value2 = data.party_id
		7: value2 = data.last_id
		8:
			value2 = data.other_id
			value3 = data.global_user_parameter
		9: value2 = data.profession_id
		10:
			value2 = data.stat_id
			match value2:
				2: # enemy:
					value3 = data.stat_enemy_id
				3: # skill
					value3 = data.stat_skill_id
				4, 5, 6: # items
					value3 = data.stat_item_id
				7, 8, 9: # weapons
					value3 = data.stat_weapon_id
				10, 11, 12: # armor
					value3 = data.stat_armor_id
				31: # Extraction:
					value3 = data.stat_extraction_profession_id
			
	option_selected.emit(value1, value2, value3)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_actor_parameter_item_selected(index: int) -> void:
	data.actor_parameter = index


func _on_enemy_parameter_item_selected(index: int) -> void:
	data.enemy_parameter = index


func _on_character_id_item_selected(index: int) -> void:
	data.character_id = index


func _on_character_parameter_item_selected(index: int) -> void:
	data.character_parameter = index


func _on_party_id_item_selected(index: int) -> void:
	data.party_id = index


func _on_last_id_item_selected(index: int) -> void:
	data.last_id = index


func _on_other_id_item_selected(index: int) -> void:
	data.other_id = index
	%GlobalUserParameterContainer.visible = index == 19
	%GlobalUserParameter.set_disabled(index != 19)
	set_deferred("size",  Vector2i(size.x, 0))


func _on_profession_id_pressed() -> void:
	var current_data = RPGSYSTEM.database.professions
	var id_selected = max(1, min(data.profession_id, current_data.size()))
	_open_select_any_data_dialog(current_data, id_selected, "Profession", 9)


func _on_stat_id_item_selected(index: int) -> void:
	data.stat_id = %StatID.get_item_metadata(index)
	match data.stat_id:
		2: # enemy:
			%StatItemID.set_disabled(false)
			%StatItemID.text = "ID = " + str(data.stat_enemy_id)
		3: # skill
			%StatItemID.set_disabled(false)
			%StatItemID.text = "ID = " + str(data.stat_skill_id)
		4, 5, 6: # items
			%StatItemID.set_disabled(false)
			%StatItemID.text = "ID = " + str(data.stat_item_id)
		7, 8, 9: # weapons
			%StatItemID.set_disabled(false)
			%StatItemID.text = "ID = " + str(data.stat_weapon_id)
		10, 11, 12: # armor
			%StatItemID.set_disabled(false)
			%StatItemID.text = "ID = " + str(data.stat_armor_id)
		31: # Extraction
			%StatItemID.set_disabled(false)
			%StatItemID.text = "ID = " + str(data.stat_extraction_profession_id)
		_:
			%StatItemID.set_disabled(true)
			%StatItemID.text = " "


func _on_stat_item_id_pressed() -> void:
	var current_data: Variant
	var id_selected: int
	var dialog_title: String
	var target_id: int
	match data.stat_id:
		2: # enemy:
			current_data = RPGSYSTEM.database.enemies
			id_selected = data.stat_snemy_id
			dialog_title = "Enemy"
			target_id = 10
		3: # skill
			current_data = RPGSYSTEM.database.skills
			id_selected = data.stat_skill_id
			dialog_title = "Skill"
			target_id = 11
		4, 5, 6: # items
			current_data = RPGSYSTEM.database.items
			id_selected = data.stat_item_id
			dialog_title = "Item"
			target_id = 12
		7, 8, 9: # weapons
			current_data = RPGSYSTEM.database.weapons
			id_selected = data.stat_weapon_id
			dialog_title = "Weapon"
			target_id = 13
		10, 11, 12: # armor
			current_data = RPGSYSTEM.database.armors
			id_selected = data.stat_armor_id
			dialog_title = "Armor"
			target_id = 14
		31: # Extraction
			current_data = RPGSYSTEM.database.professions
			id_selected = data.stat_extraction_profession_id
			dialog_title = "Profession"
			target_id = 31
	
	if current_data:
		_open_select_any_data_dialog(current_data, id_selected, dialog_title, target_id)


func _on_global_user_parameter_item_selected(index: int) -> void:
	data.global_user_parameter = index
