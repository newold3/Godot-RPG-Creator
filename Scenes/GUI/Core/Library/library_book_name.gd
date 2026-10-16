class_name GuiCoreLibraryBookTooltip
extends MarginContainer

var focused_control: Control


#region Lifecycle
func _ready() -> void:
	modulate = Color.TRANSPARENT


func _process(_delta: float) -> void:
	repos()
#endregion



#region Positioning
func repos() -> void:
	if focused_control:
		var current_size = size
		var target_pos = focused_control.global_position
		var target_size = focused_control.size
		
		var offset_x = target_pos.x + (target_size.x * 0.5) - (current_size.x * 0.5)
		var offset_y = target_pos.y - current_size.y - 12.0
		
		global_position = Vector2(offset_x, offset_y)
#endregion



#region VirtualAnimationHooks
func _play_start_animation() -> void:
	modulate = Color.WHITE
	scale = Vector2.ONE


func _play_end_animation() -> void:
	queue_free()
#endregion



#region PublicMethods
func start(book_name: String) -> void:
	focused_control = get_viewport().gui_get_focus_owner()
	if has_node("%Title"):
		var t_node = get_node("%Title")
		if "label_text" in t_node:
			t_node.label_text = book_name
		elif "text" in t_node:
			t_node.text = book_name
	
	if focused_control:
		reset_size()
		pivot_offset = size * 0.5
		repos()
	
	_play_start_animation()


func end() -> void:
	_play_end_animation()
#endregion
