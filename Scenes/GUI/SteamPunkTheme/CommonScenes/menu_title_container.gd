@tool
extends GuiCoreMenuTitle


func _ready() -> void:
	if Engine.is_editor_hint() and has_node("%MenuTitle"):
		var mt = get_node("%MenuTitle")
		if mt.has_method("_fix_label"):
			visibility_changed.connect(mt._fix_label.bind(3))
	animation_time = 0.7
	super()


func _animate_start() -> void:
	if main_tween:
		main_tween.kill()

	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(self, "position", end_position, animation_time * 0.5).set_trans(Tween.TRANS_SINE).from(initial_position)

	var gears = []
	if has_node("%GearLeft1"): gears.append(%GearLeft1)
	if has_node("%GearLeft4"): gears.append(%GearLeft4)
	for i in gears.size():
		var gear = gears[i]
		gear.rotation = PI if i == 0 else -PI
		main_tween.tween_property(gear, "rotation", 0.0, animation_time * 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	gears = []
	if has_node("%GearLeft2"): gears.append(%GearLeft2)
	if has_node("%GearLeft3"): gears.append(%GearLeft3)
	for i in gears.size():
		var gear = gears[i]
		gear.rotation = PI / 2.0 if i == 0 else -PI / 2.0
		main_tween.tween_property(gear, "rotation", 0.0, animation_time * 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _animate_end() -> void:
	if main_tween:
		main_tween.kill()

	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.tween_property(self, "position", initial_position, animation_time).set_trans(Tween.TRANS_SINE)

	var gears = []
	if has_node("%GearLeft1"): gears.append(%GearLeft1)
	if has_node("%GearLeft4"): gears.append(%GearLeft4)
	for i in gears.size():
		var gear = gears[i]
		var r = PI if i == 0 else -PI
		main_tween.tween_property(gear, "rotation", r, animation_time).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	gears = []
	if has_node("%GearLeft2"): gears.append(%GearLeft2)
	if has_node("%GearLeft3"): gears.append(%GearLeft3)
	for i in gears.size():
		var gear = gears[i]
		var r = PI / 2.0 if i == 0 else -PI / 2.0
		main_tween.tween_property(gear, "rotation", r, animation_time).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
