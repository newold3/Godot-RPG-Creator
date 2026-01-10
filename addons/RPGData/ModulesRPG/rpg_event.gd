@tool
class_name RPGEvent
extends Resource


func get_class(): return "RPGEvent"


@export var name : String = ""
@export var id : int = 0
@export var x : int = 0
@export var y : int = 0
@export var pages : Array[RPGEventPage] = []
@export var quests: Array[RPGEventPQuest] = []
@export var relationship: RPGRelationship = RPGRelationship.new()
@export var _editor_last_page_used: int
@export var legacy_mode: bool = false
@export var fade_page_swap_enabled: bool = false

var last_page_used: RPGEventPage


func _init(_id: int = 0, _x: int = 0, _y: int = 0) -> void:
	id = _id
	x = _x
	y = _y
	if pages.size() == 0:
		add_new_page(0)
	if RPGSYSTEM.database:
		legacy_mode = RPGSYSTEM.database.system.legacy_mode
		fade_page_swap_enabled = RPGSYSTEM.database.system.fade_page_swap_enabled


func initialize_page_ids() -> void:
	for i in pages.size():
		var page: RPGEventPage = pages[i]
		page.page_id = i + 1


func add_new_page(index: int) -> void:
	var new_page = RPGEventPage.new(pages.size())
	if index >= 0 and index < pages.size():
		pages.insert(index, new_page)
	else:
		pages.append(new_page)
	fix_pages_ids()


func remove_page(index: int) -> void:
	if index >= 0 and index < pages.size():
		pages.remove_at(index)
	fix_pages_ids()


func insert_page(page: RPGEventPage, index: int) -> void:
	pages.insert(index, page)
	fix_pages_ids()


func replace_page(index: int, page: RPGEventPage) -> void:
	page.id = index
	pages[index] = page


func fix_pages_ids() -> void:
	for i in pages.size():
		pages[i].id = i


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
		
	return new_event


func get_last_page_used() -> RPGEventPage:
	return last_page_used


func get_active_page() -> RPGEventPage:
	var current_page: RPGEventPage = null
	
	var game_state: GameUserData = GameManager.game_state
	
	if game_state:
		if id in game_state.current_events:
			var event_data: RPGEventSaveData = game_state.current_events[id]
			if event_data.active_page_id >= 0 and pages.size() > event_data.active_page_id:
				var page: RPGEventPage = pages[event_data.active_page_id]
				last_page_used = page
				return page
				
		for i: int in range(pages.size() - 1, -1, -1):
			var page: RPGEventPage = pages[i]
			
			if page.is_quest_page: continue
			
			var condition: RPGEventPageCondition = page.condition
			var c1: bool = true
			if condition.use_switch1:
				c1 = GameManager.get_switch(condition.switch1_id)
			var c2: bool = true
			if condition.use_switch2:
				c2 = GameManager.get_switch(condition.switch2_id)
			var c3: bool = true
			if condition.use_local_switch:
				c3 = GameManager.get_local_switch(condition.local_switch_id)
			var c4: bool = true
			if condition.use_variable:
				var variable_current_value: int = GameManager.get_variable(condition.variable_id)
				var compare_value: int = condition.variable_value
				c4 = false
				match condition.variable_operator:
					0: # <
						c4 = variable_current_value < compare_value
					1: # <=
						c4 = variable_current_value <= compare_value
					2: # ==
						c4 = variable_current_value == compare_value
					3: # >
						c4 = variable_current_value > compare_value
					4: # >=
						c4 = variable_current_value >= compare_value
					5: # !=
						c4 = variable_current_value != compare_value
			var c5 = true
			if condition.use_item:
				c5 = GameManager.is_item_in_possesion(condition.item_type, condition.item_id)
			var c6 = true
			if condition.use_actor:
				c6 = GameManager.is_actor_in_group(condition.actor_id)
			
			if (c1 and c2 and c3 and c4 and c5 and c6):
				last_page_used = page
				return page
	
	last_page_used = current_page
	return current_page


func is_equal_to(other: RPGEvent) -> bool:
	if not other:
		return false
		
	# Compare each exported property of RPGEvent
	for property in get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
			
		var prop_name = property.name
		var value_self = get(prop_name)
		var value_other = other.get(prop_name)
		
		if not _compare_values(value_self, value_other):
			return false
			
	return true


func _compare_values(a, b) -> bool:
	# If either is null
	if a == null or b == null:
		return a == b
		
	# If they are different types
	if typeof(a) != typeof(b):
		return false
		
	# If it's an array or packed array
	if a is Array or typeof(a) in [
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY,
		TYPE_PACKED_COLOR_ARRAY
	]:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _compare_values(a[i], b[i]):
				return false
		return true
		
	# If it's a dictionary
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key):
				return false
			if not _compare_values(a[key], b[key]):
				return false
		return true
		
	# If it's a custom object (RPGActor, RPGSkill, etc.)
	if a is Object and a.has_method("get_property_list"):
		# If they are different classes
		if a.get_class() != b.get_class():
			return false
			
		# Compare each exported property
		for property in a.get_property_list():
			if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
				
			var prop_name = property.name
			var value_a = a.get(prop_name)
			var value_b = b.get(prop_name)
			
			if not _compare_values(value_a, value_b):
				return false
				
		return true
		
	# For basic types (int, float, string, bool)
	return a == b


func _to_string() -> String:
	return "<RPGEvent: ID: %s, Name: %s, Position: %sx, %sy>" % [id, name, x, y]
