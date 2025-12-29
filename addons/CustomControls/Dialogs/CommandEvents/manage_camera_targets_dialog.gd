@tool
extends CommandBaseDialog

var priority_index: int = -1
var current_priorities: PackedInt32Array = []


func _ready() -> void:
	super()
	parameter_code = 123
	%TargetList.get_v_scroll_bar().value_changed.connect(_reposition_priority_node)
	fill_targets()


func fill_targets() -> void:
	var list = %TargetList
	list.clear()
	
	list.add_item("Player")
	
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene is RPGMap:
		var events = edited_scene.events.get_events()
	
		for ev: RPGEvent in events:
			var text = "Event #%s: %s" % [ev.id, ev.name]
			list.add_item(text)


func set_targets(selected_indexes: PackedInt32Array) -> void:
	var list = %TargetList
	var total_items = list.get_item_count()
	
	if total_items > 0 and selected_indexes.size() == 0:
		list.select(0)
	else:
		for index: int in selected_indexes:
			if total_items > index:
				list.select(index, false)


func set_data() -> void:
	var targets: PackedInt32Array = parameters[0].parameters.get("targets", [])
	var priorities: PackedInt32Array = parameters[0].parameters.get("priorities", [])
	
	current_priorities.append(5)
	for i in range(1, %TargetList.get_item_count(), 1):
		current_priorities.append(5)
	
	for i in priorities.size():
		if current_priorities.size() > i:
			current_priorities[i] = priorities[i]
		
	set_targets(targets)


func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.targets = %TargetList.get_selected_items()
	commands[-1].parameters.priorities = current_priorities
	return commands


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


func _update_priority_value() -> void:
	if priority_index != -1:
		%Priority.value = current_priorities[priority_index]
	else:
		%Priority.value = 0


func _on_target_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		priority_index = %TargetList.get_item_at_position(event.position)
		_reposition_priority_node()
		_update_priority_value()


func _on_priority_value_changed(value: float) -> void:
	if priority_index != -1:
		current_priorities[priority_index] = value


func _on_target_list_mouse_exited() -> void:
	%Priority.visible = false
