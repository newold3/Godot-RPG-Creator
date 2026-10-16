extends GuiCoreSelectedEquipmentCard

#region VisualAssets
@export var icon_lit_texture: Texture2D
@export var icon_unlit_texture: Texture2D
#endregion

#region NodeReferences
@onready var icon: TextureRect = %Icon if has_node("%Icon") else null
@onready var item_name_label: Label = %ItemName if has_node("%ItemName") else null
@onready var current_level_label: Label = %CurrentLevel if has_node("%CurrentLevel") else null
@onready var max_level_label: Label = %MaxLevel if has_node("%MaxLevel") else null
@onready var star_icon: TextureRect = %StarIcon if has_node("%StarIcon") else null
@onready var progress_bar_container: Control = %ProgressBarContainer if has_node("%ProgressBarContainer") else null
@onready var progress_bar: TextureProgressBar = %ProgressBar if has_node("%ProgressBar") else null
@onready var maximun_level_label: Label = %MaximunLevel if has_node("%MaximunLevel") else null
@onready var empty_slot_label: Label = %EmptySlotLabel if has_node("%EmptySlotLabel") else null
#endregion

#region VisualOverrides
func _display_empty_item() -> void:
	if icon: icon.texture = null
	if item_name_label: item_name_label.text = ""
	if current_level_label: current_level_label.text = ""
	if max_level_label: max_level_label.text = ""
	if progress_bar_container: progress_bar_container.visible = false
	if empty_slot_label: empty_slot_label.visible = true


func _display_item(data: Dictionary) -> void:
	if empty_slot_label: empty_slot_label.visible = false
	if icon: icon.texture = data.texture
	if item_name_label:
		item_name_label.text = data.name
		item_name_label.set("theme_override_colors/font_color", data.color)
	if current_level_label:
		current_level_label.text = str(data.current_level)

	if data.max_level > 1:
		if max_level_label: max_level_label.text = "/" + str(data.max_level)
		if star_icon: star_icon.texture = icon_lit_texture if data.current_level == data.max_level else icon_unlit_texture
		if progress_bar_container: progress_bar_container.visible = true
		if data.is_max_level:
			if progress_bar: progress_bar.value = 1.0
			if maximun_level_label: maximun_level_label.visible = true
		else:
			if progress_bar: progress_bar.value = data.progress
			if maximun_level_label: maximun_level_label.visible = false
	else:
		if max_level_label: max_level_label.text = ""
		if star_icon: star_icon.texture = icon_lit_texture
		if progress_bar_container: progress_bar_container.visible = false
		if maximun_level_label: maximun_level_label.visible = false
#endregion
