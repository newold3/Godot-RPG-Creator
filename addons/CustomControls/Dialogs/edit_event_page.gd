@tool
extends MarginContainer

var system
var current_page: RPGEventPage
var current_event: RPGEvent
var current_event_list: Array

var busy: bool = false

var last_item_type_selected: int

signal changed()


func _ready() -> void:
	%CharacterImage.custom_copy_and_paste_enabled = true
	%CharacterImage.clipboard_key = "event_graphic"
	var parent = get_parent().get_parent().get_parent()
	%EventPageListEditor.set_current_parent(parent)


func _fill_events(p_current_event: RPGEvent, event_list: Array, selected_id: int) -> void:
	var node = %SelectTargetEvent
	node.clear()
	
	current_event = p_current_event
	
	if event_list.is_empty():
		node.add_item("none")
		node.set_item_disabled(-1, true)
	elif event_list.size() == 1:
		node.add_item("Event %s: %s" % [current_event.id, current_event.name])
		node.set_item_disabled(-1, true)
	else:
		for ev: RPGEvent in event_list:
			node.add_item("Event %s: %s" % [ev.id, ev.name])
			node.set_item_disabled(-1, ev.id == current_event.id)
	
	if selected_id >= 0 and event_list.size() > selected_id:
		node.select(selected_id)
	else:
		node.select(0)
	
	current_event_list = event_list


func fill_local_switches() -> void:
	var node = %Condition3Value
	node.clear()
	
	if system:
		for key in system.self_switches.get_switch_names():
			node.add_item("Switch %s" % key.to_upper())


func fill_page(page: RPGEventPage) -> void:
	if page:
		fill_local_switches()
		current_page = page
		%Condition1Pressed.set_pressed(current_page.condition.use_switch1)
		%Condition2Pressed.set_pressed(current_page.condition.use_switch2)
		%Condition3Pressed.set_pressed(current_page.condition.use_local_switch)
		%Condition4Pressed.set_pressed(current_page.condition.use_variable)
		%Condition5Pressed.set_pressed(current_page.condition.use_item)
		%Condition6Pressed.set_pressed(current_page.condition.use_actor)
		%EventOption1.set_pressed(current_page.options.walking_animation)
		%EventOption2.set_pressed(current_page.options.idle_animation)
		%EventOption3.set_pressed(current_page.options.fixed_direction)
		%EventOption4.set_pressed(current_page.options.passable)
		%Condition1Pressed.toggled.emit(current_page.condition.use_switch1)
		%Condition2Pressed.toggled.emit(current_page.condition.use_switch2)
		%Condition3Pressed.toggled.emit(current_page.condition.use_local_switch)
		%Condition4Pressed.toggled.emit(current_page.condition.use_variable)
		%Condition5Pressed.toggled.emit(current_page.condition.use_item)
		%Condition6Pressed.toggled.emit(current_page.condition.use_actor)
		%EventOption1.toggled.emit(current_page.options.walking_animation)
		%EventOption2.toggled.emit(current_page.options.idle_animation)
		%EventOption3.toggled.emit(current_page.options.fixed_direction)
		%EventOption4.toggled.emit(current_page.options.passable)
		
		%PageName.text = current_page.name
		%MarkAsQuestPage.set_pressed_no_signal(current_page.is_quest_page)
		
		if current_page.character_path in FileCache.cache.events:
			var res: RPGLPCCharacter = load(current_page.character_path)
			%CharacterImage.set_icon(res.event_preview)
		else:
			%CharacterImage.set_icon("")
		var local_switch_id = max(0, min(%Condition3Value.get_item_count() - 1, current_page.condition.local_switch_id))
		current_page.condition.local_switch_id = local_switch_id 
		%Condition3Value.select(local_switch_id)
		var variable_operator = max(0, min(%Condition4Value2.get_item_count() - 1, current_page.condition.variable_operator))
		current_page.condition.variable_operator = variable_operator 
		%Condition4Value2.select(variable_operator)
		%Condition4Value3.value = current_page.condition.variable_value
		var launcher = max(0, min(%Launcher.get_item_count() - 1, current_page.launcher))
		current_page.launcher = launcher
		%Launcher.select(launcher)
		%TriggerEventList.visible = (launcher == 2)
		%ZIndex.set_value(current_page.z_index)
		var movement_type = max(0, min(%MovementType.get_item_count() - 1, current_page.movement_type))
		current_page.movement_type = movement_type
		%MovementType.select(movement_type)
		%MovementType.item_selected.emit(current_page.movement_type)
		%MovementRouteButton.set_disabled(current_page.movement_type != 4)
		%Velocity.set_value(current_page.speed)
		%Frequency.set_value(current_page.frequency)
		%EventPageListEditor.set_data(current_page.list)
		%EventPageListEditor.set_visible(false)
		await get_tree().process_frame
		%EventPageListEditor.set_visible(true)
		%Direction.select(
			0 if current_page.direction == LPCCharacter.DIRECTIONS.LEFT else
			1 if current_page.direction == LPCCharacter.DIRECTIONS.RIGHT else
			2 if current_page.direction == LPCCharacter.DIRECTIONS.UP else
			3
		)
		
		%Modulate.set_color(current_page.modulate)
		%CharacterImage.set_blend_color(current_page.modulate)
		var window: Window = get_window()
		if window and window is EditEventEditor:
			var movement_to_target = current_page.movement_to_target - 1
			_fill_events(window.current_event, window.events.get_events(), movement_to_target)
		else:
			_fill_events(null, [], -1)
		
		%MovementRouteButton.visible = movement_type == 4
		%SelectTargetEvent.visible = movement_type == 5
		
		#if (
			#current_page.launcher == current_page.LAUNCHER_MODE.UNDER_PLAYER or
			#current_page.launcher == current_page.LAUNCHER_MODE.UNDER_EVENT or
			#current_page.launcher == current_page.LAUNCHER_MODE.ANY_CONTACT or
			#current_page.launcher == current_page.LAUNCHER_MODE.CALLER
		#):
			#%EventOption4.set_disabled(true)
		#else:
			#%EventOption4.set_disabled(false)


func _on_condition_1_pressed_toggled(toggled_on: bool) -> void:
	%Condition1Value.set_disabled(!toggled_on)
	if current_page:
		current_page.condition.use_switch1 = toggled_on
		if toggled_on:
			if system:
				var switch_name = "%s:%s" % [
					str(current_page.condition.switch1_id).pad_zeros(4),
					system.switches.get_item_name(current_page.condition.switch1_id)
				]
				%Condition1Value.text = switch_name
			else:
				%Condition1Value.text = str(current_page.condition.switch1_id).pad_zeros(4) + ":"
		else:
			%Condition1Value.text = ""
	
	changed.emit()


func _on_condition_2_pressed_toggled(toggled_on: bool) -> void:
	%Condition2Value.set_disabled(!toggled_on)
	if current_page:
		current_page.condition.use_switch2 = toggled_on
		if toggled_on:
			if system:
				var switch_name = "%s:%s" % [
					str(current_page.condition.switch2_id).pad_zeros(4),
					system.switches.get_item_name(current_page.condition.switch2_id)
				]
				%Condition2Value.text = switch_name
			else:
				%Condition2Value.text = str(current_page.condition.switch2_id).pad_zeros(4) + ":"
		else:
			%Condition2Value.text = ""
	
	changed.emit()


func _on_condition_3_pressed_toggled(toggled_on: bool) -> void:
	%Condition3Value.set_disabled(!toggled_on)
	if current_page:
		current_page.condition.use_local_switch = toggled_on
	changed.emit()


func _on_condition_4_pressed_toggled(toggled_on: bool) -> void:
	%Condition4Value1.set_disabled(!toggled_on)
	%Condition4Value2.set_disabled(!toggled_on)
	%Condition4Value3.set_disabled(!toggled_on)
	if current_page:
		current_page.condition.use_variable = toggled_on
		if toggled_on:
			if system:
				var variable_name = "%s:%s" % [
					str(current_page.condition.variable_id).pad_zeros(4),
					system.variables.get_item_name(current_page.condition.variable_id)
				]
				%Condition4Value1.text = variable_name
			else:
				%Condition4Value1.text = str(current_page.condition.variable_id).pad_zeros(4) + ":"
		else:
			%Condition4Value1.text = ""
	
	changed.emit()


func _on_condition_5_pressed_toggled(toggled_on: bool) -> void:
	%Condition5Value1.set_disabled(!toggled_on)
	%Condition5Value2.set_disabled(!toggled_on)
	if current_page:
		current_page.condition.use_item = toggled_on
		if %Condition5Value2.get_item_count() > current_page.condition.item_type:
			%Condition5Value2.select(current_page.condition.item_type)
		else:
			%Condition5Value2.select(0)
		update_item_selected_name()
	
	changed.emit()


func update_item_selected_name() -> void:
	if current_page:
		var data = RPGSYSTEM.database.items if current_page.condition.item_type == 0 \
			else RPGSYSTEM.database.weapons if current_page.condition.item_type == 1 \
			else RPGSYSTEM.database.armors if current_page.condition.item_type == 2 \
			else null
		
		if data and data.size() > current_page.condition.item_id:
			var item = data[current_page.condition.item_id]
			var text: String
			if item:
				text = "%s: %s" % [str(item.id).pad_zeros(str(data.size()).length()), item.name]
			else:
				item = data[1]
				text = "%s: %s" % [str(item.id).pad_zeros(str(data.size()).length()), item.name]
			
			%Condition5Value1.text = text


func update_actor_selected_name() -> void:
	var data = RPGSYSTEM.database.actors
	
	if data and data.size() > current_page.condition.actor_id:
		var item = data[current_page.condition.actor_id]
		var text: String
		if item:
			text = "%s: %s" % [str(item.id).pad_zeros(str(data.size()).length()), item.name]
		else:
			item = data[1]
			text = "%s: %s" % [str(item.id).pad_zeros(str(data.size()).length()), item.name]
		
		%Condition6Value.text = text


func _on_condition_6_pressed_toggled(toggled_on: bool) -> void:
	%Condition6Value.set_disabled(!toggled_on)
	if current_page:
		update_actor_selected_name()
	
	changed.emit()


func _on_launcher_item_selected(index: int) -> void:
	if current_page:
		current_page.launcher = index
	
	#if (
		#current_page.launcher == current_page.LAUNCHER_MODE.UNDER_PLAYER or
		#current_page.launcher == current_page.LAUNCHER_MODE.UNDER_EVENT or
		#current_page.launcher == current_page.LAUNCHER_MODE.ANY_CONTACT or
		#current_page.launcher == current_page.LAUNCHER_MODE.CALLER
	#):
		#%EventOption4.set_disabled(true)
	#else:
		#%EventOption4.set_disabled(false)
	
	%TriggerEventList.visible = (index == 2)
	
	changed.emit()


func _on_z_index_value_changed(value: float) -> void:
	if current_page:
		current_page.z_index = value
	
	changed.emit()


func _on_movement_type_item_selected(index: int) -> void:
	if current_page:
		current_page.movement_type = index
		%MovementRouteButton.set_disabled(index != 4)
		%MovementRouteButton.visible = index == 4
		%SelectTargetEvent.visible = index == 5
	
	changed.emit()


func _on_velocity_value_changed(value: float) -> void:
	if current_page:
		current_page.speed = value
	
	changed.emit()


func update_all() -> void:
	if current_page:
		fill_page(current_page)


func select_variable_or_switch(data_type: int, target: String, id_selected: int, callable: Callable) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = data_type
	dialog.target = target
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(update_all)
	dialog.setup(id_selected)


func _on_condition_1_value_pressed() -> void:
	select_variable_or_switch(1, "switch1_id", current_page.condition.switch1_id, change_condition_value)


func _on_condition_2_value_pressed() -> void:
	select_variable_or_switch(1, "switch2_id", current_page.condition.switch2_id, change_condition_value)


func _on_condition_4_value_1_pressed() -> void:
	select_variable_or_switch(0, "variable_id",current_page.condition.variable_id,  change_condition_value)


func change_condition_value(id: int, target: String) -> void:
	mouse_default_cursor_shape
	if current_page:
		var text: String = ""
		current_page.condition.set(target, id)
		if system:
			var real_data = system.variables if target == "variable_id" else system.switches
			var data_name = "%s:%s" % [
				str(id).pad_zeros(4),
				real_data.get_item_name(id)
			]
			text = data_name
		else:
			text = str(id).pad_zeros(4) + ":"
		
		var node
		match target:
			"switch1_id":
				%Condition1Value.text = text
			"switch2_id":
				%Condition2Value.text = text
			"variable_id":
				%Condition4Value1.text = text
		
		changed.emit()


func _on_condition_5_value1_pressed() -> void:
	var target = %Condition5Value2.get_selected_id()
	var id_selected = 1 if current_page.condition.item_type != target else current_page.condition.item_id
	last_item_type_selected = id_selected
	if target == 0:
		if RPGSYSTEM.database.items.size() < id_selected:
			id_selected = 0
		_open_select_any_data_dialog(RPGSYSTEM.database.items, id_selected, "Item", 0)
	elif target == 1:
		if RPGSYSTEM.database.weapons.size() < id_selected:
			id_selected = 0
		_open_select_any_data_dialog(RPGSYSTEM.database.weapons, id_selected, "Weapon", 1)
	elif target == 2:
		if RPGSYSTEM.database.armors.size() < id_selected:
			id_selected = 0
		_open_select_any_data_dialog(RPGSYSTEM.database.armors, id_selected, "Armor", 2)


func _on_condition_6_value_pressed() -> void:
	var id_selected = 1 if current_page.condition.item_type != 3 else current_page.condition.item_id
	_open_select_any_data_dialog(RPGSYSTEM.database.actors, id_selected, "Actor", 3)


func _open_select_any_data_dialog(current_data, id_selected: int, title: String, target: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = RPGSYSTEM.database
	
	dialog.destroy_on_hide = true
	dialog.selected.connect(_on_any_data_selected, CONNECT_ONE_SHOT)
	
	dialog.setup(current_data, id_selected, title, target)


func _on_any_data_selected(id: int, target: int)  -> void:
	if target == 3:
		current_page.condition.actor_id = id
		update_actor_selected_name()
	else:
		current_page.condition.item_id = id
		current_page.condition.item_type = target
		%Condition5Value2.select(target)
		update_item_selected_name()
	
	changed.emit()


func _on_condition_5_value_2_item_selected(index: int) -> void:
	_on_condition_5_value1_pressed()
	%Condition5Value2.select(current_page.condition.item_type)


func _on_condition_3_value_item_selected(index: int) -> void:
	current_page.condition.local_switch_id = index
	changed.emit()


func _on_condition_4_value_2_item_selected(index: int) -> void:
	current_page.condition.variable_operator = index
	changed.emit()


func _on_condition_4_value_3_value_changed(value: float) -> void:
	current_page.condition.variable_value = value
	changed.emit()


func _on_event_option_1_toggled(toggled_on: bool) -> void:
	current_page.options.walking_animation = toggled_on
	changed.emit()


func _on_event_option_2_toggled(toggled_on: bool) -> void:
	current_page.options.idle_animation = toggled_on
	changed.emit()


func _on_event_option_3_toggled(toggled_on: bool) -> void:
	current_page.options.fixed_direction = toggled_on
	changed.emit()


func _on_event_option_4_toggled(toggled_on: bool) -> void:
	current_page.options.passable = toggled_on
	changed.emit()


func _on_movement_route_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/CommandEvents/movement_route_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_current_page(current_page)
	dialog.current_event = current_event
	dialog.disable_await()
	dialog.apply.connect(
		func(route: RPGMovementRoute):
			current_page.movement_route = route
			changed.emit()
	)


func _on_character_image_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _update_character_image
	dialog.set_file_selected(current_page.character_path)
	dialog.set_dialog_mode(0)
	
	dialog.fill_mix_files(["events"])


func _update_character_image(path: String) -> void:
	if path in FileCache.cache.events:
		current_page.character_path = path
		var res: RPGLPCCharacter = load(path)
		%CharacterImage.set_icon(res.event_preview)
		changed.emit()


func _on_character_image_remove_requested() -> void:
	current_page.character_path = ""
	%CharacterImage.set_icon("")
	changed.emit()


func _on_event_page_list_editor_data_changed() -> void:
	changed.emit()


func _on_direction_item_selected(index: int) -> void:
	current_page.direction = \
		LPCCharacter.DIRECTIONS.LEFT if index == 0 \
		else LPCCharacter.DIRECTIONS.RIGHT if index == 1 \
		else LPCCharacter.DIRECTIONS.UP if index == 2 \
		else LPCCharacter.DIRECTIONS.DOWN
		
	changed.emit()


func _on_modulate_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Sprite Modulation Color")
	dialog.color_selected.connect(_on_color_selected)
	dialog.preview_color.connect(_update_blend_color_preview)
	var current_color = current_page.modulate
	dialog.tree_exited.connect(
		func():
			if current_page.modulate == current_color:
				_on_color_selected(current_color)
	)
	dialog.set_color(%Modulate.get_color())


func _on_color_selected(color: Color) -> void:
	%Modulate.set_color(color)
	%CharacterImage.set_blend_color(color)
	current_page.modulate = color


func _update_blend_color_preview(color: Color):
	%CharacterImage.set_blend_color(color)


func _on_modulate_middle_clicked() -> void:
	_on_color_selected(Color.WHITE)


func _on_frequency_value_changed(value: float) -> void:
	current_page.frequency = max(1, int(value))


func _on_select_target_event_item_selected(index: int) -> void:
	if current_page:
		current_page.movement_to_target = index + 1


func _on_trigger_event_list_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_in_game_events_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var items = []
	for ev: RPGEvent in current_event_list:
		items.append({"name": ev.name, "id": ev.id})
	
	dialog.fill_events(items, current_event.id)
	dialog.select_events(current_page.event_trigger_list)
	
	dialog.events_selected.connect(
		func(list: PackedInt32Array):
			current_page.event_trigger_list = list
	)


func _on_page_name_text_changed(new_text: String) -> void:
	if current_page:
		current_page.name = new_text


func _on_mark_as_quest_page_toggled(toggled_on: bool) -> void:
	if current_page:
		current_page.is_quest_page = toggled_on
	


func _on_character_image_custom_copy(node: Control, clipboard_key: String) -> void:
	if not current_page.character_path.is_empty():
		var clipboard = StaticEditorVars.CLIPBOARD
		clipboard[clipboard_key] = current_page.character_path


func _on_character_image_custom_paste(node: Control, clipboard_key: String) -> void:
	var clipboard = StaticEditorVars.CLIPBOARD
	if clipboard_key in clipboard:
		_update_character_image(clipboard[clipboard_key])
