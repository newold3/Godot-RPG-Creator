extends Resource
class_name VolumeMapping

@export var volume_curve: Curve


func _init() -> void:
	volume_curve = Curve.new()
	volume_curve.add_point(Vector2(0.0, 0.0))
	volume_curve.add_point(Vector2(0.1, 0.01))
	volume_curve.add_point(Vector2(0.3, 0.1))
	volume_curve.add_point(Vector2(0.5, 0.3))
	volume_curve.add_point(Vector2(0.7, 0.6))
	volume_curve.add_point(Vector2(1.0, 1.0))


func set_volume_from_slider(bus_id: int, slider_value: float):
	slider_value = clamp(slider_value, 0.0, 1.0)
	var curved_value = volume_curve.sample(slider_value)
	var db_value = linear_to_db(curved_value)
	
	AudioServer.set_bus_volume_db(bus_id, db_value)
