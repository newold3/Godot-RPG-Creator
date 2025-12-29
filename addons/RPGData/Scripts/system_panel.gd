@tool
extends HBoxContainer

var data: RPGSystem
var database: RPGDATA

var busy: bool = false


func set_data(real_data: RPGSystem) -> void:
	data = real_data


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_update_data_fields()


func _update_data_fields() -> void:
	if data:
		%GameTitle.text = data.game_title
		%GameInitialChapter.text = data.initial_chapter_name
		%GoldCurrency.text = data.currency_info.get("name", "G")
		%GoldIcon.set_icon(data.currency_info.get("icon", ""))
		%PartyActiveMembers.value = data.party_active_members
		%MaxItemsPerStack.value = data.max_items_per_stack
		%MaxItemsInInventory.value = data.max_items_in_inventory
		var options = data.options
		%Other2.set_pressed(options.get("experience_in_reserve", false))
		%Other3.set_pressed(options.get("death_walking_damage", false))
		%Other4.set_pressed(options.get("death_floor_damage", false))
		%UseThousandsSeparator.set_pressed(options.get("use_thousands_separator", true))
		%ShowAbbreviatedInMenu.set_pressed(options.get("show_abbreviated_in_menu", true))
		%ShowAbbreviatedinBattle.set_pressed(options.get("show_abbreviated_in_battle", true))
		%NormalAttackColor.set_pick_color(options.get("normal_attack_color", Color.WHITE))
		%CriticalAttackColor.set_pick_color(options.get("critical_attack_color", Color.DARK_ORANGE))
		%OverpowerAttackColor.set_pick_color(options.get("overpower_attack_color", Color.PURPLE))
		%NormalShakeIntensity.value = options.get("normal_shake_screen_intensity", 0.01)
		%CriticalShakeIntensity.value = options.get("critical_shake_screen_intensity", 0.5)
		%OverpowerShakeIntensity.value = options.get("overpower_shake_screen_intensity", 1.2)
		%AutoShowPopups.set_pressed_no_signal(options.get("auto_popup_on_pick_up_items", true))
		%PauseInMenu.set_pressed_no_signal(data.pause_day_night_in_menu)
		%FollowersEnabled.set_pressed_no_signal(data.followers_enabled)
		
		var movement_mode_index = max(0, min(data.movement_mode, 1))
		%MovementMode.select(movement_mode_index)
		
		fill_party_members()
		fill_vehicles()
		fill_start_positions()
		fill_game_musics()
		fill_game_fxs()
		fill_transitions()
		fill_message_config()
		fill_day_night()
		fill_game_scenes()
		fill_preload_scenes()
		fill_signal_list()


func fill_party_members(selected_index: int = -1) -> void:
	var characters = data.start_party
	
	var node = %InitialPartyMembers
	node.clear()
	
	for id in characters:
		var character_name: String
		if id > 0:
			if database.actors.size() > id:
				character_name = "%s: %s" % [id, database.actors[id].name]
			else:
				character_name = "⚠ Invalid Data"
		
		node.add_column([character_name])
	
	await node.columns_setted
	
	if selected_index != -1:
		node.select(selected_index)


func fill_game_scenes(selected_index: int = -1) -> void:
	var scenes = data.game_scenes
	
	var node = %GameSceneList
	node.clear()
	
	for key in scenes.keys():
		node.add_column([key, scenes[key]])
	
	await node.columns_setted
	
	if selected_index != -1:
		node.select(selected_index)


func fill_preload_scenes(selected_index: int = -1) -> void:
	var scenes = data.preload_scenes
	
	var node = %PreloadSceneList
	node.clear()
	
	for path in scenes:
		node.add_column([path])
	
	await node.columns_setted
	
	if selected_index != -1:
		node.select(selected_index)


func fill_signal_list(selected_index: int = -1) -> void:
	var signals = data.custom_signal_list
	
	var node = %UserSignalList
	node.clear()
	
	for s in signals:
		node.add_column([s])
	
	await node.columns_setted
	
	if selected_index != -1:
		node.select(selected_index)


func fill_vehicles() -> void:
	%LandTransport.set_icon(data.land_transport)
	%SeaTransport.set_icon(data.sea_transport)
	%AirTransport.set_icon(data.air_transport)


func fill_start_positions(selected_index: int = -1) -> void:
	var node = %StartPositions
	node.clear()
	
	var ids = ["Player", "Land Transport", "Sea Transport", "Air Transport"]
	var info = [
		data.player_start_position,
		data.land_transport_start_position,
		data.sea_transport_start_position,
		data.air_transport_start_position
	]
	
	for i in ids.size():
		var id: String = tr(ids[i])
		var obj: RPGMapPosition = info[i]
		var map_id = obj.map_id
		var pos = obj.position
		var column = []
		column.append(id)
		column.append(RPGMapsInfo.get_map_name_from_id(map_id))
		column.append(str(pos))
		
		node.add_column(column)
	
	await node.columns_setted
	
	if selected_index != -1:
		node.select(selected_index)


func fill_game_musics(selected_index: int = -1) -> void:
	var current_data = data.game_musics
	var sound_list = [
		"Title", "Battle", "Victory", "Defeat", "Game End",
		"Land Transport", "Sea Transport", "Air Transport"
	]
	var node = %MusicList
	node.clear()
	
	for i: int in sound_list.size():
		var column = [tr(sound_list[i])]
		var sound: Dictionary = current_data[i]
		column.append((sound.get("path", "")).get_file())
		column.append(str(sound.get("volume", 0.0)))
		column.append(str(sound.get("pitch", 1.0)))
		node.add_column(column)
		
	await node.columns_setted
	
	if selected_index != -1:
		node.select(selected_index)


func fill_game_fxs(selected_index: int = -1) -> void:
	var current_data = data.game_fxs

	var sound_list = [
		"Cursor", "Accept", "Cancel", "Error", "Equip",
		"Save", "Load", "Erase Save", "Battle Start", "Battle End",
		"Escape From Battle", "Lost Battle", "Win Battle",
		"Failure", "Evasion", "Magic Reflex",
		"Buy Item", "Sell Item", "Complete Transaction",
		"No Money Error", "Store Restocks",
		"Use Item (Default)", "Use Skill (Default)",
		"Default Extraction Fx", "Extraction Success",
		"Extraction Cancel", "Extraction Critical Hit",
		"Switch Hero Panels"
	]

	var node = %SoundList
	node.clear()
	
	for i: int in sound_list.size():
		var column = [tr(sound_list[i])]
		var sound: Dictionary = current_data[i]
		column.append((sound.get("path", "")).get_file())
		column.append(str(sound.get("volume", 0.0)))
		var pitch1 = sound.get("pitch", 1.0)
		var pitch2 = sound.get("pitch2", -1)
		if pitch2 > -1 and pitch1 != pitch2:
			column.append("%s ~%s" % [pitch1, pitch2])
		else:
			column.append(str(pitch1))
		node.add_column(column)
		
	await node.columns_setted
	
	if selected_index != -1:
		node.select(selected_index)


func fill_transitions() -> void:
	var list = ["Instant", "Fade Out-In", "Fade Out To Color", "Shader Transition", "Custom Scene"]
	var type: int
	var path: String = ""
	var trans_name: String
	
	type = data.default_map_transition.parameters.type
	if type == 3:
		path = " - " + data.default_map_transition.parameters.transition_image.get_file()
	elif type == 4:
		path = " - " + data.default_map_transition.parameters.scene_image.get_file()
	trans_name = tr("Default Map Transition") + "... [ %s%s ]" % [tr(list[type]), path]
	%Other6.text = trans_name
	
	type = data.default_battle_transition.parameters.type
	if type == 3:
		path = " - " + data.default_battle_transition.parameters.transition_image.get_file()
	elif type == 4:
		path = " - " + data.default_battle_transition.parameters.scene_image.get_file()
	trans_name = tr("Default Battle Transition") + "... [ %s%s ]" % [tr(list[type]), path]
	%Other7.text = trans_name


func fill_message_config() -> void:
	var message = data.default_message_config
	var scene_path = message.get("scene_path", "").get_file()
	var max_width = message.get("max_width", "")
	var max_lines = message.get("max_lines", "")
	var skip_mode = message.get("skip_mode", 0)
	var mode = ["None", "All, Run Commands", "All", "Fast Forward"][skip_mode]
	var text = tr("Default message Config") + "... [ %s, Max Width %s, Max Lines: %s, Skip Mode %s, ... ]" % [
		scene_path,
		max_width,
		max_lines,
		tr(mode)
	]
	%Other5.text = text


func fill_day_night() -> void:
	var config = data.day_night_config
	busy = true
	
	%DayHours.value = config.day_duration_seconds / 3600
	%DayMinutes.value = (config.day_duration_seconds % 3600) / 60
	%DaySeconds.value = config.day_duration_seconds % 60
	%StartingHour.value = config.start_time
	%DawnColor.set_pick_color(config.dawn_color)
	%DayColor.set_pick_color(config.day_color)
	%DuskColor.set_pick_color(config.dusk_color)
	%NightColor.set_pick_color(config.night_color)
	%ShadowColor.set_pick_color(config.shadow_color)
	%DayVolume.value = config.day_audio_volume
	%NightVolume.value = config.night_audio_volume
	%AudioTransitionSpeed.value = config.audio_transition_speed
	%SunMaxAngle.value = config.sun_max_angle
	%SunRotationSpeed.value = config.sun_rotation_speed
	%SunDayShadowStrength.value = config.shadow_day_strength
	%SunNightShadowStrength.value = config.shadow_night_strength
	%ShadowElongationX.value = config.shadow_base_elongation.x
	%ShadowElongationY.value = config.shadow_base_elongation.y
	%ShadowSkew.value = config.shadow_base_skew
	%ShadowLengthX.value = config.shadow_max_length
	%ShadowLengthY.value = config.shadow_min_length
	%StreetLightsOnHour.value = config.street_lights_on_hour
	%StreetLightsOffHour.value = config.street_lights_off_hour
	
	update_all_switchs()
	
	busy = false


func _on_game_title_text_changed(new_text: String) -> void:
	data.game_title = new_text


func _on_gold_currency_text_changed(new_text: String) -> void:
	data.currency_info.name = new_text


func open_file_dialog() -> Window:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.destroy_on_hide = true
	await get_tree().process_frame
	
	dialog.set_dialog_mode(0)
	
	return dialog


func open_image_dialog(target_callable: Callable, default_path: String = "", filter: String = "images") -> void:
	var dialog = await open_file_dialog()
	
	dialog.target_callable = target_callable
	dialog.set_file_selected(default_path)
	
	dialog.fill_files(filter)


func update_gold_icon(path: String) -> void:
	data.currency_info.icon = path
	%GoldIcon.set_icon(path)


func _on_gold_icon_clicked() -> void:
	open_image_dialog(update_gold_icon, data.currency_info.get("icon", ""))


func _on_gold_icon_remove_requested() -> void:
	data.currency_info.icon = ""
	%GoldIcon.set_icon("")



func _on_visibility_changed() -> void:
	if visible:
		_update_data_fields()


func _on_initial_party_members_delete_pressed(indexes: PackedInt32Array) -> void:
	var items_to_removed = []
	for index in indexes:
		items_to_removed.append(data.start_party[index])
		
	while items_to_removed.size() > 0:
		var item = items_to_removed.pop_back()
		for i in data.start_party.size():
			if data.start_party[i] == item:
				data.start_party.remove_at(i)
				break
	
	if data.start_party.size() > indexes[0]:
		fill_party_members(indexes[0])
	else:
		fill_party_members()


func _on_initial_party_members_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_actor_selected, CONNECT_ONE_SHOT)
	
	var item_selected = -1 if index >= data.start_party.size() else data.start_party[index]
	dialog.setup(database.actors, item_selected, "Select Actor", null)


func _on_actor_selected(id: int, _target) -> void:
	var selected_index = 0
	if data.start_party.has(id):
		for i in data.start_party.size():
			var actor_id = data.start_party[i]
			if actor_id == id:
				selected_index = i
				break
				
		%InitialPartyMembers.select(selected_index)
	else:
		data.start_party.append(id)
		fill_party_members(data.start_party.size() - 1)


func _on_start_positions_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/select_map_position_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var mapinfo: RPGMapPosition
	
	match index:
		0:
			dialog.title = TranslationManager.tr("Player Start Position")
			mapinfo = data.player_start_position
		1:
			dialog.title = TranslationManager.tr("Land Transport Strat Position")
			mapinfo = data.land_transport_start_position
		2:
			dialog.title = TranslationManager.tr("Sea Transport Strat Position")
			mapinfo = data.sea_transport_start_position
		3:
			dialog.title = TranslationManager.tr("Air Transport Strat Position")
			mapinfo = data.air_transport_start_position
			
	var map_id: int = mapinfo.map_id
	var start_position: Vector2i = mapinfo.position
	
	if map_id:
		var map_path = RPGMapsInfo.get_map_by_id(map_id)
		dialog.set_start_map(map_path, start_position)
	else:
		dialog.select_initial_map()

	dialog.cell_selected.connect(_on_map_position_selected.bind(index))


func _on_map_position_selected(map_id: int, cell_position: Vector2i, type_index: int) -> void:
	match type_index:
		0: data.player_start_position = RPGMapPosition.new(map_id, cell_position)
		1: data.land_transport_start_position = RPGMapPosition.new(map_id, cell_position)
		2: data.sea_transport_start_position = RPGMapPosition.new(map_id, cell_position)
		3: data.air_transport_start_position = RPGMapPosition.new(map_id, cell_position)
	
	fill_start_positions(type_index)


func _on_music_list_delete_pressed(indexes: PackedInt32Array) -> void:
	for index in indexes:
		data.game_musics[index].path = ""
	
	fill_game_musics(indexes[0])
		


func _on_music_list_item_activated(index: int) -> void:
	open_sound_dialog(index, 0)


func _on_sound_list_delete_pressed(indexes: PackedInt32Array) -> void:
	for index in indexes:
		data.game_fxs[index].path = ""
	
	fill_game_fxs(indexes[0])


func _on_sound_list_item_activated(index: int) -> void:
	open_sound_dialog(index, 1)


func open_sound_dialog(index: int, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var sound: Dictionary
	
	if target == 0:
		sound = data.game_musics[index]
	else:
		sound = data.game_fxs[index]
	
	var commands: Array[RPGEventCommand]
	var command = RPGEventCommand.new(0, 0, sound)
	commands.append(command)
	dialog.enable_random_pitch()
	dialog.set_parameters(commands)
	dialog.set_data()
	
	dialog.command_changed.connect(
		func(commands: Array[RPGEventCommand]):
			var c = commands[0].parameters
			_on_sound_selected(c.path, c.volume, c.pitch, c.pitch2, index, target)
	)


func _on_sound_selected(path: String, volume: float, pitch: float, pitch2: float, index: int, target: int) -> void:
	if target == 0:
		data.game_musics[index] = {"path": path, "volume": volume, "pitch": pitch, "pitch2": pitch2}
		fill_game_musics(index)
	else:
		data.game_fxs[index] = {"path": path, "volume": volume, "pitch": pitch, "pitch2": pitch2}
		fill_game_fxs(index)


func _on_other_1_item_selected(index: int) -> void:
	data.options.movement_mode = index


func _on_other_2_toggled(toggled_on: bool) -> void:
	data.options.experience_in_reserve = toggled_on


func _on_other_3_toggled(toggled_on: bool) -> void:
	data.options.death_walking_damage = toggled_on


func _on_other_4_toggled(toggled_on: bool) -> void:
	data.options.death_floor_damage = toggled_on


func _on_other_5_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/message_config_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var parameters: Array[RPGEventCommand] = [RPGEventCommand.new()]
	parameters[0].parameters = data.default_message_config
	dialog.set_parameters(parameters)
	dialog.command_changed.connect(_on_message_config_changed)


func _on_message_config_changed(commands: Array[RPGEventCommand]) -> void:
	var config = commands[0].parameters
	data.default_message_config = config
	fill_message_config()


func _on_move_actor_up_pressed() -> void:
	var selected_items = %InitialPartyMembers.get_selected_items()
	if selected_items.size() == 0:
		return
		
	var new_start_party: PackedInt32Array = []
	var used_ids: PackedInt32Array = []
	var new_selected_items: PackedInt32Array = []
	
	for i in range(0, selected_items[0] - 1, 1):
		new_start_party.append(data.start_party[i])
		used_ids.append(i)
	
	for i in selected_items:
		new_selected_items.append(new_start_party.size())
		new_start_party.append(data.start_party[i])
		used_ids.append(i)
	
	for i in range(0, data.start_party.size(), 1):
		if i in used_ids:
			continue
		new_start_party.append(data.start_party[i])
	
	data.start_party = new_start_party
	
	await fill_party_members()
	
	%InitialPartyMembers.select_items(new_selected_items)


func _on_move_actor_down_pressed() -> void:
	var selected_items = %InitialPartyMembers.get_selected_items()
	if selected_items.size() == 0:
		return

	var new_start_party: PackedInt32Array = []
	var used_ids: PackedInt32Array = []
	var new_selected_items: PackedInt32Array = []

	for i in range(0, selected_items[0], 1):
		new_start_party.append(data.start_party[i])
		used_ids.append(i)

	for i in range(selected_items[0], selected_items[-1] + 2, 1):
		if data.start_party.size() <= i:
			break
		if !i in selected_items:
			new_start_party.append(data.start_party[i])
			used_ids.append(i)

	for i in selected_items:
		new_selected_items.append(new_start_party.size())
		new_start_party.append(data.start_party[i])
		used_ids.append(i)

	for i in range(0, data.start_party.size(), 1):
		if i in used_ids:
			continue
		new_start_party.append(data.start_party[i])
	
	data.start_party = new_start_party

	await fill_party_members()
	%InitialPartyMembers.select_items(new_selected_items)


func _on_land_transport_clicked() -> void:
	var dialog = await open_file_dialog()

	dialog.target_callable = update_land_transport
	dialog.set_file_selected(data.land_transport)
	dialog.fill_files("vehicles")


func _on_sea_transport_clicked() -> void:
	var dialog = await open_file_dialog()

	dialog.target_callable = update_sea_transport
	dialog.set_file_selected(data.sea_transport)
	
	dialog.fill_files("vehicles")


func _on_air_transport_clicked() -> void:
	var dialog = await open_file_dialog()

	dialog.target_callable = update_air_transport
	dialog.set_file_selected(data.air_transport)
	
	dialog.fill_files("vehicles")


func update_land_transport(path: String) -> void:
	data.land_transport = path
	%LandTransport.set_icon(path)


func update_sea_transport(path: String) -> void:
	data.sea_transport = path
	%SeaTransport.set_icon(path)


func update_air_transport(path: String) -> void:
	data.air_transport = path
	%AirTransport.set_icon(path)


func _on_party_active_members_value_changed(value: float) -> void:
	data.party_active_members = value


func _on_other_6_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/set_transition_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var parameters: Array[RPGEventCommand] = []
	parameters.append(data.default_map_transition)
	
	dialog.set_parameters(parameters)
	dialog.command_changed.connect(_on_map_transition_selected)


func _on_map_transition_selected(commands: Array[RPGEventCommand]) -> void:
	data.default_map_transition = commands[0]
	fill_transitions()


func _on_max_items_per_stack_value_changed(value: float) -> void:
	data.max_items_per_stack = value


func _on_movement_mode_item_selected(index: int) -> void:
	data.movement_mode = index


func _on_max_items_in_inventory_value_changed(value: float) -> void:
	data.max_items_in_inventory = value


func _on_config_data_tabs_tab_changed(index: int) -> void:
	var node_path = "%%Tab%s" % (index + 1)
	var node = get_node_or_null(node_path)
	if node:
		for child in node.get_parent().get_children():
			child.visible = false
		node.visible = true


func _on_other_7_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/set_transition_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var parameters: Array[RPGEventCommand] = []
	parameters.append(data.default_battle_transition)
	
	dialog.set_parameters(parameters)
	dialog.command_changed.connect(_on_battle_transition_selected)


func _on_battle_transition_selected(commands: Array[RPGEventCommand]) -> void:
	data.default_battle_transition = commands[0]
	fill_transitions()


func _on_use_thousands_separator_toggled(toggled_on: bool) -> void:
	data.options.use_thousands_separator = toggled_on


func _on_show_abbreviated_in_menu_toggled(toggled_on: bool) -> void:
	data.options.show_abbreviated_in_menu = toggled_on



func _on_show_abbreviatedin_battle_toggled(toggled_on: bool) -> void:
	data.options.show_abbreviated_in_battle = toggled_on


func _on_normal_attack_color_color_changed(color: Color) -> void:
	data.options.normal_attack_color = color


func _on_normal_shake_intensity_value_changed(value: float) -> void:
	data.options.normal_shake_screen_intensity = value


func _on_critical_attack_color_color_changed(color: Color) -> void:
	data.options.critical_attack_color = color


func _on_critical_shake_intensity_value_changed(value: float) -> void:
	data.options.critical_shake_screen_intensity = value


func _on_overpower_attack_color_color_changed(color: Color) -> void:
	data.options.overpower_attack_color = color


func _on_overpower_shake_intensity_value_changed(value: float) -> void:
	data.options.overpower_shake_screen_intensity = value


func _on_preload_scene_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var items_to_removed = []
	for index in range(indexes.size() - 1, -1, -1):
		data.preload_scenes.remove_at(index)
	
	if data.preload_scenes.size() > indexes[0]:
		fill_preload_scenes(indexes[0])
	else:
		fill_preload_scenes()


func _on_preload_scene_list_item_activated(index: int = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_simple_scene_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.selected.connect(_on_scene_selected)
	
	var default_scene_path = "" if index >= data.preload_scenes.size() else data.preload_scenes[index]
	dialog.setup(index, default_scene_path)


func _on_scene_selected(index: int, path: String) -> void:
	var selected_index
	if index == -1 or data.preload_scenes.size() <= index:
		data.preload_scenes.append(path)
		selected_index = data.preload_scenes.size() - 1
	else:
		data.preload_scenes[index] = path
		selected_index = index
				
	fill_preload_scenes(selected_index)


func _on_user_signal_list_delete_pressed(indexes: PackedInt32Array) -> void:
	pass # Replace with function body.


func _on_user_signal_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = TranslationManager.tr("Signal Name")
	dialog.text_selected.connect(_create_new_signal.bind(index))
	if data.custom_signal_list.size() > index:
		dialog.set_text(data.custom_signal_list[index])


func _create_new_signal(signal_name: String, index: int) -> void:
	if data.custom_signal_list.size() > index:
		data.custom_signal_list[index] = signal_name
	else:
		data.custom_signal_list.append(signal_name)
	fill_signal_list(index)


func _on_day_hours_value_changed(value: float) -> void:
	if busy: return
	var seconds = %DayHours.value * 3600 + %DayMinutes.value * 60 + %DaySeconds.value
	data.day_night_config.day_duration_seconds = seconds


func _on_day_minutes_value_changed(value: float) -> void:
	if busy: return
	var seconds = %DayHours.value * 3600 + %DayMinutes.value * 60 + %DaySeconds.value
	data.day_night_config.day_duration_seconds = seconds


func _on_day_seconds_value_changed(value: float) -> void:
	if busy: return
	var seconds = %DayHours.value * 3600 + %DayMinutes.value * 60 + %DaySeconds.value
	data.day_night_config.day_duration_seconds = seconds


func _on_starting_hour_value_changed(value: float) -> void:
	data.day_night_config.start_time = value


func _on_dawn_color_color_changed(color: Color) -> void:
	data.day_night_config.dawn_color = color


func _on_day_color_color_changed(color: Color) -> void:
	data.day_night_config.day_color = color


func _on_dusk_color_color_changed(color: Color) -> void:
	data.day_night_config.dusk_color = color


func _on_night_color_color_changed(color: Color) -> void:
	data.day_night_config.night_color = color


func _on_day_volume_value_changed(value: float) -> void:
	data.day_night_config.day_audio_volume = value


func _on_night_volume_value_changed(value: float) -> void:
	data.day_night_config.night_audio_volume = value


func _on_audio_transition_speed_value_changed(value: float) -> void:
	data.day_night_config.audio_transition_speed = value


func _on_sun_max_angle_value_changed(value: float) -> void:
	data.day_night_config.sun_max_angle = value


func _on_sun_rotation_speed_value_changed(value: float) -> void:
	data.day_night_config.sun_rotation_speed = value


func _on_sun_day_shadow_strength_value_changed(value: float) -> void:
	data.day_night_config.shadow_day_strength = value


func _on_sun_night_shadow_strength_value_changed(value: float) -> void:
	data.day_night_config.shadow_night_strength = value


func _on_shadow_elongation_x_value_changed(value: float) -> void:
	data.day_night_config.shadow_base_elongation.x = value


func _on_shadow_elongation_y_value_changed(value: float) -> void:
	data.day_night_config.shadow_base_elongation.y = value


func _on_shadow_skew_value_changed(value: float) -> void:
	data.day_night_config.shadow_base_skew = value


func _on_shadow_length_x_value_changed(value: float) -> void:
	data.day_night_config.shadow_max_length = value


func _on_shadow_length_y_value_changed(value: float) -> void:
	data.day_night_config.shadow_min_length = value


func _on_switch_id_pressed() -> void:
	var switch_id = data.day_night_config.switch_id
	select_switch(1, "switch_id", switch_id, _on_switch_selected)


func _on_switch_selected(id: int, target: String) -> void:
	data.day_night_config[target] = id
	update_all_switchs()


func select_switch(data_type: int, target: String, id_selected: int, callable: Callable) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = data_type
	dialog.target = target
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(update_all_switchs)
	dialog.setup(id_selected)



func update_all_switchs() -> void:
	var switch_id = data.day_night_config.switch_id
	var switch_name = RPGSYSTEM.system.switches.get_item_name(switch_id)
	%SwitchId.text = tr("Switch") + " #" + str(switch_id) + ": " + switch_name


func _on_street_lights_on_hour_value_changed(value: float) -> void:
	data.day_night_config.street_lights_on_hour


func _on_street_lights_off_hour_value_changed(value: float) -> void:
	data.day_night_config.street_lights_off_hour


func _on_reset_day_night_pressed() -> void:
	data.day_night_config.clear()
	fill_day_night()


func _on_auto_show_popups_toggled(toggled_on: bool) -> void:
	data.options.auto_popup_on_pick_up_items = toggled_on


func _on_gold_icon_paste_requested(icon: String, region: Rect2) -> void:
	if not region:
		var data_icon = data.currency_info
		data_icon.icon = icon
		%GoldIcon.set_icon(data_icon.icon)


func _on_land_transport_custom_copy(_node: Control, clipboard_key: String) -> void:
	if data.land_transport:
		var clipboard = StaticEditorVars.CLIPBOARD
		clipboard[clipboard_key] = data.land_transport


func _on_land_transport_custom_paste(node: Control, clipboard_key: String) -> void:
	var clipboard = StaticEditorVars.CLIPBOARD
	var path = clipboard.get(clipboard_key, "")
	if not path.is_empty():
		data.land_transport = path
		%LandTransport.set_icon(data.land_transport)


func _on_sea_transport_custom_copy(n_ode: Control, clipboard_key: String) -> void:
	if data.sea_transport:
		var clipboard = StaticEditorVars.CLIPBOARD
		clipboard[clipboard_key] = data.sea_transport


func _on_sea_transport_custom_paste(node: Control, clipboard_key: String) -> void:
	var clipboard = StaticEditorVars.CLIPBOARD
	var path = clipboard.get(clipboard_key, "")
	if not path.is_empty():
		data.sea_transport = path
		%SeaTransport.set_icon(data.sea_transport)


func _on_air_transport_custom_copy(_node: Control, clipboard_key: String) -> void:
	if data.air_transport:
		var clipboard = StaticEditorVars.CLIPBOARD
		clipboard[clipboard_key] = data.air_transport


func _on_air_transport_custom_paste(node: Control, clipboard_key: String) -> void:
	var clipboard = StaticEditorVars.CLIPBOARD
	var path = clipboard.get(clipboard_key, "")
	if not path.is_empty():
		data.air_transport = path
		%AirTransport.set_icon(data.air_transport)


func _on_game_initial_chapter_text_changed(new_text: String) -> void:
	data.initial_chapter_name = new_text


func _on_game_scene_list_delete_pressed(indexes: PackedInt32Array) -> void:
	var items_to_removed = []
	for index in range(indexes.size() - 1, -1, -1):
		if index >= 0 and data.game_scenes.size() > index:
			var id = %GameSceneList.get_column(index)[0]
			data.game_scenes.erase(id)
	
	if data.game_scenes.size() > indexes[0]:
		fill_game_scenes(indexes[0])
	else:
		fill_game_scenes()


func _on_game_scene_list_item_activated(index: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_simple_scene_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.selected.connect(_on_game_scene_selected)
	
	var default_scene_path = ""
	if index >= 0 and data.game_scenes.size() > index:
		var id = %GameSceneList.get_column(index)[1]
		default_scene_path = id

	dialog.setup(index, default_scene_path)


func _on_game_scene_selected(index: int, path: String) -> void:
	var selected_index
	if index == -1 or data.game_scenes.size() <= index:
		return
	else:
		var id = %GameSceneList.get_column(index)[0]
		data.game_scenes[id] = path
		selected_index = index
				
	fill_game_scenes(selected_index)


func _on_pause_in_menu_toggled(value: bool) -> void:
	data.pause_day_night_in_menu = value


func _on_followers_enabled_toggled(value: bool) -> void:
	data.followers_enabled = value


func _on_shadow_color_color_changed(color: Color) -> void:
	data.day_night_config.shadow_color = color
