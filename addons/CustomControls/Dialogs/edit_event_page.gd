@tool
extends MarginContainer

var system
var current_page: RPGEventPage
var current_event: RPGEvent
var current_event_list: Array

var path_cache: Dictionary = {
	"lpc_event": "",
	"image": "",
	"scene": ""
}

var busy: bool = false

var last_item_type_selected: int

signal changed()


func _ready() -> void:
	%CharacterImage.custom_copy_and_paste_enabled = true
	%CharacterImage.clipboard_key = "event_graphic"
	var parent = get_parent().get_parent().get_parent()
	%EventPageListEditor.set_current_parent(parent)
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(self)


func _fill_events(p_current_event: RPGEvent, event_list: Array, selected_id: int) -> void:
	var node = %SelectTargetEvent
	node.clear()
	
	current_event = p_current_event
	
	if event_list.is_empty():
		node.add_item("none")
		node.set_item_disabled(-1, true)
		node.set_item_metadata(-1, -1)
		selected_id = 0
	elif event_list.size() == 1:
		node.add_item("Event %s: %s" % [current_event.id, current_event.name])
		node.set_item_disabled(-1, true)
		node.set_item_metadata(-1, current_event._uniq_id)
		selected_id = 0
	else:
		for i in event_list.size():
			var ev: RPGEvent = event_list[i]
			node.add_item("Event %s: %s" % [ev.id, ev.name])
			node.set_item_disabled(-1, ev.id == current_event.id)
			node.set_item_metadata(-1, ev._uniq_id)
			if selected_id == ev._uniq_id: selected_id = i

	if selected_id >= 0 and event_list.size() > selected_id:
		node.select(selected_id)
	else:
		node.select(0)
	
	current_event_list = event_list


## Fills the local pressure targets list and updates its tooltip with human-readable names.
func _fill_pressure_targets(p_current_event: RPGEvent, event_list: Array, selected_ids: PackedInt64Array) -> void:
	var node = %AllowPressureTargets
	node.clear()

	node.add_item("player")
	node.set_item_metadata(-1, 0)
	var has_player = false
	if 0 in selected_ids:
		node.set_item_selected(0, true)
		has_player = true
	
	for i in event_list.size():
		var event: RPGEvent = event_list[i]
		if event == p_current_event: continue
		
		node.add_item("Event %s: %s" % [event.id, event.name])
		node.set_item_metadata(-1, event._uniq_id)
		if event._uniq_id in selected_ids:
			node.set_item_selected(node.get_item_count() - 1, true)
			
	var arr_ids: Array = []
	if has_player: arr_ids.append("0: Player")
	
	for ev: RPGEvent in event_list:
		if ev._uniq_id in selected_ids and ev != p_current_event:
			arr_ids.append("%s: %s" % [ev.id, ev.name])
			
	_append_ids_to_tooltip(node, arr_ids, 0)


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
		if current_page.event_tool_list == null: current_page.event_tool_list = []
		if current_page.event_signal_list == null: current_page.event_signal_list = []
		if current_page.character_type == null: current_page.character_type = 0
		
		path_cache = {
			"lpc_event": "",
			"image": "",
			"scene": ""
		}
		
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
		
		%AllowExternalEventsTrigger.set_pressed_no_signal(current_page.allow_external_events_triggers)
		%AllowExternalPressureEvents.set_pressed_no_signal(current_page.allow_external_pressure_events)
		
		%PageName.text = current_page.name
		%MarkAsQuestPage.set_pressed_no_signal(current_page.is_quest_page)
		
		_update_graphic()
			
		var local_switch_id = max(0, min(%Condition3Value.get_item_count() - 1, current_page.condition.local_switch_id))
		current_page.condition.local_switch_id = local_switch_id 
		%Condition3Value.select(local_switch_id)
		var variable_operator = max(0, min(%Condition4Value2.get_item_count() - 1, current_page.condition.variable_operator))
		current_page.condition.variable_operator = variable_operator 
		%Condition4Value2.select(variable_operator)
		%Condition4Value3.value = current_page.condition.variable_value
		var launcher = max(0, min(%Launcher.get_item_count() - 1, current_page.launcher))
		current_page.launcher = launcher
	
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
			var movement_to_target = current_page.movement_to_target
			var evs = window.events.get_events() if window.events else []
			_fill_events(window.current_event, evs, movement_to_target)
			_fill_pressure_targets(window.current_event, evs, current_page.condition.pressure_targets)
		else:
			_fill_events(null, [], -1)
			_fill_pressure_targets(null, [], [])
		
		%Condition7Pressed.set_pressed_no_signal(current_page.condition.use_pressure)
		_update_pressure_targets_visibility()
		
		_set_pressed_mode(current_page.condition.use_pressure)
		
		%MovementRouteButton.visible = movement_type == 4
		%SelectTargetEvent.visible = movement_type == 5
		
		%Launcher.select(launcher)
		%TriggerEventContainer.visible = launcher in [2, 7, 8]
		%PlaceHolderLauncher.visible = !%TriggerEventContainer.visible
		_configure_launcher()
		%Launcher.item_selected.emit(launcher)
		
		%PageExtraOptions._update_extra_config_label(current_page)


func _update_graphic() -> void:
	%DataTypeSelected.select(current_page.character_type)

	%CharacterImage.set_icon("")
	
	match current_page.character_type:
		0:
			path_cache.lpc_event = current_page.character_path
			if current_page.character_path in FileCache.cache.events:
				var res: RPGLPCCharacter = load(current_page.character_path)
				%CharacterImage.set_icon(res.event_preview)
		1:
			path_cache.image = current_page.character_path
			%CharacterImage.set_icon(current_page.character_path, current_page.character_region)
		2:
			path_cache.scene = current_page.character_path
			_set_icon_from_scene(current_page.character_path)


func _set_icon_from_scene(path: String) -> void:
	var preview_path = path.get_basename() + "_preview.png"
	if FileAccess.file_exists(preview_path):
		%CharacterImage.set_icon(preview_path)
	else:
		var event_editor = get_tree().get_nodes_in_group("event_editor")
		if event_editor:
			event_editor = event_editor[0]
			event_editor.resource_previewer.queue_resource_preview(path, self, "_update_image", true)


func _update_image(_path: String, preview: Texture, thumbnail_preview, using_counter: bool = false) -> void:
	if preview is Texture:
		%CharacterImage.set_main_texture(preview, Rect2())
	elif thumbnail_preview:
		%CharacterImage.set_main_texture(thumbnail_preview, Rect2())


func _fill_trigger_list() -> void:
	var node = %TriggerEventList
	
	if not current_page:
		node.text = ""
		node.set_disabled(true)
		return
		
	var tooltip_ids: Array = []
	var format_type: int = 0
	
	match current_page.launcher:
		2:
			if current_page.allow_external_events_triggers:
				format_type = 2
				var total_events = 0
				for map_id in current_page.external_event_triggers:
					var ext_ids = current_page.external_event_triggers[map_id]
					total_events += ext_ids.size()
					if not ext_ids.is_empty():
						tooltip_ids.append({"map_id": map_id, "event_ids": ext_ids})
				
				node.text = "External Events: %s" % total_events
			else:
				format_type = 1
				node.text = "Select Events"
				var events = current_event_list
				var text = "Event"
				var valid_events: PackedStringArray = []
				
				for ev: RPGEvent in events:
					if ev._uniq_id in current_page.event_trigger_list:
						valid_events.append("%s: %s" % [ev.id, ev.name])
						tooltip_ids.append(ev._uniq_id)
						
				if not valid_events.is_empty():
					for i in valid_events.size():
						if i == 0:
							if valid_events.size() == 1:
								text += ": " + valid_events[i]
							else:
								text += "s: " + valid_events[i]
						else:
							text += ", " + valid_events[i]
					node.text = text
		7:
			format_type = 3
			node.text = "Select Tools"
			var list = RPGSYSTEM.database.types.tool_types
			var text = "Tool"
			var valid_events: PackedStringArray = []
			
			for i in list.size():
				if i in current_page.event_tool_list:
					valid_events.append("%s: %s" % [i + 1, list[i]])
					tooltip_ids.append(i + 1)
					
			if not valid_events.is_empty():
				for i in valid_events.size():
					if i == 0:
						if valid_events.size() == 1:
							text += ": " + valid_events[i]
						else:
							text += "s: " + valid_events[i]
					else:
						text += ", " + valid_events[i]
				node.text = text
		8:
			format_type = 4
			node.text = "Select Signals"
			var list = RPGSYSTEM.database.system.custom_signal_list
			var text = "Signal"
			var valid_events: PackedStringArray = []
			
			for i in list.size():
				if i in current_page.event_signal_list:
					valid_events.append("%s: %s" % [i + 1, list[i]])
					tooltip_ids.append(i + 1)
					
			if not valid_events.is_empty():
				for i in valid_events.size():
					if i == 0:
						if valid_events.size() == 1:
							text += ": " + valid_events[i]
						else:
							text += "s: " + valid_events[i]
					else:
						text += ", " + valid_events[i]
				node.text = text
				
	_append_ids_to_tooltip(node, tooltip_ids, format_type)


func _configure_launcher() -> void:
	var node = %TriggerEventList
	node.set_disabled(!node.visible)
	
	var _is_valid: bool = false
	
	if node.pressed.is_connected(_on_trigger_event_list_pressed):
		node.pressed.disconnect(_on_trigger_event_list_pressed)
	
	if node.pressed.is_connected(_on_trigger_tool_list_pressed):
		node.pressed.disconnect(_on_trigger_tool_list_pressed)
	
	if node.pressed.is_connected(_on_trigger_signal_list_pressed):
		node.pressed.disconnect(_on_trigger_signal_list_pressed)
	
	match current_page.launcher:
		2:
			node.text = ""
			node.tooltip_text = "[title]Trigger Event List[/title]\nSelect the events that can trigger this event."
			_is_valid = true
			node.pressed.connect(_on_trigger_event_list_pressed)
		7:
			node.text = ""
			node.tooltip_text = "[title]Trigger Tool List[/title]\nSelect the tools that can trigger this event."
			_is_valid = true
			node.pressed.connect(_on_trigger_tool_list_pressed)
		8:
			node.text = ""
			node.tooltip_text = "[title]Trigger Signal List[/title]\nSelect the signals that can trigger this event."
			_is_valid = true
			node.pressed.connect(_on_trigger_signal_list_pressed)
	
	if _is_valid:
		if node.has_meta("base_tooltip"):
			node.remove_meta("base_tooltip")
			
		CustomTooltipManager.replace_all_tooltips_with_custom(node)
		_fill_trigger_list()


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
	
	%TriggerEventContainer.visible = index in [2, 7, 8]
	%PlaceHolderLauncher.visible = !%TriggerEventContainer.visible
	_configure_launcher()
	
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
	if current_page.character_type == 1:
		_on_character_picker_clicked()
		return
		
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	var current_path: String
	match current_page.character_type:
		0: current_path = path_cache.lpc_event
		2: current_path = path_cache.scene
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _update_character_image
	dialog.set_file_selected(current_path)
	dialog.set_dialog_mode(0)
	
	match current_page.character_type:
		0: dialog.fill_mix_files(["events"])
		2: dialog.fill_files_by_extension(current_path, ["tscn"])


func _update_character_image(path: String) -> void:
	current_page.character_path = path
	
	if current_page.character_type == 0 and path in FileCache.cache.events:
		var res: RPGLPCCharacter = load(path)
		%CharacterImage.set_icon(res.event_preview)
		path_cache.lpc_event = path
		changed.emit()
	elif current_page.character_type == 2 and path.get_extension() == "tscn":
		_set_icon_from_scene(current_page.character_path)
		path_cache.scene = path
		changed.emit()


func _on_character_picker_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var icon = RPGIcon.new(path_cache.image, current_page.character_region)
	dialog.set_data(icon)
	
	dialog.icon_changed.connect(update_character_image.bind(icon))


func update_character_image(icon: RPGIcon) -> void:
	%CharacterImage.set_icon(icon.path, icon.region)
	path_cache.image = icon.path
	current_page.character_path = icon.path
	current_page.character_region = icon.region
	changed.emit()


func _on_character_image_remove_requested() -> void:
	current_page.character_path = ""
	current_page.character_region = Rect2()
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
		current_page.movement_to_target = %SelectTargetEvent.get_item_metadata(index)


func _on_trigger_event_list_pressed() -> void:
	if not current_page.allow_external_events_triggers:
		_select_triggers_from_current_map()
	else:
		_select_triggers_from_any_map()


func _select_triggers_from_current_map() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_in_game_events_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var items = []
	for ev: RPGEvent in current_event_list:
		items.append({"name": ev.name, "id": ev.id, "uniq_id": ev._uniq_id})
	
	dialog.fill_events(items, current_event._uniq_id)
	dialog.select_events(current_page.event_trigger_list)
	
	dialog.events_selected.connect(
		func(list: PackedInt64Array):
			current_page.event_trigger_list = list
			_fill_trigger_list()
	)


func _select_triggers_from_any_map() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_event_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.setup_multi_events_mode(current_page.external_event_triggers)
	
	dialog.events_selected.connect(
		func(selection_data: Dictionary):
			current_page.external_event_triggers = selection_data
			_fill_trigger_list()
	)


func _on_trigger_tool_list_pressed() -> void:
	if not current_page: return
	
	var path = "res://addons/CustomControls/Dialogs/select_any_multiple_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_texts("Select Tools", "Current Tool List", "[title]Tool List[/title]\nList of tools added to the database")
	var data: PackedStringArray = RPGSYSTEM.database.types.tool_types.duplicate()
	var selected_ids = current_page.event_tool_list
	
	for i in data.size():
		data[i] = "%s: %s" % [i + 1, data[i]]
	
	dialog.fill_data(data, selected_ids)
	
	dialog.items_selected.connect(
		func(list: PackedInt32Array):
			current_page.event_tool_list = list
			_fill_trigger_list()
	)


func _on_trigger_signal_list_pressed() -> void:
	if not current_page: return
	
	var path = "res://addons/CustomControls/Dialogs/select_any_multiple_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_texts("Select Signals", "Current Signal List", "[title]Signal List[/title]\nList of signals added to the database")

	var data: PackedStringArray = RPGSYSTEM.database.system.custom_signal_list.duplicate()
	var selected_ids = current_page.event_signal_list
	
	for i in data.size():
		data[i] = "%s: %s" % [i + 1, data[i]]
	
	dialog.fill_data(data, selected_ids)
	
	dialog.items_selected.connect(
		func(list: PackedInt32Array):
			current_page.event_signal_list = list
			_fill_trigger_list()
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
		var data_copied = {}
		data_copied.character_path = current_page.character_path
		data_copied.character_region = current_page.character_region
		data_copied.character_type = current_page.character_type
		clipboard[clipboard_key] = data_copied


func _on_character_image_custom_paste(node: Control, clipboard_key: String) -> void:
	var clipboard = StaticEditorVars.CLIPBOARD
	if clipboard_key in clipboard:
		var data_copied = clipboard[clipboard_key]
		current_page.character_path = data_copied.character_path
		current_page.character_region = data_copied.character_region
		current_page.character_type = data_copied.character_type
		_update_graphic()


func _on_data_type_selected_item_selected(index: int) -> void:
	if current_page:
		current_page.character_type = index
		
		%CharacterImage.set_icon("")
		match current_page.character_type:
			0:
				current_page.character_path = path_cache.lpc_event
				if current_page.character_path in FileCache.cache.events:
					var res: RPGLPCCharacter = load(current_page.character_path)
					%CharacterImage.set_icon(res.event_preview)
			1:
				current_page.character_path = path_cache.image
				%CharacterImage.set_icon(current_page.character_path)
			2:
				current_page.character_path = path_cache.scene
				_set_icon_from_scene(current_page.character_path)


func _on_page_extra_options_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/event_extra_options_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_page_options(current_page.options, current_page.condition.use_pressure)
	dialog.current_event = current_event
	
	dialog.OK.connect(func(new_pressed_state: bool):
		current_page.condition.use_pressure = new_pressed_state
		%Condition7Pressed.set_pressed_no_signal(new_pressed_state)
		_set_pressed_mode(new_pressed_state)
		
		if current_page.has_method("emit_changed"):
			current_page.emit_changed()
		if current_event and current_event.has_method("emit_changed"):
			current_event.emit_changed()
			
		changed.emit()
		%PageExtraOptions._update_extra_config_label(current_page)
	)


func _on_condition_7_pressed_toggled(toggled_on: bool) -> void:
	if current_page:
		current_page.condition.use_pressure = toggled_on
		
		if toggled_on and current_page.options.event_type in [1, 2]:
			current_page.options.event_type = 0
			
		_set_pressed_mode(current_page.condition.use_pressure)
		
		if current_page.condition.pressure_targets.is_empty():
			_on_allow_pressure_targets_multi_selection_changed([])
		
		%PageExtraOptions._update_extra_config_label(current_page)


func _set_pressed_mode(value: bool) -> void:
	var launcher = %Launcher
	var selected_index = launcher.get_selected_id()
	var popup = launcher.get_popup()
	var external_btn = get_node_or_null("%AllowExternalPressureTargets")
	var external_check = get_node_or_null("%AllowExternalPressureEvents")
	var player_check = get_node_or_null("%ExternalAllowPlayer")
	
	var event_type = current_page.options.event_type
	
	if event_type == null or event_type < 0 or event_type > 2:
		current_page.options.event_type = 0
		
	var disable_children = false
	
	if current_page.options.event_type == 1 or current_page.options.event_type == 2:
		disable_children = true
		%EventOption4.set_pressed(false)
		%EventOption4.set_disabled(true)
		
		selected_index = 0
		current_page.launcher = 0
		launcher.set_disabled(true)
		
		for i in launcher.get_item_count():
			launcher.set_item_disabled(i, i != 0)
			popup.set_item_disabled(i, i != 0)
			
	elif value:
		disable_children = false
		%EventOption4.set_pressed(true)
		%EventOption4.set_disabled(true)
		
		selected_index = -1
		current_page.launcher = -1
		launcher.set_disabled(true)
		
		for i in launcher.get_item_count():
			launcher.set_item_disabled(i, true)
			popup.set_item_disabled(i, true)
			
	else:
		disable_children = true
		%EventOption4.set_disabled(false)
		launcher.set_disabled(false)
		
		selected_index = max(0, selected_index)
		current_page.launcher = selected_index
		
		for i in launcher.get_item_count():
			launcher.set_item_disabled(i, false)
			popup.set_item_disabled(i, false)
			
	%AllowPressureTargets.set_disabled(disable_children)
	if external_btn: external_btn.set_disabled(disable_children)
	if external_check: external_check.set_disabled(disable_children)
	if player_check: player_check.set_disabled(disable_children)
	
	if selected_index == -1:
		launcher.select(-1)
	else:
		launcher.select(selected_index)
		launcher.item_selected.emit(selected_index)


## Updates the page data and modifies the tooltip when local target selections change.
func _on_allow_pressure_targets_multi_selection_changed(selected_ids: Array[int]) -> void:
	current_page.condition.pressure_targets.clear()
	var node = %AllowPressureTargets
	
	var arr_names: Array = []
	
	if selected_ids.is_empty():
		current_page.condition.pressure_targets.append(0)
		node.set_item_selected(0, true)
		arr_names.append("0: Player")
	else:
		for id in selected_ids:
			var real_id = node.get_item_metadata(id)
			current_page.condition.pressure_targets.append(real_id)
			if real_id == 0:
				arr_names.append("0: Player")
			else:
				for ev: RPGEvent in current_event_list:
					if ev._uniq_id == real_id:
						arr_names.append("%s: %s" % [ev.id, ev.name])
						break
			
	_append_ids_to_tooltip(node, arr_names, 0)


func _on_allow_external_events_trigger_toggled(toggled_on: bool) -> void:
	current_page.allow_external_events_triggers = toggled_on
	_fill_trigger_list()


func _on_allow_external_pressure_events_toggled(toggled_on: bool) -> void:
	current_page.allow_external_pressure_events = toggled_on
	_update_pressure_targets_visibility()


func _update_pressure_targets_visibility() -> void:
	var use_external = current_page.allow_external_pressure_events
	var external_btn = get_node_or_null("%AllowExternalPressureTargets")
	var player_check = get_node_or_null("%ExternalAllowPlayer")
	
	%AllowPressureTargets.visible = not use_external
	
	if external_btn:
		external_btn.visible = use_external
		
	if player_check:
		player_check.visible = use_external
		
	if use_external:
		_fill_external_pressure_list()
		if player_check:
			player_check.set_pressed_no_signal(current_page.external_pressure_targets.has(-1))


## Fills the text and tooltip displaying the total external pressure targets with formatted map/event names.
func _fill_external_pressure_list() -> void:
	var node = get_node_or_null("%AllowExternalPressureTargets")
	if not node or not current_page: return
	
	var total_events = 0
	var tooltip_ids: Array = []
	for map_id in current_page.external_pressure_targets:
		if map_id == -1:
			%ExternalAllowPlayer.set_pressed_no_signal(true)
			continue
		var ext_ids = current_page.external_pressure_targets[map_id]
		total_events += ext_ids.size()
		if not ext_ids.is_empty():
			tooltip_ids.append({"map_id": map_id, "event_ids": ext_ids})
		
	node.text = "External Targets: %s" % total_events
	_append_ids_to_tooltip(node, tooltip_ids, 2)


func _on_allow_external_pressure_targets_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_event_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.setup_multi_events_mode(current_page.external_pressure_targets)
	
	dialog.events_selected.connect(
		func(selection_data: Dictionary):
			current_page.external_pressure_targets = selection_data
			_fill_external_pressure_list()
	)


## Appends selected IDs to the node's custom tooltip with human-readable formatting.
## Format types: 0 = Generic, 1 = Local Events, 2 = External Events, 3 = Tools, 4 = Signals
func _append_ids_to_tooltip(node: Control, ids: Array, format_type: int = 0) -> void:
	if not is_instance_valid(node): return
	
	if not node.has_meta("base_tooltip"):
		var base = node.get_meta("current_tooltip", node.tooltip_text)
		node.set_meta("base_tooltip", base)
	
	var original_tooltip = node.get_meta("base_tooltip")
	var append_text = ""
	
	if not ids.is_empty():
		var str_names: PackedStringArray = []
		
		match format_type:
			0:
				for id in ids: str_names.append(str(id))
			1:
				for id in ids:
					var found = false
					for ev: RPGEvent in current_event_list:
						if ev._uniq_id == id:
							str_names.append("%s: %s" % [ev.id, ev.name])
							found = true
							break
					if not found: str_names.append("Unknown Event")
			2:
				var maps_info = RPGSYSTEM.map_infos.map_infos
				for dict_entry in ids:
					var map_id = dict_entry.map_id
					var event_ids = dict_entry.event_ids
					var map_name = maps_info.get_map_name_from_id(map_id)
					if map_name.is_empty(): map_name = "Map %s" % map_id
					
					var map_events = maps_info.get_map_events(map_id)
					
					for ev_id in event_ids:
						var ev_name = ""
						var short_id = ""
						for ev_dict in map_events:
							if ev_dict.get("uid", -1) == ev_id:
								ev_name = ev_dict.get("name", "")
								short_id = str(ev_dict.get("id", ""))
								break
								
						if ev_name.is_empty():
							str_names.append("[%s] Unknown Event" % map_name)
						else:
							str_names.append("[%s] %s: %s" % [map_name, short_id, ev_name])
			3:
				var list = RPGSYSTEM.database.types.tool_types
				for id in ids:
					var idx = id - 1
					if idx >= 0 and idx < list.size():
						str_names.append("%s: %s" % [id, list[idx]])
					else:
						str_names.append(str(id))
			4:
				var list = RPGSYSTEM.database.system.custom_signal_list
				for id in ids:
					var idx = id - 1
					if idx >= 0 and idx < list.size():
						str_names.append("%s: %s" % [id, list[idx]])
					else:
						str_names.append(str(id))
		
		var max_items = 10
		var display_names: PackedStringArray = []
		
		for i in min(str_names.size(), max_items):
			display_names.append(str_names[i])
			
		if str_names.size() > max_items:
			display_names.append("...and %s more" % (str_names.size() - max_items))
			
		append_text = "\n\nSelected Targets:\n- " + "\n- ".join(display_names)
		
	node.set_meta("current_tooltip", original_tooltip + append_text)
	if node.has_signal("tooltip_changed"):
		node.tooltip_changed.emit()


func _on_external_allow_player_toggled(toggled_on: bool) -> void:
	if toggled_on:
		if not current_page.external_pressure_targets.has(-1):
			current_page.external_pressure_targets[-1] = []
		if not current_page.external_pressure_targets[-1].has(0):
			current_page.external_pressure_targets[-1].append(0)
	else:
		if not current_page.external_pressure_targets.has(-1):
			current_page.external_pressure_targets.erase(-1)
			
	changed.emit()
