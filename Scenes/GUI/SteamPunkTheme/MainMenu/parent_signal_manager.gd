@tool
extends Node

@export var animation_player: AnimationPlayer
@export var help_label: Label


func _on_parent_visibility_changed() -> void:
	if Engine.is_editor_hint(): return
	
	if get_parent().visible:
		%TitleContainer.start()
		%MainMenuScene.restart()
		%BottomMainMenu.restart()


func destroy() -> void:
	GameManager.set_cursor_manipulator("")
	$"..".destroy()


#region itemes/skills menu
func show_item_menu(_id: String) -> void:
	if animation_player and animation_player.has_animation("Show Item Menu"):
		animation_player.speed_scale = 1.7
		animation_player.play("Show Item Menu")


func hide_item_menu() -> void:
	if animation_player and animation_player.has_animation("Hide Item Menu"):
		animation_player.speed_scale = 1.0
		animation_player.play_backwards("Hide Item Menu")


func _on_item_list_item_activated(_item_type: int, _item_id: int) -> void:
	pass


func _on_item_list_item_focused(_item_type: int, _item_id: int) -> void:
	if help_label:
		help_label.text = "Show help for item %s with ID %s" % [_item_type, _item_id]

#endregion
