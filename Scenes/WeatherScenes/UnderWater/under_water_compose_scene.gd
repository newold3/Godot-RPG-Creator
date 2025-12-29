@tool
extends Node2D

func get_class() -> String:
	return "WeatherScene"

@export var modulate_scene: Color = Color("#628bfa")

const UNDER_WATER_BUBBLES = preload("res://Scenes/ParticleScenes/under_water_bubbles.tscn")

var foam_layer: Sprite2D
var fish_layer: Sprite2D


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
	else:
		set_repeat_and_foam()
		GameManager.set_weather_color(modulate_scene, 2.5)
			
		ignore_start_animation()


func ignore_start_animation() -> void:
	var tweens = get_tree().get_processed_tweens()
	for t in tweens:
		if t.is_valid() and t.has_meta("underwater_start_tween"):
			t.kill()
	if GameManager.main_scene:
		GameManager.main_scene.modulate = modulate_scene


func set_repeat_and_foam() -> void:
	var map: RPGMap = get_tree().get_first_node_in_group("rpgmap")
	if map:
		var map_rect = map.get_used_rect(false)
		#repeat_size = map_rect.size
		
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



func _process(_delta: float) -> void:
	if not GameManager.current_player or not GameManager.current_map:
		return
	
	if randi() % 40 == 0:
		var dice = randi() % 100
		var target: Node
		var particle_position: Vector2
		var particle_container: Node
		if dice < 30:
			target = GameManager.current_player
			if target.is_on_vehicle and target.current_vehicle and "player_position" in target.current_vehicle:
				pass
			else:
				particle_position = target.get_global_mouth_position()

			particle_container = GameManager.current_map.get_particle_container()
		elif dice < 92:
			var objs: Array
			if randi() % 2 == 0:
				var events = GameManager.current_map.get_in_game_events()
				objs = events.map(func(obj: RPGMap.IngameEvent): return obj.lpc_event)
			else:
				var vehicles = GameManager.current_map.get_in_game_vehicles()
				objs = []
				for vehicle in vehicles:
					if "is_a_living_creature" in vehicle and vehicle.is_a_living_creature == true:
						objs.append(vehicle)
						
			if objs.size() == 0: return
			
			target = objs[randi() % objs.size()]
			
			if not target: return
			particle_position = target.get_global_mouth_position() #target.get_current_position() + target.get_mouth_position()
			particle_container = GameManager.current_map.get_particle_container()
		else:
			var pm = (randi() % 100 + 100) * (-1 if randi() % 2 == 0 else 1)
			particle_position = GameManager.current_player.position - Vector2(pm, pm)
			particle_container = GameManager.current_map.get_particle_container()
		
		# Create Particle
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
