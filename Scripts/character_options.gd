class_name CharacterOptions
extends Resource


@export var movement_type: int = 0 :
	set(value):
		movement_type = value
		_request_update()


@export var walking_animation: bool = true :
	set(value):
		walking_animation = value
		_request_update()

@export var idle_animation: bool = true :
	set(value):
		idle_animation = value
		_request_update()

@export var fixed_direction: bool = false :
	set(value):
		fixed_direction = value
		_request_update()

@export var passable: bool = false :
	set(value):
		passable = value
		_request_update()

@export var blend_mode: int = 0 :
	set(value):
		blend_mode = value
		_request_update()

@export var z_index: int = 1 :
	set(value):
		z_index = value
		_request_update()

@export var movement_speed: int = 60 :
	set(value):
		movement_speed = value
		_request_update()

@export var movement_frequency: int = 0 :
	set(value):
		movement_frequency = value
		_request_update()

@export var visible: bool = true :
	set(value):
		passable = value
		_request_update()

@export var current_opacity: float = 1.0 :
	set(value):
		current_opacity = value
		_request_update()

@export var current_graphics: String = "" :
	set(value):
		current_graphics = value
		_request_update()

var _update_pending := false


func _request_update():
	if not _update_pending:
		_update_pending = true
		call_deferred("_do_update")


func _do_update():
	_update_pending = false
	emit_changed()
