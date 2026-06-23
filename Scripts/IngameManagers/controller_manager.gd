extends Node

#region Input Classes

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
			registered_frame = Engine.get_process_frames()
		base_node.get_viewport().set_input_as_handled()
		if initialize:
			initialize = false
			set_deferred("current_delay", initial_delay)
		else:
			set_deferred("current_delay", echo_interval)
	
	func is_just_pressed() -> bool:
		return registered_frame == Engine.get_process_frames()
	
	
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
	
	func _to_string() -> String:
		return "Keycode = %s,
		initialize = %s,
		initial_delay = %s,
		echo_interval = %s,
		registered_frame = %s
		" % [keycode, initialize, initial_delay, echo_interval, registered_frame]


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
		registered_frame = Engine.get_process_frames()
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

#endregion


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
var is_caps_lock_on: bool = false :
	set(value):
		is_caps_lock_on = value
		caps_lock_changed.emit(is_caps_lock_on)

var last_checked_frame: int = -1

## Toggles typing mode. When true, directional echoes ignore WASD keys to prevent virtual cursor movement while typing.
var is_typing_mode: bool = false

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
## Extra symbols for Shift + Numbers (Top row)
const SHIFT_SYMBOLS_EXTRA := {
	KEY_1: "!", KEY_2: "\"", KEY_3: "·", KEY_4: "$", KEY_5: "%",
	KEY_6: "&", KEY_7: "/", KEY_8: "(", KEY_9: ")", KEY_0: "=",
	KEY_MINUS: "?", KEY_EQUAL: "¿"
}
## Mapping for Numpad keys to their character representation
const KP_MAP := {
	KEY_KP_0: "0", KEY_KP_1: "1", KEY_KP_2: "2", KEY_KP_3: "3", 
	KEY_KP_4: "4", KEY_KP_5: "5", KEY_KP_6: "6", KEY_KP_7: "7", 
	KEY_KP_8: "8", KEY_KP_9: "9", KEY_KP_ADD: "+", KEY_KP_SUBTRACT: "-", 
	KEY_KP_MULTIPLY: "*", KEY_KP_DIVIDE: "/", KEY_KP_PERIOD: "."
}


signal controller_changed(controller_type: CONTROLLER_TYPE)
signal caps_lock_changed(value: bool)



#region Core Initialization


## Initialize the input controller
func _ready() -> void:
	if not Engine.is_editor_hint():
		get_tree().node_added.connect(_on_node_added)
		_clean_existing_controls(get_tree().root)

	clear()
	_scan_initial_caps_lock()
	set_input_delays(initial_key_delay, echo_key_delay)
	close_neighbor_script = preload("res://Scripts/close_neighbor.gd").new()


## Handles node added event.
func _on_node_added(node: Node) -> void:
	if node is Control:
		_strip_neighbors(node)


## Strips focus neighbors from a control.
func _strip_neighbors(node: Control) -> void:
	var keys = [
		"focus_neighbor_right", 
		"focus_neighbor_left", 
		"focus_neighbor_top", 
		"focus_neighbor_bottom"
	]
	var ids = [
		"right",
		"left",
		"up",
		"down"
	]
	
	var meta_data = {}
	for i in keys.size():
		var key = keys[i]
		var val = node.get(key)
		if val and not val.is_empty():
			meta_data[ids[i]] = val
		
		# Limpiamos la propiedad nativa de Godot para que no navegue solo
		node.set(key, NodePath(""))
	
	# Guardamos los vecinos originales en metadata por si el algoritmo los necesita
	if not meta_data.is_empty():
		node.set_meta("neighbors", meta_data)


## Cleans focus neighbors from all controls.
func _clean_existing_controls(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			_strip_neighbors(child)
		_clean_existing_controls(child)


## Scans the initial OS Caps Lock state.
func _scan_initial_caps_lock() -> void:
	# HACK TO GET CapsLock STATE
	
	var output = []
	var os_name = OS.get_name()
	var success : bool = false
	
	match os_name:
		"Windows":
			var exit_code = OS.execute("powershell", ["-Command", "[console]::CapsLock"], output)
			if exit_code == 0 and output.size() > 0:
				is_caps_lock_on = output[0].strip_edges().to_lower() == "true"
				success = true
				
		"macOS":
			var script = "import Quartz; print(Quartz.CGEventSourceFlagsState(1) & 0x00010000 != 0)"
			var exit_code = OS.execute("python3", ["-c", script], output)
			if exit_code == 0 and output.size() > 0:
				is_caps_lock_on = output[0].strip_edges().to_lower() == "true"
				success = true
				
		"Linux":
			var exit_code = OS.execute("xset", ["q"], output)
			if exit_code == 0 and output.size() > 0:
				var full_output = "".join(output)
				is_caps_lock_on = "Caps Lock:   on" in full_output
				success = true

	if not success:
		is_caps_lock_on = Input.is_key_pressed(KEY_CAPSLOCK)


## Toggles the OS Caps Lock state.
func toggle_os_caps_lock() -> void:
	# HACK TO TOGGLED CapsLock STATE
	
	var os_name = OS.get_name()
	
	match os_name:
		"Windows":
			var script = "$w = New-Object -ComObject WScript.Shell; $w.SendKeys('{CAPSLOCK}')"
			OS.execute("powershell", ["-Command", script])
			
		"macOS":
			var script = "tell application \"System Events\" to key code 57"
			OS.execute("osascript", ["-e", script])
			
		"Linux":
			OS.execute("xdotool", ["key", "Caps_Lock"])


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

#endregion



#region Processing


## Process input states every frame
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	# Clear all cache at the beginning of each frame
	cache.clear()
	
	# Update all registered inputs
	for key: RegisterKey in key_states.keys.values():
		if key.registered_frame == -1:
			key.registered_frame = Engine.get_process_frames()
		key.update(delta)
	for key: RegisterKey in key_states.mouse_buttons.values():
		if key.registered_frame == -1:
			key.registered_frame = Engine.get_process_frames()
		key.update(delta)
	for key: RegisterKey in key_states.joy_buttons.values():
		if key.registered_frame == -1:
			key.registered_frame = Engine.get_process_frames()
		key.update(delta)
	for action: RegisterKey in action_states.values():
		if action.registered_frame == -1:
			action.registered_frame = Engine.get_process_frames()
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


## Handle input events
func _handle_key_event(map: Dictionary, keycode: int, is_pressed: bool, entry_id: String) -> void:
	if is_pressed and not map.has(keycode):
		_register_key(entry_id, keycode)
		map[keycode].registered_frame = -1
	elif not is_pressed and map.has(keycode):
		if last_action_registered == map[keycode]:
			last_action_registered = null
		map.erase(keycode)


## Handles native input events.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return
	
	if event is InputEventKey:
		_sync_caps_lock_state(event)
		
		if event.keycode == KEY_CAPSLOCK and event.pressed and not event.is_echo():
			is_caps_lock_on = !is_caps_lock_on
			
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


## Synchronizes the internal CapsLock state with the OS state
func _sync_caps_lock_state(event: InputEventKey) -> void:
	if not event.pressed or event.unicode <= 0 or event.unicode > 0xFFFF:
		return

	var u: int = event.unicode
	var is_shift: bool = event.shift_pressed
	
	var is_lower: bool = (u >= 97 and u <= 122) or u == 241
	var is_upper: bool = (u >= 65 and u <= 90) or u == 209

	if is_lower:
		is_caps_lock_on = is_shift
	elif is_upper:
		is_caps_lock_on = not is_shift


## Cleans up released actions.
func _cleanup_released_actions() -> void:
	var actions_to_remove = []
	for action_name in action_states.keys():
		if not Input.is_action_pressed(action_name):
			actions_to_remove.append(action_name)
	
	for action_name in actions_to_remove:
		if last_action_registered == action_states[action_name]:
			last_action_registered = null
		action_states.erase(action_name)


## Changes the active controller type.
func _change_current_controller(new_controller: CONTROLLER_TYPE) -> void:
	if current_controller != new_controller:
		current_controller = new_controller
		controller_changed.emit(current_controller)

#endregion



#region Registration


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


## Registers a new action.
func _register_action(action_name: String) -> void:
	var new_action = RegisterKey.new(self, _generate_id(), 0, initial_key_delay, echo_key_delay)
	new_action.registered_frame = -1
	action_states[action_name] = new_action
	last_action_registered = new_action


## Removes the last registered action.
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

#endregion



#region Direction & Analog Sticks


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


## Gets the current pressed direction, ignoring WASD keys if typing mode is active
func _get_current_direction(ignore_opposite_keys = true) -> String:
	if cache.has("pressed_direction"):
		return cache.pressed_direction
		
	var result = ""
	
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
	elif not is_typing_mode and key_states.keys.has(KEY_A) and key_states.keys[KEY_A].is_active():
		key_states.keys[KEY_A].refresh()
		result = "left"
	elif not is_typing_mode and key_states.keys.has(KEY_D) and key_states.keys[KEY_D].is_active():
		key_states.keys[KEY_D].refresh()
		result = "right"
	elif not is_typing_mode and key_states.keys.has(KEY_W) and key_states.keys[KEY_W].is_active():
		key_states.keys[KEY_W].refresh()
		result = "up"
	elif not is_typing_mode and key_states.keys.has(KEY_S) and key_states.keys[KEY_S].is_active():
		key_states.keys[KEY_S].refresh()
		result = "down"
		
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
			
	if result.is_empty() and stick_left_direction.direction != "" and stick_left_direction.current_delay <= 0:
		stick_left_direction.refresh()
		result = stick_left_direction.direction
		
	if result and ignore_opposite_keys:
		var opposite_active = false
		match result:
			"left":
				opposite_active = key_states.keys.has(KEY_RIGHT) or \
								(not is_typing_mode and key_states.keys.has(KEY_D)) or \
								key_states.joy_buttons.has(JOY_BUTTON_DPAD_RIGHT) or \
								stick_left_direction.direction == "right"
			"right":
				opposite_active = key_states.keys.has(KEY_LEFT) or \
								(not is_typing_mode and key_states.keys.has(KEY_A)) or \
								key_states.joy_buttons.has(JOY_BUTTON_DPAD_LEFT) or \
								stick_left_direction.direction == "left"
			"up":
				opposite_active = key_states.keys.has(KEY_DOWN) or \
								(not is_typing_mode and key_states.keys.has(KEY_S)) or \
								key_states.joy_buttons.has(JOY_BUTTON_DPAD_DOWN) or \
								stick_left_direction.direction == "down"
			"down":
				opposite_active = key_states.keys.has(KEY_UP) or \
								(not is_typing_mode and key_states.keys.has(KEY_W)) or \
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

#endregion



#region Triggers


# Check if L2 trigger is pressed with repeat handling
## Checks if L2 trigger is pressed.
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
## Checks if R2 trigger is pressed.
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
## Legacy trigger check.
func is_joy_axis_trigger_pressed(joy_axis_trigger: int) -> bool:
	if joy_axis_trigger == JOY_AXIS_TRIGGER_LEFT:
		return is_trigger_left_pressed()
	elif joy_axis_trigger == JOY_AXIS_TRIGGER_RIGHT:
		return is_trigger_right_pressed()
	
	# Fallback for other axes
	var trigger = Input.get_joy_axis(0, joy_axis_trigger)
	return trigger > 0.1


# Get the raw analog value of a trigger (returns value between 0.0 and 1.0)
## Gets raw trigger value.
func get_trigger_value(trigger_axis: int) -> float:
	return joy_axis_values.get(trigger_axis, 0.0)

#endregion



#region Continuous Pressed (Held)

## Checks if any input from a map or action array is pressed with echo handling.
func is_custom_inputs_pressed(input_map: Dictionary = {}, actions: Array[String] = [], exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "custom_pressed_" + str(input_map) + "_" + str(actions) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		return cache[cache_key]
		
	var result = false
	
	if input_map.has("keys"):
		for key_code in input_map["keys"]:
			if key_code in exclude_keys: continue
			if is_key_pressed(key_code):
				result = true
				break
				
	if not result and input_map.has("mouse"):
		for button in input_map["mouse"]:
			if button in exclude_keys: continue
			if is_mouse_button_pressed(button):
				result = true
				break
				
	if not result and input_map.has("joy"):
		for button in input_map["joy"]:
			if button in exclude_keys: continue
			if is_joy_button_pressed(button):
				result = true
				break
				
	if not result and not actions.is_empty():
		for action in actions:
			if is_action_pressed(action):
				result = true
				break
				
	cache[cache_key] = result
	return result


## Checks if any input from a map or action array is held continuously.
func is_custom_inputs_held(input_map: Dictionary = {}, actions: Array[String] = [], exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "custom_held_" + str(input_map) + "_" + str(actions) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		return cache[cache_key]
		
	var result = false
	
	if input_map.has("keys"):
		for key_code in input_map["keys"]:
			if key_code in exclude_keys: continue
			if key_states.keys.has(key_code):
				result = true
				break
				
	if not result and input_map.has("mouse"):
		for button in input_map["mouse"]:
			if button in exclude_keys: continue
			if key_states.mouse_buttons.has(button):
				result = true
				break
				
	if not result and input_map.has("joy"):
		for button in input_map["joy"]:
			if button in exclude_keys: continue
			if key_states.joy_buttons.has(button):
				result = true
				break
				
	if not result and not actions.is_empty():
		for action in actions:
			if is_action_held(action):
				result = true
				break
				
	cache[cache_key] = result
	return result


func is_any_pressed() -> bool:
	if not key_states.keys.is_empty():
		return true
		
	if not key_states.mouse_buttons.is_empty():
		return true
		
	if not key_states.joy_buttons.is_empty():
		return true
		
	return false


## Check if a keyboard key is pressed with repeat handling
func is_key_pressed(keycode: int) -> bool:
	if is_key_just_pressed(keycode): return true
	
	var result = false
	if keycode in key_states.keys and key_states.keys[keycode].current_delay <= 0:
		key_states.keys[keycode].refresh()
		get_viewport().set_input_as_handled()
		result = true
	
	return result


## Check if a keyboard key is continuously held down bypassing echo
func is_key_held(keycode: int) -> bool:
	return key_states.keys.has(keycode)


# Check if a joystick/gamepad button is pressed with repeat handling
## Checks if a joypad button is pressed.
func is_joy_button_pressed(keycode: int) -> bool:
	if is_joy_button_just_pressed(keycode): return true
	
	var result = false
	if keycode in key_states.joy_buttons and key_states.joy_buttons[keycode].current_delay <= 0:
		key_states.joy_buttons[keycode].refresh()
		get_viewport().set_input_as_handled()
		result = true
	
	return result


## Check if a joystick/gamepad button is continuously held down bypassing echo
func is_joy_button_held(keycode: int) -> bool:
	return key_states.joy_buttons.has(keycode)


# Check if action is pressed with repeat handling
## Checks if an action is pressed.
func is_action_pressed(action: String) -> bool:
	if is_action_just_pressed(action): return true
	
	var cache_key = "action_" + action
	if cache.has(cache_key):
		return cache[cache_key]
	
	var result = false
	
	if Input.is_action_pressed(action):
		if not action_states.has(action):
			_register_action(action)
			if not Input.is_action_just_pressed(action):
				action_states[action].initialize = false
		
		if action_states[action].is_active():
			action_states[action].refresh()
			get_viewport().set_input_as_handled()
			result = true
	
	cache[cache_key] = result
	return result


## Check if an action is continuously held down bypassing echo
func is_action_held(action: String) -> bool:
	var cache_key = "action_held_" + action
	if cache.has(cache_key):
		return cache[cache_key]
	
	var result = Input.is_action_pressed(action)
	cache[cache_key] = result
	return result


# Check if a mouse button is pressed with repeat handling
## Checks if a mouse button is pressed.
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


## Check if a mouse button is continuously held down bypassing echo
func is_mouse_button_held(keycode: int) -> bool:
	return key_states.mouse_buttons.has(keycode)


# Check if a confirm action is pressed (Enter, Space, A button, left click, etc.)
## Checks if a confirm action is pressed.
func is_confirm_pressed(ignore_mouse_left: bool = false, extra_keys: PackedInt32Array = [], mouse_left_require_focusable: bool = true, exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "confirm_" + str(ignore_mouse_left) + "_" + str(extra_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	if Input.is_key_pressed(KEY_ALT):
		cache[cache_key] = false
		return false
	
	var result = false
	
	for key_code in CONFIRM_INPUTS.keys:
		if key_code in exclude_keys: continue
		if is_key_pressed(key_code):
			result = true
			break
			
	if not result:
		for button in CONFIRM_INPUTS.mouse:
			if button in exclude_keys: continue
			if button == MOUSE_BUTTON_LEFT and ignore_mouse_left:
				continue
			if is_mouse_button_pressed(button):
				if mouse_left_require_focusable and not GameManager.is_mouse_over_current_control_focused():
					break
				result = true
				break
				
	if not result:
		for button in CONFIRM_INPUTS.joy:
			if button in exclude_keys: continue
			if is_joy_button_pressed(button):
				result = true
				break
				
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in exclude_keys: continue
			if is_key_pressed(key):
				result = true
				break
				
	if result:
		get_viewport().set_input_as_handled()
		
	cache[cache_key] = result
	return result


## Checks if a confirm action is held.
func is_confirm_held(ignore_mouse_left: bool = false, extra_keys: PackedInt32Array = [], mouse_left_require_focusable: bool = true, exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "confirm_held_" + str(ignore_mouse_left) + "_" + str(extra_keys) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	if Input.is_key_pressed(KEY_ALT):
		cache[cache_key] = false
		return false
	
	var result = false
	
	for key_code in CONFIRM_INPUTS.keys:
		if key_code in exclude_keys: continue
		if key_states.keys.has(key_code):
			result = true
			break
			
	if not result:
		for button in CONFIRM_INPUTS.mouse:
			if button in exclude_keys: continue
			if button == MOUSE_BUTTON_LEFT and ignore_mouse_left:
				continue
			if key_states.mouse_buttons.has(button):
				if mouse_left_require_focusable and not GameManager.is_mouse_over_current_control_focused():
					break
				result = true
				break
				
	if not result:
		for button in CONFIRM_INPUTS.joy:
			if button in exclude_keys: continue
			if key_states.joy_buttons.has(button):
				result = true
				break
				
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in exclude_keys: continue
			if key_states.keys.has(key):
				result = true
				break
				
	cache[cache_key] = result
	return result


## Checks if a force confirm action is pressed.
func is_force_confirm_pressed() -> bool:
	if cache.has("force_confirm"):
		return cache.force_confirm
		
	var result = false
	
	if is_action_pressed("ForceConfirm"):
		result = true
		
	cache.force_confirm = result
	return result


## Check if force confirm action is continuously held down bypassing echo
func is_force_confirm_held() -> bool:
	var cache_key = "force_confirm_held"
	if cache.has(cache_key):
		return cache[cache_key]
	
	var result = Input.is_action_pressed("ForceConfirm")
	cache[cache_key] = result
	return result


## Check if a cancel action is pressed (Escape, Backspace, B button, right click, etc.)
func is_cancel_pressed(extra_keys: PackedInt32Array = [], exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "cancel_" + str(extra_keys) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	var result = false
	
	# Check keyboard cancel keys
	for key_code in CANCEL_INPUTS.keys:
		if key_code in exclude_keys: continue
		if is_key_pressed(key_code):
			result = true
			break
	
	# Check mouse cancel buttons if no keyboard key was pressed
	if not result:
		for button in CANCEL_INPUTS.mouse:
			if button in exclude_keys: continue
			if is_mouse_button_pressed(button):
				result = true
				break
	
	# Check gamepad cancel buttons if no keyboard/mouse button was pressed
	if not result:
		for button in CANCEL_INPUTS.joy:
			if button in exclude_keys: continue
			if is_joy_button_pressed(button):
				result = true
				break
	
	# Check extra keys if any
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in exclude_keys: continue
			if is_key_pressed(key):
				result = true
				break
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache[cache_key] = result
	return result


## Check if a cancel action is continuously held down bypassing echo
func is_cancel_held(extra_keys: PackedInt32Array = [], exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "cancel_held_" + str(extra_keys) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	var result = false
	
	for key_code in CANCEL_INPUTS.keys:
		if key_code in exclude_keys: continue
		if key_states.keys.has(key_code):
			result = true
			break
			
	if not result:
		for button in CANCEL_INPUTS.mouse:
			if button in exclude_keys: continue
			if key_states.mouse_buttons.has(button):
				result = true
				break
				
	if not result:
		for button in CANCEL_INPUTS.joy:
			if button in exclude_keys: continue
			if key_states.joy_buttons.has(button):
				result = true
				break
				
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in exclude_keys: continue
			if key_states.keys.has(key):
				result = true
				break
				
	cache[cache_key] = result
	return result


## Check if a erase letter action is pressed (BACKSPACE, B Button, Right Mouse Button)
func is_erase_letter_pressed(extra_keys: PackedInt32Array = [], exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "erase_letter_" + str(extra_keys) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	var result = false
	
	# Check keyboard erase letter keys
	for key_code in ERASE_LETTER_INPUTS.keys:
		if key_code in exclude_keys: continue
		if is_key_pressed(key_code):
			result = true
			break
	
	# Check mouse erase letter buttons if no keyboard key was pressed
	if not result:
		for button in ERASE_LETTER_INPUTS.mouse:
			if button in exclude_keys: continue
			if is_mouse_button_pressed(button):
				result = true
				break
	
	# Check gamepad erase letter buttons if no keyboard/mouse button was pressed
	if not result:
		for button in ERASE_LETTER_INPUTS.joy:
			if button in exclude_keys: continue
			if is_joy_button_pressed(button):
				result = true
				break
				
	# Check extra keys if any
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in exclude_keys: continue
			if is_key_pressed(key):
				result = true
				break
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache.erase_letter = result
	return result


## Check if an erase letter action is continuously held down bypassing echo
func is_erase_letter_held(extra_keys: PackedInt32Array = [], exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "erase_letter_held_" + str(extra_keys) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		return cache[cache_key]
	
	var result = false
	
	for key_code in ERASE_LETTER_INPUTS.keys:
		if key_code in exclude_keys: continue
		if key_states.keys.has(key_code):
			result = true
			break
			
	if not result:
		for button in ERASE_LETTER_INPUTS.mouse:
			if button in exclude_keys: continue
			if key_states.mouse_buttons.has(button):
				result = true
				break
				
	if not result:
		for button in ERASE_LETTER_INPUTS.joy:
			if button in exclude_keys: continue
			if key_states.joy_buttons.has(button):
				result = true
				break
				
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in exclude_keys: continue
			if key_states.keys.has(key):
				result = true
				break
				
	cache[cache_key] = result
	return result


## Check if either Enter or Numpad Enter is pressed with repeat handling
func is_enter_pressed() -> bool:
	if is_enter_just_pressed(): return true
	
	var result = false
	
	# Check standard Enter
	if KEY_ENTER in key_states.keys and key_states.keys[KEY_ENTER].current_delay <= 0:
		key_states.keys[KEY_ENTER].refresh()
		result = true
	
	# Check Numpad Enter if standard was not pressed
	if not result and KEY_KP_ENTER in key_states.keys and key_states.keys[KEY_KP_ENTER].current_delay <= 0:
		key_states.keys[KEY_KP_ENTER].refresh()
		result = true
	
	if result:
		get_viewport().set_input_as_handled()
		
	return result


## Check if either Enter or Numpad Enter is continuously held down bypassing echo
func is_enter_held() -> bool:
	var cache_key = "enter_held"
	if cache.has(cache_key):
		return cache[cache_key]
		
	var result = false
	if key_states.keys.has(KEY_ENTER) or key_states.keys.has(KEY_KP_ENTER):
		result = true
		
	cache[cache_key] = result
	return result


## Get the character of any key being pressed (supports echo/repeat)
func get_any_key_pressed() -> String:
	if cache.has("any_key"):
		return cache.any_key

	for keycode in key_states.keys.keys():
		if keycode == KEY_SHIFT or keycode == KEY_CAPSLOCK or keycode == KEY_CTRL or keycode == KEY_ALT:
			continue
			
		if is_key_pressed(keycode):
			var result := _keycode_to_char(keycode)
			if result != "":
				cache.any_key = result
				return result

	cache.any_key = ""
	return ""

#endregion



#region Just Pressed

## Checks if any input from a map or action array was just pressed.
func is_custom_inputs_just_pressed(input_map: Dictionary = {}, actions: Array[String] = [], consume: bool = true, exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "custom_just_pressed_" + str(input_map) + "_" + str(actions) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
		
	var result = false
	
	if input_map.has("keys"):
		for key_code in input_map["keys"]:
			if key_code in exclude_keys: continue
			if is_key_just_pressed(key_code, consume):
				result = true
				break
				
	if not result and input_map.has("mouse"):
		for button in input_map["mouse"]:
			if button in exclude_keys: continue
			if is_mouse_button_just_pressed(button, consume):
				result = true
				break
				
	if not result and input_map.has("joy"):
		for button in input_map["joy"]:
			if button in exclude_keys: continue
			if is_joy_button_just_pressed(button, consume):
				result = true
				break
				
	if not result and not actions.is_empty():
		for action in actions:
			if is_action_just_pressed(action, consume):
				result = true
				break
				
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Checks if any key, mouse button, or joypad button was just pressed.
func is_any_just_pressed(consume: bool = true) -> bool:
	var cache_key = "any_just_pressed"
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
		
	var result = false
	
	for keycode in key_states.keys.keys():
		if is_key_just_pressed(keycode, consume):
			result = true
			break
			
	if not result:
		for button in key_states.mouse_buttons.keys():
			if is_mouse_button_just_pressed(button, consume):
				result = true
				break
				
	if not result:
		for button in key_states.joy_buttons.keys():
			if is_joy_button_just_pressed(button, consume):
				result = true
				break
				
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Generic function to check if ANY key/button was just pressed (no echo)
func is_key_just_pressed(keycode: int, consume: bool = true) -> bool:
	var cache_key = "key_just_" + str(keycode)
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
	
	var current_frame = Engine.get_process_frames()
	var result = false
	if keycode in key_states.keys and key_states.keys[keycode].initialize and key_states.keys[keycode].current_delay <= 0:
		if key_states.keys[keycode].registered_frame == current_frame or key_states.keys[keycode].registered_frame == -1:
			key_states.keys[keycode].refresh()
			get_viewport().set_input_as_handled()
			result = true
	
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Generic function to check if the the specified mouse button was just pressed (no echo)
func is_mouse_button_just_pressed(keycode: int, consume: bool = true) -> bool:
	var cache_key = "mouse_just_" + str(keycode)
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
	
	var current_frame = Engine.get_process_frames()
	var result = false
	if keycode in key_states.mouse_buttons and key_states.mouse_buttons[keycode].initialize and key_states.mouse_buttons[keycode].current_delay <= 0:
		if key_states.mouse_buttons[keycode].registered_frame == current_frame or key_states.mouse_buttons[keycode].registered_frame == -1:
			key_states.mouse_buttons[keycode].refresh()
			get_viewport().set_input_as_handled()
			result = true
	
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Generic function to check if ANY joy button was just pressed (no echo)
func is_joy_button_just_pressed(keycode: int, consume: bool = true) -> bool:
	var cache_key = "joy_just_" + str(keycode)
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
	
	var current_frame = Engine.get_process_frames()
	var result = false
	if keycode in key_states.joy_buttons and key_states.joy_buttons[keycode].initialize and key_states.joy_buttons[keycode].current_delay <= 0:
		if key_states.joy_buttons[keycode].registered_frame == current_frame or key_states.joy_buttons[keycode].registered_frame == -1:
			key_states.joy_buttons[keycode].refresh()
			get_viewport().set_input_as_handled()
			result = true
	
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Generic function to check if action was just pressed (no echo)
func is_action_just_pressed(action: String, consume: bool = true) -> bool:
	var cache_key = "action_just_" + action
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
	
	var current_frame = Engine.get_process_frames()
	var result = false
	
	if Input.is_action_pressed(action):
		if not action_states.has(action):
			_register_action(action)
			if not Input.is_action_just_pressed(action):
				action_states[action].initialize = false
		
		if action_states[action].initialize and action_states[action].current_delay <= 0:
			if action_states[action].registered_frame == current_frame or action_states[action].registered_frame == -1:
				action_states[action].refresh()
				get_viewport().set_input_as_handled()
				result = true
	
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Checks if action was just released.
func is_action_just_released(action: String, consume: bool = true) -> bool:
	var cache_key = "action_just_released_" + action
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
	
	var result = Input.is_action_just_released(action)
	
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Check if a confirm action was JUST pressed (no echo, only initial press)
func is_confirm_just_pressed(ignore_mouse_left: bool = false, extra_keys: PackedInt32Array = [], mouse_left_require_focusable: bool = true, consume: bool = true, exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "confirm_just_" + str(ignore_mouse_left) + "_" + str(extra_keys) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
	
	if Input.is_key_pressed(KEY_ALT):
		cache[cache_key] = false
		return false
	
	var result = false
	
	for key_code in CONFIRM_INPUTS.keys:
		if key_code in exclude_keys: continue
		if is_key_just_pressed(key_code, consume):
			result = true
			break
	
	if not result:
		for button in CONFIRM_INPUTS.mouse:
			if button in exclude_keys: continue
			if button == MOUSE_BUTTON_LEFT and ignore_mouse_left:
				continue
			if is_mouse_button_just_pressed(button, consume):
				if mouse_left_require_focusable and not GameManager.is_mouse_over_current_control_focused():
					break
				result = true
				break
	
	if not result:
		for button in CONFIRM_INPUTS.joy:
			if button in exclude_keys: continue
			if is_joy_button_just_pressed(button, consume):
				result = true
				break
	
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in exclude_keys: continue
			if is_key_just_pressed(key, consume):
				result = true
				break
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Check if a cancel action was JUST pressed (no echo)
func is_cancel_just_pressed(extra_keys: PackedInt32Array = [], consume: bool = true, exclude_keys: PackedInt32Array = []) -> bool:
	var cache_key = "cancel_just_" + str(extra_keys) + "_" + str(exclude_keys)
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
	
	var result = false
	
	for key_code in CANCEL_INPUTS.keys:
		if key_code in exclude_keys: continue
		if is_key_just_pressed(key_code, consume):
			result = true
			break
	
	if not result:
		for button in CANCEL_INPUTS.mouse:
			if button in exclude_keys: continue
			if is_mouse_button_just_pressed(button, consume):
				result = true
				break
	
	if not result:
		for button in CANCEL_INPUTS.joy:
			if button in exclude_keys: continue
			if is_joy_button_just_pressed(button, consume):
				result = true
				break
	
	if not result and not extra_keys.is_empty():
		for key in extra_keys:
			if key in exclude_keys: continue
			if is_key_just_pressed(key, consume):
				result = true
				break
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Check if either Enter or Numpad Enter was JUST pressed (no echo)
func is_enter_just_pressed(consume: bool = true) -> bool:
	var cache_key = "enter_just"
	if cache.has(cache_key):
		var val: bool = cache[cache_key]
		if consume and val:
			cache[cache_key] = false
		return val
	
	var result = false
	
	if is_key_just_pressed(KEY_ENTER, consume):
		result = true
			
	if not result and is_key_just_pressed(KEY_KP_ENTER, consume):
		result = true
	
	if result:
		get_viewport().set_input_as_handled()
	
	cache[cache_key] = result
	if consume and result:
		cache[cache_key] = false
		
	return result


## Get the character of any key that was just pressed this frame
func get_any_key_just_pressed(consume: bool = true) -> String:
	if cache.has("any_key_just"):
		var val: String = cache.any_key_just
		if consume and val != "":
			cache.any_key_just = ""
		return val

	var final_result := ""

	for keycode in key_states.keys.keys():
		if keycode == KEY_SHIFT or keycode == KEY_CAPSLOCK or keycode == KEY_CTRL or keycode == KEY_ALT:
			continue
			
		if is_key_just_pressed(keycode, consume):
			var result := _keycode_to_char(keycode)
			if result != "":
				final_result = result
				break

	cache.any_key_just = final_result
	if consume and final_result != "":
		cache.any_key_just = ""
		
	return final_result


func is_direction_just_pressed(direction: String) -> bool:
	match direction:
		"left":
			if key_states.keys.has(KEY_LEFT) and key_states.keys[KEY_LEFT].is_just_pressed():
				return true
				
			if not is_typing_mode and key_states.keys.has(KEY_A) and key_states.keys[KEY_A].is_just_pressed():
				return true
				
			if key_states.joy_buttons.has(JOY_BUTTON_DPAD_LEFT) and key_states.joy_buttons[JOY_BUTTON_DPAD_LEFT].is_just_pressed():
				return true
				
			if stick_left_direction.direction == "left" and stick_left_direction.is_just_pressed():
				return true
				
		"right":
			if key_states.keys.has(KEY_RIGHT) and key_states.keys[KEY_RIGHT].is_just_pressed():
				return true
				
			if not is_typing_mode and key_states.keys.has(KEY_D) and key_states.keys[KEY_D].is_just_pressed():
				return true
				
			if key_states.joy_buttons.has(JOY_BUTTON_DPAD_RIGHT) and key_states.joy_buttons[JOY_BUTTON_DPAD_RIGHT].is_just_pressed():
				return true
				
			if stick_left_direction.direction == "right" and stick_left_direction.is_just_pressed():
				return true
				
		"up":
			if key_states.keys.has(KEY_UP) and key_states.keys[KEY_UP].is_just_pressed():
				return true
				
			if not is_typing_mode and key_states.keys.has(KEY_W) and key_states.keys[KEY_W].is_just_pressed():
				return true
				
			if key_states.joy_buttons.has(JOY_BUTTON_DPAD_UP) and key_states.joy_buttons[JOY_BUTTON_DPAD_UP].is_just_pressed():
				return true
				
			if stick_left_direction.direction == "up" and stick_left_direction.is_just_pressed():
				return true
				
		"down":
			if key_states.keys.has(KEY_DOWN) and key_states.keys[KEY_DOWN].is_just_pressed():
				return true
				
			if not is_typing_mode and key_states.keys.has(KEY_S) and key_states.keys[KEY_S].is_just_pressed():
				return true
				
			if key_states.joy_buttons.has(JOY_BUTTON_DPAD_DOWN) and key_states.joy_buttons[JOY_BUTTON_DPAD_DOWN].is_just_pressed():
				return true
				
			if stick_left_direction.direction == "down" and stick_left_direction.is_just_pressed():
				return true
				
	return false

#endregion



#region Utilities


## threshold used to detect neighboring controls at the given address
func set_focusable_control_threshold(horizontal: int = 30, vertical: int = 30) -> void:
	close_neighbor_script.horizontal_threshold = horizontal
	close_neighbor_script.vertical_threshold = vertical


## Gets the closest focusable control.
func get_closest_focusable_control(current: Control, direction: String, limit_to_parent: bool = false, extra_focusable_controls: Array = [], allow_h_warp: bool = true, allow_v_warp: bool = true) -> Control:
	return close_neighbor_script.get_closest_focusable_control(current, direction, limit_to_parent, extra_focusable_controls, allow_h_warp, allow_v_warp)


func find_closest_in_direction(current: Control, controls: Array, direction: String) -> Control:
	return close_neighbor_script.find_closest_in_direction(current, controls, direction)


func find_closest_control_in_list_by_direction(current: Control, controls: Array, direction: String) -> Control:
	return close_neighbor_script.find_closest_control_in_list_by_direction(current, controls, direction)


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


## Helper to convert keycode to the correct character string
func _keycode_to_char(keycode: int) -> String:
	var is_shift_pressed := Input.is_key_pressed(KEY_SHIFT)
	var should_be_upper := is_caps_lock_on != is_shift_pressed
	
	# 1. Letters A-Z
	if keycode >= KEY_A and keycode <= KEY_Z:
		var char_base := OS.get_keycode_string(keycode)
		return char_base.to_upper() if should_be_upper else char_base.to_lower()

	# 2. Special Case: Ñ
	if keycode == KEY_QUOTELEFT:
		return "Ñ" if should_be_upper else "ñ"

	# 3. Numpad Keys (0-9 and operators)
	if KP_MAP.has(keycode):
		return KP_MAP[keycode]

	# 4. Standard Top Row Numbers & Shift Symbols
	if is_shift_pressed:
		if SHIFT_SYMBOLS_EXTRA.has(keycode):
			return SHIFT_SYMBOLS_EXTRA[keycode]
	
	# 5. Standard Operators and Symbols (non-numpad)
	if keycode == KEY_PLUS: return "+"
	if keycode == KEY_MINUS: return "-"
	if keycode == KEY_SLASH: return "/"
	if keycode == KEY_ASTERISK: return "*"

	var s := OS.get_keycode_string(keycode)
	if s.length() == 1:
		return s

	return ""


# Remove erase letter action (Enter, Space, A button, left click, etc.)
## Removes confirm inputs from state.
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


# Remove erase letter action (BACKSPACE, B Button, Right Mouse Button)
## Removes cancel inputs from state.
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


# Remove erase letter action (BACKSPACE, B Button, Right Mouse Button)
## Removes erase letter inputs from state.
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


## Get the current process frame ID
func _get_current_frame() -> int:
	return Engine.get_process_frames()

#endregion
