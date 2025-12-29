@tool
class_name RPGEvents
extends Resource

## The list of events contained in this resource.
@export var events: Array[RPGEvent] = []


var last_event_pasted_id: int


## Calculates the lowest available ID by checking gaps in the sorted event list.
## E.g., if IDs [2, 3] exist, this returns 1. If [1, 2] exist, returns 3.
func get_next_id() -> int:
	# 1. Ensure events are sorted by ID to check for gaps in order
	events.sort_custom(sort_events_by_id)
	
	var expected_id: int = 1
	
	for event in events:
		# If the current event ID matches what we expect, increment the counter
		if event.id == expected_id:
			expected_id += 1
		# If we find an event ID greater than expected, it means we found a gap!
		# (e.g. expected 1, but found 2 -> 1 is free)
		elif event.id > expected_id:
			return expected_id
			
	# If no gaps were found in the loop, the next ID is simply the next number
	return expected_id


## Adds a new event to the list, naming it automatically and sorting the list.
func add_event(event: RPGEvent) -> void:
	# Assign name based on ID format EV0000
	event.name = "EV" + str(event.id).pad_zeros(4)
	events.append(event)
	
	# Keep the list sorted to ensure get_next_id works fast
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


## Sorts two events based on their ID property.
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
		if event.id == id:
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
