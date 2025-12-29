@tool
extends Control

var zoom_level: Vector2 = Vector2.ONE
var min_zoom: Vector2 = Vector2.ONE
var max_zoom: Vector2 = Vector2(3, 3)
var zoom_speed: float = 0.1
var zoom_center: Vector2
var dragging: bool = false
var selection_enabled: bool = false
var moving_selection: bool = false
var selection_start: Vector2
var selection_end: Vector2
var current_selected: Array = []
var current_members: Array[RPGTroopMember]
var busy: bool  = true

const BATTLER_POSITION = preload("res://addons/RPGData/Scenes/battler_position.tscn")


signal zoom_changed(zoom: Vector2, center: Vector2)
signal battler_is_selected(value: bool)

func _ready():
	item_rect_changed.connect(_on_item_rect_changed)
	gui_input.connect(_on_gui_input)
	focus_exited.connect(_hide_selection)
	%Selector.gui_input.connect(_on_selector_gui_input)
	
	call_deferred("_setup_zoom")


func _setup_zoom() -> void:
	min_zoom = scale
	zoom_level = min_zoom
	max_zoom = Vector2(
		min_zoom.x * 3.0,
		min_zoom.y * 3.0
	)
	busy = false


func get_battler_container() -> Control:
	return %BattlerContainer


func fill_members(members: Array[RPGTroopMember]) -> void:
	current_members = members
	var container = %BattlerContainer
	for child in container.get_children():
		child.queue_free()
	
	var party_index = 1
	var enemy_index = 1
	var data_enemies = RPGSYSTEM.database.enemies
	for member: RPGTroopMember in current_members:
		var panel = BATTLER_POSITION.instantiate()
		if member.type == 0:
			panel.frame_color = Color("#000439")
			panel.battler_name = tr("Party Member") + " #" + str(party_index)
			party_index += 1
		else:
			panel.frame_color = Color("#450013")
			if member.id > 0 and data_enemies.size() > member.id:
				panel.battler_name = tr("Enemy") + " #" + str(enemy_index) + " - " + data_enemies[member.id].name
			else:
				panel.battler_name = tr("Enemy") + " #" + str(enemy_index) + " - " + "⚠ Invalid Data"
			enemy_index += 1
			panel.delete_request.connect(
				func(scene: BattlerPositionScene):
					current_members.erase(scene.current_member)
					fill_members(current_members)
			)
		container.add_child(panel)
		panel.show_close_button(member.type == 1)
		panel.set_deferred("current_member", member)
		panel.position_changed.connect(_on_battler_change_position)
		panel.battler_selected.connect(_emit_battler_is_selected_signal)
		panel.battler_deselected.connect(_emit_battler_is_selected_signal)


func _emit_battler_is_selected_signal(_scene: BattlerPositionScene) -> void:
	var n = 0
	for child in %BattlerContainer.get_children():
		if child.is_selected:
			n += 1
		if n >= 2: break
	
	battler_is_selected.emit(n >= 2)


func _on_battler_change_position(scene: BattlerPositionScene, pos: Vector2, movement: Vector2) -> void:
	if busy: return
	busy = true
	for child: BattlerPositionScene in %BattlerContainer.get_children():
		if child == scene: continue
		if child.is_selected:
			child.move(movement)
	busy = false


func _on_selector_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				moving_selection = true
			else:
				moving_selection = false
				
	elif moving_selection and event is InputEventMouseMotion:
		%Selector.position += event.relative
		_on_battler_change_position(null, Vector2.ZERO, event.relative)
		#for candidate in current_selected:
			#candidate.position += event.relative


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if not Input.is_key_pressed(KEY_CTRL):
				_hide_selection()
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in(event.position)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out(event.position)
			elif event.button_index == MOUSE_BUTTON_MIDDLE:
				dragging = true
			elif event.button_index == MOUSE_BUTTON_LEFT:
				selection_start = get_local_mouse_position()
				selection_end = selection_start
				selection_enabled = true
		else:
			if dragging and event.button_index == MOUSE_BUTTON_MIDDLE:
				dragging = false
			elif selection_enabled and event.button_index == MOUSE_BUTTON_LEFT:
				selection_enabled = false
				_update_selection()
				queue_redraw()
	elif event is InputEventMouseMotion:
		if dragging:
			# Move the control while respecting limits
			move_with_limits(event.relative)
		elif selection_enabled:
			selection_end = get_local_mouse_position()
			queue_redraw()


func _hide_selection() -> void:
	%Selector.visible = false
	for child in %BattlerContainer.get_children():
		child.deselect()


func _update_selection() -> void:
	current_selected = []
	
	if selection_start == selection_end: return
	
	var rect = Rect2(selection_start, selection_end - selection_start).abs()
	var candidates = []
	for child in %BattlerContainer.get_children():
		child.deselect()
		if rect.intersects(child.get_rect()):
			candidates.append(child)
	
	var x1 = INF
	var x2 = -INF
	var y1 = INF
	var y2 = -INF
	for candidate in candidates:
		x1 = min(x1, candidate.position.x)
		x2 = max(x2, candidate.position.x + candidate.size.x)
		y1 = min(y1, candidate.position.y)
		y2 = max(y2, candidate.position.y + candidate.size.y)
	
	if not is_finite(x1) or not is_finite(x2) or not is_finite(y1) or not is_finite(y2):
		return
		
	var new_rect = Rect2(x1, y1, x2-x1, y2-y1)
	var node = %Selector
	if new_rect:
		node.position = new_rect.position
		node.size = new_rect.size
		node.visible = not Input.is_key_pressed(KEY_CTRL)
		for candidate in candidates:
			candidate.select()
	else:
		node.visible = false
	
	current_selected = candidates


func _draw() -> void:
	if selection_enabled:
		var rect = Rect2(selection_start, selection_end - selection_start).abs()
		draw_rect(rect, Color.WHITE, false, 2, true)

func zoom_in(mouse_pos: Vector2):
	var old_zoom = zoom_level
	zoom_level = Vector2(
		min(zoom_level.x + zoom_speed, max_zoom.x),
		min(zoom_level.y + zoom_speed, max_zoom.y)
	)
	if zoom_level != old_zoom:
		apply_zoom(mouse_pos, old_zoom)

func zoom_out(mouse_pos: Vector2):
	var old_zoom = zoom_level
	zoom_level = Vector2(
		max(zoom_level.x - zoom_speed, min_zoom.x),
		max(zoom_level.y - zoom_speed, min_zoom.y)
	)
	if zoom_level != old_zoom:
		apply_zoom(mouse_pos, old_zoom)

func apply_zoom(mouse_pos: Vector2, old_zoom: Vector2):
	# Get mouse position relative to the control before zooming
	var local_mouse = mouse_pos - position
	
	scale = zoom_level
	
	# Compute offset to keep the mouse point fixed during zoom
	var zoom_factor = zoom_level / old_zoom
	var offset = local_mouse * (Vector2.ONE - zoom_factor)
	
	position += offset
	clamp_to_container()
	
	zoom_center = mouse_pos
	zoom_changed.emit(zoom_level, zoom_center)

func move_with_limits(relative: Vector2):
	position += relative
	clamp_to_container()

func clamp_to_container():
	var container = get_parent()
	if not container:
		return
		
	var container_size = container.size
	var control_size = size * scale
	
	# Calculate bounds considering zoom level
	var min_x = -(control_size.x - container_size.x)
	var max_x = 0.0
	var min_y = -(control_size.y - container_size.y)
	var max_y = 0.0
	
	# Center if control is smaller than container
	if control_size.x < container_size.x:
		min_x = 0.0
		max_x = container_size.x - control_size.x
	
	if control_size.y < container_size.y:
		min_y = 0.0
		max_y = container_size.y - control_size.y
	
	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)

func set_background(texture: Texture) -> void:
	$Background.texture = texture

func get_zoom_level() -> Vector2:
	return zoom_level

func get_zoom_center() -> Vector2:
	return zoom_center

func _on_item_rect_changed() -> void:
	# Re-adjust limits when the size changes
	clamp_to_container()
	# Re-adjust battlers:
	for battler in %BattlerContainer.get_children():
		battler.set_position_and_direction_from_data()
