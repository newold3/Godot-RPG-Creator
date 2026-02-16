@tool
class_name LPCEditorDialog
extends Window


func _ready() -> void:
	RPGMapPlugin.reload_inputs_safely()
	close_requested.connect(_on_close_requested)
	visibility_changed.connect(_on_visibility_changed)


func _on_close_requested() -> void:
	if RPGDialogFunctions.get_current_dialog() == self:
		hide_me()


func hide_me() -> void:
	if is_inside_tree():
		await get_tree().process_frame
		hide()
	else:
		hide()


func _on_visibility_changed() -> void:
	if visible:
		CustomTooltipManager.replace_all_tooltips_with_custom.call_deferred(self)
		%EditorCharacter.refresh()
	else:
		%EditorCharacter.backup()
