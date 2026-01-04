class_name KeyController
extends RefCounted

# InputHandler - A utility class to manage keyboard input with configurable key presses
# Supports single press actions or continuous key presses with customizable timing

# KEY class represents a single key binding with its associated action and behavior
class KEY:
	var unique_id: Variant # Unique ID to register this key (can be deleted using this ID)
	var key_bind: String # The input action name
	var callable_bind: Callable # The function to call when key is pressed
	var initial_delay: float = 0.25 # Time to wait before first repeat (seconds)
	var echo_interval: float = 0.1 # Time between repeated calls after initial delay (seconds)
	var current_delay: float = 0 # Counter for current delay time
	var allow_echo: bool = true # Whether to repeat the action while key is held
	var first_check_enabled: bool = true # Whether initial press has been processed
	var is_valid: bool = true # Whether this key binding is still active


	# Signals
	signal erase_requested(obj: KEY) # Emitted when key binding should be removed
	signal key_pressed(obj: KEY) # Emitted when key is pressed/repeated


	# Constructor for the KEY class
	func _init(p_key: String, p_callable: Callable, p_echo: bool = true, p_id: Variant = null) -> void:
		key_bind = p_key
		callable_bind = p_callable
		allow_echo = p_echo
		unique_id = p_id


	func reset(p_key: String, p_callable: Callable, p_echo: bool = true) -> void:
		if p_key == key_bind and p_callable == callable_bind:
			return
		key_bind = p_key
		callable_bind = p_callable
		allow_echo = p_echo
		current_delay = 0
		is_valid = true
		first_check_enabled = true


	# Process key state and execute action when needed
	func update(delta: float) -> void:
		if not is_valid:
			return
		
		# Check if key is released
		if not Input.is_action_pressed(key_bind):
			is_valid = false
			erase_requested.emit(self)
			return
		
		if current_delay > 0.0:
			# Waiting for repeat interval
			current_delay = clamp(current_delay - delta, 0, current_delay)
			if current_delay == 0 and callable_bind:
				# Time to repeat action
				key_pressed.emit(self)
				callable_bind.call()
				current_delay = echo_interval
		elif first_check_enabled and callable_bind:
			# Initial key press
			key_pressed.emit(self)
			callable_bind.call()
			if allow_echo:
				# Set up for repeating
				first_check_enabled = false
				current_delay = initial_delay
			else:
				# One-shot action
				is_valid = false
				erase_requested.emit(self)
		else:
			# Shouldn't reach here, but clean up if it does
			is_valid = false
			erase_requested.emit(self)


class ECHO_ACTION:
	var key_bind: String # The input action name
	var initial_delay: float = 0.25 # Time to wait before first repeat (seconds)
	var echo_interval: float = 0.1 # Time between repeated calls after initial delay (seconds)
	var current_delay: float = 0.25 # Counter for current delay time
	var pressed_enabled: bool = false # Indicates that the action is ready to be processed.
	var is_valid: bool = true # Whether this key binding is still active


	signal erase_requested(obj: ECHO_ACTION) # Emitted when key binding should be removed
	@warning_ignore("unused_signal")
	signal key_pressed(obj: ECHO_ACTION) # Emitted when key is pressed/repeated


	# Constructor for the ECHO_ACTION class
	func _init(p_key_bind: String) -> void:
		key_bind = p_key_bind


	# Process key state and execute action when needed
	func update(delta: float) -> void:
		if not is_valid:
			return
		
		# Check if key is released
		if not Input.is_action_pressed(key_bind):
			is_valid = false
			erase_requested.emit(self)
			return
		
		if current_delay > 0.0:
			# Waiting for repeat interval
			current_delay = clamp(current_delay - delta, 0, current_delay)
			
		if current_delay == 0:
			pressed_enabled = true
	
	
	# Reset the echo for this action
	func reset() -> void:
		current_delay = echo_interval
		pressed_enabled = false


# Main class variables
var actions: Array[KEY] = [] # List of active key bindings
var current_action_pressed: String = "" # Most recently pressed action name
var echo_actions: Array[ECHO_ACTION] = [] # List of active echo key bindings


# Update all registered key bindings
func update(delta: float) -> void:
	for action in actions:
		if action.is_valid:
			action.update(delta)
	for action in echo_actions:
		if action.is_valid:
			action.update(delta)


# Check if an action exists in the InputMap
func _validate_action(action_name: String) -> bool:
	if not InputMap.has_action(action_name):
		push_warning("KeyController: Action '%s' is not defined in the InputMap" % action_name)
		return false
	return true


# Register multiple keys with the same callback
func register_keys(keys: Array[String], callable: Callable, allow_echo: bool = true) -> void:
	for key in keys:
		register_key(key, callable, allow_echo)


# Register a single key with a callback
func register_key(key: String, callable: Callable, allow_echo: bool = true, id: Variant = null) -> void:
	# Validate that the action exists in the InputMap
	if not _validate_action(key):
		return
	
	var new_key
	
	if id != null:
		new_key = actions.filter(
			func(action: KEY):
				if action.unique_id == id:
					return action
		)
		if not new_key.is_empty():
			new_key = new_key[0]
			new_key.reset(key, callable, allow_echo)
			return
		
	new_key = KEY.new(key, callable, allow_echo, id)
	new_key.erase_requested.connect(_erase_key)
	new_key.key_pressed.connect(_on_key_pressed)
	actions.append(new_key)


# Remove all bindings for a specific key
func unregister_key(key: String) -> void:
	var to_erase_keys = []
	
	for action in actions:
		if action.key_bind == key:
			to_erase_keys.append(action)
	
	for erase_key in to_erase_keys:
		actions.erase(erase_key)


# Remove specific key using ID
func unregister_key_by_id(id: int) -> void:
	for action in actions:
		if action.unique_id == id:
			actions.erase(action)
			break


# Callback for KEY.erase_requested signal
func _erase_key(obj: KEY) -> void:
	actions.erase(obj)


# Callback for ECHO_ACTION.erase_requested signal
func _erase_echo_key(obj: ECHO_ACTION) -> void:
	echo_actions.erase(obj)


# Callback for KEY.key_pressed signal
func _on_key_pressed(obj: KEY) -> void:
	current_action_pressed = obj.key_bind


# Callback for ECHO_ACTION.key_pressed signal
func _on_echo_key_pressed(obj: ECHO_ACTION) -> void:
	current_action_pressed = obj.key_bind


# Clear all registered actions
func clear() -> void:
	actions.clear()
	echo_actions.clear()


# Checks if a key of a series of keys is being pressed
func is_any_key_pressed(keys: Array, allow_echo: bool = false) -> bool:
	for key in keys:
		# Validate that the action exists in the InputMap
		if not _validate_action(key):
			continue
			
		var key_is_pressed = is_key_pressed(key, allow_echo)

		if key_is_pressed:
			return true
		
	return false


# Checks if a key is being pressed
func is_key_pressed(key: String, allow_echo: bool = false) -> bool:
	# Validate that the action exists in the InputMap
	if not _validate_action(key):
		return false
		
	if allow_echo:
		var key_registered = echo_actions.filter(
			func(action: ECHO_ACTION):
				if action.key_bind == key:
					return action
		)
		if not key_registered.is_empty():
			if key_registered[0].pressed_enabled:
				key_registered[0].key_pressed.emit(key_registered[0])
				key_registered[0].reset()
				return true
		else:
			if Input.is_action_pressed(key, true):
				key_registered = ECHO_ACTION.new(key)
				key_registered.key_pressed.connect(_on_echo_key_pressed)
				key_registered.erase_requested.connect(_erase_echo_key)
				echo_actions.append(key_registered)
				key_registered.key_pressed.emit(key_registered)
				return true
				
	else:
		return Input.is_action_just_pressed(key)
	
	return false


func add_focusable_candidates(node: Node, from_pos: Vector2, direction: String, current: Control, candidates: Array) -> void:
	if node is Control and node != current:
		var ctrl := node as Control
		if ctrl.focus_mode != Control.FOCUS_NONE and ctrl.visible and ctrl.is_inside_tree():
			var ctrl_rect = ctrl.get_global_rect()
			var ctrl_center = ctrl_rect.position + ctrl_rect.size / 2
			var delta = ctrl_center - from_pos
			match direction:
				"left":
					if delta.x < 0 and abs(delta.y) < ctrl_rect.size.y:
						candidates.append({"node": ctrl, "distance": delta.length()})
				"right":
					if delta.x > 0 and abs(delta.y) < ctrl_rect.size.y:
						candidates.append({"node": ctrl, "distance": delta.length()})
				"up":
					if delta.y < 0 and abs(delta.x) < ctrl_rect.size.x:
						candidates.append({"node": ctrl, "distance": delta.length()})
				"down":
					if delta.y > 0 and abs(delta.x) < ctrl_rect.size.x:
						candidates.append({"node": ctrl, "distance": delta.length()})
	for child in node.get_children():
		add_focusable_candidates(child, from_pos, direction, current, candidates)

func get_all_focusable_in_line(node: Node, current: Control, direction: String, candidates: Array) -> void:
	if node is Control and node != current:
		var ctrl := node as Control
		if ctrl.focus_mode != Control.FOCUS_NONE and ctrl.visible and ctrl.is_inside_tree():
			var ctrl_rect = ctrl.get_global_rect()
			var current_rect = current.get_global_rect()
			
			match direction:
				"up", "down":
					# For vertical movement, check if they are on the same horizontal "line"
					if abs(ctrl_rect.position.x - current_rect.position.x) < max(ctrl_rect.size.x, current_rect.size.x):
						candidates.append(ctrl)
				"left", "right":
					# For horizontal movement, check if they are on the same vertical "line"
					if abs(ctrl_rect.position.y - current_rect.position.y) < max(ctrl_rect.size.y, current_rect.size.y):
						candidates.append(ctrl)
	
	for child in node.get_children():
		get_all_focusable_in_line(child, current, direction, candidates)

func get_closest_focusable_control(current: Control, direction: String, limit_to_parent: bool = false) -> Control:
	if not current:
		return null
	
	var from_pos = current.get_global_rect().position + current.get_global_rect().size / 2
	var candidates = []
	var search_root = current.get_tree().root
	
	# If limit_to_parent is true, limit search to current control's parent
	if limit_to_parent and current.get_parent():
		search_root = current.get_parent()
	
	# First attempt: normal search in specified direction
	add_focusable_candidates(search_root, from_pos, direction, current, candidates)
	
	# If no candidates found, wrap-around
	if candidates.size() == 0:
		var all_candidates = []
		get_all_focusable_in_line(search_root, current, direction, all_candidates)
		
		if all_candidates.size() > 0:
			match direction:
				"up":
					# If going up and nothing found, select the lowest control on the same line
					var lowest = all_candidates[0]
					for ctrl in all_candidates:
						if ctrl.get_global_rect().position.y > lowest.get_global_rect().position.y:
							lowest = ctrl
					return lowest
				"down":
					# If going down and nothing found, select the highest control on the same line
					var highest = all_candidates[0]
					for ctrl in all_candidates:
						if ctrl.get_global_rect().position.y < highest.get_global_rect().position.y:
							highest = ctrl
					return highest
				"left":
					# If going left and nothing found, select the rightmost control on the same line
					var rightmost = all_candidates[0]
					for ctrl in all_candidates:
						if ctrl.get_global_rect().position.x > rightmost.get_global_rect().position.x:
							rightmost = ctrl
					return rightmost
				"right":
					# If going right and nothing found, select the leftmost control on the same line
					var leftmost = all_candidates[0]
					for ctrl in all_candidates:
						if ctrl.get_global_rect().position.x < leftmost.get_global_rect().position.x:
							leftmost = ctrl
					return leftmost
	
	if candidates.size() == 0:
		return null
	
	candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])
	return candidates[0]["node"]
