@tool
extends CommandBaseDialog



var _map_id: int = -1
var _event_id: int = -1
var _global_quest: PackedInt64Array
var _specific_quest: PackedInt64Array



## Initialize the base command parameters
func _ready() -> void:
	super()
	parameter_code = 126



## Set the UI data from the command parameters dictionary
func set_data() -> void:
	var data = parameters[0].parameters
	
	_map_id = data.get("map_id", -1)
	_event_id = data.get("event_id", -1)
	_global_quest = data.get("global_ids", [])
	_specific_quest = data.get("specific_ids", [])
	
	var selected_action = data.get("operation_type", 0)
	%StartQuest.set_pressed_no_signal(selected_action == 0)
	%CancelQuest.set_pressed_no_signal(selected_action == 1)
	%CompleteQuest.set_pressed_no_signal(selected_action == 2)
	%FailQuest.set_pressed_no_signal(selected_action == 3)
	%UnlockQuest.set_pressed_no_signal(selected_action == 4)
	%RestartQuest.set_pressed_no_signal(selected_action == 5)
	%UpdateUserQuest.set_pressed_no_signal(selected_action == 6)
	
	var progress = data.get("progress", 0.1)
	%UserProgress.set_value_no_signal(progress)
	
	_update_event_name()
	_update_quest_list()



## Lock or unlock the event selector based on the scope index
func _on_quest_scope_item_selected(index: int) -> void:
	%TargetEvent.set_disabled(index == 0)
	_update_quest_list()



## Open the dialog to select the target map event
func _on_target_event_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_event_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var map_id = _map_id
	var event_id = _event_id
	dialog.setup_single_event_quest_mode(map_id, event_id)
	
	dialog.event_selected.connect(
		func(selected_map_id: int, selected_event_id: int, _page_id: int):
			_map_id = selected_map_id
			_event_id = selected_event_id
			_update_event_name()
	)



## Update the display text of the target event button
func _update_event_name() -> void:
	var map_id = _map_id
	var map_name = RPGSYSTEM.map_infos.get_map_name_from_id(map_id)
	var event_id = _event_id
	var event_name = RPGSYSTEM.map_infos.get_event_name(map_id, event_id)
	
	if map_name and event_name:
		%TargetEvent.text = map_name + " -> " + event_name
	elif map_id != -1 and event_id != -1:
		%TargetEvent.text = "<⚠️ Invalid Event>"
	else:
		%TargetEvent.text = tr("Select Event")



## Open the multiple-data selection dialog for quests, handling IDs correctly
func _on_quest_list_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_multiple_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var valid_ids: Array = []
	var data: Array[String] = []
	var target_indexes: PackedInt32Array = []
	var target_help_list: String = ""
	
	if %QuestScope.get_selected_id() == 0:
		var db_quests = RPGSYSTEM.database.quests
		
		for q in db_quests:
			if q:
				valid_ids.append(int(q._uniq_id))
				data.append("%s: %s" % [q.id, q.name])
		
		for i in range(valid_ids.size()):
			if valid_ids[i] in _global_quest:
				target_indexes.append(i)
		
		target_help_list = tr("the database")
		
	else:
		var map_id = _map_id
		var event_id = _event_id
		var events = RPGSYSTEM.map_infos.get_events(map_id)
		var quest_ids = []
		
		for ev in events:
			if ev.get("id") == event_id or ev.get("uid") == event_id:
				quest_ids = ev.get("quest_ids", [])
				break
		
		var db_quests = RPGSYSTEM.database.quests
		var db_lookup = {}
		
		for q in db_quests:
			if q:
				db_lookup[int(q.id)] = q
				db_lookup[int(q._uniq_id)] = q
		
		for q_id in quest_ids:
			valid_ids.append(int(q_id))
			var q = db_lookup.get(int(q_id))
			
			if q:
				data.append("%s: %s" % [q.id, q.name])
			else:
				data.append("%s: <Missing>" % [q_id])
		
		for i in range(valid_ids.size()):
			if valid_ids[i] in _specific_quest:
				target_indexes.append(i)
		
		target_help_list = tr("the selected event")
	
	var data_name = tr("Select Quest")
	
	dialog.set_texts(
		data_name,
		data_name + ":",
		tr("List of available quests"),
		"[title]%s[/title]\n" % data_name +
		tr("Quests added in {0}. Left-click items to add or remove them from the selection. Multiple items can be selected.".format([target_help_list]))
	)
	dialog.fill_data(data, target_indexes)
	
	dialog.items_selected.connect(
		func(list: PackedInt32Array):
			var quests: PackedInt64Array = []
			
			for index in list:
				if index >= 0 and index < valid_ids.size():
					quests.append(valid_ids[index])
			
			if %QuestScope.get_selected_id() == 0:
				_global_quest = quests
			else:
				_specific_quest = quests
			
			print("Global = ", _global_quest, "\n", "Specific = ", _specific_quest)
			_update_quest_list()
	)



## Update the label that lists the currently selected quests in the UI
func _update_quest_list() -> void:
	var data: Array[String] = []
	
	if %QuestScope.get_selected_id() == 0:
		var db_quests = RPGSYSTEM.database.quests
		
		for q in db_quests:
			if q and (int(q._uniq_id) in _global_quest or int(q.id) in _global_quest):
				data.append("%s: %s" % [q.id, q.name])
				
	else:
		var map_id = _map_id
		var event_id = _event_id
		var events = RPGSYSTEM.map_infos.get_events(map_id)
		var quest_ids = []
		
		for ev in events:
			if ev.get("id") == event_id or ev.get("uid") == event_id:
				quest_ids = ev.get("quest_ids", [])
				break
		
		var db_quests = RPGSYSTEM.database.quests
		var db_lookup = {}
		
		for q in db_quests:
			if q:
				db_lookup[int(q.id)] = q
				db_lookup[int(q._uniq_id)] = q
		
		for q_id in quest_ids:
			if int(q_id) in _specific_quest:
				var q = db_lookup.get(int(q_id))
				
				if q:
					data.append("%s: %s" % [q.id, q.name])
				else:
					data.append("%s: <Missing>" % [q_id])
	
	%QuestList.text = str(data)



## Disable or enable the progress bar based on the action selected
func _on_update_user_quest_toggled(toggled_on: bool) -> void:
	%UserProgress.set_disabled(!toggled_on)



## Build the array of event commands with all current parameter values
func build_command_list() -> Array[RPGEventCommand]:
	propagate_call("apply")
	
	var commands: Array[RPGEventCommand] = super()
	
	commands[-1].parameters.quest_scope = %QuestScope.get_selected_id()
	commands[-1].parameters.operation_type = %StartQuest.button_group.get_pressed_button().get_meta("id")
	commands[-1].parameters.progress = %UserProgress.value
	commands[-1].parameters.map_id = _map_id
	commands[-1].parameters.event_id = _event_id
	commands[-1].parameters.global_ids = _global_quest
	commands[-1].parameters.specific_ids = _specific_quest
	
	return commands
