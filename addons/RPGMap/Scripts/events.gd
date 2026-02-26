@tool
class_name RPGEvents
extends Resource

## The list of events contained in this resource.
@export var events: Array[RPGEvent] = []

var last_event_pasted_id: int

func get_next_id() -> int:
	events.sort_custom(sort_events_by_id)
	
	var expected_id: int = 1
	
	for event in events:
		if event.id == expected_id:
			expected_id += 1
		elif event.id > expected_id:
			return expected_id
			
	return expected_id


func add_event(event: RPGEvent) -> void:
	event.name = "EV" + str(event.id).pad_zeros(4)
	events.append(event)
	
	if events.size() > 0:
		events.sort_custom(sort_events_by_id)


func replace_event(event: RPGEvent) -> void:
	for i in events.size():
		if events[i].x == event.x and events[i].y == event.y:
			events[i] = event
			break


func paste_event_in(pos: Vector2i, new_event: RPGEvent) -> bool:
	for event in events:
		if event.x == pos.x and event.y == pos.y:
			event.name = new_event.name
			event.pages = new_event.pages
			last_event_pasted_id = event.id
			return true
	
	new_event.id = get_next_id()
	new_event.x = pos.x
	new_event.y = pos.y
	add_event(new_event)
	
	last_event_pasted_id = new_event.id
	
	return true


func get_last_event_added() -> int:
	return last_event_pasted_id


func remove_event(event: RPGEvent) -> void:
	if events.has(event):
		events.erase(event)


func remove_event_in(pos: Vector2i) -> bool:
	for event in events:
		if event.x == pos.x and event.y == pos.y:
			remove_event(event)
			return true
	
	return false


func sort_events_by_id(a: RPGEvent, b: RPGEvent) -> bool:
	return a.id < b.id


func get_event_in(pos: Vector2i) -> RPGEvent:
	var rpg_event
	for event in events:
		if event.x == pos.x and event.y == pos.y:
			rpg_event = event
			break
	
	return rpg_event


func get_event(index: int) -> RPGEvent:
	if events.size() > index and index >= 0:
		return events[index]
	else:
		return null


func get_event_by_id(id: int) -> RPGEvent:
	for event: RPGEvent in get_events():
		if event._uniq_id == id:
			return event
	
	return null


func get_event_by_uniq_id(id: int) -> RPGEvent:
	for event: RPGEvent in get_events():
		if event._uniq_id == id:
			return event
	
	return null


func get_events() -> Array:
	return events


func is_place_free_in(pos: Vector2i) -> bool:
	var result: bool = true
	for event in events:
		if event.x == pos.x and event.y == pos.y:
			result = false
			break
	
	return result


func size() -> int:
	return events.size()
