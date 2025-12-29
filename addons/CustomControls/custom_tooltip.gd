@tool
class_name MainTooltipScene
extends Window

## Dynamic tooltip window that displays formatted titles and content with smooth animations.
## Automatically positions itself relative to the mouse cursor while staying within screen bounds.
## Features fade-in/fade-out animations and responsive sizing based on content.

## Controls whether the tooltip is currently active and visible
var is_alive: bool = false

## Main tween animation for controlling tooltip fade in/out effects
var main_tween: Tween

## Target size for tooltip animations (currently unused)
var target_size := Vector2.ZERO

## Flag indicating if the tooltip animation has started
var started: bool = false

## Controls if the tooltip is enabled and can respond to interactions
var is_enabled: bool = false

## Reference to the parent node that owns this tooltip
var parent_node: Node

var busy: bool = false


## Emitted when the tooltip becomes inactive
signal inactive_tooltip(tooltip: Window)


## Initialize the tooltip window with transparent background and minimal size
func _ready() -> void:
	transparent = true
	transparent_bg = true
	set_transparent_background(true)
	RenderingServer.viewport_set_clear_mode(get_viewport_rid(),RenderingServer.VIEWPORT_CLEAR_ALWAYS)
	size = Vector2i.ONE
	set_window_position()


func restart() -> void:
	busy = true
	%MainContainer.modulate.a = 0.0
	request_ready()
	set_deferred("busy", false)


## Formats a camelCase or PascalCase title into readable text with proper spacing
func get_tooltip_title_formatted(_title : String) -> String:
	if parent_node and parent_node is FileSelector:
		return _title
		
	var result := ""
	var regex := RegEx.new()
	regex.compile("([A-Z][^A-Z]*)")
	
	for word in regex.search_all(_title):
		if result:
			result += " " + word.get_string(0)
		else:
			result = word.get_string(0)
	
	result = result.strip_edges()
	result = result.replace("  ", " ")
	
	var result_array = result.split(" ")
	result = ""
	for i in result_array.size():
		var word1: String = result_array[i]
		var word2: String = "" if i == 0 else result_array[i-1]
		if word1.length() == 1 and word1.to_upper() == word1 and word2.length() == 1 and word2.to_upper() == word2:
			result += word1
		else:
			if result:
				result += " " + word1
			else:
				result += word1
	
	return result.strip_edges()


## Sets the tooltip content and initializes the display
func set_data(_title, _contents) -> void:
	%Title.text = ""
	%Title.size = Vector2.ZERO
	%Title.text = get_tooltip_title_formatted(_title)
	%Contents.text = ""
	%Contents.size = Vector2.ZERO
	%Contents.text = _contents.strip_edges()
	size = Vector2i.ONE
	if "gui_input" in get_parent() :
		if get_parent().gui_input.is_connected(_on_parent_gui_input):
			get_parent().gui_input.disconnect(_on_parent_gui_input)
		get_parent().gui_input.connect(_on_parent_gui_input)
	start()


## Checks if the window instance is valid and has a proper window ID
func _is_valid_window() -> bool:
	return is_instance_valid(self) and get_window_id() != -1


## Process function called every frame to update tooltip position
func _process(delta: float) -> void:
	if !started or not is_alive:
		return
		
	if _is_valid_window():
		call_deferred("set_window_position")


## Positions the tooltip window relative to the mouse cursor and screen boundaries
## Ensures the tooltip stays within screen bounds and doesn't overlap with the cursor
func set_window_position() -> void:
	var current_parent = get_parent()
	if not current_parent or not current_parent.has_method("get_local_mouse_position"):
		return
	var mouse_position = get_parent().get_local_mouse_position()
	var rect = Rect2(Vector2.ZERO, get_parent().size)
	var p: Vector2
	if !rect.has_point(mouse_position):
		end()
		set_process(false)
		return
	else:
		mouse_position = DisplayServer.mouse_get_position()
		p = mouse_position + Vector2i(-size.x * 0.5, 20)
	
	#var view = get_tree().get_root().get_viewport()
	var screen_size = DisplayServer.screen_get_size()

	if p.x < 10:
		p.x = 10
	elif p.x > screen_size.x - size.x - 10:
		p.x = screen_size.x - size.x - 10
	
	if p.y > screen_size.y - size.y - 10:
		p.y = p.y - size.y - 40
	
	if p.y < 10:
		p.y = 10
	
	rect = Rect2(p, size)
	if rect.has_point(mouse_position):
		p.x -= size.x * 0.5 + 10
	
	if p.x < 10:
		p.x = 10
		 
	position = p


## Initiates the tooltip display sequence with fade-in animation
## Sets up the tween animation to show the tooltip smoothly
func start() -> void:
	if !is_alive:
		is_alive = true
		is_enabled = true
		set_process(true)
		show_tooltip()


## Makes the tooltip visible and updates its size based on content
## Called as part of the start animation sequence
func show_tooltip() -> void:
	#await get_tree().process_frame
	propagate_call("set_visible", [true])
	update_size()
	position = Vector2i(-1000000,1000000)
	
	if main_tween:
		main_tween.kill()
	main_tween = create_tween()
	main_tween.tween_property(%MainContainer, "modulate:a", 1.0, 0.18)
	
	started = true


## Calculates and applies the appropriate size for the tooltip based on its content
## Handles both title and content sizing with proper margins and maximum width constraints
func update_size() -> void:
	var _title = %Title.text
	var _contents = %Contents.text
	
	var HORIZONTAL_MARGIN = 14
	var VERTICAL_MARGIN = 13
	var CONTENT_OFFSET_X = 7
	var MAX_WIDTH = 1200
	
	var message_size = Vector2i(%Contents.get_content_width(), %Contents.get_content_height())
	%Contents.get_parent().custom_minimum_size = message_size
	%Contents.position.x = CONTENT_OFFSET_X
	
	if message_size.x > %Title.size.x:
		%Title.size.x = message_size.x
	%Title.get_parent().custom_minimum_size = %Title.size
	
	size.x = min(MAX_WIDTH, max(%Title.size.x, message_size.x)) + HORIZONTAL_MARGIN
	size.y = %Title.size.y + message_size.y + VERTICAL_MARGIN


## Closes the tooltip with a fade-out animation and cleanup
## Handles the complete tooltip closure sequence including animations and signal emission
func end() -> void:
	if busy: return
	if is_alive:
		is_alive = false
		
		set_process(false)

		if main_tween:
			main_tween.kill()
		
		# Wait n frames
		is_enabled = false
		
		started = false
		
		#_remove_tooltip()
		
		# visual  bug in vulkan (black background)
		#
		#if not is_inside_tree():
			#_remove_tooltip()
			#return
		#
		#if main_tween:
			#main_tween.kill()
		#
		main_tween = create_tween()
		main_tween.tween_property(%MainContainer, "modulate:a", 0.0, 0.06)
		main_tween.tween_callback(_remove_tooltip)


## The tooltip requests to be removed from the scene.
func _remove_tooltip() -> void:
	if "gui_input" in get_parent() and get_parent().gui_input.is_connected(_on_parent_gui_input):
		get_parent().gui_input.disconnect(_on_parent_gui_input)
	%Title.text = ""
	%Contents.text = ""
	is_enabled = false
	inactive_tooltip.emit(self)
	#propagate_call("set_size", [Vector2.ONE])


## Handles input events from the parent node to close tooltip on non-mouse-motion events
func _on_parent_gui_input(event: InputEvent) -> void:
	if !event is InputEventMouseMotion:
		call_deferred("end")
