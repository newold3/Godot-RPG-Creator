@tool
extends Node2D

func get_class() -> String:
	return "WeatherScene"

const LINE_WIND = preload("res://Scenes/WeatherScenes/HotDesert/line_wind.tscn")
const MAX_LINE_WIND: int = 10

@export var modulate_scene: Color = Color("#081662")

var current_camera_position: Vector2 = Vector2.ZERO
var current_lines: int  = 0

var mist: ColorRect


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
	else:
		
		pass



func _physics_process(delta: float) -> void:
	if ([1, 5, 15].has(randi() % 20) and current_lines < MAX_LINE_WIND):
		var wind = LINE_WIND.instantiate()
		var screen_size = get_viewport().size
		wind.position = Vector2(randi() % screen_size.x, randi() % screen_size.y)
		wind.direction = Vector2(randf_range(0.75, 1), randf_range(-0.35, 0.35))
		wind.tree_exiting.connect(
			func():
				current_lines -= 1
		)
		GameManager.current_map.add_child(wind)
		current_lines += 1
