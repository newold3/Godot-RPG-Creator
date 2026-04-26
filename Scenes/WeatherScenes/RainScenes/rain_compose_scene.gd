@tool
extends Node2D


func get_class() -> String:
	return "WeatherScene"


@export var modulate_scene: Color = Color("#081662")


var delay: float = 0.0
var is_started: bool = false

var rumble_fxs = [
	preload("res://Assets/Sounds/SE/rain_rumble.ogg"),
	preload("res://Assets/Sounds/SE/rain_rumble2.ogg"),
	preload("res://Assets/Sounds/SE/rain_rumble3.ogg"),
	preload("res://Assets/Sounds/SE/rain_rumble4.ogg")
]

const RAIN_IMPACT = preload("res://Scenes/WeatherScenes/RainScenes/rain_impact.tscn")
const MIN_SHADOW_OPACITY = 0.4
const MAX_IMPACTS = 150

var current_impacts = 0
var shadow_container


func _ready() -> void:
	shadow_container = get_tree().get_first_node_in_group("dynamic_shadow_container")
	set_process(false)


## Initializes the scene, checking for inherited audio and setting up initial visual states.
func start(skip_animation: bool = false) -> void:
	shadow_container = get_tree().get_first_node_in_group("dynamic_shadow_container")
	var orphaned_audio = GameManager.get_node_or_null("WeatherAudio_Rain")
	
	if skip_animation and orphaned_audio:
		var old_pos = orphaned_audio.get_meta("old_pos", 0.0)
		%BGSPlayer.volume_db = orphaned_audio.volume_db
		%BGSPlayer.play(old_pos)
		orphaned_audio.queue_free()
	elif skip_animation and not orphaned_audio:
		%BGSPlayer.volume_db = -80.0
		%BGSPlayer.play()
	elif not skip_animation:
		%BGSPlayer.volume_db = -80.0
		%BGSPlayer.play()
		
	show()
	%WaterRipplesScene.visible = true
	%RainScene.visible = true
	%Ray.visible = true
	
	if skip_animation:
		if shadow_container:
			shadow_container.modulate.a = MIN_SHADOW_OPACITY
		%WaterRipplesScene.modulate.a = 1.0
		%RainScene.modulate.a = 1.0
		%Ray.self_modulate.a = 0.0
		GameManager.set_weather_color(modulate_scene, 0.0)
		is_started = true
		set_process(true)
	else:
		%WaterRipplesScene.modulate.a = 0.0
		%RainScene.modulate.a = 0.0
		%Ray.self_modulate.a = 0.0
		
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(%BGSPlayer, "volume_db", 0.0, 4.5)
		if shadow_container:
			t.tween_property(shadow_container, "modulate:a", MIN_SHADOW_OPACITY, 4.5)
		t.tween_property(%WaterRipplesScene, "modulate:a", 1.0, 4.5)
		t.tween_property(%RainScene, "modulate:a", 1.0, 4.5)
		
		GameManager.set_weather_color(modulate_scene, 2.5)
		t.tween_callback(set.bind("is_started", true)).set_delay(2.5)
		t.tween_callback(set_process.bind(true)).set_delay(2.5)


## Cleans up weather effects and resources before destroying the scene node.
func end() -> void:
	is_started = false
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(shadow_container, "modulate:a", 1.0, 4.5)
	t.tween_property(%WaterRipplesScene, "modulate:a", 0.0, 4.5)
	t.tween_property(%RainScene, "modulate:a", 0.0, 4.5)
	t.tween_property(%BGSPlayer, "volume_db", -80.0, 4.5)
	t.tween_property(%SEPlayer, "volume_db", -80.0, 2.5)
	
	GameManager.set_weather_color(Color.WHITE, 2.5)
	queue_free()


## Detaches the background sound to the GameManager to ensure it survives map transitions.
func hibernate() -> void:
	set_process(false)
	is_started = false
	
	if %BGSPlayer.playing:
		var audio_node = %BGSPlayer
		var playback_pos = audio_node.get_playback_position()
		audio_node.set_meta("old_pos", playback_pos)
		audio_node.reparent(GameManager)
		audio_node.name = "WeatherAudio_Rain"
		audio_node.play(playback_pos)


## Disables visuals and logic, clears global color tint, and fading out the sound for indoor map areas.
func pause_weather() -> void:
	var bgs_player = get_node_or_null("%BGSPlayer")
	if bgs_player:
		var t = create_tween()
		t.tween_property(bgs_player, "volume_db", -80.0, 0.8)
		t.tween_callback(bgs_player.stop)
		
	var ripples = get_node_or_null("%WaterRipplesScene")
	if ripples:
		ripples.visible = false
		ripples.process_mode = Node.PROCESS_MODE_DISABLED
		
	var rain = get_node_or_null("%RainScene")
	if rain:
		rain.visible = false
		rain.process_mode = Node.PROCESS_MODE_DISABLED
		
	var ray = get_node_or_null("%Ray")
	if ray: ray.visible = false
	
	GameManager.set_weather_color(Color.WHITE, 1.0)
	
	set_process(false)
	is_started = false


## Restores visuals and resumes logic, reapplies global color tint, and fading the sound back in after a short delay.
func resume_weather() -> void:
	var bgs_player = get_node_or_null("%BGSPlayer")
	if bgs_player:
		if not bgs_player.playing:
			bgs_player.volume_db = -80.0
			bgs_player.play()
		var t = create_tween()
		t.tween_property(bgs_player, "volume_db", 0.0, 2.5).set_delay(1.0)
		
	var ripples = get_node_or_null("%WaterRipplesScene")
	if ripples:
		ripples.visible = true
		ripples.process_mode = Node.PROCESS_MODE_INHERIT
		
	var rain = get_node_or_null("%RainScene")
	if rain:
		rain.visible = true
		rain.process_mode = Node.PROCESS_MODE_INHERIT
		
	var ray = get_node_or_null("%Ray")
	if ray: ray.visible = true
	
	GameManager.set_weather_color(modulate_scene, 2.5)
	
	set_process(true)
	is_started = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or !is_started or !visible:
		return
	
	if delay > 0.0:
		delay -= delta
		
	var n = randi() % 500
	if n == 0:
		rumble()
	
	n = randi() % 200
	if n > 100:
		if current_impacts < MAX_IMPACTS:
			create_impact()
			current_impacts += 1


func create_impact() -> void:
	var player: LPCCharacter = GameManager.current_player
	if player:
		var div = Vector2i(GameManager.get_camera().zoom) / 2
		if div != Vector2i.ZERO:
			var viewport_size = get_viewport().size / div
			var over_player = randi() % 60 == 0
			var new_position = Vector2(
				player.global_position.x + (randi_range(-viewport_size.x, viewport_size.x) if !over_player else randi_range(-10, 10)),
				player.global_position.y + (randi_range(-viewport_size.y, viewport_size.y) if !over_player else randi_range(-30, -5))
			)
			new_position = GameManager.current_map.get_wrapped_position(new_position)
			var node_impact = RAIN_IMPACT.instantiate()
			%ImpacstGroup.add_child(node_impact)
			node_impact.start(new_position)
			node_impact.tree_exiting.connect(erase_impact)


func erase_impact() -> void:
	current_impacts -= 1


func rumble() -> void:
	var player: AudioStreamPlayer = %SEPlayer
	if player.is_playing():
		await player.finished
		await get_tree().create_timer(randf_range(0.1, 0.4)).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
	
	if !is_started:
		return
		
	var rumble_fx = rumble_fxs.pick_random()
	player.stream = rumble_fx
	player.pitch_scale = randf_range(0.8, 1.2)
	player.volume_db = randf_range(-10, 1.5)
	player.play()
	
	var node = %Ray
	node.modulate.a = randf_range(0.2, 0.7)
	var end_time = randf_range(0.3, 2.5)
	var t = create_tween()
	var n = randi_range(2, 8)
	for i in n:
		var mid_time = randf_range(0.03, 0.06)
		t.tween_property(node, "self_modulate:a", 1.0, mid_time)
		t.tween_property(shadow_container, "modulate:a", 1.0, mid_time)
	t.tween_property(node, "self_modulate:a", 0.0, end_time)
	t.tween_property(shadow_container, "modulate:a", MIN_SHADOW_OPACITY, end_time)
	
	if GameManager.main_scene:
		t = create_tween()
		for i in n:
			var mid_time = randf_range(0.03, 0.06)
			t.tween_callback(GameManager.set_weather_flash.bind(Color(1.811, 1.508, 0.719, 0.474), mid_time))
			t.tween_interval(mid_time)
	
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.add_trauma(3000, 1.0)
	
	delay = randf_range(6.5, 15.0)
