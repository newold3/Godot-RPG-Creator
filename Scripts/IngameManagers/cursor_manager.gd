class_name CursorManager
extends Node


var hand_cursor_path: String = "res://Scenes/GUI/default_hand_cursor.tscn"
var hand_cursor: MainHandCursor
var backup_hand_data: Array = []



func _ready() -> void:
	if not Engine.is_editor_hint():
		if AssetManager.exists(hand_cursor_path):
			hand_cursor = load(hand_cursor_path).instantiate()
			add_child(hand_cursor)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not hand_cursor: 
		return
	hand_cursor.update(delta)


func manage_cursor(node: Variant, offset: Vector2 = Vector2.ZERO) -> void:
	set_cursor_manipulator(node)
	hide_cursor(false, node)
	set_cursor_offset(offset, node)
	tree_exiting.connect(
		func():
			hide_cursor(false, node)
			set_cursor_offset(Vector2.ZERO, node)
	)


func show_cursor(hand_position: MainHandCursor.HandPosition = MainHandCursor.HandPosition.LEFT, manipulator_context: Variant = null, default_offset: Vector2 = Vector2.ZERO) -> void:
	if hand_cursor:
		hand_cursor.show_cursor(hand_position, manipulator_context, default_offset)


func force_show_cursor() -> void:
	if hand_cursor:
		hand_cursor.force_show()


func force_hide_cursor() -> void:
	if hand_cursor:
		hand_cursor.force_hide()


func hide_cursor(instant_hide: bool = false, manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.hide_cursor(instant_hide, manipulator_context)


func get_hand_style() -> MainHandCursor.HandPosition:
	if hand_cursor:
		return hand_cursor.current_hand_position
	return MainHandCursor.HandPosition.LEFT


func set_cursor_manipulator(manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.set_manipulator(manipulator_context)


func get_cursor_manipulator() -> Variant:
	if hand_cursor:
		return hand_cursor.manipulator
	return ""


func set_hand_properties(
	current_hand_position: MainHandCursor.HandPosition = MainHandCursor.HandPosition.LEFT,
	hand_offset: Vector2 = Vector2.ZERO,
	confined_area: Rect2 = Rect2(),
	manipulator_context: Variant = null) -> void:
	
	if hand_cursor:
		hand_cursor.manipulator = manipulator_context
		hand_cursor.hand_offset = hand_offset
		hand_cursor.confined_area = confined_area
		hand_cursor.current_hand_position = current_hand_position


func backup_hand_properties() -> void:
	if hand_cursor:
		backup_hand_data.append({
			"manipulator": hand_cursor.manipulator,
			"hand_offset": hand_cursor.hand_offset,
			"confined_area": hand_cursor.confined_area,
			"current_hand_position": hand_cursor.current_hand_position
		})


func restore_hand_properties() -> void:
	if backup_hand_data and not backup_hand_data.is_empty() and hand_cursor:
		var hand_data = backup_hand_data.pop_back()
		hand_cursor.manipulator = hand_data.manipulator
		hand_cursor.hand_offset = hand_data.hand_offset
		hand_cursor.confined_area = hand_data.confined_area
		hand_cursor.current_hand_position = hand_data.current_hand_position


func set_confin_area(area: Rect2, manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.set_confin_area(area, manipulator_context)


func set_hand_position(hand_position: MainHandCursor.HandPosition = MainHandCursor.HandPosition.LEFT, _manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.current_hand_position = hand_position


func force_hand_position_over_node(manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.force_hand_position_over_node(manipulator_context)


func get_cursor_position() -> Vector2:
	if hand_cursor:
		return hand_cursor.get_cursor_position()
	return Vector2.INF


func set_cursor_offset(offset: Vector2, manipulator_context: Variant = null) -> void:
	if hand_cursor:
		hand_cursor.set_cursor_offset(offset, manipulator_context)
