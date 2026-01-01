extends Node

class KeyBase:
	var base_node: Node
	var unique_id: String # Unique ID to register this key
	var initial_delay: float = 0.25 # Time to wait before first repeat (seconds)
	var echo_interval: float = 1.15 # Time between repeated calls after initial delay (seconds)
	var current_delay: float = 0 # Counter for current delay time
	var initialize: bool = true # Flag to indicate that the key has just been added
	var registered_frame: int = -1
	
	# Update the delay timer based on elapsed time
	func update(delta: float) -> void:
		if current_delay > 0:
			current_delay -= delta
	
	# Reset the delay timer when direction is processed
	func refresh() -> void:
		if registered_frame == -1:
			registered_frame = Engine.get_physics_frames()
		base_node.get_viewport().set_input_as_handled()
		if initialize:
			initialize = false
			set_deferred("current_delay", initial_delay)
		else:
			set_deferred("current_delay", echo_interval)
	
	func is_active() -> bool:
		return initialize or (current_delay <= 0.0 and not initialize)


## RegisterKey class to handle key input with repeat functionality
class RegisterKey extends KeyBase:
	var keycode: int # The input action name
	
	# Initialize the RegisterKey with a unique ID and keycode
	func _init(p_base_node: Node, p_unique_id: String, p_keycode: int, p_initial_delay: float, p_echo_interval: float) -> void:
		base_node = p_base_node
		unique_id = p_unique_id
		keycode = p_keycode
		initial_delay = p_initial_delay
		echo_interval = p_echo_interval
		initialize = true


## Class to handle analog triggers with repeat functionality
class TriggerState extends KeyBase:
	var axis: int # The trigger axis (JOY_AXIS_TRIGGER_LEFT or JOY_AXIS_TRIGGER_RIGHT)
	var threshold: float = 0.1 # Threshold to consider the trigger pressed
	var current_value: float = 0.0 # Current axis value
	
	func _init(p_base_node: Node, p_axis: int, p_initial_delay: float, p_echo_interval: float) -> void:
		base_node = p_base_node
		axis = p_axis
		initial_delay = p_initial_delay
		echo_interval = p_echo_interval
		unique_id = "trigger_" + str(p_axis)
		registered_frame = Engine.get_physics_frames()
		initialize = true
	
	# Update the current value and check if it's pressed
	func update_value(value: float) -> void:
		current_value = value
		# If the trigger is not pressed anymore, reset the state
		if current_value <= threshold:
			initialize = true
			current_delay = 0
	
	# Check if the trigger is currently pressed above threshold
	func is_pressed() -> bool:
		return current_value > threshold


## Class to handle analog stick directions with repeat functionality
class StickDirection extends KeyBase:
	var direction: String = "" # Current active direction
	var stick_name: String = "" # Name identifier for the stick (left/right)
	
	func _init(p_base_node: Node, p_stick_name: String = "left") -> void:
		base_node = p_base_node
		stick_name = p_stick_name
		unique_id = "stick_" + p_stick_name
		
	# Set a new direction and reset the initialization
	func set_direction(new_direction: String) -> void:
		if direction != new_direction:
			direction = new_direction
			initialize = true
	
	# Clear state
	func clear() -> void:
		direction = ""
		current_delay = 0


var key_states = { # Dictionary to store all current input states
	"keys": {},
	"mouse_buttons": {},
	"joy_buttons": {}
}
var joy_axis_values = {} # Joystick axis values
var action_states = {} # Dictionary to store action states
var stick_left_direction = null # Left analog stick direction handler
var stick_right_direction = null # Right analog stick direction handler
var trigger_left_state = null # Left trigger state handler
var trigger_right_state = null # Right trigger state handler
var initial_key_delay: float = 0.15 # Global initial delay
var echo_key_delay: float = 0.1 # Global echo delay
var last_action_registered: RegisterKey = null # Last action registered
var close_neighbor_script
var current_controller: CONTROLLER_TYPE
var controller_info: Dictionary = {}

var last_checked_frame: int = -1

# Cache system for frame-consistent results
var cache = {}

## Input configuration for special actions
const CONFIRM_INPUTS = {
	"keys": [KEY_ENTER, KEY_SPACE, KEY_Z], # Keyboard keys for confirm
	"mouse": [MOUSE_BUTTON_LEFT], # Mouse buttons for confirm
	"joy": [JOY_BUTTON_A, JOY_BUTTON_X] # Gamepad buttons for confirm
}
const CANCEL_INPUTS = {
	"keys": [KEY_ESCAPE, KEY_BACKSPACE, KEY_X,
			KEY_KP_0], # Keyboard keys for cancel
	"mouse": [MOUSE_BUTTON_RIGHT], # Mouse buttons for cancel
	"joy": [JOY_BUTTON_B, JOY_BUTTON_Y] # Gamepad buttons for cancel
}
const ERASE_LETTER_INPUTS = {
	"keys": [KEY_BACKSPACE], # Keyboard keys for erase action
	"mouse": [MOUSE_BUTTON_RIGHT], # Mouse buttons for erase action
	"joy": [JOY_BUTTON_B] # Gamepad buttons for erase action
}
enum CONTROLLER_TYPE {Keyboard, Mouse, Joypad}


signal controller_changed(controller_type: CONTROLLER_TYPE)


## Initialize the input controller
func _ready() -> void:
	clear()
	set_input_delays(initial_key_delay, echo_key_delay)
	close_neighbor_script = preload("res://Scripts/close_neighbor.gd").new()


## initiale key states
func clear() -> void:
	key_states.keys.clear() # Keyboard keys
	key_states.mouse_buttons.clear() # Mouse buttons
	key_states.joy_buttons.clear() # Joystick/gamepad buttons
	action_states.clear()
	joy_axis_values[JOY_AXIS_LEFT_X] = 0.0 # Left stick horizontal
	joy_axis_values[JOY_AXIS_LEFT_Y] = 0.0 # Left stick vertical
	joy_axis_values[JOY_AXIS_RIGHT_X] = 0.0 # Right stick horizontal
	joy_axis_values[JOY_AXIS_RIGHT_Y] = 0.0 # Right stick vertical
	joy_axis_values[JOY_AXIS_TRIGGER_LEFT] = 0.0 # Left trigger
	joy_axis_values[JOY_AXIS_TRIGGER_RIGHT] = 0.0 # Right trigger
	
	if stick_left_direction:
		stick_left_direction.clear()
	else:
		stick_left_direction = StickDirection.new(self, "left") # Assign a new StickDirection for left stick
	
	if stick_right_direction:
		stick_right_direction.clear()
	else:
		stick_right_direction = StickDirection.new(self, "right") # Assign a new StickDirection for right stick
	
	# Initialize trigger states
	trigger_left_state = TriggerState.new(self, JOY_AXIS_TRIGGER_LEFT, initial_key_delay, echo_key_delay)
	trigger_right_state = TriggerState.new(self, JOY_AXIS_TRIGGER_RIGHT, initial_key_delay, echo_key_delay)


## Get the current process frame ID
func _get_current_frame() -> int:
	return Engine.get_physics_frames()


## threshold used to detect neighboring controls at the given address
func set_focusable_control_threshold(horizontal: int = 10, vertical: int = 50) -> void:
	close_neighbor_script.horizontal_threshold = horizontal
	close_neighbor_script.vertical_threshold = vertical


## Check if a keyboard key is pressed with repeat handling
func is_key_pressed(keycode: int) -> bool:
	if is_key_just_pressed(keycode): return true
	
	var result = false
	if keycode in key_states.keys and key_states.keys[keycode].current_delay <= 0:
		key_states.keys[keycode].refresh()
		get_viewport().set_input_as_handled()
		result = true
	
	return result


# Check if a joystick/gamepad button is pressed with repeat handling
func is_joy_button_pressed(keycode: int) -> bool:
	if is_joy_button_just_pressed(keycode): return true
	
	var result = false
	if keycode in key_states.joy_buttons and key_states.joy_buttons[keycode].current_delay <= 0:
		key_states.joy_buttons[keycode].refresh()
		get_viewport().set_input_as_handled()
		result = true
	
	return result


# Check if action is pressed with repeat handling
func is_action_pressed(action: String) -> bool:
	if is_action_just_pressed(action): return true
	
	var cache_key = "action_" + action
	if cache.has(cache_key):
		return cache[cache_key]
	
	var result = false
	
	if Input.is_action_pressed(action):
		if not action_states.has(action):
			_register_action(action)
		
		if action_states[action].is_active():
			action_states[action].refresh()
			get_viewport().set_input_as_handled()
			result = true
	
	cache[cache_key] = result
	return result


# Check if L2 trigger is pressed with repeat handling
func is_trigger_left_pressed() -> bool:
	if cache.has("trigger_left"):
		return cache.trigger_left
	
	var result = false
	if trigger_left_state.is_pressed() and trigger_left_state.is_active():
		trigger_left_state.refresh()
		get_viewport().set_input_as_handled()
		result = true
	
	cache.trigger_left = result
	return result


# Check if R2 trigger is pressed with repeat handling
func is_trigger_right_pressed() -> bool:
	if cache.has("trigger_right"):
		return cache.trigger_right
	
	var result = false
	if trigger_right_state.is_pressed() and trigger_right_state.is_active():
		trigger_right_state.refresh()
		get_viewport().set_input_as_handled()
		result = true
	
	cache.trigger_right = result
	return result


# Legacy function for backward compatibility - now uses the new trigger system
func is_joy_axis_trigger_pressed(joy_axis_trigger: int) -> bool:
	if joy_axis_trigger == JOY_AXIS_TRIGGER_LEFT:
		return is_trigger_left_pressed()
	elif joy_axis_trigger == JOY_AXIS_TRIGGER_RIGHT:
		return is_trigger_right_pressed()
	
	# Fallback for other axes
	var trigger = Input.get_joy_axis(0, joy_axis_trigger)
	return trigger > 0.1


# Get the raw analog value of a trigger (returns value between 0.0 and 1.0)
func get_trigger_value(trigger_axis: int) -> float:
	return joy_axis_values.get(trigger_axis, 0.0)


# Check if a mouse button is pressed with repeat handling
func is_mouse_button_pressed(keycode: int) -> bool:
	if is_mouse_button_just_pressed(keycode): return true
	
	if not Input.is_mouse_button_pressed(keycode):
		if keycode in key_states.mouse_buttons:
			key_states.mouse_buttons.erase(keycode)
		return false
		
	var result = false
	if keycode in key_states.mouse_buttons and key_states.mouse_buttons[keycode].current_delay <= 0:
		key_states.mouse_buttons[keycode].refresh()
		get_viewport().set_input_as_handled()
		result = true
	return result


# Check if a confirm action is pressed (Enter, Space, A button, left click, etc.)
func is_confirm_pressed(ignore_mouse_left: bool = false, extra_keys: PackedInt32Array = [], mouse_left_require_focusable: bool = true) -> bool:
	var cache_key = "confirm_" + str(ignore_mouse_left) + "_" + str(extra_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	if Input.is_key_pressed(KEY_ALT):
		cache[cache_key] = false
		return false
	
	var result = false
	
	# Check keyboard confirm keys
	for key_code in CONFIRM_INPUTS.keys:
		if is_key_pressed(key_code):
			result = true
			break
	
	# Check mouse confirm buttons if no keyboard key was pressed
	if not result:
		for button in CONFIRM_INPUTS.mouse:
			if button == MOUSE_BUTTON_LEFT and ignore_mouse_left:
				continue
			if is_mouse_button_pressed(button):
				if mouse_left_require_focusable and not GameManager.is_mouse_over_current_control_focused():
					break
				result = true
				break
	
	# Check gamepad confirm buttons if no keyboard/mouse button was pressed
	if not result:
		for button in CONFIRM_INPUTS.joy:
			if is_joy_button_pressed(button):
				result = true
				break
	
	# Check extra keys if any
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if is_key_pressed(key):
				result = true
				break
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache[cache_key] = result
	return result


func is_force_confirm_pressed() -> bool:
	if cache.has("force_confirm"):
		return cache.force_confirm
	
	var result = false
	if Input.is_action_just_pressed("ForceConfirm"):
		get_viewport().set_input_as_handled()
		result = true
	
	cache.force_confirm = result
	return result


# Remove erase letter action (Enter, Space, A button, left click, etc.)
func remove_confirm() -> void:
	# Check keyboard confirm keys
	for key_code in CONFIRM_INPUTS.keys:
		key_states.keys.erase(key_code)
	
	# Check mouse confirm buttons
	for button in CONFIRM_INPUTS.mouse:
		key_states.mouse_buttons.erase(button)
			
	# Check gamepad confirm buttons
	for button in CONFIRM_INPUTS.joy:
		key_states.joy_buttons.erase(button)


# Check if a cancel action is pressed (Escape, Backspace, B button, right click, etc.)
func is_cancel_pressed(extra_keys: PackedInt32Array = []) -> bool:
	var cache_key = "cancel_" + str(extra_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	var result = false
	
	# Check keyboard cancel keys
	for key_code in CANCEL_INPUTS.keys:
		if is_key_pressed(key_code):
			result = true
			break
	
	# Check mouse cancel buttons if no keyboard key was pressed
	if not result:
		for button in CANCEL_INPUTS.mouse:
			if is_mouse_button_pressed(button):
				result = true
				break
	
	# Check gamepad cancel buttons if no keyboard/mouse button was pressed
	if not result:
		for button in CANCEL_INPUTS.joy:
			if is_joy_button_pressed(button):
				result = true
				break
	
	# Check extra keys if any
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if is_key_pressed(key):
				result = true
				break
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache[cache_key] = result
	return result


# Remove erase letter action (BACKSPACE, B Button, Right Mouse Button)
func remove_cancel() -> void:
	# Check keyboard confirm keys
	for key_code in CANCEL_INPUTS.keys:
		key_states.keys.erase(key_code)
	
	# Check mouse confirm buttons
	for button in CANCEL_INPUTS.mouse:
		key_states.mouse_buttons.erase(button)
			
	# Check gamepad confirm buttons
	for button in CANCEL_INPUTS.joy:
		key_states.joy_buttons.erase(button)


# Check if a erase letter action is pressed (BACKSPACE, B Button, Right Mouse Button)
func is_erase_letter_pressed() -> bool:
	if cache.has("erase_letter"):
		return cache.erase_letter
	
	var result = false
	
	# Check keyboard erase letter keys
	for key_code in ERASE_LETTER_INPUTS.keys:
		if is_key_pressed(key_code):
			result = true
			break
	
	# Check mouse erase letter buttons if no keyboard key was pressed
	if not result:
		for button in ERASE_LETTER_INPUTS.mouse:
			if is_mouse_button_pressed(button):
				result = true
				break
	
	# Check gamepad erase letter buttons if no keyboard/mouse button was pressed
	if not result:
		for button in ERASE_LETTER_INPUTS.joy:
			if is_joy_button_pressed(button):
				result = true
				break
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache.erase_letter = result
	return result


# Remove erase letter action (BACKSPACE, B Button, Right Mouse Button)
func remove_erase_letter() -> void:
	# Check keyboard confirm keys
	for key_code in ERASE_LETTER_INPUTS.keys:
		key_states.keys.erase(key_code)
	
	# Check mouse confirm buttons
	for button in ERASE_LETTER_INPUTS.mouse:
		key_states.mouse_buttons.erase(button)
			
	# Check gamepad confirm buttons
	for button in ERASE_LETTER_INPUTS.joy:
		key_states.joy_buttons.erase(button)


func get_closest_focusable_control(current: Control, direction: String, limit_to_parent: bool = false, extra_focusable_controls: Array = []) -> Control:
	return close_neighbor_script.get_closest_focusable_control(current, direction, limit_to_parent, extra_focusable_controls)


## Process input states every frame
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	# Clear all cache at the beginning of each frame
	cache.clear()
	
	# Update all registered inputs
	for key: RegisterKey in key_states.keys.values():
		if key.registered_frame == -1:
			key.registered_frame = Engine.get_physics_frames()
		key.update(delta)
	for key: RegisterKey in key_states.mouse_buttons.values():
		if key.registered_frame == -1:
			key.registered_frame = Engine.get_physics_frames()
		key.update(delta)
	for key: RegisterKey in key_states.joy_buttons.values():
		if key.registered_frame == -1:
			key.registered_frame = Engine.get_physics_frames()
		key.update(delta)
	for action: RegisterKey in action_states.values():
		if action.registered_frame == -1:
			action.registered_frame = Engine.get_physics_frames()
		action.update(delta)
	
	# Update analog stick directions
	stick_left_direction.update(delta)
	stick_right_direction.update(delta)
	
	# Update trigger states
	trigger_left_state.update(delta)
	trigger_right_state.update(delta)
	
	# Update trigger values from current input state
	trigger_left_state.update_value(Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT))
	trigger_right_state.update_value(Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT))
	
	# Process analog stick directions
	_process_stick_direction("left")
	_process_stick_direction("right")


## Generate a unique ID with specified number of digits
func _generate_id(digits: int = 16) -> String:
	var id = ""
	
	for i in range(digits):
		var digit = randi_range(0, 9)
		id += str(digit)
	
	return id

## Register a new key
func _register_key(entry_id: String, keycode: int) -> void:
	var new_key = RegisterKey.new(self, _generate_id(), keycode, initial_key_delay, echo_key_delay)
	new_key.registered_frame = -1
	key_states[entry_id][keycode] = new_key
	last_action_registered = new_key


func _register_action(action_name: String) -> void:
	var new_action = RegisterKey.new(self, _generate_id(), 0, initial_key_delay, echo_key_delay)
	new_action.registered_frame = -1
	action_states[action_name] = new_action
	last_action_registered = new_action


func remove_last_action_registered() -> void:
	if last_action_registered:
		# Check keyboard keys
		for key in key_states.keys:
			if key_states.keys[key].unique_id == last_action_registered.unique_id:
				key_states.keys.erase(key)
				return
		
		# Check mouse buttons
		for key in key_states.mouse_buttons:
			if key_states.mouse_buttons[key].unique_id == last_action_registered.unique_id:
				key_states.mouse_buttons.erase(key)
				return
				
		# Check gamepad buttons
		for key in key_states.joy_buttons:
			if key_states.joy_buttons[key].unique_id == last_action_registered.unique_id:
				key_states.joy_buttons.erase(key)
				return
		
		# Check actions
		for action in action_states:
			if action_states[action].unique_id == last_action_registered.unique_id:
				action_states.erase(action)
				return


## Handle input events
func _handle_key_event(map: Dictionary, keycode: int, is_pressed: bool, entry_id: String) -> void:
	if is_pressed and not map.has(keycode):
		_register_key(entry_id, keycode)
		map[keycode].registered_frame = -1
	elif not is_pressed and map.has(keycode):
		if last_action_registered == map[keycode]:
			last_action_registered = null
		map.erase(keycode)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	
	if event is InputEventKey:
		controller_info.clear()
		_change_current_controller(CONTROLLER_TYPE.Keyboard)
		_handle_key_event(key_states.keys, event.keycode, event.is_pressed(), "keys")

	elif event is InputEventMouseButton:
		_change_current_controller(CONTROLLER_TYPE.Mouse)
		_handle_key_event(key_states.mouse_buttons, event.button_index, event.is_pressed(), "mouse_buttons")

	elif event is InputEventMouseMotion:
		_change_current_controller(CONTROLLER_TYPE.Mouse)

	elif event is InputEventJoypadButton:
		var device_id = event.device
		controller_info = Input.get_joy_info(device_id)
		controller_info.name = Input.get_joy_name(device_id)
		_change_current_controller(CONTROLLER_TYPE.Joypad)
		_handle_key_event(key_states.joy_buttons, event.button_index, event.is_pressed(), "joy_buttons")

	elif event is InputEventJoypadMotion:
		_change_current_controller(CONTROLLER_TYPE.Joypad)
		joy_axis_values[event.axis] = event.axis_value
	
	for action: RegisterKey in action_states.values():
		action.update(get_process_delta_time())
	
	_cleanup_released_actions()


func _cleanup_released_actions() -> void:
	var actions_to_remove = []
	for action_name in action_states.keys():
		if not Input.is_action_pressed(action_name):
			actions_to_remove.append(action_name)
	
	for action_name in actions_to_remove:
		if last_action_registered == action_states[action_name]:
			last_action_registered = null
		action_states.erase(action_name)


func _change_current_controller(new_controller: CONTROLLER_TYPE) -> void:
	if current_controller != new_controller:
		current_controller = new_controller
		controller_changed.emit(current_controller)


## Process the analog stick movement and update direction
func _process_stick_direction(stick_type: String) -> void:
	# Define deadzone for analog stick (value between 0.0 and 1.0)
	var deadzone: float = 0.3
	var direction = ""
	
	# Get axis values based on stick type
	var axis_x: float
	var axis_y: float
	var stick_handler: StickDirection
	
	if stick_type == "left":
		axis_x = joy_axis_values.get(JOY_AXIS_LEFT_X, 0.0)
		axis_y = joy_axis_values.get(JOY_AXIS_LEFT_Y, 0.0)
		stick_handler = stick_left_direction
	elif stick_type == "right":
		axis_x = joy_axis_values.get(JOY_AXIS_RIGHT_X, 0.0)
		axis_y = joy_axis_values.get(JOY_AXIS_RIGHT_Y, 0.0)
		stick_handler = stick_right_direction
	else:
		return # Invalid stick type
	
	# Calculate the magnitude of the stick movement
	var magnitude = sqrt(axis_x * axis_x + axis_y * axis_y)
	
	# Only process if the stick is outside the deadzone
	if magnitude > deadzone:
		# Calculate the angle in radians (atan2 returns -PI to PI)
		var angle = atan2(axis_y, axis_x)
		
		# Convert to degrees and normalize to 0-360 range
		var angle_degrees = rad_to_deg(angle)
		if angle_degrees < 0:
			angle_degrees += 360
		
		# Determine the closest cardinal direction
		# Right: 315-45 degrees (or -45 to 45)
		# Down: 45-135 degrees  
		# Left: 135-225 degrees
		# Up: 225-315 degrees
		if angle_degrees >= 315 or angle_degrees < 45:
			direction = "right"
		elif angle_degrees >= 45 and angle_degrees < 135:
			direction = "down"
		elif angle_degrees >= 135 and angle_degrees < 225:
			direction = "left"
		elif angle_degrees >= 225 and angle_degrees < 315:
			direction = "up"
	
	# Update the stick direction handler
	if direction != stick_handler.direction:
		stick_handler.set_direction(direction)


## Get the raw analog value of a joystick axis (returns value between -1.0 and 1.0)
func get_joy_axis_value(axis: int) -> float:
	return joy_axis_values.get(axis, 0.0)


## Get the raw analog values of the left stick (returns Vector2 with x and y values)
func get_left_stick_vector() -> Vector2:
	var x = joy_axis_values.get(JOY_AXIS_LEFT_X, 0.0)
	var y = joy_axis_values.get(JOY_AXIS_LEFT_Y, 0.0)
	return Vector2(x, y)


## Get the raw analog values of the right stick (returns Vector2 with x and y values)
func get_right_stick_vector() -> Vector2:
	var x = joy_axis_values.get(JOY_AXIS_RIGHT_X, 0.0)
	var y = joy_axis_values.get(JOY_AXIS_RIGHT_Y, 0.0)
	return Vector2(x, y)


## Get the current direction being pressed from the right stick
## Returns "left", "right", "up", "down" or an empty string if no direction
func get_right_stick_direction() -> String:
	if cache.has("right_stick_direction"):
		return cache.right_stick_direction
	
	var result = ""
	
	# Check right analog stick with repeat handling
	if stick_right_direction.direction != "" and stick_right_direction.current_delay <= 0:
		stick_right_direction.refresh()
		result = stick_right_direction.direction
		get_viewport().set_input_as_handled()
	
	cache.right_stick_direction = result
	return result


## Get the current direction being pressed from the left stick
## Returns "left", "right", "up", "down" or an empty string if no direction
func get_left_stick_direction() -> String:
	if cache.has("left_stick_direction"):
		return cache.left_stick_direction
	
	var result = ""
	
	# Check left analog stick with repeat handling
	if stick_left_direction.direction != "" and stick_left_direction.current_delay <= 0:
		stick_left_direction.refresh()
		result = stick_left_direction.direction
		get_viewport().set_input_as_handled()
	
	cache.left_stick_direction = result
	return result


## Set global delay timings for all input types
## Use this to adjust responsiveness based on context (menus, maps, etc.)
func set_input_delays(initial_delay: float, repeat_delay: float) -> void:
	# Validate inputs to prevent negative values
	var safe_initial = max(0.0, initial_delay)
	var safe_repeat = max(0.0, repeat_delay)
	
	# Update timing for RegisterKey instances
	for key in key_states.keys.values():
		key.initial_delay = safe_initial
		key.echo_interval = safe_repeat
	
	for key in key_states.mouse_buttons.values():
		key.initial_delay = safe_initial
		key.echo_interval = safe_repeat
		
	for key in key_states.joy_buttons.values():
		key.initial_delay = safe_initial
		key.echo_interval = safe_repeat
	
	for action in action_states.values():
		action.initial_delay = safe_initial
		action.echo_interval = safe_repeat
	
	# Update timing for analog sticks
	if stick_left_direction:
		stick_left_direction.initial_delay = safe_initial
		stick_left_direction.echo_interval = safe_repeat
	
	if stick_right_direction:
		stick_right_direction.initial_delay = safe_initial
		stick_right_direction.echo_interval = safe_repeat
	
	# Update timing for triggers
	if trigger_left_state:
		trigger_left_state.initial_delay = safe_initial
		trigger_left_state.echo_interval = safe_repeat
	
	if trigger_right_state:
		trigger_right_state.initial_delay = safe_initial
		trigger_right_state.echo_interval = safe_repeat
	
	initial_key_delay = safe_initial
	echo_key_delay = safe_repeat


func _get_current_direction(ignore_opposite_keys = true) -> String:
	if cache.has("pressed_direction"):
		return cache.pressed_direction
	
	var result = ""
	# Check keyboard arrow keys and WASD
	if key_states.keys.has(KEY_LEFT) and key_states.keys[KEY_LEFT].is_active():
		key_states.keys[KEY_LEFT].refresh()
		result = "left"
	elif key_states.keys.has(KEY_RIGHT) and key_states.keys[KEY_RIGHT].is_active():
		key_states.keys[KEY_RIGHT].refresh()
		result = "right"
	elif key_states.keys.has(KEY_UP) and key_states.keys[KEY_UP].is_active():
		key_states.keys[KEY_UP].refresh()
		result = "up"
	elif key_states.keys.has(KEY_DOWN) and key_states.keys[KEY_DOWN].is_active():
		key_states.keys[KEY_DOWN].refresh()
		result = "down"
	elif key_states.keys.has(KEY_A) and key_states.keys[KEY_A].is_active():
		key_states.keys[KEY_A].refresh()
		result = "left"
	elif key_states.keys.has(KEY_D) and key_states.keys[KEY_D].is_active():
		key_states.keys[KEY_D].refresh()
		result = "right"
	elif key_states.keys.has(KEY_W) and key_states.keys[KEY_W].is_active():
		key_states.keys[KEY_W].refresh()
		result = "up"
	elif key_states.keys.has(KEY_S) and key_states.keys[KEY_S].is_active():
		key_states.keys[KEY_S].refresh()
		result = "down"

	# If no keyboard direction, check gamepad D-pad
	if result.is_empty():
		if key_states.joy_buttons.has(JOY_BUTTON_DPAD_LEFT) and key_states.joy_buttons[JOY_BUTTON_DPAD_LEFT].is_active():
			key_states.joy_buttons[JOY_BUTTON_DPAD_LEFT].refresh()
			result = "left"
		elif key_states.joy_buttons.has(JOY_BUTTON_DPAD_RIGHT) and key_states.joy_buttons[JOY_BUTTON_DPAD_RIGHT].is_active():
			key_states.joy_buttons[JOY_BUTTON_DPAD_RIGHT].refresh()
			result = "right"
		elif key_states.joy_buttons.has(JOY_BUTTON_DPAD_UP) and key_states.joy_buttons[JOY_BUTTON_DPAD_UP].is_active():
			key_states.joy_buttons[JOY_BUTTON_DPAD_UP].refresh()
			result = "up"
		elif key_states.joy_buttons.has(JOY_BUTTON_DPAD_DOWN) and key_states.joy_buttons[JOY_BUTTON_DPAD_DOWN].is_active():
			key_states.joy_buttons[JOY_BUTTON_DPAD_DOWN].refresh()
			result = "down"

	# If no keyboard or D-pad direction, check left analog stick with repeat handling
	if result.is_empty() and stick_left_direction.direction != "" and stick_left_direction.current_delay <= 0:
		stick_left_direction.refresh()
		result = stick_left_direction.direction
	
	if result and ignore_opposite_keys:
		var opposite_active = false
		match result:
			"left":
				opposite_active = key_states.keys.has(KEY_RIGHT) or \
								key_states.keys.has(KEY_D) or \
								key_states.joy_buttons.has(JOY_BUTTON_DPAD_RIGHT) or \
								stick_left_direction.direction == "right"
			"right":
				opposite_active = key_states.keys.has(KEY_LEFT) or \
								key_states.keys.has(KEY_A) or \
								key_states.joy_buttons.has(JOY_BUTTON_DPAD_LEFT) or \
								stick_left_direction.direction == "left"
			"up":
				opposite_active = key_states.keys.has(KEY_DOWN) or \
								key_states.keys.has(KEY_S) or \
								key_states.joy_buttons.has(JOY_BUTTON_DPAD_DOWN) or \
								stick_left_direction.direction == "down"
			"down":
				opposite_active = key_states.keys.has(KEY_UP) or \
								key_states.keys.has(KEY_W) or \
								key_states.joy_buttons.has(JOY_BUTTON_DPAD_UP) or \
								stick_left_direction.direction == "up"
		if opposite_active:
			result = ""
	
	cache.pressed_direction = result
	return result


## Get the current direction being pressed (from keyboard or gamepad)
## Returns "left", "right", "up", "down" or an empty string if no direction
func get_pressed_direction() -> String:
	# If not in cache, compute the result
	var direction = _get_current_direction()
	
	if not direction.is_empty():
		get_viewport().set_input_as_handled()
	
	return direction
	

## Check if a confirm action was JUST pressed (no echo, only initial press)
func is_confirm_just_pressed(ignore_mouse_left: bool = false, extra_keys: PackedInt32Array = [], mouse_left_require_focusable: bool = true) -> bool:
	var cache_key = "confirm_just_" + str(ignore_mouse_left) + "_" + str(extra_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	if Input.is_key_pressed(KEY_ALT):
		cache[cache_key] = false
		return false
	
	var current_frame = Engine.get_physics_frames()
	var result = false
	
	# Check keyboard confirm keys (only if pressed THIS FRAME)
	for key_code in CONFIRM_INPUTS.keys:
		if key_code in key_states.keys and key_states.keys[key_code].initialize and key_states.keys[key_code].current_delay <= 0:
			if key_states.keys[key_code].registered_frame == current_frame or key_states.keys[key_code].registered_frame == -1:
				key_states.keys[key_code].refresh()
				result = true
				break
	
	# Check mouse confirm buttons
	if not result:
		for button in CONFIRM_INPUTS.mouse:
			if button == MOUSE_BUTTON_LEFT and ignore_mouse_left:
				continue
			if button in key_states.mouse_buttons and key_states.mouse_buttons[button].initialize and key_states.mouse_buttons[button].current_delay <= 0:
				if key_states.mouse_buttons[button].registered_frame == current_frame or key_states.mouse_buttons[button].registered_frame == -1:
					if mouse_left_require_focusable and not GameManager.is_mouse_over_current_control_focused():
						break
					key_states.mouse_buttons[button].refresh()
					result = true
					break
	
	# Check gamepad confirm buttons
	if not result:
		for button in CONFIRM_INPUTS.joy:
			if button in key_states.joy_buttons and key_states.joy_buttons[button].initialize and key_states.joy_buttons[button].current_delay <= 0:
				if key_states.joy_buttons[button].registered_frame == current_frame or key_states.joy_buttons[button].registered_frame == -1:
					key_states.joy_buttons[button].refresh()
					result = true
					break
	
	# Check extra keys
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in key_states.keys and key_states.keys[key].initialize and key_states.keys[key].current_delay <= 0:
				if key_states.keys[key].registered_frame == current_frame or key_states.keys[key].registered_frame == -1:
					key_states.keys[key].refresh()
					result = true
					break
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache[cache_key] = result

	return result


## Check if a cancel action was JUST pressed (no echo)
func is_cancel_just_pressed(extra_keys: PackedInt32Array = []) -> bool:
	var cache_key = "cancel_just_" + str(extra_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	var current_frame = Engine.get_physics_frames()
	var result = false
	
	# Check keyboard cancel keys
	for key_code in CANCEL_INPUTS.keys:
		if key_code in key_states.keys and key_states.keys[key_code].initialize and key_states.keys[key_code].current_delay <= 0:
			if key_states.keys[key_code].registered_frame == current_frame or key_states.keys[key_code].registered_frame == -1:
				key_states.keys[key_code].refresh()
				result = true
				break
	
	# Check mouse cancel buttons
	if not result:
		for button in CANCEL_INPUTS.mouse:
			if button in key_states.mouse_buttons and key_states.mouse_buttons[button].initialize and key_states.mouse_buttons[button].current_delay <= 0:
				if key_states.mouse_buttons[button].registered_frame == current_frame or key_states.mouse_buttons[button].registered_frame == -1:
					key_states.mouse_buttons[button].refresh()
					result = true
					break
	
	# Check gamepad cancel buttons
	if not result:
		for button in CANCEL_INPUTS.joy:
			if button in key_states.joy_buttons and key_states.joy_buttons[button].initialize and key_states.joy_buttons[button].current_delay <= 0:
				if key_states.joy_buttons[button].registered_frame == current_frame or key_states.joy_buttons[button].registered_frame == -1:
					key_states.joy_buttons[button].refresh()
					result = true
					break
	
	# Check extra keys
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in key_states.keys and key_states.keys[key].initialize and key_states.keys[key].current_delay <= 0:
				if key_states.keys[key].registered_frame == current_frame or key_states.keys[key].registered_frame == -1:
					key_states.keys[key].refresh()
					result = true
					break
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache[cache_key] = result
	return result


## Generic function to check if the the specified mouse button was just pressed (no echo)
func is_mouse_button_just_pressed(keycode: int) -> bool:
	var cache_key = "mouse_just_" + str(keycode)
	if cache.has(cache_key):
		return cache[cache_key]
	
	var current_frame = Engine.get_physics_frames()
	var result = false
	if keycode in key_states.mouse_buttons and key_states.mouse_buttons[keycode].initialize and key_states.mouse_buttons[keycode].current_delay <= 0:
		if key_states.mouse_buttons[keycode].registered_frame == current_frame or key_states.mouse_buttons[keycode].registered_frame == -1:
			key_states.mouse_buttons[keycode].refresh()
			get_viewport().set_input_as_handled()
			result = true
	
	cache[cache_key] = result
	return result


## Generic function to check if ANY key/button was just pressed (no echo)
func is_key_just_pressed(keycode: int) -> bool:
	var cache_key = "key_just_" + str(keycode)
	if cache.has(cache_key):
		return cache[cache_key]
	
	var current_frame = Engine.get_physics_frames()
	var result = false
	if keycode in key_states.keys and key_states.keys[keycode].initialize and key_states.keys[keycode].current_delay <= 0:
		if key_states.keys[keycode].registered_frame == current_frame or key_states.keys[keycode].registered_frame == -1:
			key_states.keys[keycode].refresh()
			get_viewport().set_input_as_handled()
			result = true
	
	cache[cache_key] = result
	return result


## Generic function to check if ANY joy button was just pressed (no echo)
func is_joy_button_just_pressed(keycode: int) -> bool:
	var cache_key = "joy_just_" + str(keycode)
	if cache.has(cache_key):
		return cache[cache_key]
	
	var current_frame = Engine.get_physics_frames()
	var result = false
	if keycode in key_states.joy_buttons and key_states.joy_buttons[keycode].initialize and key_states.joy_buttons[keycode].current_delay <= 0:
		if key_states.joy_buttons[keycode].registered_frame == current_frame or key_states.joy_buttons[keycode].registered_frame == -1:
			key_states.joy_buttons[keycode].refresh()
			get_viewport().set_input_as_handled()
			result = true
	
	cache[cache_key] = result
	return result


## Generic function to check if action was just pressed (no echo)
func is_action_just_pressed(action: String) -> bool:
	var cache_key = "action_just_" + action
	if cache.has(cache_key):
		return cache[cache_key]
	
	var current_frame = Engine.get_physics_frames()
	var result = false
	
	if Input.is_action_pressed(action):
		if not action_states.has(action):
			_register_action(action)
		
		if action_states[action].initialize and action_states[action].current_delay <= 0:
			if action_states[action].registered_frame == current_frame or action_states[action].registered_frame == -1:
				action_states[action].refresh()
				get_viewport().set_input_as_handled()
				result = true
	
	cache[cache_key] = result
	return result
