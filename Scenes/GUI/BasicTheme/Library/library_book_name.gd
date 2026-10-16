extends MarginContainer

var focused_control: Control


#region Lifecycle
## Initializes the tooltip making it transparent
func _ready() -> void:
	modulate = Color.TRANSPARENT


## Updates the tooltip position every frame
func _process(_delta: float) -> void:
	repos()
#endregion


#region Positioning
## Calculates and sets the correct position above the focused control
func repos() -> void:
	if focused_control:
		var current_size = size
		var target_pos = focused_control.global_position
		var target_size = focused_control.size
		
		var offset_x = target_pos.x + (target_size.x * 0.5) - (current_size.x * 0.5)
		var offset_y = target_pos.y - current_size.y - 12.0
		
		global_position = Vector2(offset_x, offset_y)
#endregion


#region Animation
## Starts the popup animation with a mechanical scale and fade effect
func start(book_name: String) -> void:
	focused_control = get_viewport().gui_get_focus_owner()
	%Title.label_text = book_name
	
	if focused_control:
		reset_size()
		pivot_offset = size * 0.5
		repos()
	
	modulate = Color.TRANSPARENT
	pivot_offset = size * 0.5
	scale = Vector2(0.8, 0.8)
	
	var t = create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate", Color.WHITE, 0.35)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35)


## Ends the animation shrinking and fading the tooltip before destroying it
func end() -> void:
	var t = create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate", Color.TRANSPARENT, 0.2)
	t.tween_property(self, "scale", Vector2(0.8, 0.8), 0.2)
	
	t.chain().tween_callback(queue_free)
#endregion
