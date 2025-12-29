@tool
extends Window

var target: Callable
var database: RPGDATA

var current_learnable_skill: RPGLearnableSkill

# Set data, minimum/maximum level value and current_learnable_skill, in that order


func _ready() -> void:
	close_requested.connect(queue_free)


func select_level_spinbox() -> void:
	await get_tree().process_frame
	var line_edit: LineEdit = %Level.get_line_edit()
	line_edit.caret_column = line_edit.text.length()
	line_edit.select_all()
	line_edit.grab_focus()


func set_min_max_level(min_value: int, max_value: int) -> void:
	%Level.max_value = max_value
	%Level.min_value = min_value


func set_current_learnable_skill(obj: RPGLearnableSkill) -> void:
	current_learnable_skill = obj.clone(true)
	if database:
		if database.skills.size() > obj.skill_id:
			%SkillsButton.text = database.skills[obj.skill_id].name
		else:
			%SkillsButton.text = "⚠ Invalid Data"
	else:
		%SkillsButton.text = ""
	
	%Level.value = current_learnable_skill.level
	%Notes.text = current_learnable_skill.notes
	
	select_level_spinbox()


func set_new_learnable_skill() -> void: # Set 3º
	current_learnable_skill = RPGLearnableSkill.new()
	current_learnable_skill.skill_id = 1
	current_learnable_skill.level = %Level.min_value
	if database:
		if database.skills.size() > current_learnable_skill.skill_id:
			%SkillsButton.text = database.skills[current_learnable_skill.skill_id].name
		else:
			%SkillsButton.text = "⚠ Invalid Data"
	
	%Level.value = current_learnable_skill.level
	%Notes.text = current_learnable_skill.notes
	
	select_level_spinbox()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_ok_button_pressed() -> void:
	if target:
		target.call(current_learnable_skill)
	queue_free()


func _on_level_value_changed(value: float) -> void:
	if current_learnable_skill:
		current_learnable_skill.level = value


func _on_notes_text_changed() -> void:
	if current_learnable_skill:
		current_learnable_skill.notes = %Notes.text


func _on_skills_button_pressed() -> void:
	if !database:
		return
		
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.database = database
	dialog.destroy_on_hide = true
	
	dialog.selected.connect(_on_skill_selected)
	
	var id_selected = 1
	if database.skills.size() > current_learnable_skill.skill_id:
		id_selected = current_learnable_skill.skill_id
	
	dialog.setup(database.skills, id_selected, "Skills", %SkillsButton)


func _on_skill_selected(id: int, target: Variant) -> void:
	current_learnable_skill.skill_id = id
	target.text = database.skills[id].name
