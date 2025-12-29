@tool
extends Node2D
class_name CustomAudioPlayer2D

# Use only in Editor tool Script, cause AudioPlayer2D dont works
@export var stream: AudioStream
@export var base_volume_db: float = 0.0
@export var max_distance: float = 2000.0

# Static variables
static var listener_position: Vector2 = Vector2.ZERO
static var pan_sum: float = 0.0
static var active_nodes: int = 0

var audio_player: AudioStreamPlayer


func _ready():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	audio_player.stream = stream
	audio_player.volume_db = base_volume_db
	audio_player.bus = "SE"
	
	audio_player.play()
	
	active_nodes += 1
	
	tree_exiting.connect(func():
		active_nodes -= 1
		pan_sum -= calculate_pan()
		update_combined_pan()
	)


func _process(delta: float) -> void:
	update_pan_and_volume()


func update_pan_and_volume():
	var distance_squared = global_transform.origin.distance_squared_to(listener_position)
	var max_distance_squared = max_distance * max_distance
	
	var linear_energy = max(0.0, 1.0 - (distance_squared / max_distance_squared))
	audio_player.volume_db = linear_to_db(linear_energy) + base_volume_db
	
	var old_pan = calculate_pan()
	pan_sum -= old_pan
	
	var new_pan = calculate_pan()
	pan_sum += new_pan
	
	update_combined_pan()


func calculate_pan() -> float:
	var relative_position = global_transform.origin - listener_position
	var pan = relative_position.x / max_distance
	return clamp(pan, -1.0, 1.0)


static func update_combined_pan():
	if active_nodes > 0:
		var combined_pan = pan_sum / active_nodes
		AudioServer.get_bus_effect(AudioServer.get_bus_index("SE"), 0).pan = combined_pan
	else:
		# Reset pan when no active nodes
		AudioServer.get_bus_effect(AudioServer.get_bus_index("SE"), 0).pan = 0.0


# Static method to get the current combined pan value
static func get_current_pan() -> float:
	return pan_sum / active_nodes if active_nodes > 0 else 0.0


# Static method to set the listener position
static func set_listener_position(new_position: Vector2):
	listener_position = new_position


# Static method to get the current listener position
static func get_listener_position() -> Vector2:
	return listener_position
