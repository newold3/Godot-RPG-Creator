@tool
extends CommandBaseDialog

#region Variables
var priority_index: int = -1
var current_priorities: PackedInt32Array = []
#endregion



#region Lifecycle & Setup
## Initializes the base configuration for the priority command
func _ready() -> void:
	super()
	parameter_code = 123
	%TargetList.get_v_scroll_bar().value_changed.connect(_reposition_priority_node)
	fill_targets()



## Populates the list with Player and all map events securely using UIDs
func fill_targets() -> void:
	var list = %TargetList
	list.clear()
	
	list.add_item("Player")
	list.set_item_metadata(0, 0)
	
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene is RPGMap:
		var events = edited_scene.events.get_events()
	
		for ev: RPGEvent in events:
			var text = "Event #%s: %s" % [ev.id, ev.name]
			list.add_item(text)
			var real_id = ev._uniq_id if "_uniq_id" in ev else ev.id
			list.set_item_metadata(list.get_item_count() - 1, real_id)



## Selects elements and restores their saved priority values from loaded data
func set_targets_by_ids(saved_ids: PackedInt64Array, saved_priorities: PackedInt32Array) -> void:
	var list = %TargetList
	var total_items = list.get_item_count()
	
	current_priorities.clear()
	for i in range(total_items):
		current_priorities.append(5)
	
	if saved_ids.size() == 0:
		list.select(0)
	else:
		for i in range(saved_ids.size()):
			var target_id = saved_ids[i]
			var target_priority = 5
			if i < saved_priorities.size():
				target_priority = saved_priorities[i]
			
			for item_idx in range(total_items):
				var meta_id = list.get_item_metadata(item_idx)
				if meta_id == target_id:
					list.select(item_idx, false)
					current_priorities[item_idx] = target_priority
					break



## Parses the initial command data loading target UIDs and priorities
func set_data() -> void:
	var targets: PackedInt64Array = parameters[0].parameters.get("targets", [])
	var priorities: PackedInt32Array = parameters[0].parameters.get("priorities", [])
	
	set_targets_by_ids(targets, priorities)



## Compiles the UI state back extracting UIDs and priority mappings
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	
	var list = %TargetList
	var selected_indexes = list.get_selected_items()
	
	var final_targets: Array = []
	var final_priorities: Array = []
	
	for index in selected_indexes:
		var real_id = list.get_item_metadata(index)
		final_targets.append(real_id)

		if index < current_priorities.size():
			final_priorities.append(current_priorities[index])
		else:
			final_priorities.append(5) # Fallback
	
	commands[-1].parameters.targets = final_targets
	commands[-1].parameters.priorities = final_priorities
	commands[-1].parameters.legacy_targets = selected_indexes
	return commands
#endregion



#region UI Interaction & Priority Management
## Synchronizes the floating priority spinbox position with the scroll bar
func _reposition_priority_node(_value: float = 0.0) -> void:
	var node1 = %TargetList
	var node2 = %Priority
	if node2.visible:
		node2.apply()
	if priority_index != -1:
		var item_rect = node1.get_item_rect(priority_index)
		node2.position = (
			Vector2(item_rect.position) +
			Vector2(item_rect.size.x, item_rect.size.y * 0.5) -
			Vector2(node2.size.x, node2.size.y * 0.5) - 
			Vector2(16, 0) - 
			Vector2(0, node1.get_v_scroll_bar().value)
		)
		node2.visible = true
	else:
		node2.visible = false



## Refreshes the display value on the floating priority spinbox
func _update_priority_value() -> void:
	if priority_index != -1:
		%Priority.value = current_priorities[priority_index]
	else:
		%Priority.value = 0



## Captures hover state to move and update the priority spinbox context
func _on_target_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		priority_index = %TargetList.get_item_at_position(event.position)
		_reposition_priority_node()
		_update_priority_value()



## Saves the spinbox value changes to memory
func _on_priority_value_changed(value: float) -> void:
	if priority_index != -1:
		current_priorities[priority_index] = value



## Hides the priority spinbox when the cursor leaves the target list area
func _on_target_list_mouse_exited() -> void:
	%Priority.visible = false
#endregion
