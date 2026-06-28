class_name ClockCanvas
extends Control

## Whether to use the system time instead of the in-game time
@export var use_system_time: bool = true
## Texture style for the hour hand
@export var hour_hand_texture: Texture2D
## Texture style for the minute hand
@export var minute_hand_texture: Texture2D
## The total height (length) of the hour hand as a percentage (0.0 to 1.0)
@export_range(0.0, 1.0) var hour_hand_length: float = 0.5
## The total height (length) of the minute hand as a percentage (0.0 to 1.0)
@export_range(0.0, 1.0) var minute_hand_length: float = 0.8
## The color of the hour hand
@export var hour_hand_color: Color = Color.WHITE
## The color of the minute hand
@export var minute_hand_color: Color = Color.WHITE


#region Core Functions
## Actualiza el canvas en cada frame.
func _process(_delta: float) -> void:
	queue_redraw()


## Dibuja los componentes del reloj en el canvas.
func _draw() -> void:
	var current_hour: float = 0.0
	var current_minute: float = 0.0
	
	if use_system_time:
		var time_dict: Dictionary = Time.get_time_dict_from_system()
		current_hour = time_dict["hour"]
		current_minute = time_dict["minute"]
	else:
		current_hour = DayNightManager.get_current_hour()
		current_minute = DayNightManager.get_current_minute()
	
	var hour_angle: float = ((fmod(current_hour, 12.0) + (current_minute / 60.0)) / 12.0) * TAU - PI / 2.0
	var minute_angle: float = (current_minute / 60.0) * TAU - PI / 2.0
	
	var center: Vector2 = size / 2.0
	var radius_x: float = size.x / 2.0
	var radius_y: float = size.y / 2.0
	
	_draw_hand(center, radius_x, radius_y, hour_angle, hour_hand_length, hour_hand_color, hour_hand_texture, 4.0)
	_draw_hand(center, radius_x, radius_y, minute_angle, minute_hand_length, minute_hand_color, minute_hand_texture, 2.0)
#endregion


#region Drawing Helpers
## Dibuja una manija individual del reloj usando una textura o una linea.
func _draw_hand(center: Vector2, rx: float, ry: float, angle: float, length_pct: float, color: Color, texture: Texture2D, line_width: float) -> void:
	var direction: Vector2 = Vector2(cos(angle), sin(angle))
	var end_point: Vector2 = center + Vector2(direction.x * rx, direction.y * ry) * length_pct
	
	if texture != null:
		var tex_size: Vector2 = texture.get_size()
		var hand_length: float = center.distance_to(end_point)
		
		var transform: Transform2D = Transform2D()
		transform = transform.translated(Vector2(-tex_size.x / 2.0, -tex_size.y))
		transform = transform.scaled(Vector2(1.0, hand_length / tex_size.y))
		transform = transform.rotated(angle + PI / 2.0)
		transform = transform.translated(center)
		
		draw_set_transform_matrix(transform)
		draw_texture(texture, Vector2.ZERO, color)
		draw_set_transform_matrix(Transform2D())
	else:
		draw_line(center, end_point, color, line_width, true)
#endregion
