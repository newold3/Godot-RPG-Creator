@tool
extends Node2D

## The color used to modulate the scene weather.
@export var modulate_scene: Color = Color("#628bfa")

## Array of audio effects to simulate a realistic underwater environment (LowPass, Reverb, Chorus).
@export var underwater_effects: Array[AudioEffect]

const UNDER_WATER_BUBBLES = preload("res://Scenes/ParticleScenes/under_water_bubbles.tscn")

var foam_layer: Sprite2D
var fish_layer: Sprite2D


## Returns the class name for identification.
func get_class() -> String:
	return "WeatherScene"


## Initializes the weather scene, setting up visuals and audio effects.
func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
	else:
		set_repeat_and_foam()
		GameManager.set_weather_color(modulate_scene, 2.5)
		ignore_start_animation()

	_install_fx()


## Cleans up the audio effects when the node is removed from the scene tree.
func _exit_tree() -> void:
	_uninstall_fx()


## Installs the underwater audio effect to the sound effects bus safely.
func _install_fx() -> void:
	if underwater_effects.is_empty():
		return

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
	if underwater_effects.is_empty():
		return

	var bus_index = AudioServer.get_bus_index("SE")

	for fx in underwater_effects:
		for i in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus_index, i) == fx:
				AudioServer.remove_bus_effect(bus_index, i)
				break


## Cancels any starting underwater tweens to prevent visual glitches.
func ignore_start_animation() -> void:
	var tweens = get_tree().get_processed_tweens()

	for t in tweens:
		if t.is_valid() and t.has_meta("underwater_start_tween"):
			t.kill()


## Sets up the repeating water foam and fish layers on the current map.
func set_repeat_and_foam() -> void:
	var map: RPGMap = get_tree().get_first_node_in_group("rpgmap")

	if map:
		var map_rect = map.get_used_rect(false)
		var final_scale = Vector2(map_rect.size) / Vector2(%Foam.size)
		var shader_scale = final_scale.normalized()

		%Fish.get_material().set_shader_parameter("global_scale", shader_scale)
		fish_layer = %FishFinal
		fish_layer.reparent(GameManager.current_map)
		fish_layer.position = map_rect.position
		fish_layer.scale = final_scale
		tree_exiting.connect(fish_layer.queue_free)

		%Foam.get_material().set_shader_parameter("global_scale", shader_scale)
		foam_layer = %FoamFinal
		foam_layer.reparent(GameManager.current_map)
		foam_layer.position = map_rect.position
		foam_layer.scale = final_scale
		tree_exiting.connect(foam_layer.queue_free)


## Processes random bubble particle spawning logic.
func _process(_delta: float) -> void:
	if not GameManager.current_player or not GameManager.current_map:
		return

	if randi() % 40 != 0:
		return

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

	if not should_spawn or not particle_container:
		return

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
