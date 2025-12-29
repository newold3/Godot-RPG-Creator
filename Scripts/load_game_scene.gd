class_name LoadSaveMainScript
extends WindowBase


var current_slot_selected: int = 0
var current_list = 0
var back_list = 0

const MAX_SAVE_SLOTS = 10
const SAVE_SLOT = preload("res://Scenes/LoadSaveScene/save_slot.tscn")

@onready var slots_container: VBoxContainer = %SlotsContainer


func _ready() -> void:
	create_save_slots()
	GameManager.set_text_config(self)
	%BackButton.focus_entered.connect(_config_hand_in_back_button)
	_config_hand_in_main_buttons()
	start()


func _config_hand_in_main_buttons() -> void:
	var manipulator = slots_container
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.LEFT, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 0), manipulator)
	var rect = %SaveContainer.get_rect()
	rect.position.y += 16
	rect.size.y += 16
	GameManager.set_confin_area(rect, manipulator)


func _config_hand_in_back_button() -> void:
	var manipulator = slots_container
	GameManager.set_cursor_manipulator(manipulator)
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, manipulator)
	GameManager.set_cursor_offset(Vector2(0, 2), manipulator)
	GameManager.set_confin_area(Rect2(), manipulator)


func _process(_delta: float) -> void:
	if not %BackButton.has_focus():
		_config_hand_in_main_buttons()
	else:
		_config_hand_in_back_button()

	if current_list == 0 and %BackButton.has_focus():
		%SlotsContainer.get_child(current_slot_selected).select(false)
	elif current_list == 1:
		if not %BackButton.has_focus():
			%BackButton.grab_focus()
		var direction = ControllerManager.get_pressed_direction()
		if direction:
			slots_container.get_child(current_slot_selected).select()
			GameManager.play_fx("cursor")
	
	if not busy and GameManager.get_cursor_manipulator() == scene_manipulator:
		if ControllerManager.is_cancel_just_pressed([KEY_0, KEY_KP_0]):
			get_viewport().set_input_as_handled()
			%BackButton._on_pressed()


func create_save_slots() -> void:
	for child in slots_container.get_children():
		slots_container.remove_child(child)
		child.queue_free()
		
	for i in MAX_SAVE_SLOTS:
		var slot = SAVE_SLOT.instantiate()
		slots_container.add_child(slot)
		slot.selected.connect(_on_save_slot_selected)
		slot.direction_pressed.connect(_on_direction_pressed)
		slot.set_no_data_label(tr("SLOT") + " " + str(i+1) + " - " + tr("NO DATA"))


func _on_direction_pressed(direction: String) -> void:
	if busy: return
	
	if ["left", "right"].has(direction):
		current_list = wrapi(current_list + 1, 0, 2)
		back_list = current_list
		get_viewport().set_input_as_handled()
		if current_list == 0:
			%BackButton.deselect(true)
			slots_container.get_child(current_slot_selected).call_deferred("select")
		else:
			%BackButton.call_deferred("select")
		
		GameManager.play_fx("cursor")

	elif current_list == 0:
		var current_index = current_slot_selected
		var slots = slots_container.get_children()
		if current_index >= 0:
			var next_index: int
			if direction == "up":
				next_index = wrapi(current_index - 1, 0, slots_container.get_child_count())
			else:
				next_index = wrapi(current_index + 1, 0, slots_container.get_child_count())
			slots[next_index].select()
			current_slot_selected = next_index

	get_viewport().set_input_as_handled()


func _on_save_slot_selected(node: PanelContainer, index: int) -> void:
	if busy: return
	
	for child in slots_container.get_children():
		if child != node:
			child.deselect()
	
	%BackButton.deselect(true)
	
	current_list = 0
	current_slot_selected = index
	
	_config_hand_in_main_buttons()
	
	await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame
		%SaveContainer.call_deferred("bring_focus_target_into_view", false)


func start() -> void:
	var node3 = %BackButton
	
	node3.visible = false
	node3.modulate.a = 0
	
	super()
	
	main_tween.tween_callback(node3.set.bind("visible", true))
	main_tween.tween_property(node3, "modulate:a", 1.0, 0.8)
	
	var t = create_tween()
	t.tween_callback(
		func():
			GameManager.show_cursor(MainHandCursor.HandPosition.LEFT, slots_container)
			GameManager.set_confin_area(%Contents.get_rect())
	).set_delay(0.4)
	
	if slots_container.get_child_count() > 0:
		slots_container.get_child(0).select(false)
	else:
		node3.select(false)


func end() -> void:
	super()
	
	%BackButton.visible = false
	
	GameManager.hide_cursor(false, slots_container)


func _on_back_button_selected(_obj: TextureButton) -> void:
	if busy: return
	
	for child in slots_container.get_children():
		child.deselect()


func _on_back_button_focus_exited() -> void:
	if busy: return
	slots_container.get_child(current_slot_selected).select()


func _on_back_button_end_click() -> void:
	if busy: return
	end()


func _on_back_button_begin_click() -> void:
	current_list = 1
	
	if busy: return
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(%Contents, "modulate:a", 0.75, 0.5)
	t.tween_property(%Contents, "scale", Vector2(1.04, 1.01), 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _on_back_button_focus_entered() -> void:
	GameManager.set_hand_position(MainHandCursor.HandPosition.UP, slots_container)


func _on_back_button_mouse_entered() -> void:
	back_list = current_list
	current_list = 1


func _on_back_button_mouse_exited() -> void:
	current_list = back_list
