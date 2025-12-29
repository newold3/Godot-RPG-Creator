extends Node
class_name MapLayout

## The size (in pixels) of each cell in the spatial grid.
## Adjust based on your game's size and event density. 256 or 512 is a good start.
@export var quadrant_size: int = 50

## Stores events by quadrant.
## Format: { Vector2i(quad_id): [event1, event2, ...] }
var quadrant_data: Dictionary = {}

## A reverse index to quickly find which quadrant an event is in.
## Format: { event_instance: Vector2i(quad_id) }
var event_location: Dictionary = {}


## Calculates the quadrant ID for a world position.
func _get_quadrant_id(pos: Vector2) -> Vector2i:
	if quadrant_size <= 0:
		printerr("MapLayout quadrant_size is not set or is zero.")
		return Vector2i.ZERO
	return Vector2i(floor(pos.x / quadrant_size), floor(pos.y / quadrant_size))


## Adds or updates an event's position in the grid.
## This function is efficient and only performs work if the event
## has actually changed quadrants.
func update_event_position(event: Node) -> void:
	if not is_instance_valid(event):
		return
		
	var new_quad_id = _get_quadrant_id(event.position)
	var old_quad_id = event_location.get(event, null)
	
	# If the quadrant hasn't changed, do nothing.
	if new_quad_id == old_quad_id:
		return

	if old_quad_id != null and quadrant_data.has(old_quad_id):
		quadrant_data[old_quad_id].erase(event)
		
	if not quadrant_data.has(new_quad_id):
		quadrant_data[new_quad_id] = []
	
	quadrant_data[new_quad_id].append(event)
	event_location[event] = new_quad_id


## Removes an event from the grid (e.g., if it's destroyed).
func remove_event_from_layout(event: Node) -> void:
	var current_quad_id = event_location.get(event, null)
	
	if current_quad_id != null and quadrant_data.has(current_quad_id):
		quadrant_data[current_quad_id].erase(event)
		
	if event_location.has(event):
		event_location.erase(event)


## Returns an Array of all events in the position's quadrant
## and the 8 adjacent quadrants.
func get_events_near_position(pos: Vector2) -> Array:
	var nearby_events: Array = []
	var center_quad_id = _get_quadrant_id(pos)

	# Iterate over the central quadrant and the 8 surrounding ones (3x3)
	for x in range(-1, 2): # -1, 0, 1
		for y in range(-1, 2): # -1, 0, 1
			var quad_id = center_quad_id + Vector2i(x, y)
			
			if quadrant_data.has(quad_id):
				nearby_events.append_array(quadrant_data[quad_id])
				
	return nearby_events
