class_name MeleeActionBase
extends CombatActionBase

## Handles ephemeral hitboxes and logic for melee attacks.


## How long the melee hitbox remains active after shoot() is called.
@export var duration: float = 0.2

var _hit_targets: Array[Node2D] = []


func setup(_action_id: String, direction: String, start_pos: Vector2, custom_stats: Dictionary = {}) -> void:
	position = start_pos
	
	damage = custom_stats.get("damage", damage)
	duration = custom_stats.get("duration", duration)
	
	if collision_shape:
		var tile_size: float = 32.0 
		if GameManager.current_map and "tile_size" in GameManager.current_map:
			var ts = GameManager.current_map.tile_size
			tile_size = ts.x if typeof(ts) == TYPE_VECTOR2I else float(ts)
			
		var shape_type = custom_stats.get("shape_type", "circle")
		
		if shape_type == "rect":
			if not (collision_shape.shape is RectangleShape2D):
				collision_shape.shape = RectangleShape2D.new()
				
			var w = custom_stats.get("shape_width", 0.8) * tile_size
			var h = custom_stats.get("shape_height", 0.8) * tile_size
			
			var dir_lower = direction.to_lower()
			if dir_lower == "left" or dir_lower == "right":
				collision_shape.shape.size = Vector2(h, w)
			else:
				collision_shape.shape.size = Vector2(w, h)
				
		else:
			if not (collision_shape.shape is CircleShape2D):
				collision_shape.shape = CircleShape2D.new()
			var r = custom_stats.get("shape_width", 0.8) * tile_size
			collision_shape.shape.radius = r
			
	var default_sound_path: String = custom_stats.get("initial_sound", "")
	_play_initial_sound(default_sound_path)


## Plays the initial weapon sound based on the path provided by the player.
func _play_initial_sound(sound_path: String = "") -> void:
	if sound_path.is_empty():
		return
		
	var fx = ZipMediaLoader.get_audio_stream(sound_path)
	if fx:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = fx
		audio_player.bus = "SE"
		var parent = get_parent()
		if parent:
			parent.add_child(audio_player)
			audio_player.play()
			audio_player.finished.connect(func(): audio_player.queue_free())


## Enables the hitbox and starts the lifetime timer.
func shoot() -> void:
	super.shoot()
	
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(destroy)


func hit(target: Node2D = null) -> void:
	if _is_destroyed or is_queued_for_deletion():
		return
		
	if target:
		var target_parent = target.get_parent()
		if player and target_parent and player == target_parent:
			return
			
		if target in _hit_targets:
			return
			
		if is_instance_valid(player) and target == player:
			return
			
		if target_parent.is_in_group("event"):
			print("event")
			pass
			
		_hit_targets.append(target)
		_play_impact_sound()


## Plays specific sounds when the weapon strikes a target.
func _play_impact_sound() -> void:
	var stream_path = "uid://did4aih30hyu7"
	var fx = ZipMediaLoader.get_audio_stream(stream_path)
	print(fx)
	if fx:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = fx
		audio_player.bus = "SE"
		var parent = get_parent()
		if parent:
			parent.add_child(audio_player)
			audio_player.play()
			audio_player.finished.connect(func(): audio_player.queue_free())
