extends GuiCoreIngameItemList

const SFX_SLIDE_MENU = preload("uid://cegbob6fb11g2")

var right_decoration_spin: Tween


func _animate_start() -> void:
	GameManager.play_se(SFX_SLIDE_MENU)
	
	if has_node("%MainAnimator"):
		var node = %MainAnimator
		var t = create_tween()
		t.tween_property(node, "speed_scale", 1.5, 0.2).from(0.0)
		if has_node("%ItemList"):
			t.tween_callback(%ItemList.restore_selection)
		t.tween_property(node, "speed_scale", 0.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	else:
		if has_node("%ItemList"):
			%ItemList.restore_selection()


func _animate_end() -> void:
	if right_decoration_spin:
		right_decoration_spin.kill()
	
	if has_node("%MainAnimator"):
		var node = %MainAnimator
		var t = create_tween()
		t.tween_property(node, "speed_scale", 1.5, 0.1).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
		t.tween_callback(func(): close_requested.emit())
		t.tween_property(node, "speed_scale", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	else:
		close_requested.emit()


func _animate_spin(direction: String) -> void:
	if right_decoration_spin:
		right_decoration_spin.kill()
	
	if has_node("%MainAnimator"):
		var node = %MainAnimator
		if direction == "right":
			node.play("gears_on")
		else:
			node.play_backwards("gears_on")
			
		right_decoration_spin = create_tween()
		right_decoration_spin.tween_property(node, "speed_scale", 0.8, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		right_decoration_spin.tween_property(node, "speed_scale", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	if direction == "right" and has_node("%PanelL2Tab"):
		var panel = %PanelL2Tab
		panel.pivot_offset = Vector2(panel.size.x, panel.size.y * 0.5)
		var t = create_tween()
		t.tween_property(panel, "scale:x", 1.1, 0.1)
		t.tween_property(panel, "scale:x", 1.0, 0.2)
	elif direction != "right" and has_node("%PanelR2Tab"):
		var panel = %PanelR2Tab
		panel.pivot_offset = Vector2(0, panel.size.y * 0.5)
		var t = create_tween()
		t.tween_property(panel, "scale:x", 1.1, 0.1)
		t.tween_property(panel, "scale:x", 1.0, 0.2)
