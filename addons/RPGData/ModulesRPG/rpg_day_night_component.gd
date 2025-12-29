@tool
class_name RPGDayNightComponent
extends Resource


@export var enabled: bool = true


@export var time_string: String = "00:00"
@export var current_hour: float = 0.0
@export var day_phase: String = "day"
@export var is_day: bool = true
@export var is_night: bool = false

@export var sun_angle: float = 0.0
@export var sun_height: float = 0.0
@export var sun_intensity: float = 1.0
@export var sun_rotation_x: float =  0.0
@export var sun_rotation_y: float = 0.0

@export var moon_visible: bool = false
@export var moon_angle: float = 0.0
@export var moon_intensity: float = 1.0

@export var ambient_color: Color = Color.WHITE
@export var ambient_intensity: float = 1.0

@export var audio_volume: float = 0.8
@export var audio_volume_db: float = 0.0

@export var shadow_strength: float = 1.0
@export var shadows_enabled: bool = true

# Shadow system data
@export var shadow_elongation: Vector2 = Vector2.ONE
@export var shadow_dynamic_skew: float = 0.0
@export var shadow_offset: Vector2 = Vector2.ZERO
@export var shadow_opacity: float = 1.0
@export var shadow_visible: bool = true

@export var street_lights_on: bool = false
@export var night_sounds_active: bool = false


func clone(value: bool) -> RPGDayNightComponent:
	return duplicate(value)
