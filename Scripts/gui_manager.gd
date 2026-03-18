class_name GUIManager
extends Node


var temporally_popup_disabled: bool = false


func _create_popup_message(type: int, item_id: int, quantity: int, popup_prefix = "", level = -1) -> void:
	if temporally_popup_disabled: return
	
	var obj: Dictionary
	
	if item_id > 0:
		@warning_ignore("incompatible_ternary")
		var data = RPGSYSTEM.database.items if type == 0 \
			else RPGSYSTEM.database.weapons if type == 1 \
			else RPGSYSTEM.database.armors
		
		if data.size() > item_id:
			var real_data = data[item_id]
			var rarity_type = real_data.rarity_type
			var types = RPGSYSTEM.database.types.item_rarity_color_types if type == 0 \
				else RPGSYSTEM.database.types.weapon_rarity_color_types if type == 1 \
				else RPGSYSTEM.database.types.armor_rarity_color_types
			
			var color = Color.WHITE if rarity_type < 1 or types.size() <= rarity_type else types[rarity_type]
		
			obj = {
				"icon_path": real_data.icon,
				"item_name": real_data.name + ("" if level == -1 else " (" + tr("Lv ") + str(level) + ")"),
				"item_color": color,
				"quantity": quantity,
				"prefix": popup_prefix
			}
	
	if obj:
		show_popup_message(obj)


func show_popup_message(obj: Dictionary) -> void:
	if temporally_popup_disabled: return
	
	if GameManager.main_scene:
		GameManager.main_scene.show_popup_message(obj)


func is_mouse_over_current_control_focused() -> bool:
	var control = get_viewport().gui_get_focus_owner()
	if control and control.get_global_rect().has_point(control.get_global_mouse_position()):
		return true
		
	return false
