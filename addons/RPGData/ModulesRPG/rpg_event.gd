@tool
class_name RPGEvent
extends Resource


## Returns the class name for engine identification.
func get_class(): return "RPGEvent"


## Unique 16-digit identifier for the event resource.
@export var _uniq_id: int = -1 :
	get():
		if _uniq_id == -1: _uniq_id = _generate_16_digit_id()
		return _uniq_id

## Display name for the event in the editor.
@export var name : String = ""

## Database identifier for the event.
@export var id : int = 0

## X-coordinate position on the map grid.
@export var x : int = 0

## Y-coordinate position on the map grid.
@export var y : int = 0

## Collection of pages containing visual and logic data.
@export var pages : Array[RPGEventPage] = []

## Active quests associated with this specific event.
@export var quests: Array[RPGEventPQuest] = []

## Social and faction relationship data for this event.
@export var relationship: RPGRelationship = RPGRelationship.new()

## Internal storage for the last page viewed in the database editor.
@export var _editor_last_page_used: int

## If true, uses older logic systems for backwards compatibility.
@export var legacy_mode: bool = false

## If enabled, a visual fade effect is applied when switching between event pages.
@export var fade_page_swap_enabled: bool = false

## Runtime reference to the last executed or displayed page.
var last_page_used: RPGEventPage


## Generates a unique 16-digit integer for internal identification.
func _generate_16_digit_id() -> int:
	var id = str(randi_range(1, 9))
	var characters = "0123456789"
	for i in range(15):
		var random_index = randi() % characters.length()
		id += characters.substr(random_index, 1)
	
	return int(id)


## Initializes the event with basic positioning and ensures at least one page exists.
func _init(_id: int = 0, _x: int = 0, _y: int = 0) -> void:
	id = _id
	x = _x
	y = _y
	if pages.size() == 0:
		add_new_page(0)


## Synchronizes the page_id property of all pages based on their current array index.
func initialize_page_ids() -> void:
	for i in pages.size():
		var page: RPGEventPage = pages[i]
		page.page_id = i + 1


## Appends or inserts a new blank page and refreshes internal IDs.
func add_new_page(index: int) -> void:
	var new_page = RPGEventPage.new(pages.size())
	if index >= 0 and index < pages.size():
		pages.insert(index, new_page)
	else:
		pages.append(new_page)
	fix_pages_ids()


## Deletes a page at the specified index and updates remaining IDs.
func remove_page(index: int) -> void:
	if index >= 0 and index < pages.size():
		pages.remove_at(index)
	fix_pages_ids()


## Inserts an existing page resource into a specific position.
func insert_page(page: RPGEventPage, index: int) -> void:
	pages.insert(index, page)
	fix_pages_ids()


## Replaces a specific page index with a new page resource.
func replace_page(index: int, page: RPGEventPage) -> void:
	page.id = index
	pages[index] = page


## Reassigns the ID property of all pages to match their array sequence.
func fix_pages_ids() -> void:
	for i in pages.size():
		pages[i].id = i


## Creates a deep copy of the event, including all pages and quest data.
func clone(value: bool = true) -> RPGEvent:
	var new_event = duplicate(value)
	
	new_event.pages.assign([])
	for i in pages.size():
		new_event.pages.append(pages[i].clone(value))
	
	for i in quests.size():
		new_event.quests[i] = new_event.quests[i].clone(value)
		
	if not new_event.relationship:
		new_event.relationship = RPGRelationship.new()
	else:
		new_event.relationship = new_event.relationship.clone(value)
	
	new_event._uniq_id = _generate_16_digit_id()
		
	return new_event


## Accessor for the runtime cached page.
func get_last_page_used() -> RPGEventPage:
	return last_page_used


## Evaluates if any of the provided tool IDs can activate a page, respecting right-to-left priority.
func get_page_by_tool(tool_ids: PackedInt32Array) -> RPGEventPage:
	for i: int in range(pages.size() - 1, -1, -1):
		var page: RPGEventPage = pages[i]
		
		if page.is_quest_page:
			continue
			
		if _are_page_conditions_met(page):
			for t_id in tool_ids:
				if t_id in page.event_tool_list:
					page._event_owner = _uniq_id
					return page
			return null
			
	return null


## Evaluates if any of the provided signal IDs can activate a page, respecting right-to-left priority.
func get_page_by_signal(signal_ids: PackedInt32Array) -> RPGEventPage:
	for i: int in range(pages.size() - 1, -1, -1):
		var page: RPGEventPage = pages[i]
		
		if page.is_quest_page:
			continue
			
		if _are_page_conditions_met(page):
			for s_id in signal_ids:
				if s_id in page.event_signal_list:
					page._event_owner = _uniq_id
					return page
			return null
			
	return null


## Searches for a specific quest page based on its unique identifier.
func get_page_by_quest(quest_page_uniq_id: int) -> RPGEventPage:
	for page in pages:
		if page.is_quest_page and page._uniq_id == quest_page_uniq_id:
			page._event_owner = _uniq_id
			return page
			
	return null


## Determines the active page by evaluating conditions from right to left (priority).
func get_active_page() -> RPGEventPage:
	if Engine.is_editor_hint():
		for i: int in range(pages.size() - 1, -1, -1):
			var page: RPGEventPage = pages[i]
			
			if (
				page.launcher == page.LAUNCHER_MODE.TOOL or
				page.launcher == page.LAUNCHER_MODE.SIGNAL or
				page.is_quest_page
			):
				continue 
			
			var condition: RPGEventPageCondition = page.condition
			
			var has_any_condition: bool = (
				condition.use_switch1 or 
				condition.use_switch2 or 
				condition.use_local_switch or 
				condition.use_variable or 
				condition.use_item or 
				condition.use_actor or
				condition.use_pressure
			)
			
			if not has_any_condition:
				last_page_used = page
				return page
		
		if not pages.is_empty():
			last_page_used = pages[0]
			return pages[0]
			
		return null

	for i: int in range(pages.size() - 1, -1, -1):
		var page: RPGEventPage = pages[i]
		
		if page.is_quest_page: 
			continue
		
		if _are_page_conditions_met(page):
			last_page_used = page
			page._event_owner = _uniq_id
			return page
	
	last_page_used = null
	return null


## Helper function to evaluate all runtime conditions for a given page.
func _are_page_conditions_met(page: RPGEventPage) -> bool:
	var condition: RPGEventPageCondition = page.condition
	
	if condition.use_switch1 and not GameManager.get_switch(condition.switch1_id): return false
	if condition.use_switch2 and not GameManager.get_switch(condition.switch2_id): return false
	if condition.use_local_switch and not GameManager.get_local_switch(condition.local_switch_id): return false
	if condition.use_pressure and not _is_pressed(condition.pressure_targets): return false
	
	if condition.use_variable:
		var current_value: int = GameManager.get_variable(condition.variable_id)
		var compare_value: int = condition.variable_value
		match condition.variable_operator:
			0: if not (current_value < compare_value): return false
			1: if not (current_value <= compare_value): return false
			2: if not (current_value == compare_value): return false
			3: if not (current_value > compare_value): return false
			4: if not (current_value >= compare_value): return false
			5: if not (current_value != compare_value): return false
			
	if condition.use_item and not GameManager.is_item_in_possesion(condition.item_type, condition.item_id): return false
	if condition.use_actor and not GameManager.is_actor_in_group(condition.actor_id): return false
	
	return true


## Evaluates if the event's grid cell is occupied by any valid targets.
func _is_pressed(targets: PackedInt64Array) -> bool:
	var current_ingame_event = GameManager.get_in_game_event_by_uniq_id(_uniq_id)

	if not current_ingame_event:
		return false
		
	var events: Array[IngameEvent] = GameManager.get_ingame_events()
	
	if events.is_empty():
		return false

	var my_cell: Vector2i = current_ingame_event.get_current_virtual_tile()

	if targets.has(0):
		if GameManager.current_player:
			var p_cell: Vector2i = GameManager.current_player.get_current_virtual_tile()
			if my_cell == p_cell:
				return true
				
		var followers: Array = GameManager.get_followers()
		for f in followers:
			if is_instance_valid(f):
				var f_cell: Vector2i = f.get_current_virtual_tile()
				if my_cell == f_cell:
					return true
					
	var check_specific_events: bool = false
	for t in targets:
		if t > 0:
			check_specific_events = true
			break
			
	if check_specific_events:
		for e in events:
			var node = e.lpc_event
			if not is_instance_valid(node):
				continue
				
			var e_uniq_id: int = e.uniq_id
			
			if e_uniq_id == _uniq_id:
				continue
				
			if targets.has(e_uniq_id):
				var e_cell: Vector2i = node.get_current_virtual_tile()
				if my_cell == e_cell:
					return true
	return false


## Compares this event with another based on storage-usage properties.
func is_equal_to(other: RPGEvent) -> bool:
	if not other:
		return false
		
	for property in get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
			
		var prop_name = property.name
		var value_self = get(prop_name)
		var value_other = other.get(prop_name)
		
		if not _compare_values(value_self, value_other):
			return false
			
	return true


## Internal recursive helper to compare nested arrays, dictionaries, and objects.
func _compare_values(a, b) -> bool:
	if a == null or b == null:
		return a == b
		
	if typeof(a) != typeof(b):
		return false

	if a is Array or typeof(a) in [TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY]:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _compare_values(a[i], b[i]):
				return false
		return true

	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key):
				return false
			if not _compare_values(a[key], b[key]):
				return false
		return true
		
	if a is Object:
		var script_a = a.get_script()
		var script_b = b.get_script()
		if script_a != script_b:
			return false
			
		if a.has_method("get_property_list"):
			for property in a.get_property_list():
				if not (property.usage & PROPERTY_USAGE_STORAGE):
					continue
				
				var prop_name = property.name
				var value_a = a.get(prop_name)
				var value_b = b.get(prop_name)
				
				if not _compare_values(value_a, value_b):
					return false
			return true
		
	return a == b


func _to_string() -> String:
	return "<RPGEvent: ID: %s, Name: %s, Position: %sx, %sy Internal ID: %s>" % [id, name, x, y, _uniq_id]
