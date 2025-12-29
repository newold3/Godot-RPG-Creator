@tool
class_name BattlerPositionScene
extends Control

@export var frame_color: Color = Color("#000439") :
	set(color):
		frame_color = color
		if is_node_ready():
			var panel = %Panel1.get("theme_override_styles/panel")
			panel.bg_color = frame_color
			panel = %Panel2.get("theme_override_styles/panel")
			panel.bg_color = Color(frame_color.r, frame_color.g, frame_color.b, 0.28)
			panel.border_color = frame_color
			panel = %Panel3.get("theme_override_styles/panel")
			panel.bg_color = frame_color

@export var battler_name: String = "" :
	set(value):
		battler_name = value
		if is_node_ready():
			%Name.text = battler_name

@export var main_texture: Texture :
	set(value):
		main_texture = value
		if is_node_ready():
			%Image.texture = null
			%Image.size = Vector2.ZERO
			%Image.texture = main_texture

@export var hide_close_button: bool = false :
	set(value):
		hide_close_button = value
		if is_node_ready():
			erase_battler.visible = !value

# Drag and zoom-related variables
var dragging: bool = false
var zoom_level: Vector2 = Vector2.ONE
var main_control: Control = null

var rotation_tween: Tween

var current_member: RPGTroopMember : set = _set_current_member

var busy: bool = false

var frame_hide_color = Color("#383838")
var is_selected: bool = false

@onready var battler_direction: TextureButton = %BattlerDirection
@onready var startup_visibility: TextureButton = %StartupVisibility
@onready var erase_battler: TextureButton = %EraseBattler


# Signals
signal position_changed(scene: BattlerPositionScene, pos: Vector2, movement: Vector2)
signal direction_changed(value: int)
signal delete_request(scene: BattlerPositionScene)
signal battler_selected(scene: BattlerPositionScene)
signal battler_deselected(scene: BattlerPositionScene)


func _ready() -> void:
	item_rect_changed.connect(
		func():
			if current_member:
				current_member.position = (position + Vector2(size.x / 2, size.y)) / get_parent().size
	)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func(): %Selector.visible = true)
	mouse_exited.connect(func(): %Selector.visible = false)
	%MainContainer.item_rect_changed.connect(_resize_parent)
	
	focus_entered.connect(select)
	focus_exited.connect(deselect)

	find_main_control()

	frame_color = frame_color
	battler_name = battler_name
	main_texture = main_texture
	
	erase_battler.visible = not hide_close_button


func _set_current_member(member: RPGTroopMember) -> void:
	current_member = member
	startup_visibility.set_pressed_no_signal(current_member.hide)
	_on_visibility_button_toggled(current_member.hide)
	call_deferred("set_position_and_direction_from_data")


func set_position_and_direction_from_data() -> void:
	if not is_inside_tree() or busy:
		return
		
	if current_member:
		position = get_parent().size * current_member.position - Vector2(size.x / 2, size.y)
		var rot = 0 if current_member.direction == 1 \
			else deg_to_rad(180) if current_member.direction == 2 \
			else deg_to_rad(90) if current_member.direction == 4 \
			else deg_to_rad(-90)

		var button = battler_direction
		button.pivot_offset = button.size / 2
		button.rotation = rot


func show_close_button(value: bool) -> void:
	hide_close_button = !value


func show_visibility_button(value: bool) -> void:
	startup_visibility.visible = value


func find_main_control():
	# Search for the main control in the node tree to retrieve zoom info
	var current = get_parent()
	while current != null:
		if current.has_method("get_zoom_level"):
			main_control = current
			if current.has_signal("zoom_changed"):
				current.zoom_changed.connect(_on_zoom_changed)
			break
		current = current.get_parent()

func _on_zoom_changed(zoom: Vector2, center: Vector2):
	zoom_level = zoom

func _resize_parent() -> void:
	size = %MainContainer.size

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and dragging:
		move(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.is_pressed()
		if dragging:
			move_to_front()

func move(amount: Vector2) -> void:
	var target_position = position + amount
	var limits = calculate_movement_limits()

	target_position.x = clamp(target_position.x, limits.min_x, limits.max_x)
	target_position.y = clamp(target_position.y, limits.min_y, limits.max_y)

	position = target_position
	position_changed.emit(self, position, amount)

func calculate_movement_limits() -> Dictionary:
	var result = {
		"min_x": 0.0,
		"max_x": 0.0,
		"min_y": 0.0,
		"max_y": 0.0
	}

	var container = main_control if main_control != null else get_parent()
	if not container:
		return result

	var container_global_rect = Rect2()
	container_global_rect.position = container.global_position
	container_global_rect.size = container.size * container.get_global_transform().get_scale()

	var our_global_rect = get_global_rect()

	var parent = get_parent()
	if not parent:
		return result

	var parent_transform = parent.get_global_transform()
	var container_local_rect = parent_transform.affine_inverse() * container_global_rect

	var control_size = size * scale

	result.min_x = container_local_rect.position.x
	result.max_x = container_local_rect.position.x + container_local_rect.size.x - control_size.x
	result.min_y = container_local_rect.position.y
	result.max_y = container_local_rect.position.y + container_local_rect.size.y - control_size.y

	if control_size.x > container_local_rect.size.x:
		result.min_x = container_local_rect.position.x + container_local_rect.size.x - control_size.x
		result.max_x = container_local_rect.position.x

	if control_size.y > container_local_rect.size.y:
		result.min_y = container_local_rect.position.y + container_local_rect.size.y - control_size.y
		result.max_y = container_local_rect.position.y

	return result

func _on_flip_button_pressed() -> void:
	if current_member:
		busy = true
		match current_member.direction:
			1: current_member.direction = 4 # left to up
			2: current_member.direction = 8 # right to down 
			4: current_member.direction = 2 # up to right
			8: current_member.direction = 1 # down to left
		
		if rotation_tween:
			rotation_tween.kill()
		
		var target_rot = 0 if current_member.direction == 1 \
			else deg_to_rad(180) if current_member.direction == 2 \
			else deg_to_rad(90) if current_member.direction == 4 \
			else deg_to_rad(-90)
		
		var button = battler_direction
		button.pivot_offset = button.size / 2
		
		# Calcular el camino más corto
		var current_rot = button.rotation
		var diff = target_rot - current_rot
		
		# Normalizar la diferencia para encontrar el camino más corto
		while diff > PI:
			diff -= TAU
		while diff < -PI:
			diff += TAU
		
		rotation_tween = create_tween()
		rotation_tween.tween_property(button, "rotation", current_rot + diff, 0.15)
		
		busy = false

func _on_close_button_pressed() -> void:
	delete_request.emit(self)


func select() -> void:
	%Selection1.visible = true
	%Selection2.visible = true
	is_selected = true
	battler_selected.emit(self)


func deselect() -> void:
	if not Input.is_key_pressed(KEY_CTRL):
		%Selection1.visible = false
		%Selection2.visible = false
		is_selected = false
		battler_deselected.emit(self)


func _on_visibility_button_toggled(toggled_on: bool) -> void:
	if current_member:
		if not has_meta("original_frame_color"):
			set_meta("original_frame_color", frame_color)
		current_member.hide = toggled_on
		if toggled_on:
			%Panel2.modulate.a = 0.55
			frame_color = frame_hide_color
		else:
			%Panel2.modulate.a = 1.0
			frame_color = get_meta("original_frame_color")
