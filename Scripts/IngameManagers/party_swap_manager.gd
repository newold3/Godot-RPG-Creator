class_name PartySwapManager
extends Node


## Emitted when the swap mode is fully entered and the UI is ready.
signal swap_mode_started

## Emitted when the swap mode is ended and everything is restored.
signal swap_mode_ended

## The texture used for the selection cursor (e.g., a pointing hand).
@export var cursor_texture: Texture2D

## The zoom level applied to the camera during the selection phase.
@export var selection_zoom: Vector2 = Vector2(1.2, 1.2)

## Speed of the camera transition between characters.
@export var camera_speed: float = 5.0

var is_swap_mode_active: bool = false
var is_selecting: bool = false
var current_index: int = 0
var party_nodes: Array[CharacterBody2D] = []

var _original_zoom: Vector2 = Vector2.ONE
var _camera: Camera2D
var _cursor: Sprite2D
var _active_character: CharacterBody2D


func _ready() -> void:
	set_process_unhandled_input(false)
	set_process(false)


## Activates the follower selection mode, taking control away from normal gameplay.
func start_swap_mode() -> void:
	if is_swap_mode_active:
		return
		
	is_swap_mode_active = true
	is_selecting = true
	current_index = 0
	party_nodes.clear()
	
	if GameManager.current_player:
		party_nodes.append(GameManager.current_player)
		GameManager.current_player.set_physics_process(false)
		
	var followers = GameManager.get_followers()
	for child in followers:
		party_nodes.append(child)
		child.add_to_group("player")
		child.disable_following(true)
		if child.has_node("CollisionShape2D"):
			child.get_node("CollisionShape2D").disabled = false
					
	_camera = GameManager.get_camera()
	if _camera:
		_original_zoom = _camera.zoom
		
	_create_cursor()
	set_process_unhandled_input(true)
	set_process(true)
	swap_mode_started.emit()


## Deactivates the follower selection mode and returns control to the main player.
func end_swap_mode() -> void:
	if not is_swap_mode_active:
		return
		
	is_swap_mode_active = false
	is_selecting = false
	set_process_unhandled_input(false)
	set_process(false)
	
	if _cursor:
		_cursor.queue_free()
		
	for node in party_nodes:
		if node is SimpleFollower:
			if node.is_in_group("player"):
				node.remove_from_group("player")
			node.enable_following()
			if node.has_node("CollisionShape2D"):
				node.get_node("CollisionShape2D").disabled = true
			node.is_player_controlled = false
			
	if GameManager.current_player:
		GameManager.current_player.set_physics_process(true)
		
	if _camera:
		_camera.zoom = _original_zoom
		if GameManager.current_player:
			_camera.global_position = GameManager.current_player.global_position
			
	party_nodes.clear()
	_active_character = null
	swap_mode_ended.emit()


func _process(delta: float) -> void:
	if not is_selecting or party_nodes.is_empty():
		if _active_character and _camera:
			_camera.global_position = _camera.global_position.lerp(_active_character.global_position, camera_speed * delta)
		return
		
	var target_node = party_nodes[current_index]
	
	if _camera:
		_camera.global_position = _camera.global_position.lerp(target_node.global_position, camera_speed * delta)
		_camera.zoom = _camera.zoom.lerp(selection_zoom, camera_speed * delta)
		
	if _cursor:
		var tile_size = GameManager.get_map_tile_size()
		var bobbing = sin(Time.get_ticks_msec() / 150.0) * 4.0
		var target_cursor_pos = target_node.global_position + Vector2(0, -tile_size.y - 16 + bobbing)
		_cursor.global_position = _cursor.global_position.lerp(target_cursor_pos, camera_speed * 1.5 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not is_swap_mode_active:
		return
		
	if is_selecting:
		if event.is_action_pressed("ui_right"):
			current_index = (current_index + 1) % party_nodes.size()
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("ui_left"):
			current_index = (current_index - 1 + party_nodes.size()) % party_nodes.size()
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("ui_accept"):
			_select_character(party_nodes[current_index])
			get_viewport().set_input_as_handled()
			
	else:
		if event.is_action_pressed("ui_cancel"):
			_return_to_selection()
			get_viewport().set_input_as_handled()


func _create_cursor() -> void:
	if _cursor:
		_cursor.queue_free()
		
	_cursor = Sprite2D.new()
	if cursor_texture:
		_cursor.texture = cursor_texture
		
	_cursor.z_index = 100
	add_child(_cursor)
	
	if not party_nodes.is_empty():
		_cursor.global_position = party_nodes[current_index].global_position


func _select_character(character: CharacterBody2D) -> void:
	is_selecting = false
	
	if _cursor:
		_cursor.visible = false
		
	if _camera:
		_camera.zoom = _original_zoom
		
	for node in party_nodes:
		if node is SimpleFollower:
			node.is_player_controlled = false
		elif node == GameManager.current_player:
			node.set_physics_process(false)
			
	_active_character = character
	
	if character is SimpleFollower:
		character.is_player_controlled = true
	elif character == GameManager.current_player:
		character.set_physics_process(true)


func _return_to_selection() -> void:
	is_selecting = true
	
	if _cursor:
		_cursor.visible = true
		
	if _active_character:
		if _active_character is SimpleFollower:
			_active_character.is_player_controlled = false
			_active_character.current_animation = "idle"
		elif _active_character == GameManager.current_player:
			_active_character.set_physics_process(false)
			
	_active_character = null
