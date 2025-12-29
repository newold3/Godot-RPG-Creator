@tool
extends Node2D


func get_class() -> String:
	return "WeatherScene"


@export var modulate_scene: Color = Color("#081662")


var snow_hits_fxs = [
	preload("res://Assets/Sounds/SE/snow_hit1.ogg"),
	preload("res://Assets/Sounds/SE/snow_hit2.ogg"),
	preload("res://Assets/Sounds/SE/snow_hit3.ogg"),
	preload("res://Assets/Sounds/SE/snow_hit4.ogg")
]


const SNOW_IMPACT = preload("res://Scenes/WeatherScenes/SnowScenes/snow_impact.tscn")
const MIN_SHADOW_OPACITY = 0.4

var shadow_container


func _ready() -> void:
	set_process(false)
	
	if !Engine.is_editor_hint():
		while !shadow_container:
			shadow_container = get_tree().get_first_node_in_group("dynamic_shadow_container")
			await get_tree().process_frame
		start()


func start() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	var nodes = [%TrailScene, %SnowScene, %TileableSnow]
	
	%BGSPlayer.volume_db = -80
	%BGSPlayer.play()
	
	var t = create_tween()
	t.set_parallel(true)
	
	t.tween_property(%BGSPlayer, "volume_db", 0.0, 4.5)
	t.tween_property(shadow_container, "modulate:a", MIN_SHADOW_OPACITY, 4.5)
	
	for node in nodes:
		node.visible = true
		node.modulate.a = 0.0
		t.tween_property(node, "modulate:a", 1.0, 4.5)
	
	GameManager.set_weather_color(modulate_scene, 2.5)
	
	t.tween_callback(set_process.bind(true)).set_delay(2.5)


func end() -> void:
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(shadow_container, "modulate:a", 1.0, 4.5)


func _process(_delta: float) -> void:
	var luck = randi() % 200
	if luck == 0:
		animate_wind_pitch()
	elif luck > 185:
		create_impact()


func create_impact() -> void:
	var player: LPCCharacter = get_tree().get_first_node_in_group("player")
	if player:
		var viewport_size = get_viewport().size / 2
		var new_position = Vector2(
			player.global_position.x + randi_range(-viewport_size.x, viewport_size.x),
			player.global_position.y + randi_range(-viewport_size.y, viewport_size.y)
		)
		new_position = GameManager.current_map.get_wrapped_position(new_position)
		var node_impact = SNOW_IMPACT.instantiate()
		%ImpacstGroup.add_child(node_impact)
		node_impact.start(new_position)
			
		var impact_fx = snow_hits_fxs.pick_random()
		%SEPlayer.stream = impact_fx
		%SEPlayer.play()


func animate_wind_pitch() -> void:
	var t = create_tween()
	t.tween_property(%BGSPlayer, "pitch_scale", randf_range(0.8, 1.2), 0.5)
