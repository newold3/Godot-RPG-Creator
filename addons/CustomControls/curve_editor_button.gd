@tool
extends TextureButton

var index : int
var tangent_left : float
var tangent_right : float
var max_points : int

var main_button_texture = preload("res://addons/CustomControls/Images/curve_editor_button.png")
var left_texture = preload("res://addons/CustomControls/Images/curve_editor_button_left.png")
var right_texture = preload("res://addons/CustomControls/Images/curve_editor_button_right.png")

var dragging : bool
var forcing_dragging : bool

var click_position : Vector2

signal position_changed(index : int, position : Vector2, tangent_left : float, tangent_right : float)
signal remove_point(index : int)
signal point_selected(index : int)


func _ready() -> void:
	set_texture_normal(main_button_texture)
	draw.connect(on_draw)
	gui_input.connect(_on_gui_input.bind(self))
	mouse_entered.connect(_on_mouse_entered.bind(self))
	mouse_exited.connect(_on_mouse_exited.bind(self))
	focus_entered.connect(_show_tangent_points)
	focus_exited.connect(_hide_tangent_points)
	self_modulate = Color(0.9375, 0.084228515625, 0.084228515625)
	add_to_group("main_point")
	
	for i in 2:
		var button = get_child(i)
		var tex = left_texture if i == 1 else right_texture
		button.set_texture_normal(tex)
		button.gui_input.connect(_on_gui_input.bind(button))
		button.mouse_entered.connect(_on_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_mouse_exited.bind(button))
		button.self_modulate = Color(0.052871704101, 0.683339238166, 0.90234375)
		button.pivot_offset = tex.get_size() * 0.5
		button.add_to_group("tangent_point")
	
	_hide_tangent_points()


func set_data(_index : int, _position : Vector2, _tangent_left : float, _tangent_right : float, _max_points : int) -> void:
	position = _position
	index = _index
	tangent_left = _tangent_left
	tangent_right = _tangent_right
	max_points = _max_points
	var distance = 30
	var direction = Vector2(
		cos(tangent_left),
		sin(tangent_left)
	)
	%LeftTangent.position = -direction * distance
	%LeftTangent.rotation = %LeftTangent.position.angle() + PI
	direction = Vector2(
		cos(tangent_right),
		sin(tangent_right)
	)
	%RightTangent.position = direction * distance
	%RightTangent.rotation = %RightTangent.position.angle()


func _on_mouse_entered(node : Control) -> void:
	node.self_modulate = Color(0.902343, 0.729794740676, 0.052871704101)


func _on_mouse_exited(node : Control) -> void:
	if node.is_in_group("main_point"):
		node.self_modulate = Color(0.9375, 0.084228515625, 0.084228515625)
	else:
		node.self_modulate = Color(0.052871704101, 0.683339238166, 0.90234375)


func _on_gui_input(event: InputEvent, node : Control) -> void:
	if !visible: false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			dragging = true
			click_position = node.position
			point_selected.emit(index)
		else:
			dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		move(event, node)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed() and node.is_in_group("main_point"):
		if index != 0 and index != max_points - 1:
			emit_signal("remove_point", index)
			get_viewport().set_input_as_handled()


func move(event : InputEvent, node : Control) -> void:
	var ts = main_button_texture.get_size() * 0.5
	if node.is_in_group("main_point"):
		click_position += event.relative
		if index != 0 and index != max_points - 1:
			node.position = click_position
		else:
			node.position.y = click_position.y
		
		if node.position.x < -ts.x:
			node.position.x = -ts.x
		elif node.position.x > get_parent().size.x - ts.x:
			node.position.x = get_parent().size.x - ts.x
		if node.position.y < -ts.y:
			node.position.y = -ts.y
		elif node.position.y > get_parent().size.y - ts.y:
			node.position.y = get_parent().size.y - ts.y
	else:
		var distance = 30
		var direction : Vector2 = (get_local_mouse_position() - ts).normalized()
		var angle = direction.angle()
		if (index == 0 and abs(angle) > PI/2) or \
			(index == max_points - 1 and abs(angle) < PI/2):
			angle += PI * sign(-angle)
			direction = Vector2(cos(angle), sin(angle))
		
		angle = fmod(angle, PI/2)
		
		if node == %LeftTangent:
			if angle != 0:
				angle = (PI / 2 - angle) if (angle > 0) else (-PI / 2 - angle)

		node.position = direction * distance
		
		if is_equal_approx(abs(angle), PI/2):
			angle = 0.0
	
		if node == %LeftTangent:
			tangent_left = angle
			node.rotation = node.position.angle() + PI
		else:
			tangent_right = angle
			node.rotation = node.position.angle()
		
		if !Input.is_key_pressed(KEY_CTRL):
			if node == %LeftTangent:
				tangent_left *= -1
				tangent_right = tangent_left
				%RightTangent.position = node.position * -1
				%RightTangent.rotation = %RightTangent.position.angle()
			else:
				tangent_left = tangent_right
				%LeftTangent.position = node.position * -1
				%LeftTangent.rotation = %LeftTangent.position.angle() + PI
		elif node == %LeftTangent:
			tangent_left *= -1
		
		queue_redraw()
	
	emit_signal("position_changed", index, position + ts, tangent_left, tangent_right)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if !event.is_pressed() and forcing_dragging:
			forcing_dragging = false
	elif event is InputEventMouseMotion and forcing_dragging:
		move(event, self)
		get_viewport().set_input_as_handled()


func _show_tangent_points() -> void:
	if index == 0:
		%LeftTangent.visible = false
		%RightTangent.visible = true
	elif index == max_points - 1:
		%RightTangent.visible = false
		%LeftTangent.visible = true
	else:
		%LeftTangent.visible = true
		%RightTangent.visible = true
	
	queue_redraw()


func _hide_tangent_points() -> void:
	%RightTangent.visible = false
	%LeftTangent.visible = false
	queue_redraw()


func on_draw() -> void:
	if !has_focus():
		return
	var t = Vector2(10, 10)
	if index != 0:
		draw_line(%LeftTangent.position + t, t, Color.DARK_GRAY)
	if index != max_points - 1:
		draw_line(%RightTangent.position + t, t, Color.DARK_GRAY)
