@tool
extends Window

#region Variables
var target: Callable
var database: RPGDATA

var current_learnable_skill: RPGLearnableSkill
#endregion



#region Lifecycle
## Called when the node enters the scene tree for the first time
func _ready() -> void:
	close_requested.connect(queue_free)
#endregion



#region Setup
## Gives focus to the level spinbox and selects all its text
func select_level_spinbox() -> void:
	await get_tree().process_frame
	var line_edit: LineEdit = %Level.get_line_edit()
	line_edit.caret_column = line_edit.text.length()
	line_edit.select_all()
	line_edit.grab_focus()



## Sets the minimum and maximum boundaries for the level spinbox
func set_min_max_level(min_value: int, max_value: int) -> void:
	%Level.max_value = max_value
	%Level.min_value = min_value



## Loads an existing learnable skill converting its UID for the UI
func set_current_learnable_skill(obj: RPGLearnableSkill) -> void:
	current_learnable_skill = obj.clone(true)
	
	if database:
		var skill_data = RPGSYSTEM.get_data("skills", obj.skill_id)
		if skill_data:
			var classic_id = RPGSYSTEM.uid_to_id("skills", obj.skill_id)
			var id_padded = str(classic_id).pad_zeros(str(database.skills.size()).length())
			%SkillsButton.text = "%s: %s" % [id_padded, skill_data.name]
		else:
			%SkillsButton.text = "⚠ Invalid Data"
	else:
		%SkillsButton.text = ""
	
	%Level.value = current_learnable_skill.level
	%Notes.text = current_learnable_skill.notes
	
	select_level_spinbox()



## Creates a fresh learnable skill with default values and UID
func set_new_learnable_skill() -> void:
	current_learnable_skill = RPGLearnableSkill.new()
	current_learnable_skill.skill_id = RPGSYSTEM.id_to_uid("skills", 1)
	current_learnable_skill.level = %Level.min_value
	
	if database:
		var skill_data = RPGSYSTEM.get_data("skills", current_learnable_skill.skill_id)
		if skill_data:
			var classic_id = RPGSYSTEM.uid_to_id("skills", current_learnable_skill.skill_id)
			var id_padded = str(classic_id).pad_zeros(str(database.skills.size()).length())
			%SkillsButton.text = "%s: %s" % [id_padded, skill_data.name]
		else:
			%SkillsButton.text = "⚠ Invalid Data"
	
	%Level.value = current_learnable_skill.level
	%Notes.text = current_learnable_skill.notes
	
	select_level_spinbox()
#endregion



#region UI_Handlers
## Cancels the operation and closes the dialog
func _on_cancel_button_pressed() -> void:
	queue_free()



## Confirms the operation, sends the data back, and closes the dialog
func _on_ok_button_pressed() -> void:
	if target:
		target.call(current_learnable_skill)
	queue_free()



## Updates the level value when the spinbox changes
func _on_level_value_changed(value: float) -> void:
	if current_learnable_skill:
		current_learnable_skill.level = value



## Updates the notes string when the text edit changes
func _on_notes_text_changed() -> void:
	if current_learnable_skill:
		current_learnable_skill.notes = %Notes.text



## Opens the selection dialog to choose a skill passing the classic ID
func _on_skills_button_pressed() -> void:
	if !database:
		return
		
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.database = database
	dialog.destroy_on_hide = true
	
	dialog.selected.connect(_on_skill_selected)
	
	var classic_id = RPGSYSTEM.uid_to_id("skills", current_learnable_skill.skill_id)
	classic_id = max(1, min(classic_id, database.skills.size() - 1))
	
	dialog.setup(database.skills, classic_id, TranslationManager.tr("Skills"), %SkillsButton)



## Receives the classic ID from the sub-dialog, converts it to UID, and updates the UI
func _on_skill_selected(id: int, target: Variant) -> void:
	var uid = RPGSYSTEM.id_to_uid("skills", id)
	current_learnable_skill.skill_id = uid
	
	var skill_data = RPGSYSTEM.get_data("skills", uid)
	if skill_data:
		var id_padded = str(id).pad_zeros(str(database.skills.size()).length())
		target.text = "%s: %s" % [id_padded, skill_data.name]
	else:
		target.text = "⚠ Invalid Data"
#endregion
