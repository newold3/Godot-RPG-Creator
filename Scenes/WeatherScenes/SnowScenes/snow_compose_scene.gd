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

@onready var bgs_player: AudioStreamPlayer = %BGSPlayer




func _ready() -> void:
	set_process(false)
	
	if !Engine.is_editor_hint():
		while !shadow_container:
			shadow_container = get_tree().get_first_node_in_group("dynamic_shadow_container")
			await get_tree().process_frame


func start(skip_animation: bool = false) -> void:
	shadow_container = get_tree().get_first_node_in_group("dynamic_shadow_container")
	var orphaned_audio = GameManager.get_node_or_null("WeatherAudio_Snow")
	
	if skip_animation and orphaned_audio:
		var old_pos = orphaned_audio.get_meta("old_pos", 0.0)
		bgs_player.volume_db = orphaned_audio.volume_db
		bgs_player.play(old_pos)
		orphaned_audio.queue_free()
	elif skip_animation and not orphaned_audio:
		bgs_player.volume_db = -80.0
		bgs_player.play()
	elif not skip_animation:
		bgs_player.volume_db = -80.0
		bgs_player.play()
	
	var nodes = [%TrailScene, %SnowScene, %TileableSnow]
	
	if skip_animation:
		if shadow_container:
			shadow_container.modulate.a = MIN_SHADOW_OPACITY
		for node in nodes:
			node.visible = true
			node.modulate.a = 1.0
		GameManager.set_weather_color(modulate_scene, 0.0)
		set_process(true)
	else:
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(bgs_player, "volume_db", 0.0, 4.5)
		if shadow_container:
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
	if not visible: return
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
	t.tween_property(bgs_player, "pitch_scale", randf_range(0.8, 1.2), 0.5)


func pause_weather() -> void:
	hide()
	var node = bgs_player
	var t = node.create_tween()
	t.tween_property(node, "volume_db", -60.0, 0.8)
	set_process(false)


func resume_weather() -> void:
	if not bgs_player.playing:
		bgs_player.volume_db = -80.0
		bgs_player.play()
		
	var t = create_tween()
	t.tween_property(bgs_player, "volume_db", 0.0, 1.5)
	
	set_process(true)


func hibernate() -> void:
	if bgs_player.playing:
		var audio_node = bgs_player
		var playback_pos = audio_node.get_playback_position()
		audio_node.set_meta("old_pos", playback_pos)
		audio_node.reparent(GameManager)
		audio_node.name = "WeatherAudio_Snow"
		audio_node.play(playback_pos)
