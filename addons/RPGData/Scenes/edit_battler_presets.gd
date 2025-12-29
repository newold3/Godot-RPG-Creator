@tool
class_name EditBattlerPresets
extends MarginContainer

@export var battler_positions_container: NodePath

enum ALIGN {LEFT, HORIZONTAL_CENTER, RIGHT, TOP, VERTICAL_CENTER, BOTTOM}


signal aligment_requested(align: ALIGN)


func _ready() -> void:
	_fill_presets()


func show_align_controls(value: bool = true) -> void:
	%AlignContainer.visible = value


func _fill_presets(selected_index1: int = 0, selected_index2: int = 0) -> void:
	if not FileCache.options.has("battler_position_presets"):
		FileCache.options.battler_position_presets = {
			"enemy_presets": [],
			"hero_presets": []
		}
		
		FileCache.options.battler_position_presets.hero_presets.append({
			"name": "Default",
			"data": {
				0: {"direction": 1, "position": Vector2(0.727157, 0.647638)},
				1: {"direction": 1, "position": Vector2(0.727157, 0.780091)},
				2: {"direction": 1, "position": Vector2(0.764279, 0.501619)},
				3: {"direction": 1, "position": Vector2(0.764279, 0.920553)},
				4: {"direction": 1, "position": Vector2(0.854446, 0.644456)},
				5: {"direction": 1, "position": Vector2(0.854446, 0.782847)},
				6: {"direction": 1, "position": Vector2(0.876681, 0.511619)},
				7: {"direction": 1, "position": Vector2(0.876681, 0.917289)}
			}
		})

		FileCache.options.battler_position_presets.enemy_presets.append({
			"name": "Default",
			"data": {
				0: {"direction": 2, "position": Vector2(0.274775, 0.401795)},
				1: {"direction": 2, "position": Vector2(0.265766, 0.587692)},
				2: {"direction": 2, "position": Vector2(0.245045, 0.77359)},
				3: {"direction": 2, "position": Vector2(0.16036, 0.414615)},
				4: {"direction": 2, "position": Vector2(0.151351, 0.600513)},
				5: {"direction": 2, "position": Vector2(0.130631, 0.78641)}
			}
		})
	
	var node1 = %EnemyPresets
	var node2 = %HeroPresets
	node1.clear()
	node2.clear()
	
	var preset_list = FileCache.options.battler_position_presets
	
	for preset in preset_list.enemy_presets:
		node1.add_item(preset.name)
	
	for preset in preset_list.hero_presets:
		node2.add_item(preset.name)
	
	if preset_list.enemy_presets.size() > selected_index1 and selected_index1 >= 0:
		node1.select(selected_index1)
		node1.item_selected.emit(selected_index1)
	if preset_list.hero_presets.size() > selected_index2 and selected_index2 >= 0:
		node2.select(selected_index2)
		node2.item_selected.emit(selected_index2)


func _get_preset_list() -> Dictionary:
	var preset_list = FileCache.options.get("battler_position_presets", null)
	return preset_list


func _open_set_preset_name_dialog(id: int) -> void: # id = 0 -> Hero, 1 = Enemy
	var path = "res://addons/CustomControls/Dialogs/select_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.title = "Set Preset name"
	dialog.text_selected.connect(
		func(preset_name: String):
			var preset_list = _get_preset_list()
			if preset_list:
				var preset_data = {"name": preset_name, "data": {}}
				var battler_main_node = get_node_or_null(battler_positions_container)
				if battler_main_node and battler_main_node.has_method("get_battler_container"):
					var container = battler_main_node.get_battler_container()
					var battlers = container.get_children()
					var index = 0
					for battler: BattlerPositionScene in battlers:
						if battler.current_member and battler.current_member.type == id:
							preset_data.data[index] = {}
							preset_data.data[index].direction = battler.current_member.direction
							preset_data.data[index].position = battler.current_member.position
							index += 1
				if not preset_data.data.is_empty():
					var selected_index: int = 0
					if id == 0:
						var existing_preset = preset_list.hero_presets.find_custom(
							func(p):
								return p.name == preset_data.name
						)
						if existing_preset != -1:
							preset_list.hero_presets[existing_preset].data = preset_data.data
							selected_index = existing_preset
						else:
							preset_list.hero_presets.append(preset_data)
							selected_index = preset_list.hero_presets.size() - 1
						_fill_presets(%EnemyPresets.get_selected_id(), selected_index)
					else:
						var existing_preset = preset_list.enemy_presets.find_custom(
							func(p):
								return p.name == preset_data.name
						)
						if existing_preset != -1:
							preset_list.enemy_presets[existing_preset].data = preset_data.data
							selected_index = existing_preset
						else:
							preset_list.enemy_presets.append(preset_data)
							selected_index = preset_list.enemy_presets.size() - 1
						_fill_presets(selected_index, %HeroPresets.get_selected_id())
	)


func _on_enemy_presets_item_selected(index: int) -> void:
	%RemoveEnemyPreset.set_disabled(index == 0) 


func _on_apply_enemy_preset_pressed() -> void:
	var preset_list = _get_preset_list()
	if preset_list:
		var id = %EnemyPresets.get_selected_id()
		if preset_list.enemy_presets.size() > id:
			var preset_data = preset_list.enemy_presets[id].data
		
			var i = 0
			var battler_main_node = get_node_or_null(battler_positions_container)
			if battler_main_node and battler_main_node.has_method("get_battler_container"):
				var container = battler_main_node.get_battler_container()
				for child in container.get_children():
					var member: RPGTroopMember = child.current_member
					if member.type == 1:
						member.position = preset_data[i].position
						member.direction = preset_data[i].direction
						child.set_position_and_direction_from_data()
						i += 1
						if i >= preset_data.size(): break


func _on_remove_enemy_preset_pressed() -> void:
	var id = %EnemyPresets.get_selected_id()
	var preset_list = _get_preset_list()
	if id > 0 and preset_list.enemy_presets.size() > id:
		preset_list.enemy_presets.remove_at(id)
		id = max(0, min(id, preset_list.enemy_presets.size() - 1))
		_fill_presets(id, %HeroPresets.get_selected_id())


func _on_save_enemy_preset_pressed() -> void:
	_open_set_preset_name_dialog(1)


func _on_hero_presets_item_selected(index: int) -> void:
	%RemoveHeroPreset.set_disabled(index == 0) 


func _on_apply_hero_preset_pressed() -> void:
	var preset_list = _get_preset_list()
	if preset_list:
		var id = %EnemyPresets.get_selected_id()
		if preset_list.hero_presets.size() > id:
			var preset_data = preset_list.hero_presets[id].data
			var i = 0
			var battler_main_node = get_node_or_null(battler_positions_container)
			if battler_main_node and battler_main_node.has_method("get_battler_container"):
				var container = battler_main_node.get_battler_container()
				for child in container.get_children():
					var member: RPGTroopMember = child.current_member
					if member.type == 0:
						member.position = preset_data[i].position
						member.direction = preset_data[i].direction
						child.set_position_and_direction_from_data()
						i += 1
						if i >= preset_data.size(): break


func _on_remove_hero_preset_pressed() -> void:
	var id = %HeroPresets.get_selected_id()
	var preset_list = _get_preset_list()
	if id > 0 and preset_list.hero_presets.size() > id:
		preset_list.hero_presets.remove_at(id)
		id = max(0, min(id, preset_list.hero_presets.size() - 1))
		_fill_presets(%EnemyPresets.get_selected_id(), id)


func _on_save_hero_preset_pressed() -> void:
	_open_set_preset_name_dialog(0)


func _on_vertical_aligment_left_pressed() -> void:
	aligment_requested.emit(ALIGN.LEFT)


func _on_vertical_aligment_center_pressed() -> void:
	aligment_requested.emit(ALIGN.HORIZONTAL_CENTER)


func _on_vertical_aligment_right_pressed() -> void:
	aligment_requested.emit(ALIGN.RIGHT)


func _on_horizontal_aligment_left_pressed() -> void:
	aligment_requested.emit(ALIGN.TOP)


func _on_horizontal_aligment_center_pressed() -> void:
	aligment_requested.emit(ALIGN.VERTICAL_CENTER)


func _on_horizontal_aligment_right_pressed() -> void:
	aligment_requested.emit(ALIGN.BOTTOM)
