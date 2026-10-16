extends GuiCoreStatsDrawPanel

#region VisualAssets
@export var upgrade_icon: TextureRect
#endregion

#region VisualOverrides
func _on_equipment_evaluation_result(result: int) -> void:
	super._on_equipment_evaluation_result(result)
	if not upgrade_icon: return
	upgrade_icon.visible = result != -1
	if show_comparison and upgrade_icon.texture and "region" in upgrade_icon.texture:
		upgrade_icon.texture.region.position.x = 0 if result == 0 else upgrade_icon.texture.region.size.x


func _on_show_comparison_changed(show: bool) -> void:
	if upgrade_icon:
		upgrade_icon.visible = show
#endregion
