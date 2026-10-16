extends PanelContainer

## Automatically select the first button when the menu opens
@export var auto_select_button: bool = true
## Delay before the first button is selected
@export var initial_selection_delay: float = 0.15

@onready var button_container: Control = %ButtonContainer

var button_names = [
	"Items", "Skills", "Equipment", "Status", "Formation", 
	"Quests", "Encyclopedia", "Options", "Save", "Game End"
]
var button_tooltips = [
	"Items Help", "Skills Help", "Equipment Help", "Status Help", "Formation Help",
	"Quests Help", "Encyclopedia Help", "Options Help", "Save Help", "Game End Help"
]
var button_mapping: Dictionary = {
	0: 0,  # Items
	1: 1,  # Skills
	2: 2,  # Equipment
	3: 3,  # Status
	4: 4,  # Formation
	5: 5,  # Quests
	6: 10, # Encyclopedia / Library
	7: 7,  # Options (3rd from end)
	8: 6,  # Save (2nd from end)
	9: 8   # Game End (last item)
}
var current_button
var current_button_index: int = 0
var busy: bool = false
var fixed_disabled_buttons: Array[Node] = []

signal button_hovered(button: Control, index: int, tooltip: String)
signal selected(obj: Control, real_index: int)
signal begin_click(id: int)
signal clicked(id: int)
@warning_ignore("unused_signal")
signal started_animation_finished()
signal selection_completed()
signal finish()


#region Functions
## Initialize the menu state and configure buttons
func _ready() -> void:
	_prepare_fixed_disabled_buttons()
	_disabled()
	_config_buttons()
	start()
	
	if auto_select_button:
		restart()


## Prepare the list of permanently disabled buttons based on game state
func _prepare_fixed_disabled_buttons() -> void:
	fixed_disabled_buttons.clear()
	
	var disabled_db_ids: Array = []
	
	if not GameManager.game_state or GameManager.game_state.current_party.is_empty():
		disabled_db_ids = [1, 2, 3, 4] # Skills, Equipment, Status, Formation
	
	for button: Control in button_container.get_children():
		var visual_index = button.get_index()
		var db_id = button_mapping.get(visual_index, visual_index)
		
		if db_id in disabled_db_ids:
			fixed_disabled_buttons.append(button)
		
		if GameManager.game_state:
			if GameManager.game_state.save_scene_prohibited and db_id == 6:
				if not button in fixed_disabled_buttons:
					fixed_disabled_buttons.append(button)
			
			if GameManager.game_state.formation_scene_prohibited and db_id == 4:
				if not button in fixed_disabled_buttons:
					fixed_disabled_buttons.append(button)


## Restart the button logic and focus targeting
func restart() -> void:
	busy = false
	_prepare_fixed_disabled_buttons()
	_disabled()
	start()
	
	await get_tree().create_timer(initial_selection_delay).timeout
	
	if not is_instance_valid(self) or not is_inside_tree(): return
	
	_enabled()
	select_button()
	
	var manipulator = GameManager.get_cursor_manipulator()
	GameManager.force_hand_position_over_node(manipulator)
	GameManager.force_show_cursor()


## Get a button reference by its database ID
func get_button(button_id: int) -> Control:
	for button: Control in button_container.get_children():
		var visual_index = button.get_index()
		if button_mapping.get(visual_index, visual_index) == button_id:
			return button
	
	return null


## Set the starting state for all buttons
func set_starting() -> void:
	for button: Control in button_container.get_children():
		button.set_disabled()


## Configure the cursor manipulator specifically for the main menu buttons
func _config_hand_over_menu_main_buttons() -> void:
	var hand_manipulator = GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS
	GameManager.set_cursor_manipulator(hand_manipulator)
	GameManager.set_confin_area(Rect2(), hand_manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.RIGHT, hand_manipulator)
	GameManager.set_cursor_offset(Vector2(-16, 0), hand_manipulator)
	ControllerManager.set_focusable_control_threshold(150, 150)


## Apply cursor configuration
func config_cursor() -> void:
	_config_hand_over_menu_main_buttons()


## Handle process logic and manual input validation
func _process(_delta: float) -> void:
	if busy: return

	if GameManager.get_cursor_manipulator() == GameManager.MANIPULATOR_MODES.MAIN_MENU_MAIN_BUTTONS:
		var direction = ControllerManager.get_pressed_direction()
		
		if direction and direction in ["up", "down"]:
			_change_selected_control(direction)
		elif ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0], true):
			end()
		elif ControllerManager.is_confirm_just_pressed(false, [KEY_KP_ENTER], true, true):
			clicked.emit(current_button_index)


## Change the selected control based on input direction
func _change_selected_control(direction: String) -> void:
	var new_control = ControllerManager.get_closest_focusable_control(current_button, direction, true)
	if new_control:
		if new_control.has_method("select"):
			new_control.select()
		else:
			new_control.grab_focus()
		
		GameManager.play_fx("cursor")


## Configure all buttons with their corresponding data and signals
func _config_buttons() -> void:
	for button: Control in button_container.get_children():
		var visual_index = button.get_index()
		var db_id = button_mapping.get(visual_index, visual_index)
		
		if visual_index < button_names.size():
			button.button_text = RPGSYSTEM.database.terms.search_message(button_names[visual_index])
		
		button.focus_entered.connect(
			func():
				current_button_index = db_id
				var button_tooltip: String = RPGSYSTEM.database.terms.search_message(button_tooltips[visual_index])
				button_hovered.emit(button, db_id, button_tooltip)
				button.z_index = 100
				_config_hand_over_menu_main_buttons()
		)
		
		button.focus_exited.connect(
			func():
				button.z_index = 0
		)
		
		button.selected.connect(
			func(b):
				current_button_index = db_id
				current_button = button
				selected.emit(b, db_id)
				b.keep_selected_state = false
		)
		
		button.begin_click.connect(
			func(_i):
				current_button = button
				begin_click.emit(db_id)
		)
		
		button.clicked.connect(
			func(_i):
				if not button.is_selected:
					button.select()
					button.keep_selected_state = true
				clicked.emit(db_id)
		)
		
		button.mouse_entered.connect(
			func():
				var button_tooltip: String = RPGSYSTEM.database.terms.search_message(button_tooltips[visual_index])
				button_hovered.emit(button, db_id, button_tooltip)
		)


## Disable animations on all buttons
func disable_animations() -> void:
	for button in button_container.get_children():
		button.disable_animations()


## Enable animations on all buttons
func enable_animations() -> void:
	for button in button_container.get_children():
		button.enable_animations()


## Enable the entire button set
func enabled() -> void:
	_enabled()


## Disable the entire button set
func disabled() -> void:
	_disabled()


## Internal function to enable interactable buttons
func _enabled() -> void:
	for button in button_container.get_children():
		if not button in fixed_disabled_buttons:
			button.set_enabled()


## Internal function to disable all buttons
func _disabled() -> void:
	for button in button_container.get_children():
		button.set_disabled()


## Disable a specific button by its database ID
func disable_button(index: int) -> void:
	for button: Control in button_container.get_children():
		var visual_index = button.get_index()
		if button_mapping.get(visual_index, visual_index) == index:
			button.set_disabled()
			break


## Enable a specific button by its database ID
func enable_button(index: int) -> void:
	for button: Control in button_container.get_children():
		var visual_index = button.get_index()
		if button_mapping.get(visual_index, visual_index) == index:
			if not button in fixed_disabled_buttons:
				button.set_enabled()
			break


## Remove keep selection state from all buttons
func remove_any_keep_state() -> void:
	for button: Control in button_container.get_children():
		button.keep_selected_state = false
		button.busy = false
		button.busy2 = false


## Set keep selected state strictly on the target button
func _set_keep_selected_state(button: Control) -> void:
	for other_button: Control in button_container.get_children():
		if other_button == button:
			other_button.keep_selected_state = true
		else:
			other_button.keep_selected_state = false
			other_button.busy = false
			if other_button.has_method("_on_focus_exited"):
				other_button._on_focus_exited()


## Calculate the total time required for the animation
func get_total_animation_time() -> float:
	return 0.2


var _button_tween: Tween

## Trigger the container's starting animation sequence
func start() -> void:
	if _button_tween: _button_tween.kill()
	modulate.a = 0.0
	_button_tween = create_tween()
	_button_tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	started_animation_finished.emit()


## Trigger the container's ending animation sequence
func end() -> void:
	if _button_tween: _button_tween.kill()
	_button_tween = create_tween()
	_button_tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_button_tween.tween_callback(func(): finish.emit())


## Select a valid button and update the UI focus
func select_button() -> void:
	busy = true
	var target_visual_index = -1
	
	for v_idx in button_mapping:
		if button_mapping[v_idx] == current_button_index:
			target_visual_index = v_idx
			break
			
	if target_visual_index == -1:
		target_visual_index = current_button_index
		
	if target_visual_index >= 0 and target_visual_index < button_container.get_child_count():
		var button = button_container.get_child(target_visual_index)
		
		if button.is_enabled:
			button.busy = false
			button.select()
		else:
			for i in range(button_container.get_child_count()):
				var b = button_container.get_child(i)
				if b.is_enabled:
					b.busy = false
					b.select()
					current_button_index = button_mapping.get(i, i)
					break
			
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	selection_completed.emit()
	busy = false
#endregion
