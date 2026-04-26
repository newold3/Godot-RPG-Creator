@tool
extends CommandBaseDialog

var _map_id: int = -1
var _event_id: int = -1
var _global_quest: PackedInt32Array
var _specific_quest: PackedInt32Array

func _ready() -> void:
	super()
	parameter_code = 126


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


func _on_quest_scope_item_selected(index: int) -> void:
	%TargetEvent.set_disabled(index == 0)
	_update_quest_list()


func _on_target_event_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_event_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var map_id = _map_id
	var event_id = _event_id
	dialog.setup_single_event_quest_mode(map_id, event_id)
	
	dialog.event_selected.connect(
		func(map_id: int, event_id: int, _page_id: int):
			_map_id = map_id
			_event_id = event_id
			_update_event_name()
	)


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


func _on_quest_list_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_multiple_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var indexes = []
	var data = []
	
	if %QuestScope.get_selected_id() == 0:
		indexes = _global_quest
		data = RPGSYSTEM.database.quests.map(
			func(q: RPGQuest): if q: return "%s: %s" % [q.id, q.name]
		)
		data = data.filter(func(q): return q != null)
	else:
		var map_id = _map_id
		var event_id = _event_id
		indexes = _specific_quest
		var events = RPGSYSTEM.map_infos.get_events(map_id)
		var quest_ids = []
		var real_data = RPGSYSTEM.database.quests
		for ev in events:
			if ev.get("id") == event_id or ev.get("uid") == event_id:
				quest_ids = ev.get("quest_ids", [])
				break
		
		var db_quests = RPGSYSTEM.database.quests
		var db_lookup = {}
		for q in db_quests:
			if not q: continue
			db_lookup[q.id] = q.name
		
		data = Array(quest_ids).map(
			func(q_id):
				var name = db_lookup.get(q_id, "<Missing>")
				return "%s: %s" % [q_id, name]
		)
	
	dialog.set_texts(tr("Select Quest"), tr("Quest list:"), tr("List of available quests"))
	dialog.fill_data(data, indexes)
	
	dialog.items_selected.connect(
		func(list: PackedInt32Array):
			if %QuestScope.get_selected_id() == 0:
				_global_quest = list
			else:
				_specific_quest = list
			_update_quest_list()
	)


func _update_quest_list() -> void:
	var data: Array
	var indexes: Array
	if %QuestScope.get_selected_id() == 0:
		indexes = _global_quest
		data = RPGSYSTEM.database.quests.map(
			func(q: RPGQuest): if q: return "%s: %s" % [q.id, q.name]
		)
		data = data.filter(func(q): return q != null)
	else:
		var map_id = _map_id
		var event_id = _event_id
		indexes = _specific_quest
		
		var events = RPGSYSTEM.map_infos.get_events(map_id)
		var quest_ids = []
		var real_data = RPGSYSTEM.database.quests
		for ev in events:
			if ev.get("id") == event_id or ev.get("uid") == event_id:
				quest_ids = ev.get("quest_ids", [])
				break
		
		var db_quests = RPGSYSTEM.database.quests
		var db_lookup = {}
		for q in db_quests:
			if not q: continue
			db_lookup[q.id] = q.name
		
		data = Array(quest_ids).map(
			func(q_id):
				var name = db_lookup.get(q_id, "<Missing>")
				return "%s: %s" % [q_id, name]
		)


func _on_update_user_quest_toggled(toggled_on: bool) -> void:
	%UserProgress.set_disabled(!toggled_on)


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
