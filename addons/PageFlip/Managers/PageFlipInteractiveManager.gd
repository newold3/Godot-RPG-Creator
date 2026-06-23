class_name PageFlipInteractiveManager extends RefCounted

## Reference to the main book node.
var book: Node2D



## Initializes the interactive manager.
func _init(book_node: Node2D) -> void:
	book = book_node



#region Interaction Handshake
## Enables or disables interactive processing in the underlying scenes based on animation state.
func set_input_enabled(enabled: bool) -> void:
	book._active_interactive_is_left = false
	book._active_interactive_is_right = false
	
	if not enabled:
		return
		
	var allowed_idx_l = -999
	var allowed_idx_r = -999
	
	if book.get("anim_manager") and book.anim_manager.has_method("get_page_index_for_spread"):
		allowed_idx_l = book.anim_manager.get_page_index_for_spread(book.current_spread, true)
		allowed_idx_r = book.anim_manager.get_page_index_for_spread(book.current_spread, false)
		
	if allowed_idx_l >= 0 and allowed_idx_l < book._runtime_pages.size():
		book._active_interactive_is_left = true
		
	if allowed_idx_r >= 0 and allowed_idx_r < book._runtime_pages.size():
		book._active_interactive_is_right = true


## Checks and activates interaction states specifically for the currently displayed spread.
func check_scene_activation() -> void:
	set_input_enabled(true)
#endregion
