extends Node

@export var scene_parent: BaseAnimatableWindow
@export var back_button: Control
@export var title_scene: Control

const MANIPULATOR: String = "BASE_SUB_MENU_MANIPULATOR"

var current_actor: GameActor
var is_closing: bool = false
var _last_manipulator: Variant

func _ready() -> void:
	_last_manipulator = GameManager.get_cursor_manipulator()
	
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = false

	if not scene_parent:
		scene_parent = get_parent() as BaseAnimatableWindow
	if not back_button and has_node("../SceneMainContainer/BackButton"):
		back_button = get_node("../SceneMainContainer/BackButton") as Control
	if not title_scene and has_node("../SceneMainContainer/MainContainer/Title/TitleContainer"):
		title_scene = get_node("../SceneMainContainer/MainContainer/Title/TitleContainer") as Control

	if back_button:
		if not back_button.pressed.is_connected(_on_back_pressed):
			back_button.pressed.connect(_on_back_pressed)
		if not back_button.selected.is_connected(_on_back_selected):
			back_button.selected.connect(_on_back_selected)
		if not back_button.mouse_entered.is_connected(_on_back_mouse_entered):
			back_button.mouse_entered.connect(_on_back_mouse_entered)

	if scene_parent:
		if not scene_parent.animation_in_finished.is_connected(_on_animation_in_finished):
			scene_parent.animation_in_finished.connect(_on_animation_in_finished)


func set_actor(actor: GameActor) -> void:
	current_actor = actor


func _on_animation_in_finished() -> void:
	if is_closing:
		return
	if back_button and back_button.has_method("grab_focus"):
		back_button.grab_focus()
	_config_hand_for_back_button()


func _config_hand_for_back_button() -> void:
	if is_closing:
		return
	GameManager.set_cursor_manipulator(MANIPULATOR)
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, MANIPULATOR)
	GameManager.set_cursor_offset(Vector2(0, 2), MANIPULATOR)
	GameManager.set_confin_area(Rect2(), MANIPULATOR)
	GameManager.force_show_cursor()
	GameManager.force_hand_position_over_node(MANIPULATOR)


func _on_back_selected() -> void:
	GameManager.play_fx("cursor")
	_config_hand_for_back_button()


func _on_back_mouse_entered() -> void:
	if is_closing or not is_inside_tree():
		return
	if back_button:
		if not back_button.has_focus() and back_button.has_method("grab_focus"):
			back_button.grab_focus()
		_config_hand_for_back_button()


func _input(event: InputEvent) -> void:
	if is_closing or not is_inside_tree() or not get_parent().is_visible_in_tree():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back_pressed()
			return

	if ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return

	if ControllerManager.is_confirm_pressed(false, [], true, []):
		if back_button and back_button.has_focus():
			get_viewport().set_input_as_handled()
			_on_back_pressed()
			return


func _on_back_pressed() -> void:
	if is_closing:
		return
	is_closing = true
	
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = true
	
	GameManager.force_hide_cursor()
	GameManager.play_fx("cancel")
	
	if title_scene and title_scene.has_method("end"):
		title_scene.end()
	if scene_parent and scene_parent.has_method("destroy"):
		scene_parent.destroy()
		
	GameManager.set_cursor_manipulator(_last_manipulator)


func _exit_tree() -> void:
	if GameManager.cursor_manager and GameManager.cursor_manager.hand_cursor:
		GameManager.cursor_manager.hand_cursor.hide_hand_when_mouse_over_focused = true
