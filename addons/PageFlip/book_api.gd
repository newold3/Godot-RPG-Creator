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

## Turns the page forward (to the next page/spread).
## Does nothing if the book is animating or at the end.
static func next_page() -> void:
	if is_instance_valid(_current_book):
		force_release_control(_current_book)
		_current_book.next_page()


## Turns the page backward (to the previous page/spread).
## Does nothing if the book is animating or at the beginning.
static func prev_page() -> void:
	if is_instance_valid(_current_book):
		force_release_control(_current_book)
		_current_book.prev_page()


## Forces the active book to close towards a specific cover.
## [param to_front_cover]: If true, closes to the Front Cover (Right to Left). If false, closes to Back Cover.
static func force_close_book(to_front_cover: bool) -> void:
	if is_instance_valid(_current_book):
		force_release_control(_current_book)
		_current_book.force_close_book(to_front_cover)


## Navigates to a specific page number (1-based index).
## Acts as a wrapper for go_to_spread, calculating the correct index automatically.
## [b]ASYNC:[/b] Must be called with 'await' if animated is true.
## [param page_num]: The 1-based page number (1 = first texture in pages_paths).
## [param target]: Specifies if the target is a content page or a cover.
static func go_to_page(page_num: int = 1, target: JumpTarget = JumpTarget.CONTENT_PAGE, animated: bool = true) -> void:
	var book = _current_book
	if not is_instance_valid(book): return
	
	var target_spread_idx: int = 0
	
	match target:
		JumpTarget.FRONT_COVER:
			target_spread_idx = -1
		JumpTarget.BACK_COVER:
			target_spread_idx = book.total_spreads
		JumpTarget.CONTENT_PAGE:
			# Calculate spread index: 1-2 -> Spread 0, 3-4 -> Spread 1, etc.
			var safe_page = max(1, page_num)
			target_spread_idx = int(safe_page / 2.0)
			target_spread_idx = clampi(target_spread_idx, 0, book.total_spreads - 1)
			
	await go_to_spread(book, target_spread_idx, animated)


## Navigates to a specific spread index directly.
## [b]ASYNC:[/b] Must be called with 'await' if animated is true.
## - Animated: Fast-forwards through pages with dynamic speed.
## - Instant: Snaps to page and manually triggers the scene activation handshake.
static func go_to_spread(book: PageFlip2D, target_spread: int, animated: bool = true) -> void:
	if not is_instance_valid(book): return
	
	# Clamp target
	var final_target = clampi(target_spread, -1, book.total_spreads)
	var diff = final_target - book.current_spread

	if diff == 0:
		return
		
	force_release_control(book)
	
	if not animated:
		# INSTANT TELEPORT
		book.current_spread = final_target
		book.call("_update_static_visuals_immediate")
		book.call("_update_volume_visuals")
		# Force check for interactive scenes after teleport
		book.call("_check_scene_activation")
		
	else:
		# ANIMATED FAST-FORWARD
		if book.is_animating: return # Don't interrupt an existing animation
		
		var original_speed = book.anim_player.speed_scale
		
		# --- DYNAMIC SPEED CALCULATION ---
		var steps = abs(diff)
		# Base speed: 1.5x -> Max speed: 10.0x
		var dynamic_speed = remap(float(steps), 0.0, float(book.total_spreads), 1.5, 10.0)
		book.anim_player.speed_scale = dynamic_speed
		
		var going_forward = diff > 0
		
		for i in range(steps):
			if not is_instance_valid(book): break
			
			if going_forward: book.next_page()
			else: book.prev_page()
			
			# Wait for the physical page turn to finish before starting the next one.
			if book.anim_player.is_playing():
				await book.anim_player.animation_finished
			else:
				await book.get_tree().process_frame
		
		# RESTORE STATE
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
	book.call("_pageflip_set_input_enabled", true)


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
