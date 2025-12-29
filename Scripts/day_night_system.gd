@tool
class_name DayNightSystem
extends Node


@export var day_night_config: GameDayNight


var current_time: float = 0.0
var time_speed: float = 1.0
var is_started: bool = false
var update_timer: Timer

# All calculated data available for final_update()
var calculated_data: RPGDayNightComponent

signal time_changed(hour: float, data: Dictionary)
signal day_phase_changed(phase: String, data: Dictionary)
signal switch_activated(switch_name: String, state: bool, data: Dictionary)

func _ready():
	calculated_data = RPGDayNightComponent.new()
	day_night_config = RPGSYSTEM.database.system.day_night_config.clone(true)
	# Setup update timer (10 FPS for day/night cycle)
	update_timer = Timer.new()
	update_timer.wait_time = 0.1  # 10 times per second
	update_timer.timeout.connect(_on_timer_update)
	update_timer.autostart = false
	add_child(update_timer)


func set_config(config: GameDayNight) -> void:
	day_night_config = config
	
	if is_started:
		stop()
		start()


func _on_timer_update():
	if not is_started:
		return
		
	var delta = update_timer.wait_time
	current_time += time_speed * delta
	if current_time >= 24.0:
		current_time -= 24.0
	
	update_calculations()
	final_update()
	
	time_changed.emit(current_time, calculated_data)


func update_calculations():
	calculate_time_data()
	calculate_sun_data()
	calculate_moon_data()
	calculate_ambient_data()
	calculate_audio_data()
	calculate_shadow_data()
	calculate_dynamic_shadow_data()
	calculate_switches_data()


func calculate_time_data():
	calculated_data.current_hour = current_time
	calculated_data.time_string = get_time_string()
	
	var old_phase = calculated_data.day_phase
	calculated_data.day_phase = get_day_phase()
	calculated_data.is_day = is_day_time()
	calculated_data.is_night = is_night_time()
	
	if old_phase != calculated_data.day_phase:
		day_phase_changed.emit(calculated_data.day_phase, calculated_data)


func calculate_sun_data():
	# 6 AM = 0°, 12 PM = 90°, 6 PM = 180°
	var sun_angle = (current_time - 6.0) * 15.0
	calculated_data.sun_angle = sun_angle
	
	var sun_height = sin(deg_to_rad(sun_angle)) * day_night_config.sun_max_angle
	calculated_data.sun_height = sun_height
	
	calculated_data.sun_rotation_x = -sun_height
	calculated_data.sun_rotation_y = sun_angle
	
	calculated_data.sun_intensity = max(0.0, sin(deg_to_rad(sun_angle)))


func calculate_moon_data():
	"""Calculate moon-specific data for the night cycle"""
	if current_time >= 22.5 or current_time < 6.0:
		# Night hours when moon is active
		calculated_data.moon_visible = true
		calculated_data.moon_angle = rad_to_deg(calculate_moon_angle())
		
		# Moon intensity based on time (strongest around midnight)
		var night_progress: float
		
		if current_time >= 22.5:
			night_progress = remap(current_time, 22.5, 24.0, 0.0, 0.2)  # First part of night
		else:
			night_progress = remap(current_time, 0.0, 6.0, 0.2, 1.0)  # Second part of night
		
		# Peak intensity around midnight (progress = 0.2, which is 24:00)
		calculated_data.moon_intensity = sin(night_progress * PI) * 0.4
	else:
		# Day time
		calculated_data.moon_visible = false
		calculated_data.moon_angle = 0.0
		calculated_data.moon_intensity = 0.0


func calculate_moon_angle() -> float:
	"""Calculate moon angle that continues smoothly from sun position at 22:30 to sun position at 6:00"""
	
	# Sun angle at 22:30: (22.5 - 6.0) * 15.0 = 247.5°
	# Sun angle at 6:00: (6.0 - 6.0) * 15.0 = 0°
	var sun_angle_at_22_30 = deg_to_rad(247.5)  # Where sun "ends"
	
	# Calculate total angular distance the moon needs to travel
	# From 247.5° to 360° (or 0°) = 112.5° of movement over 7.5 hours
	# This gives us about 15°/hour, which is much more realistic for lunar movement
	var total_night_duration = 7.5  # hours from 22:30 to 6:00
	var moon_angular_speed = 112.5 / total_night_duration  # ~15°/hour (realistic lunar speed)
	
	var moon_angle: float
	var elapsed_night_hours: float
	
	if current_time >= 22.5:
		# From 22:30 to 24:00 (1.5 hours)
		elapsed_night_hours = current_time - 22.5
	else: # current_time < 6.0
		# From 0:00 to 6:00 (6 hours) + the initial 1.5 hours
		elapsed_night_hours = (current_time) + 1.5
	
	# Calculate moon position based on realistic angular speed
	var moon_movement = elapsed_night_hours * moon_angular_speed
	moon_angle = sun_angle_at_22_30 + deg_to_rad(moon_movement)
	
	# Ensure we don't overshoot the target (wrap around 2π if needed)
	if moon_angle > PI * 2:
		moon_angle -= PI * 2
	
	return moon_angle


func calculate_ambient_data():
	calculated_data.ambient_color = get_ambient_color()
	calculated_data.ambient_intensity = get_ambient_intensity()


func get_ambient_color() -> Color:
	var hour = current_time
	
	if hour >= 5.0 and hour < 8.0:  # Dawn
		var t = (hour - 5.0) / 3.0
		return day_night_config.night_color.lerp(day_night_config.dawn_color, t)
	elif hour >= 8.0 and hour < 17.0:  # Day
		var t = (hour - 8.0) / 9.0
		return day_night_config.dawn_color.lerp(day_night_config.day_color, t)
	elif hour >= 17.0 and hour < 20.0:  # Dusk
		var t = (hour - 17.0) / 3.0
		return day_night_config.day_color.lerp(day_night_config.dusk_color, t)
	else:  # Night
		if hour >= 20.0:
			var t = (hour - 20.0) / 4.0
			return day_night_config.dusk_color.lerp(day_night_config.night_color, t)
		else:  # 0-5 AM
			return day_night_config.night_color


func get_ambient_intensity() -> float:
	var hour = current_time
	
	if hour >= 6.0 and hour <= 18.0:  # Day
		return 1.0
	elif hour >= 4.0 and hour < 6.0:  # Dawn transition
		return lerp(0.3, 1.0, (hour - 4.0) / 2.0)
	elif hour > 18.0 and hour <= 22.0:  # Dusk transition
		return lerp(1.0, 0.3, (hour - 18.0) / 4.0)
	else:  # Night
		return 0.3


func calculate_audio_data():
	var target_volume = day_night_config.day_audio_volume if is_day_time() else day_night_config.night_audio_volume
	
	calculated_data.audio_volume = target_volume
	calculated_data.audio_volume_db = linear_to_db(target_volume)


func calculate_shadow_data():
	calculated_data.shadow_strength = day_night_config.shadow_day_strength if is_day_time() else day_night_config.shadow_night_strength
	calculated_data.shadows_enabled = calculated_data.shadow_strength > 0.0


func calculate_dynamic_shadow_data():
	"""Calculate dynamic shadow properties based on sun position"""
	if not day_night_config.shadow_enabled:
		calculated_data.shadow_visible = false
		calculated_data.shadow_elongation = Vector2.ZERO
		calculated_data.shadow_dynamic_skew = 0.0
		calculated_data.shadow_offset = Vector2.ZERO
		calculated_data.shadow_opacity = 0.0
		return
	
	var sun_angle_rad = deg_to_rad(calculated_data.sun_angle)
	
	# shadow opacity based in current hour
	var min_shadow_opacity = 0.15
	var max_shadow_opacity = 1.0
	
	if current_time >= 22.5 or current_time < 6.0:
		# Deep night: shadows barely visible
		calculated_data.shadow_visible = true  # Changed to true to show subtle shadows
		calculated_data.shadow_opacity = min_shadow_opacity
	elif current_time >= 18.0 and current_time < 22.5:
		# Evening transition: from full opacity to minimum
		calculated_data.shadow_visible = true
		calculated_data.shadow_opacity = remap(current_time, 18.0, 22.5, max_shadow_opacity, min_shadow_opacity)
	elif current_time >= 6.0 and current_time < 7.0:
		# Morning transition: from minimum to full opacity
		calculated_data.shadow_visible = true
		calculated_data.shadow_opacity = remap(current_time, 6.0, 7.0, min_shadow_opacity, max_shadow_opacity)
	else:
		# Day time: full shadow visibility
		calculated_data.shadow_visible = true
		calculated_data.shadow_opacity = max_shadow_opacity
	
	# Shadow length based on sun height (higher sun = shorter shadows)
	var shadow_length: float
	if current_time >= 6.0 and current_time <= 12.0:
		# Morning: long shadows → short shadows (sun rises)
		shadow_length = remap(current_time, 6.0, 12.0, day_night_config.shadow_max_length, day_night_config.shadow_min_length)
	elif current_time > 12.0 and current_time <= 18.0:
		# Afternoon: short shadows → long shadows (sun goes down)
		shadow_length = remap(current_time, 12.0, 18.0, day_night_config.shadow_min_length, day_night_config.shadow_max_length)
	else:
		# Night period: from 18:00 to 6:00 (crosses midnight)
		if current_time >= 18.0:
			# From 18:00 to 24:00 - map from max to min
			var night_progress = remap(current_time, 18.0, 24.0, 0.0, 0.5)  # 0 to 0.5
			shadow_length = remap(night_progress, 0.0, 0.5, day_night_config.shadow_max_length, day_night_config.shadow_min_length)
		else:  # current_time < 6.0
			# From 0:00 to 6:00 - continue mapping from min back to max
			var night_progress = remap(current_time, 0.0, 6.0, 0.5, 1.0)  # 0.5 to 1.0
			shadow_length = remap(night_progress, 0.5, 1.0, day_night_config.shadow_min_length, day_night_config.shadow_max_length)
	
	# Shadow elongation (longer shadows when sun is low)
	calculated_data.shadow_elongation = day_night_config.shadow_base_elongation * shadow_length
	calculated_data.shadow_elongation.x = max(0.6, calculated_data.shadow_elongation.x)
	calculated_data.shadow_elongation.y = max(1.2, calculated_data.shadow_elongation.y)
	
	# Calculate shadow direction based on time of day with smooth transitions
	var shadow_direction: Vector2
	var light_angle_rad: float
	
	if current_time >= 6.0 and current_time <= 22.5:
		# Day time: use sun position
		light_angle_rad = sun_angle_rad
	else:
		# Night time (22.5-6.0): use moon position that continues from sun
		light_angle_rad = calculate_moon_angle()
	
	# Dynamic skew based on light direction (east/west)
	var skew_factor = sin(light_angle_rad) * day_night_config.shadow_base_skew
	calculated_data.shadow_dynamic_skew = skew_factor * shadow_length
	
	# Shadow offset - shadows appear opposite to light direction
	shadow_direction = Vector2(-cos(light_angle_rad), 1.0).normalized()
	calculated_data.shadow_offset = day_night_config.shadow_base_offset + (shadow_direction * shadow_length * 10)


func calculate_switches_data():
	var old_street_lights = calculated_data.street_lights_on
	var should_street_lights_be_on = (current_time >= day_night_config.street_lights_on_hour or current_time <= day_night_config.street_lights_off_hour)
	calculated_data.street_lights_on = should_street_lights_be_on
	
	if old_street_lights != calculated_data.street_lights_on:
		switch_activated.emit("street_lights", calculated_data.street_lights_on, calculated_data)
	
	var old_night_sounds = calculated_data.night_sounds_active
	var should_night_sounds_play = (current_time >= day_night_config.night_sounds_start or current_time <= day_night_config.night_sounds_end)
	calculated_data.night_sounds_active = should_night_sounds_play
	
	if old_night_sounds != calculated_data.night_sounds_active:
		switch_activated.emit("night_sounds", calculated_data.night_sounds_active, calculated_data)


func is_day_time() -> bool:
	return current_time >= 6.0 and current_time <= 18.0


func is_night_time() -> bool:
	return not is_day_time()


func get_current_hour() -> int:
	return int(current_time)


func get_current_minute() -> int:
	return int((current_time - float(get_current_hour())) * 60.0)


func get_time_string() -> String:
	var hour = get_current_hour()
	var minute = get_current_minute()
	return "%02d:%02d" % [hour, minute]


func get_day_phase() -> String:
	var hour = current_time
	
	if hour >= 5.0 and hour < 8.0:
		return "dawn"
	elif hour >= 8.0 and hour < 17.0:
		return "day"
	elif hour >= 17.0 and hour < 20.0:
		return "dusk"
	else:
		return "night"


func get_data() -> RPGDayNightComponent:
	return calculated_data


func start() -> void:
	current_time = day_night_config.start_time
	time_speed = 24.0 / day_night_config.day_duration_seconds
	
	update_calculations()
	final_update()
	
	is_started = true
	update_timer.start()


func continue_from_time(hour: float) -> void:
	current_time = clamp(hour, 0.0, 24.0)
	time_speed = 24.0 / day_night_config.day_duration_seconds
	
	update_calculations()
	final_update()
	
	is_started = true
	update_timer.start()


func stop() -> void:
	is_started = false
	update_timer.stop()


func set_time(hour: float):
	if hour == -1: return
	current_time = clamp(hour, 0.0, 24.0)
	update_calculations()
	final_update()


func set_time_speed(speed: float):
	time_speed = (24.0 / day_night_config.day_duration_seconds) * speed


func set_enabled() -> void:
	calculated_data.enabled = true


func set_disabled() -> void:
	calculated_data.enabled = false


func is_enabled() -> bool:
	return calculated_data.enabled


func pause_time():
	time_speed = 0.0


func resume_time():
	time_speed = 24.0 / day_night_config.day_duration_seconds


# Override this function with your custom implementation
func final_update():
	GameManager.set_day_color(calculated_data.ambient_color)


func print_current_data():
	print("=== DAY/NIGHT SYSTEM DATA ===")
	for key in calculated_data.keys():
		print(key + ": " + str(calculated_data[key]))
