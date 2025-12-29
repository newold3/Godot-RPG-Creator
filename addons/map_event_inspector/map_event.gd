@tool
class_name MapEvent
extends Resource

## The internal ID of the selected event.
## We do not use @export here because we define the property manually in _get_property_list.
var event_id: int = 0


## Returns the runtime Node2D associated with this event ID from the current map.
func get_event() -> Node2D:
	if event_id <= 0:
		return null
	
	if GameManager.current_map:
		return GameManager.current_map.get_in_game_event(event_id)
	
	return null


func _get_property_list() -> Array:
	var properties: Array = []
	
	# We only generate the dynamic dropdown inside the Editor
	if Engine.is_editor_hint():
		var enum_string: String = "None:0"
		var root = EditorInterface.get_edited_scene_root()
		var id_found_in_list: bool = false
		
		# Check if we are currently editing an RPGMap
		if root and root is RPGMap:
			var event_list = root.events.get_events()
			
			for event in event_list:
				var raw_name = str(event.get("name"))
				var real_id = event.get("id")
				
				if real_id == event_id:
					id_found_in_list = true
				
				# Sanitize: Remove commas and colons to prevent breaking the ENUM format
				var safe_name = raw_name.replace(",", ".").replace(":", "")
				
				# Append option: "ID - Name:ID"
				enum_string += ",%s - %s:%s" % [str(real_id), safe_name, str(real_id)]
		
		# CRITICAL: If we have a saved ID that is no longer on the map,
		# we inject it into the list so the Inspector displays it as "MISSING" 
		# instead of resetting the value to 0 or showing an index error.
		if event_id > 0 and not id_found_in_list:
			enum_string += ",⚠ MISSING (ID %s):%s" % [str(event_id), str(event_id)]
		
		# Manually define the property to force the Dropdown (ENUM) appearance
		properties.append({
			"name": "event_id",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, # Ensures it is saved (STORAGE) and shown (EDITOR)
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": enum_string
		})
		
	return properties
