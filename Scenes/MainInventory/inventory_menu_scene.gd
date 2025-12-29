extends Panel

var main_tween: Tween
var tween_animation_time = 0.25
var is_enabled: bool = false

@onready var inventory_scene: Control = %InventoryScene

signal menu_is_ready()


func _ready() -> void:
	visible = false
	await get_tree().process_frame
	set_meta("original_position", position)
	end()


func start() -> void:
	is_enabled = false
	inventory_scene.is_enabled = false
	await get_tree().process_frame
	
	if main_tween:
		main_tween.kill()
	
	visible = true
	
	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	main_tween.tween_property(%Gear, "rotation", 90, tween_animation_time)
	main_tween.tween_method(_set_real_position, position.x, get_meta("original_position").x, tween_animation_time)
	main_tween.set_parallel(false)
	main_tween.tween_callback(set.bind("is_enabled", true))
	main_tween.tween_callback(inventory_scene.set.bind("is_enabled", true))
	main_tween.tween_callback(func(): menu_is_ready.emit())
	
	inventory_scene.select_item(0)
	inventory_scene.focus()


func end() -> void:
	is_enabled = false
	inventory_scene.is_enabled = false
	inventory_scene.select_item(-1)
	await get_tree().process_frame
	
	if main_tween:
		main_tween.kill()
	
	main_tween = create_tween()
	main_tween.set_parallel(true)
	main_tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	main_tween.tween_property(%Gear, "rotation", 0, tween_animation_time)
	main_tween.tween_method(_set_real_position, position.x, get_meta("original_position").x + size.x, tween_animation_time)
	main_tween.tween_callback(set.bind("visible", false))



func _set_real_position(value: float) -> void:
	position.x = value
