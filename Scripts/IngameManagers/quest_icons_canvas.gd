extends Node2D


#region VARIABLES
@export var update_every_x_frames: int = 1

@export var base_offset_for_node_up: Vector2 = Vector2(0, -24)
@export var base_offset_for_no_node_up: Vector2 = Vector2(0, -64)

var active_icons: Dictionary = {}
#endregion


func _process(_delta: float) -> void:
	if update_every_x_frames > 1 and Engine.get_frames_drawn() % update_every_x_frames != 0:
		return
		
	var cam_zoom: Vector2 = Vector2.ONE
	
	if GameManager.has_method("get_camera_zoom"):
		cam_zoom = GameManager.get_camera_zoom()
	elif GameManager.has_method("get_camera") and GameManager.get_camera():
		cam_zoom = GameManager.get_camera().zoom
		
	for event in active_icons.keys():
		var wrapper = active_icons[event]
		
		if is_instance_valid(event) and is_instance_valid(event.lpc_event) and is_instance_valid(wrapper):
			var up_node = event.lpc_event.get_node_or_null("%Up")
			var target_node = up_node if up_node else event.lpc_event
			var base_offset = base_offset_for_node_up if up_node \
				else base_offset_for_no_node_up
			
			var npc_scale = event.lpc_event.global_scale.abs()
			
			wrapper.scale = cam_zoom * npc_scale
			
			var desired_world_pos = target_node.global_position + (base_offset * npc_scale)
			wrapper.position = target_node.get_viewport().get_canvas_transform() * desired_world_pos
		else:
			if is_instance_valid(wrapper):
				wrapper.queue_free()
			active_icons.erase(event)


## Creates a wrapper node to hold the icon, allowing the AnimationPlayer to work without overriding the camera zoom scale.
func add_quest_icon(icon: Node2D, target_event: IngameEvent) -> void:
	remove_quest_icon(target_event)
	
	if not is_instance_valid(icon) or not is_instance_valid(target_event):
		return
		
	var wrapper = Node2D.new()
	wrapper.name = "IconWrapper_" + str(target_event.uniq_id)
	
	wrapper.add_child(icon)
	add_child(wrapper)
	
	active_icons[target_event] = wrapper


## Removes and frees the quest icon wrapper associated with the target event.
func remove_quest_icon(target_event: IngameEvent) -> void:
	if active_icons.has(target_event):
		var old_wrapper = active_icons[target_event]
		if is_instance_valid(old_wrapper):
			old_wrapper.queue_free()
		active_icons.erase(target_event)


## Safely removes all active quest icons wrappers from the canvas.
func clear_quest_icons() -> void:
	for event in active_icons.keys():
		if is_instance_valid(active_icons[event]):
			active_icons[event].queue_free()
	active_icons.clear()
