@tool
class_name BookAPI
extends RefCounted

## Static utility class for the PageFlip2D system by Newold.
## Provides helper methods to configure the book and facilitate interaction
## from embedded scenes (UI, puzzles, maps).
##
## [b]How to use:[/b][br]
## This class is designed to be used statically. You do not need to instance it.
## Simply call [code]BookAPI.function_name()[/code] from anywhere in your project.
## It automatically tracks the active [PageFlip2D] instance.
## (When a PageFlip scene enters the tree, it registers itself as the current_book.)

# ==============================================================================
# ENUMS (Mirrored for easy access)
# ==============================================================================

enum JumpTarget {
	## Jump to the closed state showing the Front Cover.
	FRONT_COVER,
	## Jump to the closed state showing the Back Cover.
	BACK_COVER,
	## Jump to a specific content page number.
	CONTENT_PAGE
}

# Internal reference to the currently active book.
static var _current_book: PageFlip2D

static var _register_books: Dictionary[String, PageFlip2D]

static var _last_book_spread: int = -1


# ==============================================================================
# SETUP & REFERENCES
# ==============================================================================

## Registers a book instance as the currently active one.
## Automatically called by [PageFlip2D] in its [method Node._ready] and [method Node._enter_tree].
## It must be called manually if you want to have more than one book active simultaneously.
static func set_current_book(book: PageFlip2D) -> void:
	_current_book = book


## Returns the currently active book instance, or null if none is registered.
static func get_current_book() -> PageFlip2D:
	return _current_book


## register a book to keep track of it and be able to retrieve it by ID
static func register_book(book_id: String, book: PageFlip2D):
	if book_id in _register_books:
		if _register_books[book_id] == book:
			return
		if is_instance_valid(_register_books[book_id]):
			_register_books[book_id].queue_free()
		_register_books[book_id] = book


## Retrieves a book using an ID. The function returns null if the book is not found.
static func get_book_by_id(book_id: String) -> PageFlip2D:
	if book_id in _register_books and is_instance_valid(_register_books[book_id]):
		return _register_books[book_id]
	
	return null


# ==============================================================================
# NAVIGATION CONTROLS
# ==============================================================================
static func set_book_speed(_book: PageFlip2D = null, _speed: float = 1.0) -> void:
	if not _book: _book = _current_book
	if is_instance_valid(_book):
		_book.set_speed_scale(_speed)


## Turns the page forward (to the next page/spread).
## Does nothing if the book is animating or at the end.
static func next_page(_book: PageFlip2D = null) -> void:
	if not _book: _book = _current_book
	if is_instance_valid(_book):
		force_release_control(_book)
		_book.next_page()


## Turns the page backward (to the previous page/spread).
## Does nothing if the book is animating or at the beginning.
static func prev_page(_book: PageFlip2D = null) -> void:
	if not _book: _book = _current_book
	if is_instance_valid(_book):
		force_release_control(_book)
		_book.prev_page()


## Disable a book (a disabled book cannot handle input).
static func disable_book(_book: PageFlip2D = null) -> void:
	if not _book: _book = _current_book
	if is_instance_valid(_book):
		_book.disabled = true


## Enable a book (an enabled book can handle input).
static func enable_book(_book: PageFlip2D = null) -> void:
	if not _book: _book = _current_book
	if is_instance_valid(_book):
		_book.disabled = false


## Forces the active book to close towards a specific cover.
## [param to_front_cover]: If true, closes to the Front Cover (Right to Left). If false, closes to Back Cover.
static func force_close_book(to_front_cover: bool, _book: PageFlip2D = null) -> void:
	if not _book: _book = _current_book
	if is_instance_valid(_current_book):
		force_release_control(_current_book)
		_current_book.book_closed.emit()
		_current_book.force_close_book(to_front_cover)


## Navigates to a specific page number (1-based index).
## Acts as a wrapper for go_to_spread, calculating the correct index automatically.
## [b]ASYNC:[/b] Must be called with 'await' if animated is true.
## [param page_num]: The 1-based page number (1 = first texture in pages_paths).
## [param target]: Specifies if the target is a content page or a cover.
static func go_to_page(page_num: int = 1, target: JumpTarget = JumpTarget.CONTENT_PAGE, animated: bool = true, _book: PageFlip2D = null, max_animated_turns: int = 5) -> void:
	var book = _current_book if not _book else _book
	if not is_instance_valid(book): return
	
	var target_spread_idx: int = 0
	
	match target:
		JumpTarget.FRONT_COVER:
			target_spread_idx = -1
		JumpTarget.BACK_COVER:
			target_spread_idx = book.total_spreads
		JumpTarget.CONTENT_PAGE:
			var safe_page = max(1, page_num)
			target_spread_idx = int(safe_page / 2.0)
			target_spread_idx = clampi(target_spread_idx, 0, book.total_spreads - 1)
			
	await go_to_spread(book, target_spread_idx, animated, null, max_animated_turns)


## Navigates to a specific spread index directly.
## [b]ASYNC:[/b] Must be called with 'await' if animated is true.
## - Animated: Fast-forwards through pages with dynamic speed.
## - Instant: Snaps to page and manually triggers the scene activation handshake.
static func go_to_spread(book: PageFlip2D, target_spread: int, animated: bool = true, ease_curve: Curve = null, max_turns: int = 5) -> void:
	if not is_instance_valid(book): return
	
	if not ease_curve: ease_curve = preload("uid://sc80vo3tu71s")
	
	var final_target = clampi(target_spread, -1, book.total_spreads)
	var diff = final_target - book.current_spread

	if diff == 0:
		return
		
	force_release_control(book)
	
	if not animated:
		var start_spread = book.current_spread
		if start_spread == -1 or start_spread == book.total_spreads:
			if final_target != -1 and final_target != book.total_spreads:
				book.book_opened.emit()
				
		book.previous_spread = book.current_spread
		book.current_spread = final_target
		book.call("_update_static_visuals_immediate")
		book.call("_update_volume_visuals")
		book.call("_check_scene_activation")
		
		if final_target == -1 or final_target == book.total_spreads:
			if start_spread != -1 and start_spread != book.total_spreads:
				book.book_closed.emit()
		
	else:
		if book.is_animating: return
		
		var original_speed = book.anim_player.speed_scale
		
		var total_steps = abs(diff)
		var going_forward = diff > 0

		var actual_turns = min(total_steps, max_turns)
		var start_spread = book.current_spread

		var min_speed = 1.0
		var max_speed = 4.5
		
		var random_intermediates = []
		if actual_turns > 2:
			var penultimate_target = final_target - 1 if going_forward else final_target + 1
			var pool_min = min(start_spread, penultimate_target) + 1
			var pool_max = max(start_spread, penultimate_target) - 1
			if pool_max >= pool_min:
				var needed = actual_turns - 2
				var pool_size = pool_max - pool_min + 1
				if needed >= pool_size:
					for v in range(pool_min, pool_max + 1):
						random_intermediates.append(v)
				else:
					while random_intermediates.size() < needed:
						var r = randi_range(pool_min, pool_max)
						if not r in random_intermediates:
							random_intermediates.append(r)
				random_intermediates.sort()
				if not going_forward:
					random_intermediates.reverse()

		for i in range(actual_turns):
			if not is_instance_valid(book): break
			
			var is_first_step = (i == 0)
			var is_last_step = (i == actual_turns - 1)
			
			var intermediate_target = final_target
			if not is_last_step:
				if i == actual_turns - 2:
					intermediate_target = final_target - 1 if going_forward else final_target + 1
				else:
					if i < random_intermediates.size():
						intermediate_target = random_intermediates[i]
					else:
						var penultimate_target = final_target - 1 if going_forward else final_target + 1
						var t_spreads = float(i + 1) / float(actual_turns - 1)
						intermediate_target = int(round(lerp(float(start_spread), float(penultimate_target), t_spreads)))
			
			var t_linear = float(i + 1) / float(actual_turns)
			var _current_speed = min_speed
			if actual_turns > 1:
				var arc = sin(t_linear * PI)
				_current_speed = lerp(min_speed, max_speed, arc)
				
			book.anim_player.speed_scale = _current_speed
			
			book.set("_jump_target_spread", intermediate_target)
			book.set("_ultimate_jump_target_spread", final_target)
			book.set("_is_jumping", true)
			book.call("_start_animation", going_forward)
			
			if book.is_animating:
				await book.ended_page_flip_animation
			else:
				await book.get_tree().process_frame
		
		if is_instance_valid(book):
			book.anim_player.speed_scale = original_speed

# ==============================================================================
# STATE & INTERACTION HELPERS
# ==============================================================================

## Returns true if the book (active or specific) is currently animating.
static func is_busy(book_instance: PageFlip2D = null) -> bool:
	var book = book_instance if book_instance else _current_book
	if not is_instance_valid(book): return false
	return book.is_animating


## Returns true if the given node/scene is currently instanced and visible within the book.
## Returns true if the given node/scene is currently instanced and visible in one of the static pages of the book.
static func is_scene_shown(node: Node, book_instance: PageFlip2D = null) -> bool:
	if not is_instance_valid(node):
		return false
	var book = book_instance if book_instance else _current_book
	if not is_instance_valid(book):
		return false
	
	var slots = []
	if is_instance_valid(book._slot_1): slots.append(book._slot_1)
	if is_instance_valid(book._slot_2): slots.append(book._slot_2)
	
	var current = node
	while current:
		if current in slots:
			return true
		current = current.get_parent()
	return false


## Locates the PageFlip2D controller ancestor from any node inside an interactive page.
static func find_book_controller(caller_node: Node) -> PageFlip2D:
	var current = caller_node
	while current:
		if current is PageFlip2D:
			return current
		current = current.get_parent()
	return null


## Safely locks or unlocks the book's ability to turn pages manually.
## WARNING: If locked, the interactive scene MUST be responsible for unlocking it later.
static func set_interaction_lock(book: PageFlip2D, locked: bool) -> void:
	if not is_instance_valid(book): return
	book.call("_pageflip_set_input_enabled", not locked)


## Forces the book to regain input control immediately.
## Useful as a failsafe if an interactive scene closes unexpectedly.
static func force_release_control(book: PageFlip2D) -> void:
	if not is_instance_valid(book): return
	_last_book_spread = book.current_spread
	book.call("_pageflip_set_input_enabled", true)


## Returns the current spread index being shown.
## Returns -999 if the book instance is invalid.
static func get_current_spread(book: PageFlip2D = null) -> int:
	if not book: book = _current_book
	if is_instance_valid(book):
		return book.current_spread
	return -999


## Returns the 1-based page number of the left page currently shown.
## Returns -999 if no page is shown on the left (e.g. book is closed or invalid).
## Returns negative values for covers:
## -101: Front Cover Interior
## -103: Back Cover Exterior
static func get_left_page_number(book: PageFlip2D = null) -> int:
	if not book: book = _current_book
	if is_instance_valid(book) and book.anim_manager:
		var idx = book.anim_manager.get_page_index_for_spread(book.current_spread, true)
		if idx >= 0:
			return idx + 1
		return idx
	return -999


## Returns the 1-based page number of the right page currently shown.
## Returns -999 if no page is shown on the right (e.g. book is closed or invalid).
## Returns negative values for covers:
## -100: Front Cover Exterior
## -102: Back Cover Interior
static func get_right_page_number(book: PageFlip2D = null) -> int:
	if not book: book = _current_book
	if is_instance_valid(book) and book.anim_manager:
		var idx = book.anim_manager.get_page_index_for_spread(book.current_spread, false)
		if idx >= 0:
			return idx + 1
		return idx
	return -999


static func get_focusable_controls(book: PageFlip2D = null, is_left_page: bool = false) -> Array[Control]:
	if not book: book = _current_book
	
	var controls: Array[Control] = []
	if not is_instance_valid(book):
		return controls
	
	var slot = book._slot_1 if is_left_page else book._slot_2
	if is_instance_valid(slot) and slot.get_child_count() > 0:
		var node = slot.get_child(-1)
		if is_instance_valid(node) and node.has_method("_get_focusable_controls"):
			controls.append_array(node._get_focusable_controls())

	return controls


# ==============================================================================
# CONFIGURATION HELPERS
# ==============================================================================

## Configures the visual properties of a Book instance via a dictionary.
static func configure_visuals(book: PageFlip2D, data: Dictionary) -> void:
	if not is_instance_valid(book): return

	if "pages" in data:
		book.pages_paths = data["pages"]
		book.call("_prepare_book_content")

	if "cover_front_out" in data: book.tex_cover_front_out = data["cover_front_out"]
	if "cover_front_in" in data: book.tex_cover_front_in = data["cover_front_in"]
	if "cover_back_in" in data: book.tex_cover_back_in = data["cover_back_in"]
	if "cover_back_out" in data: book.tex_cover_back_out = data["cover_back_out"]
	
	if "spine_col" in data: book.spine_color = data["spine_col"]
	if "spine_width" in data:
		book.spine_width = data["spine_width"]
		book.call("_build_spine")

	if "size" in data:
		book.target_page_size = data["size"]
		book.call("_apply_new_size")
	
	book.call("_update_static_visuals_immediate")
	book.call("_update_volume_visuals")


## Configures the physics simulation of the page turning effect.
static func configure_physics(book: PageFlip2D, data: Dictionary) -> void:
	if not is_instance_valid(book) or not book.dynamic_poly: return
	
	var rigger = book.dynamic_poly
	for key in data.keys():
		rigger.set(key, data[key])
	
	if rigger.has_method("rebuild"):
		rigger.rebuild(book.target_page_size)
