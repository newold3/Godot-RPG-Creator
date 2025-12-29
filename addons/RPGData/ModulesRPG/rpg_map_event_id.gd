@tool
class_name RPGMapEventID
extends  Resource

func get_class(): return "RPGMapEventID"

## Indicates a event on a specific map

## Destination map id
@export var map_id: int = -1
## Current event on the map
@export var event_id: int = -1
## Current page for the event
@export var event_page_id: int = -1


func _init(_map_id : int = -1, _event_id: int = -1, _event_page_id: int = -1) -> void:
	map_id = _map_id
	event_id = _event_id
	event_page_id = _event_page_id


func clear():
	map_id = -1
	event_id = -1
	event_page_id  = -1


func clone(value: bool) -> RPGMapEventID:
	return duplicate(value)


func _to_string() -> String:
	return "<RPGMapPosition: map_id: %s, event_id: %s>" % [map_id, event_id]
