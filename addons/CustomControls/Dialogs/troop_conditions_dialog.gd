@tool
extends Window


var condition: RPGTroopCondition = RPGTroopCondition.new()
var original_condition: RPGTroopCondition
var current_enemies: PackedStringArray = []

signal condition_changed()

func _ready() -> void:
	close_requested.connect(queue_free)
	propagate_call("set_disabled", [true])
	fill_enemies()
	fill_characters()
	fill_signals()
	set_variable(1)
	set_switch(1)
	enable_conditions_and_buttons()


func set_enemies(p_enemies: PackedStringArray) -> void:
	current_enemies = p_enemies
	fill_enemies()


func fill_enemies() -> void:
	var node = %EnemyParamValue1
	node.clear()
	var data = current_enemies
	
	for i in data.size():
		var obj = data[i]
		if !obj: continue
		var obj_name = "%s: %s" % [str(i).pad_zeros(str(data.size()).length()), obj.name]
		node.add_item(obj_name)


func fill_characters() -> void:
	var node = %CharacterParamValue1
	node.clear()
	var data = RPGSYSTEM.database.actors
	
	for i in data.size():
		var obj = data[i]
		if !obj: continue
		var obj_name = "%s: %s" % [str(i).pad_zeros(str(data.size()).length()), obj.name]
		node.add_item(obj_name)


func fill_signals() -> void:
	var node = %SignalValue
	node.clear()


func set_variable(id) -> void:
	var node = %VariableButton
	var data = RPGSYSTEM.system.variables.data
	var obj_name: String
	if data.size() > id:
		obj_name = "%s: %s" % [str(id).pad_zeros(str(data.size()).length()), data[id].name]
	else:
		obj_name = "⚠ Invalid Data"
	node.text = obj_name


func set_switch(id) -> void:
	var node = %SwitchButton
	var data = RPGSYSTEM.system.switches.data
	var obj_name: String
	if data.size() > id:
		obj_name = "%s: %s" % [str(id).pad_zeros(str(data.size()).length()), data[id].name]
	else:
		obj_name = "⚠ Invalid Data"
	node.text = obj_name


func enable_conditions_and_buttons() -> void:
	%TurnEndingCondition.set_disabled(false)
	%TurnValidCondition.set_disabled(false)
	%EnemyValidCondition.set_disabled(false)
	%CharacterValidCondition.set_disabled(false)
	%SwitchValidCondition.set_disabled(false)
	%VariableValidCondition.set_disabled(false)
	%SignalValidCondition.set_disabled(false)
	%OKButton.set_disabled(false)
	%CancelButton.set_disabled(false)


func set_condition(_condition: RPGTroopCondition) -> void:
	original_condition = _condition
	condition = _condition.clone(true)
	
	%TurnEndingCondition.set_pressed(condition.turn_ending)
	
	%TurnValidCondition.set_pressed(condition.turn_valid)
	%TurnValue1.value = condition.turn_a
	%TurnValue2.value = condition.turn_b
	
	%EnemyValidCondition.set_pressed(condition.enemy_valid)
	if %EnemyParamValue1.get_item_count() > condition.enemy_id - 1:
		%EnemyParamValue1.select(condition.enemy_id - 1)
	elif %EnemyParamValue1.get_item_count() > 0:
		condition.enemy_id = 1
		%EnemyParamValue1.select(0)
	%EnemyParamValue2.select(condition.enemy_param_index)
	%EnemyParamValue3.select(condition.enemy_param_operation)
	%EnemyPercent.set_pressed(condition.enemy_param_value_is_percent)
	%EnemyParamValue4.value = condition.enemy_param_value
	
	%CharacterValidCondition.set_pressed(condition.actor_valid)
	if %CharacterParamValue1.get_item_count() > condition.actor_id - 1:
		%CharacterParamValue1.select(condition.actor_id - 1)
	else:
		condition.actor_id = 1
		%CharacterParamValue1.select(0)
	%CharacterParamValue2.select(condition.actor_param_index)
	%CharacterParamValue3.select(condition.actor_param_operation)
	%CharacterPercent.set_pressed(condition.actor_param_value_is_percent)
	%CharacterParamValue4.value = condition.actor_param_value
	
	%SwitchValidCondition.set_pressed(condition.switch_valid)
	set_switch(condition.switch_id)
	%SwitchValue.select(condition.switch_value)
	
	%VariableValidCondition.set_pressed(condition.variable_valid)
	set_variable(condition.variable_id)
	%VariableOperation.select(condition.variable_operation)
	%VariableValue.value = condition.variable_value
	
	%SignalValidCondition.set_pressed(condition.signal_valid)
	if %SignalValue.get_item_count() > condition.signal_id:
		%SignalValue.select(condition.signal_id)
		print(5)
	else:
		condition.signal_id = 0
		if %SignalValue.get_item_count() > condition.signal_id:
			%SignalValue.select(condition.signal_id)
			print(5)


func _on_ok_button_pressed() -> void:
	var properties = [
		"turn_ending", "turn_valid", "enemy_valid", "actor_valid", "switch_valid",
		"variable_valid", "signal_valid", "turn_a", "turn_b", "enemy_id", "enemy_param_index",
		"enemy_param_value", "enemy_param_operation", "enemy_param_value_is_percent",
		"actor_id", "actor_param_index", "actor_param_value", "actor_param_operation",
		"actor_param_value_is_percent", "switch_id", "switch_value", "variable_id",
		"variable_value", "signal_id"
	]
	for p in properties:
		original_condition.set(p, condition.get(p))
		
	condition_changed.emit()
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_turn_ending_condition_toggled(toggled_on: bool) -> void:
	condition.turn_ending = toggled_on
	var node = %TurnEndingCondition
	node.get_parent().propagate_call("set_disabled", [!toggled_on])
	node.set_disabled(false)


func _on_turn_valid_condition_toggled(toggled_on: bool) -> void:
	condition.turn_valid = toggled_on
	var node = %TurnValidCondition
	node.get_parent().propagate_call("set_disabled", [!toggled_on])
	node.set_disabled(false)


func _on_turn_value_1_value_changed(value: float) -> void:
	condition.turn_a = value


func _on_turn_value_2_value_changed(value: float) -> void:
	condition.turn_b = value


func _on_enemy_valid_condition_toggled(toggled_on: bool) -> void:
	condition.enemy_valid = toggled_on
	var node = %EnemyValidCondition
	node.get_parent().propagate_call("set_disabled", [!toggled_on])
	node.set_disabled(false)


func _on_enemy_param_value_1_item_selected(index: int) -> void:
	condition.enemy_id = index + 1


func _on_enemy_param_value_2_item_selected(index: int) -> void:
	condition.enemy_param_index = index


func _on_enemy_param_value_3_item_selected(index: int) -> void:
	condition.enemy_param_operation = index


func _on_enemy_param_value_4_value_changed(value: float) -> void:
	condition.enemy_param_value = value


func _on_enemy_percent_toggled(toggled_on: bool) -> void:
	condition.enemy_param_value_is_percent = toggled_on
	var node = %EnemyParamValue4
	if toggled_on:
		node.suffix = " %"
		node.max_value = 100
		node.min_value = 0
	else:
		node.suffix = ""
		var max_int = pow(2, 31) - 1
		node.max_value = max_int
		node.min_value = -max_int


func _on_character_valid_condition_toggled(toggled_on: bool) -> void:
	condition.actor_valid = toggled_on
	var node = %CharacterValidCondition
	node.get_parent().propagate_call("set_disabled", [!toggled_on])
	node.set_disabled(false)


func _on_character_param_value_1_item_selected(index: int) -> void:
	condition.actor_id = index + 1


func _on_character_param_value_2_item_selected(index: int) -> void:
	condition.actor_param_index = index


func _on_character_param_value_3_item_selected(index: int) -> void:
	condition.actor_param_operation = index


func _on_character_param_value_4_value_changed(value: float) -> void:
	condition.actor_param_value = value


func _on_character_percent_toggled(toggled_on: bool) -> void:
	condition.actor_param_value_is_percent = toggled_on
	var node = %CharacterParamValue4
	if toggled_on:
		node.suffix = " %"
		node.max_value = 100
		node.min_value = 0
	else:
		node.suffix = ""
		var max_int = pow(2, 31) - 1
		node.max_value = max_int
		node.min_value = -max_int


func _on_switch_valid_condition_toggled(toggled_on: bool) -> void:
	condition.switch_valid = toggled_on
	var node = %SwitchValidCondition
	node.get_parent().propagate_call("set_disabled", [!toggled_on])
	node.set_disabled(false)


func _on_switch_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_switch_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 1
	dialog.target = %SwitchButton
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_on_variable_or_switch_name_changed)
	dialog.setup(condition.switch_id)


func _on_variable_or_switch_name_changed() -> void:
	set_switch(condition.switch_id)
	set_variable(condition.variable_id)


func _on_switch_changed(index: int, _target: Node) -> void:
	condition.switch_id = index
	set_switch(index)


func _on_switch_value_item_selected(index: int) -> void:
	condition.switch_value = (index == 0)


func _on_variable_valid_condition_toggled(toggled_on: bool) -> void:
	condition.variable_valid = toggled_on
	var node = %VariableValidCondition
	node.get_parent().propagate_call("set_disabled", [!toggled_on])
	node.set_disabled(false)


func _on_variable_button_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var callable = _on_variable_changed
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 0
	dialog.target = %VariableButton
	dialog.selected.connect(callable)
	dialog.variable_or_switch_name_changed.connect(_on_variable_or_switch_name_changed)
	dialog.setup(condition.variable_id)


func _on_variable_changed(index: int, _target: Node) -> void:
	condition.variable_id = index
	set_variable(index)


func _on_variable_operation_item_selected(index: int) -> void:
	condition.variable_operation = index


func _on_variable_value_value_changed(value: float) -> void:
	condition.variable_value = value


func _on_signal_valid_condition_toggled(toggled_on: bool) -> void:
	condition.signal_valid = toggled_on
	var node = %SignalValidCondition
	node.get_parent().propagate_call("set_disabled", [!toggled_on])
	node.set_disabled(false)


func _on_signal_value_item_selected(index: int) -> void:
	condition.signal_id = index
