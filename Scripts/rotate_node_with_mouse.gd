extends Node3D


var rotating = false

var prev_mouse_position
var next_mouse_position


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Mouse Left"):
		rotating = true
		prev_mouse_position = get_viewport().get_mouse_position()
		
	elif Input.is_action_just_released("Mouse Left"):
		rotating = false
	
	if rotating:
		next_mouse_position =  get_viewport().get_mouse_position()
		%CSGMesh3D.rotate_y((next_mouse_position.x - prev_mouse_position.x) * .1 * delta * 5)
		%CSGMesh3D.rotate_x(-(next_mouse_position.y - prev_mouse_position.y) * .1 * delta * 5)
		prev_mouse_position = next_mouse_position
