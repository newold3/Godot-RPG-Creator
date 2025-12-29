@tool
extends MarginContainer


@export var button_size: Vector2 = Vector2(100, 100) : set = _set_button_size

var main_tween: Tween


signal button_clicked(index: int)
signal button_selected(index: int)
signal change_focus_requested()
signal back_pressed()
signal change_hero_by_hotkey()


func _ready() -> void:
	%SmoothScrollContainer.single_target_focus = %ButtonsVerticalMenuContainer.get_focus_control()
	%ButtonsVerticalMenuContainer.button_clicked.connect(func(index): button_clicked.emit(index))
	%ButtonsVerticalMenuContainer.button_selected.connect(func(index): button_selected.emit(index))
	_fill_actors()


func start() -> void:
	if main_tween:
		main_tween.kill()
	
	var a = PI / 2.0
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%GearTop, "rotation", a, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(%GearBottom, "rotation", a, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.01)
	t.set_parallel(false)
	t.tween_callback(set.bind("started", [true]))


func end() -> void:
	if main_tween:
		main_tween.kill()


func _fill_actors() -> void:
	if not GameManager.game_state: return
	
	var textures: Array[Dictionary] = []
	var real_ids: PackedInt32Array = []
	for actor_id in GameManager.game_state.current_party:
		var actor: GameActor = GameManager.get_actor(actor_id)
		if actor:
			var real_actor: RPGActor = actor.get_real_actor()
			if real_actor:
				var current_icon: RPGIcon = real_actor.face_preview
				var tex = null
				
				if current_icon and ResourceLoader.exists(current_icon.path):
					tex = ResourceLoader.load(current_icon.path)
					
				textures.append({"texture": tex, "region": current_icon.region})
				real_ids.append(real_actor.id)

	set_images(textures)
	set_real_ids(real_ids)


func _process(_delta: float) -> void:
	var manipulator = GameManager.get_cursor_manipulator()
	if manipulator in [GameManager.MANIPULATOR_MODES.EQUIP_ACTORS_MENU, GameManager.MANIPULATOR_MODES.EQUIP_MENU]:
		if ControllerManager.is_action_pressed("Button L1"):
			navigate_button(-1)
			change_hero_by_hotkey.emit()
		elif ControllerManager.is_action_pressed("Button R1"):
			navigate_button(1)
			change_hero_by_hotkey.emit()
		elif manipulator == GameManager.MANIPULATOR_MODES.EQUIP_ACTORS_MENU:
			var direction = ControllerManager.get_pressed_direction()
			if direction and direction in ["up", "down"]:
				if direction == "up":
					navigate_button(-1)
				else:
					navigate_button(1)
			elif direction and direction in ["left", "right"] or ControllerManager.is_confirm_just_pressed():
				get_viewport().set_input_as_handled()
				GameManager.play_fx("cursor")
				change_focus_requested.emit()
			elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
				back_pressed.emit()


func _set_button_size(value: Vector2) -> void:
	button_size = value
	if is_inside_tree():
		%ButtonsVerticalMenuContainer.button_size = button_size


func set_images(value: Array[Dictionary]) -> void:
	%ButtonsVerticalMenuContainer.set_images(value)


func set_real_ids(value: PackedInt32Array) -> void:
	%ButtonsVerticalMenuContainer.set_real_ids(value)


func select(id: int, skip_animation: bool = false) -> void:
	%ButtonsVerticalMenuContainer.select_button_by_index(id, skip_animation)


func select_last_button() -> void:
	%ButtonsVerticalMenuContainer.select_last_button()


func navigate_button(direction: int) -> void:
	%ButtonsVerticalMenuContainer.navigate_button(direction)
