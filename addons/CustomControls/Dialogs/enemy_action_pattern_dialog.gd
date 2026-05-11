@tool
extends Window

#region Signals & Variables
var database: RPGDATA
var data: RPGEnemyAction

var skill_selected = 1
var state_selected = 1
var switch_selected = 1
var variable_selected = 1
var selected_index = -1
var busy: bool = false

signal action_created(data: RPGEnemyAction)
signal action_updated(data: RPGEnemyAction, selected_index: int)
#endregion



#region Lifecycle & Setup
## Initializes the dialog and connects checkbox groups
func _ready() -> void:
	close_requested.connect(queue_free)
	connect_all_checkboxs(self)



## Loads existing data into the dialog
func set_data(_data: RPGEnemyAction, _selected_index = -1) -> void:
	data = _data.clone(true)
	selected_index = _selected_index
	fill()



## Initializes fresh data for a new action pattern
func create_new_data() -> void:
	data = RPGEnemyAction.new()
	selected_index = -1
	fill()



## Populates all UI fields based on current data
func fill() -> void:
	busy = true
	
	# Handles Skill UID translation
	skill_selected = data.skill_id
	if skill_selected > 0 and skill_selected < 1000000:
		skill_selected = RPGSYSTEM.id_to_uid("skills", skill_selected)
		data.skill_id = skill_selected
	
	%Raiting.value = data.rating
	
	var checkbox_pressed = "%%CheckBox%s" % (data.condition_type + 1)
	get_node(checkbox_pressed).set_pressed(true)
	
	match data.condition_type:
		1: # Turn
			%StartTurn.value = data.condition_param1
			%RepeatEachTurn.value = data.condition_param2
		2: # HP
			%HPFrom.value = data.condition_param1
			%HPTo.value = data.condition_param2
		3: # MP
			%MPFrom.value = data.condition_param1
			%MPTo.value = data.condition_param2
		4: # State
			state_selected = data.condition_param1
			if state_selected > 0 and state_selected < 1000000:
				state_selected = RPGSYSTEM.id_to_uid("states", state_selected)
				data.condition_param1 = state_selected
		5: # Party Level
			%PartyLevelCondition.select(data.condition_param1)
			%PartyLevelValue.value = data.condition_param2
		6: # Switch
			switch_selected = data.condition_param1
			%SwitchValue.select(data.condition_param2)
		7: # Variable
			variable_selected = data.condition_param1
			%VariableCondition.select(data.condition_param2)
			%VariableValue.value = data.condition_param3
	
	fill_skill_selected()
	fill_state_selected()
	fill_switch_selected()
	fill_variable_selected()
		
	busy = false



## Recursively connects all condition checkboxes to logic
func connect_all_checkboxs(node: Node, button_group = ButtonGroup.new()) -> void:
	if node is CheckBox:
		node.add_to_group("checkboxs")
		node.button_group = button_group
		node.toggled.connect(_on_node_toggled.bind(node))
	
	for child in node.get_children():
		connect_all_checkboxs(child, button_group)
#endregion



#region UI Updates
## Updates the Skill button text formatting with UID mapping
func fill_skill_selected() -> void:
	if !database: return
	
	var node = %Skill
	var item_name = "⚠ Invalid Data"
	
	if skill_selected > 0:
		var skill_data = RPGSYSTEM.get_data("skills", skill_selected)
		if skill_data:
			var classic_id = RPGSYSTEM.uid_to_id("skills", skill_selected)
			var id = str(classic_id).pad_zeros(str(database.skills.size()).length())
			item_name = id + ": " + skill_data.name
			
	node.text = item_name



## Updates the State condition button text formatting with UID mapping
func fill_state_selected() -> void:
	if !database: return
	
	var node = %State
	var item_name = "⚠ Invalid Data"
	
	if state_selected > 0:
		var state_data = RPGSYSTEM.get_data("states", state_selected)
		if state_data:
			var classic_id = RPGSYSTEM.uid_to_id("states", state_selected)
			var id = str(classic_id).pad_zeros(str(database.states.size()).length())
			item_name = id + ": " + state_data.name
			
	node.text = item_name



## Updates the Switch condition button text
func fill_switch_selected() -> void:
	if !database: return
	var current_data = RPGSYSTEM.system.switches.data
	var node = %Switch
	var item_name = "⚠ Invalid Data"
	
	if current_data.size() > switch_selected:
		var id = str(switch_selected).pad_zeros(str(current_data.size()).length())
		item_name = id + ": " + current_data[switch_selected].name
		
	node.text = item_name



## Updates the Variable condition button text
func fill_variable_selected() -> void:
	if !database: return
	var current_data = RPGSYSTEM.system.variables.data
	var node = %Variable
	var item_name = "⚠ Invalid Data"
	
	if current_data.size() > variable_selected:
		var id = str(variable_selected).pad_zeros(str(current_data.size()).length())
		item_name = id + ": " + current_data[variable_selected].name
		
	node.text = item_name
#endregion



#region Event Handlers
## Disables irrelevant condition inputs when a checkbox is toggled
func _on_node_toggled(toggles_on: bool, node: CheckBox) -> void:
	%ConditionContainer.propagate_call("set_disabled", [true])
	var checkboxs = get_tree().get_nodes_in_group("checkboxs")
	
	for c in checkboxs:
		c.set_disabled(false)
		
	if toggles_on:
		node.get_parent().propagate_call("set_disabled", [false])



## Submits the pattern data and closes the dialog
func _on_ok_button_pressed() -> void:
	%ConditionContainer.propagate_call("apply")
	
	var button_pressed = %CheckBox1.button_group.get_pressed_button()
	var id = int(str(button_pressed.name)) - 1
	
	data.condition_type = id
	data.skill_id = skill_selected
	data.rating = %Raiting.value
	
	match id:
		1: # Turn
			data.condition_param1 = %StartTurn.value
			data.condition_param2 = %RepeatEachTurn.value
		2: # HP
			data.condition_param1 = %HPFrom.value
			data.condition_param2 = %HPTo.value
		3: # MP
			data.condition_param1 = %MPFrom.value
			data.condition_param2 = %MPTo.value
		4: # State
			data.condition_param1 = state_selected
		5: # Party Level
			data.condition_param1 = %PartyLevelCondition.get_selected_id()
			data.condition_param2 = %PartyLevelValue.value
		6: # Switch
			data.condition_param1 = switch_selected
			data.condition_param2 = %SwitchValue.get_selected_id()
		7: # Variable
			data.condition_param1 = variable_selected
			data.condition_param2 = %VariableCondition.get_selected_id()
			data.condition_param3 = %VariableValue.value
	
	if selected_index != -1:
		action_updated.emit(data, selected_index)
	else:
		action_created.emit(data)
			
	queue_free()



## Cancels the operation and closes the dialog
func _on_cancel_button_pressed() -> void:
	queue_free()



## Synchronizes HP minimum condition
func _on_hp_from_value_changed(value: float) -> void:
	if busy: return
	%HPTo.value = max(value, %HPTo.value)



## Synchronizes HP maximum condition
func _on_hp_to_value_changed(value: float) -> void:
	if busy: return
	%HPFrom.value = min(value, %HPFrom.value)



## Synchronizes MP minimum condition
func _on_mp_from_value_changed(value: float) -> void:
	if busy: return
	%MPTo.value = max(value, %MPTo.value)



## Synchronizes MP maximum condition
func _on_mp_to_value_changed(value: float) -> void:
	if busy: return
	%MPFrom.value = min(value, %MPFrom.value)
#endregion



#region Dialog Openers & Callbacks
## Helper to open the generic data selector converting UID to index first
func open_select_any_data_dialog(title, current_data, target_callable, id_selected, db_key) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	dialog.destroy_on_hide = true
	
	var classic_id = RPGSYSTEM.uid_to_id(db_key, id_selected) if id_selected > 0 else 1
	classic_id = max(1, min(classic_id, current_data.size() - 1))
	
	dialog.selected.connect(target_callable, CONNECT_ONE_SHOT)
	dialog.setup(current_data, classic_id, title, self)



## Opens the skill selection dialog
func _on_skill_pressed() -> void:
	open_select_any_data_dialog("Skills", database.skills, _on_skill_selected, skill_selected, "skills")



## Receives the classic ID, converts it to UID and sets the skill
func _on_skill_selected(id: int, target: Variant) -> void:
	var uid = RPGSYSTEM.id_to_uid("skills", id)
	skill_selected = uid
	fill_skill_selected()



## Opens the state selection dialog
func _on_state_pressed() -> void:
	open_select_any_data_dialog("States", database.states, _on_state_selected, state_selected, "states")



## Receives the classic ID, converts it to UID and sets the state
func _on_state_selected(id: int, target: Variant) -> void:
	var uid = RPGSYSTEM.id_to_uid("states", id)
	state_selected = uid
	fill_state_selected()



## Helper to open the Switch/Variable dialog
func open_switch_variable_dialog(data_type: int, current_selected: int, target_callable: Callable, name_changed_target: Callable) -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE, null, true)
	dialog.data_type = data_type
	dialog.selected.connect(target_callable)
	dialog.variable_or_switch_name_changed.connect(name_changed_target)
	dialog.setup(current_selected)



## Opens the switch selection dialog
func _on_switch_pressed() -> void:
	open_switch_variable_dialog(1, switch_selected, _on_switch_selected, fill_switch_selected)



## Sets the selected switch
func _on_switch_selected(id: int, target: Variant) -> void:
	switch_selected = id
	fill_switch_selected()



## Opens the variable selection dialog
func _on_variable_pressed() -> void:
	open_switch_variable_dialog(0, variable_selected, _on_variable_selected, fill_variable_selected)



## Sets the selected variable
func _on_variable_selected(id: int, target: Variant) -> void:
	variable_selected = id
	fill_variable_selected()
#endregion
