@tool
extends Node2D

## The color used to modulate the scene weather.
@export var modulate_scene: Color = Color("#628bfa")

## Array of audio effects to simulate a realistic underwater environment (LowPass, Reverb, Chorus).
@export var underwater_effects: Array[AudioEffect]

const UNDER_WATER_BUBBLES = preload("res://Scenes/ParticleScenes/under_water_bubbles.tscn")

var foam_layer: Sprite2D
var fish_layer: Sprite2D
var is_started: bool = false


## Returns the class name for identification.
func get_class() -> String:
	return "WeatherScene"


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
	set_process(false)


## Initializes the weather scene, configuring shader sources and map layers.
func start(skip_animation: bool = false) -> void:
	var bgs_player = get_node_or_null("%BGSPlayer")
	var orphaned_audio = GameManager.get_node_or_null("WeatherAudio_Underwater")
	
	if skip_animation and orphaned_audio and bgs_player:
		var old_pos = orphaned_audio.get_meta("old_pos", 0.0)
		bgs_player.volume_db = orphaned_audio.volume_db
		bgs_player.play(old_pos)
		orphaned_audio.queue_free()
	elif skip_animation and not orphaned_audio and bgs_player:
		bgs_player.volume_db = -80.0
		bgs_player.play()
	elif not skip_animation and bgs_player:
		bgs_player.volume_db = -80.0
		bgs_player.play()

	_install_fx()
	
	%Fish.visible = true
	%Foam.visible = true
	
	_setup_layers_to_map()
	
	if skip_animation:
		GameManager.set_weather_color(modulate_scene, 0.0)
		is_started = true
		set_process(true)
	else:
		var t = create_tween()
		if bgs_player:
			t.tween_property(bgs_player, "volume_db", 0.0, 4.5)
		GameManager.set_weather_color(modulate_scene, 2.5)
		t.tween_callback(set.bind("is_started", true)).set_delay(2.5)
		t.tween_callback(set_process.bind(true)).set_delay(2.5)


## Cleans up audio effects, rescues reparented layers, and destroys the scene node.
func end() -> void:
	is_started = false
	_uninstall_fx()
	_rescue_layers()
	
	%Fish.visible = false
	%Foam.visible = false
	
	var bgs_player = get_node_or_null("%BGSPlayer")
	var t = create_tween()
	
	if bgs_player:
		t.tween_property(bgs_player, "volume_db", -80.0, 2.5)
		
	GameManager.set_weather_color(Color.WHITE, 2.5)
	t.tween_callback(queue_free).set_delay(2.5)


## Pulls layers back from the dying map and parks the background audio to survive the transition.
func hibernate() -> void:
	set_process(false)
	is_started = false
	_rescue_layers()
	
	var bgs_player = get_node_or_null("%BGSPlayer")
	if bgs_player and bgs_player.playing:
		var playback_pos = bgs_player.get_playback_position()
		bgs_player.set_meta("old_pos", playback_pos)
		bgs_player.reparent(GameManager)
		bgs_player.name = "WeatherAudio_Underwater"
		bgs_player.play(playback_pos)


## Disables shader sources, hides visuals, and fades out audio for indoor map areas.
func pause_weather() -> void:
	var bgs_player = get_node_or_null("%BGSPlayer")
	if bgs_player:
		var t = create_tween()
		t.tween_property(bgs_player, "volume_db", -80.0, 0.8)
		t.tween_callback(bgs_player.stop)
		
	_uninstall_fx()
	
	var main_sprite = get_node_or_null("%MainSprite")
	if main_sprite: main_sprite.visible = false
	
	var fish = get_node_or_null("%Fish")
	if fish: fish.visible = false
	
	var foam = get_node_or_null("%Foam")
	if foam: foam.visible = false
	
	if is_instance_valid(fish_layer): fish_layer.visible = false
	if is_instance_valid(foam_layer): foam_layer.visible = false
	
	GameManager.set_weather_color(Color.WHITE, 1.0)
	
	set_process(false)
	is_started = false


## Re-enables shader sources, restores visuals, reapplies global color tint, and resumes audio playback.
func resume_weather() -> void:
	var bgs_player = get_node_or_null("%BGSPlayer")
	if bgs_player:
		if not bgs_player.playing:
			bgs_player.volume_db = -80.0
			bgs_player.play()
		var t = create_tween()
		t.tween_property(bgs_player, "volume_db", 0.0, 2.5).set_delay(1.0)
		
	_install_fx()
	
	var main_sprite = get_node_or_null("%MainSprite")
	if main_sprite: main_sprite.visible = true
	
	var fish = get_node_or_null("%Fish")
	if fish: fish.visible = true
	
	var foam = get_node_or_null("%Foam")
	if foam: foam.visible = true
	
	if is_instance_valid(fish_layer): fish_layer.visible = true
	if is_instance_valid(foam_layer): foam_layer.visible = true
	
	GameManager.set_weather_color(modulate_scene, 2.5)
	
	set_process(true)
	is_started = true


## Safely attaches the foam and fish layers to the new map and calculates their shader scales.
func _setup_layers_to_map() -> void:
	var map: RPGMap = get_tree().get_first_node_in_group("rpgmap")
	if not map: return
	
	var map_rect = map.get_used_rect(false)
	
	if not is_instance_valid(foam_layer): foam_layer = %FoamFinal
	if not is_instance_valid(fish_layer): fish_layer = %FishFinal
	
	var final_scale = Vector2(map_rect.size) / Vector2(%Foam.size)
	var shader_scale = final_scale.normalized()

	%Fish.get_material().set_shader_parameter("global_scale", shader_scale)
	fish_layer.reparent(map)
	fish_layer.position = map_rect.position
	fish_layer.scale = final_scale

	%Foam.get_material().set_shader_parameter("global_scale", shader_scale)
	foam_layer.reparent(map)
	foam_layer.position = map_rect.position
	foam_layer.scale = final_scale


## Pulls the foam and fish layers back to this node so they aren't destroyed when the map frees them.
func _rescue_layers() -> void:
	if is_instance_valid(fish_layer) and fish_layer.get_parent() != self:
		fish_layer.reparent(self)
	if is_instance_valid(foam_layer) and foam_layer.get_parent() != self:
		foam_layer.reparent(self)


## Installs the underwater audio effect to the sound effects bus safely.
func _install_fx() -> void:
	if underwater_effects.is_empty(): return
	var bus_index = AudioServer.get_bus_index("SE")

	for fx in underwater_effects:
		var already_installed = false
		for i in range(AudioServer.get_bus_effect_count(bus_index)):
			if AudioServer.get_bus_effect(bus_index, i) == fx:
				already_installed = true
				break

		if not already_installed:
			AudioServer.add_bus_effect(bus_index, fx)
			var effect_index = AudioServer.get_bus_effect_count(bus_index) - 1
			AudioServer.set_bus_effect_enabled(bus_index, effect_index, true)


## Removes the array of underwater audio effects from the sound effects bus.
func _uninstall_fx() -> void:
	if underwater_effects.is_empty(): return
	var bus_index = AudioServer.get_bus_index("SE")

	for fx in underwater_effects:
		for i in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus_index, i) == fx:
				AudioServer.remove_bus_effect(bus_index, i)
				break


## Processes random bubble particle spawning logic.
func _process(_delta: float) -> void:
	if not is_started or not visible: return
	if not GameManager.current_player or not GameManager.current_map: return

	if randi() % 40 != 0: return

	var dice = randi() % 100
	var target: Node
	var particle_position: Vector2
	var particle_container: Node = GameManager.current_map.get_particle_container()
	var should_spawn: bool = false

	if dice < 30:
		var targets = GameManager.get_followers() + [GameManager.current_player]
		target = targets.pick_random()

		if not target is SimpleFollower and target.is_on_vehicle and target.current_vehicle and "player_position" in target.current_vehicle:
			pass
		else:
			particle_position = target.get_global_mouth_position()
			should_spawn = true

	elif dice < 92:
		var objs: Array

		if randi() % 2 == 0:
			var events = GameManager.current_map.get_in_game_events()
			objs = events.map(func(obj: IngameEvent): return obj.lpc_event)
		else:
			var vehicles = GameManager.current_map.get_in_game_vehicles()
			objs = []
			for vehicle in vehicles:
				if "is_a_living_creature" in vehicle and vehicle.is_a_living_creature == true:
					objs.append(vehicle)

		if objs.size() > 0:
			target = objs[randi() % objs.size()]
			if target:
				particle_position = target.get_global_mouth_position()
				should_spawn = true

	else:
		var pm = (randi() % 100 + 100) * (-1 if randi() % 2 == 0 else 1)
		particle_position = GameManager.current_player.position - Vector2(pm, pm)
		should_spawn = true

	if not should_spawn or not particle_container: return

	var particle = UNDER_WATER_BUBBLES.instantiate()
	particle.keep_position = false
	particle.position = particle_position

	if target and "current_direction" in target:
		if target.current_direction != CharacterBase.DIRECTIONS.UP:
			particle.z_index = 10
		else:
			particle.z_index = 0
			particle.z_as_relative = true

	particle_container.add_child(particle)
