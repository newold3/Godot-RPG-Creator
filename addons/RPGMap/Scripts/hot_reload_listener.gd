extends Node

var udp := PacketPeerUDP.new()
var listen_port := 4242


func _ready() -> void:
	if OS.has_feature("editor"):
		set_process(false)
		return
		
	udp.bind(listen_port)


func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var packet := udp.get_packet()
		
		var data_string := packet.get_string_from_utf8()
		
		var data: Dictionary = JSON.parse_string(data_string)
		
		_route_hot_reload(data)


func _route_hot_reload(data: Dictionary) -> void:
	if not data or not GameManager.current_map:
		return
		
	var current_map = GameManager.current_map
	
	if data.get("map_id") != current_map.internal_id:
		return
		
	var type: String = data.get("type", "")
	var id: int = data.get("id", -1)
	var path: String = data.get("path", "")
	
	match type:
		"update_event":
			current_map.call("_hot_reload_event", id, path)
		"update_extraction_event":
			current_map.call("_hot_reload_extraction_event", id, path)
		"update_enemy_spawn":
			current_map.call("_hot_reload_enemy_spawn", id, path)
		"update_event_region":
			current_map.call("_hot_reload_event_region", id, path)
		"move_event":
			var ev = current_map.get_in_game_event_by_id(id)
			if ev:
				current_map.set_event_position(ev, Vector2i(data.get("x"), data.get("y")), ev.current_direction)
