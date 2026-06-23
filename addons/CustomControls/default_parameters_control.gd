@tool
extends PanelContainer

var current_data: PackedInt32Array


func set_data(_data: PackedInt32Array) -> void:
	current_data = _data
	_fill()
	%PasteParameters.set_disabled(!StaticEditorVars.CLIPBOARD.get("items_parameters_list", false))


func set_title(_title: String) -> void:
	%Title.text = _title


func _fill() -> void:
	if not current_data: return
	%MaxHPSpinBox.value = current_data[RPGActor.BaseParamType.HP]
	%AttackSpinBox.value = current_data[RPGActor.BaseParamType.ATK]
	%MagicAttackSpinBox.value = current_data[RPGActor.BaseParamType.MATK]
	%AgilitySpinBox.value = current_data[RPGActor.BaseParamType.AGI]
	%MaxMPSpinBox.value = current_data[RPGActor.BaseParamType.MP]
	%DefenseSpinBox.value = current_data[RPGActor.BaseParamType.DEF]
	%MagicDefenseSpinBox.value = current_data[RPGActor.BaseParamType.MDEF]
	%LuckSpinBox.value = current_data[RPGActor.BaseParamType.LUK]


## Updates base parameter: HP
func _on_max_hp_spin_box_value_changed(value: float) -> void:
	if not current_data: return
	current_data[RPGActor.BaseParamType.HP] = value


## Updates base parameter: Attack
func _on_attack_spin_box_value_changed(value: float) -> void:
	if not current_data: return
	current_data[RPGActor.BaseParamType.ATK] = value


## Updates base parameter: Magic Attack
func _on_magic_attack_spin_box_value_changed(value: float) -> void:
	if not current_data: return
	current_data[RPGActor.BaseParamType.MATK] = value


## Updates base parameter: Agility
func _on_agility_spin_box_value_changed(value: float) -> void:
	if not current_data: return
	current_data[RPGActor.BaseParamType.AGI] = value


## Updates base parameter: MP
func _on_max_mp_spin_box_value_changed(value: float) -> void:
	if not current_data: return
	current_data[RPGActor.BaseParamType.MP] = value


## Updates base parameter: Defense
func _on_defense_spin_box_value_changed(value: float) -> void:
	if not current_data: return
	current_data[RPGActor.BaseParamType.DEF] = value


## Updates base parameter: Magic Defense
func _on_magic_defense_spin_box_value_changed(value: float) -> void:
	if not current_data: return
	current_data[RPGActor.BaseParamType.MDEF] = value


## Updates base parameter: Luck
func _on_luck_spin_box_value_changed(value: float) -> void:
	if not current_data: return
	current_data[RPGActor.BaseParamType.LUK] = value


## Copies base parameters to the clipboard
func _on_copy_parameters_pressed() -> void:
	if not current_data: return
	StaticEditorVars.CLIPBOARD.items_parameters_list = current_data.duplicate()
	%PasteParameters.set_disabled(false)
	RPGEditorToast.show_message("Parameters copied to Clipboard")


## Pastes base parameters from the clipboard
func _on_paste_parameters_pressed() -> void:
	var params = StaticEditorVars.CLIPBOARD.get("items_parameters_list", null)
	if params:
		%MaxHPSpinBox.value = params[0]
		%AttackSpinBox.value = params[1]
		%MagicAttackSpinBox.value = params[2]
		%AgilitySpinBox.value = params[3]
		%MaxMPSpinBox.value = params[4]
		%DefenseSpinBox.value = params[5]
		%MagicDefenseSpinBox.value = params[6]
		%LuckSpinBox.value = params[7]


func _on_random_user_parameters_pressed() -> void:
	if current_data.size() > 0:
		
		for i in current_data.size():
			current_data[i] = randi_range(
				%MinValue.value,
				%MaxValue.value
			)
		
		_fill()


func _on_min_value_value_changed(value: float) -> void:
	if %MaxValue.value < value:
		%MaxValue.set_value_no_signal(value)


func _on_max_value_value_changed(value: float) -> void:
	if %MinValue.value > value:
		%MinValue.set_value_no_signal(value)
