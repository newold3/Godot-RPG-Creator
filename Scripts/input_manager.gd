class_name InputManager
extends Node


var controller: KeyController
var key_delay: float = 0.0
var last_key_pressed: String
var last_key_echo: bool


func _ready() -> void:
	controller = KeyController.new()


func update_input(delta: float) -> void:
	if controller:
		controller.update(delta)


func is_key_pressed(keys: Variant, allow_echo: bool = true) -> bool:
	var keys_array = []
	if keys is String:
		keys_array = [keys]
	elif keys is Array:
		keys_array = keys
	else:
		return false
	if controller: return controller.is_any_key_pressed(keys_array, allow_echo)
	return false


func add_key_callback(key: String, callable: Callable, allow_echo: bool = true, id: Variant = null) -> void:
	if controller: controller.register_key(key, callable, allow_echo, id)


func remove_key_callback(id: Variant) -> void:
	if controller: controller.unregister_key_by_id(id)


func get_last_key_pressed() -> String:
	if controller: return controller.current_action_pressed
	return ""
