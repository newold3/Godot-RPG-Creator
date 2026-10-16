extends GuiCoreEquipmentContainer

const EQUIP_ITEM_BUTTON = preload("res://Scenes/GUI/BasicTheme/Equip/equip_item_button.tscn")


func _get_equip_button_scene() -> PackedScene:
	if equip_button_scene:
		return equip_button_scene
	return EQUIP_ITEM_BUTTON
