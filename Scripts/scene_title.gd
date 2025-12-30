@tool
class_name SCENE_TITTLE
extends Control

@export var rich_gradient_shader: ShaderMaterial

@export var logo_scale: Vector2 = Vector2(0.78, 0.78)

@export var scene_manipulator: String

var paths: Array

var speed: float = 0.05

var scene_loader: PackedScene
var scene_credits: PackedScene
var options_scene: PackedScene

var busy: bool = false

var current_item: int = 0
var current_button_list: int = 0
var sub_scene_opened: bool =  false

@onready var menu_buttons: VBoxContainer = %MenuButtons
@onready var credits_button: Button = %CreditsButton
@onready var button_1: Button = %Button1
@onready var button_2: Button = %Button2
@onready var button_3: Button = %Button3
@onready var button_4: Button = %Button4



func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	
	scene_loader = load(RPGSYSTEM.database.system.game_scenes["Scene Load Game"])
	scene_credits = load(RPGSYSTEM.database.system.game_scenes["Scene Credits"])
	options_scene = load(RPGSYSTEM.database.system.game_scenes["Scene Options"])
	
	GameManager.starting_menu = self
	GameManager.current_save_slot = -1
	
	tree_exiting.connect(GameManager.set.bind("starting_menu", null))
	
	GameManager.set_text_config(self)
	if not %GameTitle.font_size_changed.is_connected(_on_game_title_font_size_changed):
		%GameTitle.font_size_changed.connect(_on_game_title_font_size_changed)
	
	set_game_title()
	set_buttons()
	
	paths = %Path2D.get_children()
	paths.append_array(%Path2D2.get_children())
	for node in paths:
		var s = randf_range(0.6, 1.0)
		node.scale = Vector2(s, s)
	
	%GameTileOutline.set("theme_override_font_sizes/font_size", %GameTitle.get("theme_override_font_sizes/font_size"))
	if %GameTileOutline.label_settings:
		%GameTileOutline.label_settings.font_size = %GameTitle.get("theme_override_font_sizes/font_size")
	%GameTileOutline.set("theme_override_constants/outline_size", 8)
	%GameTileOutline.text = %GameTitle.text
	%GameTitle.set("theme_override_constants/outline_size", 0)
	
	var exists_savefile = SaveLoadManager.has_any_save_file()
	if not exists_savefile:
		button_2.set_fake_disabled(true)
	
	start_animation()


func set_brightness() -> void:
	if GameManager.current_game_options:
		var brightness = GameManager.current_game_options.brightness
		var canvas = %CanvasModulate
		if not canvas.has_meta("original_color"):
			canvas.set_meta("original_color", canvas.color)
		var original_color: Color = canvas.get_meta("original_color")
		canvas.color = original_color * brightness
		canvas.color.a = original_color.a


func _config_hand_in_credit_button() -> void:
	var manipulator = scene_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.force_show_cursor()


func _config_hand_in_other_button() -> void:
	var manipulator = scene_manipulator
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)
	GameManager.force_show_cursor()


func set_game_title() -> void:
	var node = %GameTitle
	node.text = RPGSYSTEM.database.system.game_title
	await get_tree().process_frame
	node.material = rich_gradient_shader.duplicate()
	node.material.set_shader_parameter("size", node.size)


func set_buttons() -> void:
	var buttons = [credits_button, button_1, button_2, button_3, button_4]
	var texts = ["Credits", "New Game", "Load Game", "Options", "Game End"]
	for i in buttons.size():
		buttons[i].button_name = RPGSYSTEM.database.terms.search_message(texts[i])
		buttons[i].set_label_material(rich_gradient_shader.duplicate())
		buttons[i].get_label_material().set_shader_parameter("size", buttons[i].size)



func start_animation() -> void:
	busy = true
		
	GameManager.play_music("title")
	
	button_1.grab_focus()
	GameManager.force_hand_position_over_node()
	
	var node = %Logo
	node.scale = Vector2.ZERO
	node.rotation = PI * 3.0
	node.modulate.a = 0.0
	
	var t = create_tween()
	t.set_parallel(true)
	
	var delay = 0.9
	t.tween_property(node, "scale", logo_scale, delay).set_trans(Tween.TRANS_BACK)
	t.tween_property(node, "rotation", 0.0, delay)
	t.tween_property(node, "modulate:a", 1.0, delay * 0.25)
	t.tween_property(node, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.1).set_delay(delay)
	t.tween_property(node, "modulate", Color.WHITE, 0.25).set_delay(delay + 0.1)
	
	t.tween_property(%GameTitle, "scale", Vector2(3.9, 2.9), 0.1).set_delay(delay - 0.15)
	t.tween_property(%GameTitle, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BOUNCE).set_delay(delay - 0.05)
	t.tween_property(%LogoContainer, "modulate", Color(1.5, 1.5, 1.5, 1), 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT).set_delay(delay + 0.45)
	t.tween_property(%LogoContainer, "modulate", Color(1, 1, 1, 1), 0.5).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN).set_delay(delay + 0.65)
	t.tween_property(%GameTitle, "scale", Vector2(1.3, 1.3), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(delay + 0.15)
	t.tween_property(%GameTitle, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(delay + 0.32)
	t.tween_property(%GameTitle, "scale", Vector2(1.1, 1.1), 0.03).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(delay + 0.47)
	t.tween_property(%GameTitle, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(delay + 0.5)
	
	t.tween_property(%Flare, "modulate:a", 1.0, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(delay + 0.3)
	t.tween_property(%Flare, "scale:x", 6.0, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(delay + 0.3).from(0.0)
	t.tween_property(%Flare, "scale:x", 7.0, 3.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(delay + 0.4)
	t.tween_property(%Flare, "scale:y", 0.8, 3.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(delay + 0.4)
	t.tween_property(%Flare, "modulate:a", 0.0, 3.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(delay + 0.4)
	
	%RadialBlurEffect.set_visible(true)
	var mat: ShaderMaterial = %RadialBlurEffect.get_material()
	mat.set_shader_parameter("blur_power", 0.159)
	t.tween_property(mat, "shader_parameter/blur_power", 0.0, delay * 0.7)
	t.tween_callback(%RadialBlurEffect.set_visible.bind(false)).set_delay(delay * 0.7)
	
	var buttons = menu_buttons.get_children()
	for i in buttons.size():
		buttons[i].modulate.a = 0.0
		if i > 0:
			buttons[i].force_scale = Vector2(1.2, 1.2)
			t.tween_property(buttons[i], "force_scale", Vector2.ONE, 0.8).set_delay(i * 0.2).set_trans(Tween.TRANS_BACK)
		t.tween_property(buttons[i], "modulate:a", 1.0, 0.8).set_delay(i * 0.2)
		t.tween_property(buttons[i], "force_rotation", 0.0, 0.3).set_delay(i * 0.2 + 0.8)
	
	t.tween_method(%Flash.set_color, Color.TRANSPARENT, Color(5, 5, 1, 0.6), 0.5).set_delay(delay-0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_method(%Flash.set_color, Color(5, 5, 1, 0.6), Color.TRANSPARENT, 0.5).set_delay(delay+0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	t.tween_callback(
		func():
			var exists_savefile = SaveLoadManager.has_any_save_file()
			var button_id = 1 if not exists_savefile else 2
			current_item = button_id - 1
			var button = get("button_%s" % button_id)
			button.can_emit_sound = false
			button.select()
			button.can_emit_sound = true
			_config_hand_in_other_button()
			GameManager.force_hand_position_over_node(scene_manipulator)
			busy = false
	).set_delay(delay)


func _process(delta: float) -> void:
	if sub_scene_opened: return
	
	for item: PathFollow2D in paths:
		item.progress_ratio = wrapf(item.progress_ratio + speed * delta * randf_range(1.0, 1.1), 0.0, 1.0)
	
	refresh_hand_cursor()
	
	if GameManager.get_cursor_manipulator() == scene_manipulator:
		_check_button_pressed()


func _check_button_pressed() -> void:
	if busy or sub_scene_opened:
		return
	
	var direction = ControllerManager.get_pressed_direction()
	if direction:
		if current_button_list == 0 and  ["up", "down"].has(direction):
			change_vertical_index(direction)
		elif ["left", "right"].has(direction):
			change_horizontal_index(direction)
	elif ControllerManager.is_mouse_button_just_pressed(MOUSE_BUTTON_LEFT):
		var buttons = [credits_button] + menu_buttons.get_children()
		for button in buttons:
			if not button.has_focus() and button.get_global_rect().has_point(get_global_mouse_position()):
				button.select(true)
				get_viewport().set_input_as_handled()
				break
	elif ControllerManager.is_confirm_just_pressed():
		if current_button_list == 0:
			var buttons = menu_buttons.get_children()
			buttons[current_item].select(true)
		else:
			credits_button.select(true)


func change_vertical_index(direction: String) -> void:
	get_viewport().set_input_as_handled()
		
	var prev_item = current_item
	if direction == "down":
		current_item = wrapi(current_item + 1, 0, 4)
	elif direction == "up":
		current_item = wrapi(current_item - 1, 0, 4)
	
	if prev_item != current_item:
		_update_button_selection()


func _update_button_selection() -> void:
	var buttons = menu_buttons.get_children()
	for button in buttons:
		button.deselect(true)
	if current_button_list == 0:
		buttons[current_item].call_deferred("select")
	else:
		credits_button.call_deferred("select")
	credits_button.deselect(true)
	buttons[current_item].select()


func _set_button_selected(button: Control, new_item: int, new_list: int) -> void:
	button.select()
	if new_item >= 0:
		current_item = new_item
	current_button_list = new_list
	_update_button_selection()


func change_horizontal_index(direction: String) -> void:
	get_viewport().set_input_as_handled()
		
	var prev_button_list = current_button_list
	if direction == "left":
		current_button_list = wrapi(current_button_list - 1, 0, 2)
	elif direction == "right":
		current_button_list = wrapi(current_button_list + 1, 0, 2)
	if prev_button_list != current_button_list:
		_update_button_selection()


func _on_button_2_click() -> void:
	var exists_savefile = SaveLoadManager.has_any_save_file()
	if not exists_savefile: return
	GameManager.set_fx_busy(true)
	_set_button_selected(button_2, 1, 0)
	_update_button_selection()
	sub_scene_opened = true
	var scn = scene_loader.instantiate()
	scn.move_in_direction = 2
	add_child(scn)
	scn.tree_exited.connect(
		func():
			set("sub_scene_opened", false)
			reset_busy()
			var _exists_savefile = SaveLoadManager.has_any_save_file()
			if not _exists_savefile:
				button_2.set_fake_disabled(true)
	)


func _on_any_button_pressed(button_id: int) -> void:
	busy = true
	var buttons = menu_buttons.get_children()
	for i in buttons.size():
		if i == button_id:
			continue
		var button = buttons[i]
		button.busy = busy
		button.deselect(true)
	if button_id != 4:
		current_item = button_id
		current_button_list = 0
		credits_button.busy = busy
		credits_button.deselect(true)
	else:
		current_button_list = 1


func reset_busy() -> void:
	if not is_instance_valid(menu_buttons): return
	busy = false
	for button in menu_buttons.get_children():
		button.busy = busy
	credits_button.busy = busy
	
	if current_button_list == 0:
		menu_buttons.get_child(current_item).select(false)
		_config_hand_in_other_button()
	else:
		credits_button.select(false)
		_config_hand_in_credit_button()
	GameManager.force_hand_position_over_node(scene_manipulator)
	GameManager.set_fx_busy(false)


func _on_credits_button_begin_click() -> void:
	GameManager.set_fx_busy(true)
	_set_button_selected(credits_button, -1, 1)
	GameManager.force_hide_cursor()
	sub_scene_opened = true
	var scn = scene_credits.instantiate()
	add_child(scn)
	if scn.has_signal("early_tree_exited"):
		scn.early_tree_exited.connect(_enable_scene)
	elif scn.has_signal("end"):
		scn.end.connect(_enable_scene)
	else:
		scn.tree_exited.connect(_enable_scene)


func _on_button_1_click() -> void:
	GameManager.set_fx_busy(true)
	set_process(false)
	_set_button_selected(button_1, 0, 0)
	button_1.select()
	_update_button_selection()
	GameManager.force_hide_cursor()
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	if GameManager.main_scene:
		GameManager.hide_cursor(false, scene_manipulator)
		await get_tree().create_timer(0.35).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return

		GameManager.main_scene.setup_new_game()
	else:
		reset_busy()


func refresh_hand_cursor() -> void:
	if busy: return
	
	if current_button_list == 0:
		var button = menu_buttons.get_child(current_item)
		if not button.has_focus(): button.select(false)
		_config_hand_in_other_button()
	else:
		var button = credits_button
		if not button.has_focus(): button.select(false)
		_config_hand_in_credit_button()


func _on_button_3_begin_click() -> void:
	GameManager.set_fx_busy(true)
	_set_button_selected(button_3, 2, 0)
	_update_button_selection()
	sub_scene_opened = true
	var scn = options_scene.instantiate()
	add_child(scn)
	if scn.has_signal("early_tree_exited"):
		scn.early_tree_exited.connect(_enable_scene)
	elif scn.has_signal("end"):
		scn.end.connect(_enable_scene)
	else:
		scn.tree_exited.connect(_enable_scene)


func _enable_scene() -> void:
	sub_scene_opened = false
	reset_busy()


func _on_button_4_begin_click() -> void:
	GameManager.set_fx_busy(true)
	_set_button_selected(button_4, 3, 0)
	_update_button_selection()
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return

	if GameManager.main_scene:
		GameManager.main_scene.change_scene("res://Scenes/EndScene/scene_end.tscn")
	else:
		get_tree().quit()


func _on_game_title_font_size_changed(new_size: int) -> void:
	%GameTileOutline.text = %GameTitle.text
	%GameTileOutline.set("theme_override_font_sizes/font_size", new_size)
	if %GameTileOutline.label_settings:
		%GameTileOutline.label_settings.font_size = new_size
