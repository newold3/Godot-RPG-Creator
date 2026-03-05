class_name ScreenVisualsManager
extends Node


var current_canvas_modulation = Color.WHITE
var _day_color: Color = Color.WHITE
var _use_day_night: bool = true
var _map_color: Color = Color.WHITE
var _weather_color: Color = Color.WHITE
var _weather_ratio: float = 0.0
var _tint_color: Color = Color.WHITE
var _tint_ratio: float = 0.0
var transition_speed: float = 5.0

var flash_tween: Tween
var _weather_tween: Tween
var _tint_tween: Tween


func _process(delta: float) -> void:
	var target_color: Color = _calculate_final_color()
	var main_modulate = get_node_or_null("%MainModulate")
	
	if main_modulate:
		var color = main_modulate.color
		if not color.is_equal_approx(target_color):
			color = color.lerp(target_color, delta * transition_speed)
		else:
			color = target_color
		main_modulate.color = color


func set_day_color(new_color: Color) -> void:
	new_color.a = 1.0
	_day_color = new_color


func set_use_day_night(enabled: bool) -> void:
	_use_day_night = enabled


func set_map_color(new_color: Color) -> void:
	new_color.a = 1.0
	
	_map_color = new_color


func set_weather_color(new_color: Color, duration: float) -> void:
	new_color.a = 1.0
	
	if _weather_tween: _weather_tween.kill()
	
	if duration > 0.0:
		_weather_tween = create_tween().set_parallel(true)
		
		if _weather_ratio > 0.0:
			_weather_tween.tween_property(self, "_weather_color", new_color, duration)
		else:
			_weather_color = new_color
			
		_weather_tween.tween_property(self, "_weather_ratio", 1.0, duration)
		
	else:
		_weather_color = new_color
		_weather_ratio = 1.0
		var main_modulate = get_node_or_null("%MainModulate")
		if main_modulate:
			main_modulate.color = _calculate_final_color()


func remove_weather_color(duration: float) -> void:
	if _weather_tween: _weather_tween.kill()
	
	if duration > 0.0:
		_weather_tween = create_tween()
		_weather_tween.tween_property(self, "_weather_ratio", 0.0, duration)
	else:
		_weather_ratio = 0.0
		var main_modulate = get_node_or_null("%MainModulate")
		if main_modulate:
			main_modulate.color = _calculate_final_color()


func set_weather_flash(color: Color, duration: float) -> void:
	var node = get_node_or_null("%WeatherModulate")
	if not node: return
	
	var mat: ShaderMaterial = node.get_material()
	if flash_tween: flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.tween_method(
		func(value: float):
			var final_color = Color.WHITE.lerp(color, value)
			mat.set_shader_parameter("modulate", final_color)
	, 0.0, 1.0, duration)
	flash_tween.tween_method(
		func(value: float):
			var final_color = color.lerp(Color.TRANSPARENT, value)
			mat.set_shader_parameter("modulate", final_color)
	, 0.0, 1.0, duration * 5.0)


func set_tint_color(new_color: Color, duration: float) -> void:
	new_color.a = 1.0
	
	if _tint_tween: _tint_tween.kill()

	if duration > 0.0:
		_tint_tween = create_tween().set_parallel(true)
		
		if _tint_ratio > 0.0:
			_tint_tween.tween_property(self, "_tint_color", new_color, duration)
		else:
			_tint_color = new_color

		_tint_tween.tween_property(self, "_tint_ratio", 1.0, duration)
		
	else:
		_tint_color = new_color
		_tint_ratio = 1.0
		var main_modulate = get_node_or_null("%MainModulate")
		if main_modulate:
			main_modulate.color = _calculate_final_color()


func remove_tint_color(duration: float) -> void:
	if _tint_tween: _tint_tween.kill()
	
	if duration > 0.0:
		_tint_tween = create_tween()
		_tint_tween.tween_property(self, "_tint_ratio", 0.0, duration)
	else:
		_tint_ratio = 0.0
		var main_modulate = get_node_or_null("%MainModulate")
		if main_modulate:
			main_modulate.color = _calculate_final_color()


func _calculate_final_color() -> Color:
	var final_color: Color = _map_color
	
	if _use_day_night:
		final_color = final_color * _day_color
	
	if _weather_ratio > 0.0:
		final_color = final_color.lerp(_weather_color, _weather_ratio)
	
	if _tint_ratio > 0.0:
		final_color = final_color.lerp(_tint_color, _tint_ratio)
	
	return final_color


func get_modulate_scenes() -> Dictionary:
	var dict = {}
	var main_mod = get_node_or_null("%MainModulate")
	var weather_mod = get_node_or_null("%WeatherModulate")
	
	if main_mod: dict["main_modulate"] = main_mod.color
	if weather_mod: dict["weather_modulate"] = weather_mod.color
	
	return dict


func set_canvas_modulate_color(color: Color) -> void:
	color.a = 1.0
	
	current_canvas_modulation = color
	var brightness_factor = GameManager.current_game_options.brightness if GameManager.current_game_options else 1.0
	
	var final_color = color * brightness_factor
	final_color.a = current_canvas_modulation.a
	
	var main_modulate = get_node_or_null("%MainModulate")
	if main_modulate:
		main_modulate.color = final_color


func set_weather_modulate_color(color: Color) -> void:
	color.a = 1.0
	
	var node = get_node_or_null("%WeatherModulate")
	if node:
		node.get_material().set_shader_parameter("modulate", color)


func get_canvas_modulate_color() -> Color:
	return current_canvas_modulation


func set_flash_color(color: Color, blend: CanvasItemMaterial.BlendMode) -> void:
	var flash_node = get_node_or_null("%Flash")
	if flash_node:
		flash_node.color = color
		flash_node.get_material().blend_mode = blend


func play_video(path: String, loop: bool = false, fade_out_time: float = 0.0) -> VideoStreamPlayer:
	stop_video()
		
	if AssetManager.exists(path):
		var video = load(path)
		if video is VideoStream:
			var scn = VideoStreamPlayer.new()
			scn.stream = video
			scn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scn.expand = true
			scn.loop = loop
			
			var video_container = get_node_or_null("%VideoContainer")
			if video_container:
				video_container.add_child(scn)
			
			scn.play()
			var video_length = scn.get_stream_length()

			if not loop:
				if fade_out_time > 0 and video_length > fade_out_time:
					var t = create_tween()
					t.tween_interval(fade_out_time - fade_out_time)
					t.tween_property(scn, "modulate", Color.TRANSPARENT, fade_out_time)
					t.tween_callback(scn.queue_free)
				else:
					scn.finished.connect(scn.queue_free)

			return scn
	
	return null


func stop_video() -> void:
	var video_container = get_node_or_null("%VideoContainer")
	if video_container:
		for child in video_container.get_children():
			child.queue_free()
