class_name GUIManager
extends Node


var temporally_popup_disabled: bool = false


func _create_popup_message(type: int, item_id: int, quantity: int, popup_prefix = "", level = -1) -> void:
	if temporally_popup_disabled: return
	
	var obj: Dictionary
	
	if type == -10: # gold
		var icon_path = RPGSYSTEM.database.system.currency_info.icon
		var gold_name = RPGSYSTEM.database.system.currency_info.name
		
		obj = {
			"icon_path": icon_path,
			"item_name": gold_name,
			"item_color": Color(0.871, 0.687, 0.144, 1.0) if quantity > 0 \
				else Color(0.798, 0.118, 0.125, 1.0) if quantity < 0 \
				else Color.WHITE,
			"quantity": quantity,
			"prefix": popup_prefix,
			"icon_align": "right"
		}
	
	elif item_id > 0:
		@warning_ignore("incompatible_ternary")
		var data = RPGSYSTEM.get_data("items", item_id) if type == 0 \
			else RPGSYSTEM.get_data("weapons", item_id) if type == 1 \
			else RPGSYSTEM.get_data("armors", item_id) if type == 2 \
			else RPGSYSTEM.get_data("costumes", item_id)
		
		if data:
			var rarity_type = data.rarity_type if item_id < 3 else 0
			@warning_ignore("incompatible_ternary")
			var types = RPGSYSTEM.database.types.item_rarity_color_types if type == 0 \
				else RPGSYSTEM.database.types.weapon_rarity_color_types if type == 1 \
				else RPGSYSTEM.database.types.armor_rarity_color_types if type == 2 \
				else []
			
			var icon: RPGIcon
			if data is RPGCostume:
				var path = data.lpc_part
				var preview_path = path.get_basename().trim_suffix("_data") + "_preview.png"
				icon = RPGIcon.new(preview_path)
			elif "icon" in data:
				icon = data.icon
			else:
				icon = RPGIcon.new()
			
			var color = Color.WHITE if rarity_type < 1 or types.size() <= rarity_type else types[rarity_type]
		
			obj = {
				"icon_path": icon,
				"item_name": data.name + ("" if level == -1 else " (" + tr("Lv ") + str(level) + ")"),
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
