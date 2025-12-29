@tool
class_name GameDayNight
extends Resource

## Duration of a full day cycle in seconds
@export var day_duration_seconds: int = 300
## Starting time of day (in 24-hour format, e.g., 13 = 1:00 PM)
@export var start_time: float = 13

@export_group("Ambient Colors")
## Color tint during dawn/sunrise period
@export var dawn_color: Color = Color(1.0, 0.7, 0.5, 1.0)
## Color tint during daytime period
@export var day_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Color tint during dusk/sunset period
@export var dusk_color: Color = Color(1.0, 0.5, 0.3, 1.0)
## Color tint during nighttime period
@export var night_color: Color = Color(0.2, 0.3, 0.6, 1.0)
## Color for the Shadow
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.753)

@export_group("Audio")
## Audio volume level during daytime (0.0 to 1.0)
@export var day_audio_volume: float = 0.8
## Audio volume level during nighttime (0.0 to 1.0)
@export var night_audio_volume: float = 0.3
## Speed of audio volume transitions between day/night
@export var audio_transition_speed: float = 2.0
## Time (in 24-hour format) when night sounds begin
@export var night_sounds_start: float = 20.0
## Time (in 24-hour format) when night sounds end
@export var night_sounds_end: float = 5.0

@export_group("Sun")
## Maximum angle the sun reaches during its arc (in degrees)
@export var sun_max_angle: float = 60.0
## Speed of sun rotation across the sky (degrees per time unit)
@export var sun_rotation_speed: float = 15.0
## Shadow intensity/opacity during daytime
@export var shadow_day_strength: float = 1.0
## Shadow intensity/opacity during nighttime
@export var shadow_night_strength: float = 0.1

@export_group("Shadow System")
## Enables shadows calculated by the day/night system.
@export var shadow_enabled: bool = true
## Base elongation factor for shadows (X and Y scaling)
@export var shadow_base_elongation: Vector2 = Vector2(1.0, 1.5)
## Base skew/slant angle for shadow distortion
@export var shadow_base_skew: float = 0.5
## Base position offset for shadow placement
@export var shadow_base_offset: Vector2 = Vector2(0, 10)
## Maximum length shadows can reach
@export var shadow_max_length: float = 3.0
## Minimum length shadows can shrink to
@export var shadow_min_length: float = 0.3

@export_group("Time Switches")
## Switch activated/deactivated when lights are turned on or off
## Use this in-game switch to create things that happen when night falls, such as turning on lights.
@export var switch_id: int = 1
## Hour offset when street lights turn on (relative to sunset)
@export var street_lights_on_hour: int = 21
## Hour offset when street lights turn off (relative to sunset)
@export var street_lights_off_hour: int = 8


func clear() -> void:
	day_duration_seconds = 300
	start_time = 13
	dawn_color = Color(1.0, 0.7, 0.5, 1.0)
	day_color = Color(1.0, 1.0, 1.0, 1.0)
	dusk_color = Color(1.0, 0.5, 0.3, 1.0)
	night_color = Color(0.2, 0.3, 0.6, 1.0)
	day_audio_volume = 0.8
	night_audio_volume = 0.3
	audio_transition_speed = 2.0
	night_sounds_start = 20.0
	night_sounds_end = 5.0
	sun_max_angle = 60.0
	sun_rotation_speed = 15.0
	shadow_day_strength = 1.0
	shadow_night_strength = 0.1
	shadow_enabled = true
	shadow_base_elongation = Vector2(1.0, 1.5)
	shadow_base_skew = 0.5
	shadow_base_offset = Vector2(0, 10)
	shadow_max_length = 3.0
	shadow_min_length = 0.3
	switch_id = 1
	street_lights_on_hour = 21
	street_lights_off_hour = 8


func clone(value: bool) -> GameDayNight:
	return duplicate(value)
