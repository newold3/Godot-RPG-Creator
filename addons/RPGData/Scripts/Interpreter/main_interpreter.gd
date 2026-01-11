class_name MainInterpreter
extends Node


# Interpreter: Represents a smaller interpreter with its own set of commands
class Interpreter:
	var id: String = ""
	var main_interpreter: MainInterpreter
	var obj: Variant  # Target associated with this interpreter
	var commands: Array[RPGEventCommand] = []  # List of commands for this interpreter to process
	var command_index: int = 0  # Index of the current command being processed
	var busy: bool = false  # Flag indicating whether the interpreter is currently busy processing a command
	var completed: bool = false  # Flag indicating whether all commands have been processed
	var parallel: bool = false # Flag indicating that this interpreter is running in parallel
	var paused: bool = false # Flag indicating that this interpreter is paused by a wait command
	var loop: Dictionary = {"start_index": -1, "end_index": -1} # Dictionary to store loop data for the interpreter
	var is_updating: bool = false
	var is_common_event: bool = false
	
	signal all_commands_processed(interpreter: Interpreter)  # Signal emitted when all commands have been processed
	signal force_stop(interpreter: Interpreter) # Signal emitted when command "Exit Event Processing" is executed
	signal force_delete(interpreter: Interpreter) # Signal emitted when command "Erase Event" is executed


	# Initialize the Interpreter with a node and a list of commands
	func _init(_obj: Variant, _commands: Array[RPGEventCommand], is_parallel: bool = false, main: MainInterpreter = null, _id: String = ""):
		id = _id
		obj = _obj  # Set the node associated with this interpreter
		commands = _commands  # Set the list of commands to be processed
		parallel = is_parallel  # Set whether this is a parallel interpreter
		
		# Connect the signal to mark the interpreter as completed when all commands are processed
		all_commands_processed.connect(
			func(_interpreter: Interpreter):
				completed = true
		)
		main_interpreter = main


	# Process a single command through the main interpreter
	func _process_command() -> bool:
		if busy or completed or commands.is_empty(): 
			return false
		
		# Saltar comandos desactivados
		_skip_disabled_commands()
		
		# Re-chequeo tras saltar comandos
		if command_index >= commands.size():
			next()
			return true
		
		while main_interpreter.showing_any_menu:
			await main_interpreter.get_tree().process_frame
		
		busy = true  # Mark as busy
		
		var success = await main_interpreter._process_other_interpreter_command(self)  # Try processing the command
		
		if not success and main_interpreter.prints_debugs:
			print("[Interpreter %s] Skip command %s for obj %s" % [id, commands[command_index], obj])
		
		next()  # Move to the next command
		busy = false  # Mark as not busy
		return success
	
	
	# Salta comandos desactivados asegurándose de no procesar hijos de comandos desactivados
	func _skip_disabled_commands() -> void:
		var start_idx = command_index
		while command_index < commands.size():
			var current_command = commands[command_index]
			
			if not current_command.ignore_command:
				return
			
			var current_indent = current_command.indent
			var skip_to_index = command_index + 1
			
			while skip_to_index < commands.size():
				var next_command = commands[skip_to_index]
				if next_command.indent <= current_indent:
					break
				skip_to_index += 1
			
			command_index = skip_to_index


	# Move to the next command in the list
	func next() -> void:
		command_index += 1  # Increment the command index
		
		# Si el comando index está fuera de rango
		if command_index >= commands.size():
			if parallel:
				command_index = 0 
			else:
				end()
		else:
			_skip_disabled_commands()
	
	
	# Set the command index to a specific position
	func go_to(index: int) -> void:
		if index >= 0 and commands.size() > index:
			command_index = index
		elif main_interpreter.prints_debugs:
			print("Invalid command index: ", index)
	
	
	# Return the command index to a specific position
	func get_command(index: int) -> RPGEventCommand:
		if index >= 0 and commands.size() > index:
			return commands[index]
		return null
	
	
	func is_complete() -> bool:
		return completed
	
	
	func is_parallel() -> bool:
		return parallel
	
	
	func is_paused() -> bool:
		return paused
	
	
	func is_valid() -> bool:
		if is_updating:
			is_updating = false
			return true
		return is_instance_valid(obj) if obj != null else true


	func end() -> void:
		command_index = commands.size()
		completed = true  # Mark as completed
		busy = false  # Mark as not busy
		all_commands_processed.emit(self)
	
	func _to_string() -> String:
		return "<Interpreter %s: %s, complete=%s>" % [get_instance_id(), id, completed]


# MainInterpreter properties
var busy: bool = false : set = _set_busy  # Flag indicating if the main interpreter is busy
var busy2: bool = false  # Flag indicating if processing parallel interpreters
var busy3: bool = false  # Flag indicating if processing automatic interpreters group
var showing_message: bool = false  # Flag indicating if a message is being shown
var showing_any_menu: bool = false  # Flag indicating if any menu/shop is being shown
var current_command: RPGEventCommand  # The current command being processed
var interpreters: Array[Interpreter] = []  # List of registered interpreters
var current_interpreter: Interpreter  # The current interpreter whose command is being processed
var current_automatic_interpreter: Interpreter  # The current automatic interpreter whose command is being processed
var selected_choice_id: int = 0 # Variable used to retain the option selected in a choice dialog.
var code_eval: CodeEval = preload("res://Scripts/code_eval.gd").new() # call code_eval.execute(code) to eval block code
var prints_debugs: bool = false  # For debugging purposes only
var transfer_in_progress: bool = false # block input when transfer player

var command_handler_scripts: Array = []

var current_automatic_events: Array[Dictionary] = []

var safe_call_methods = SafeCallMethods.new()

var _pending_automatic_events: Array
var _pending_automatic_events_ids: Dictionary
var _current_interpreters: Array

const HANDLERS_PATH = "res://addons/RPGData/Scripts/Interpreter/ExtendedFunctions/"


# Signal emitted if a command was not processed because the corresponding
# function does not exist in the interpreter
# Useful for creating functions in other scripts connected to this signal to handle custom commands.
signal unprocessed_command(current_interpreter: Interpreter, current_command: RPGEventCommand)

signal notes_found(notes: String)  # Signal emitted when a commentary command is found

signal processed_command(command: RPGEventCommand, interpreter_last_scene_created: Node)

# Set up the process loop when the node is ready
func _ready() -> void:
	set_process(true)  # Enable processing every physic frame
	_load_command_handlers()


func _set_busy(value: bool) -> void:
	if not value and current_automatic_events.is_empty():
		busy = false
	elif value:
		busy = true


# Dynamically loads all command handlers
func _load_command_handlers() -> void:
	var path = HANDLERS_PATH
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if (file_name.ends_with(".gd") or file_name.ends_with(".gdc")) and not file_name.begins_with("."):
				var file = file_name.get_basename() + ".gd"
				var script_path = path + file
				var script = load(script_path)
				if script:
					var handler = script.new()
					handler.interpreter = self  # Pasamos referencia al intérprete principal
					command_handler_scripts.append(handler)
					if prints_debugs:
						print("Loaded command handler: ", file_name)
			file_name = dir.get_next()


# Main process loop, called every frame
func _process(delta: float) -> void:
	# If busy with a auto run interpreter or parallel interpreter, don't process.
	if is_busy() or interpreters.is_empty():
		return
	
	await _process_sequential_interpreters()
	await _process_parallel_interpreters()


func _process_sequential_interpreters() -> void:
	# Process auto run interpreters first one at a time
	for interpreter in interpreters:
		if not interpreter.is_parallel():
			busy = true
			# Process all commands from this auto run interpreter
			while not interpreter.is_complete() and not interpreter.busy:
				await interpreter._process_command()
				processed_command.emit(current_command, GameManager.interpreter_last_scene_created)
			busy = false


func _process_parallel_interpreters() -> void:
	# Process parallel interpreters
	busy2 = true
	# Process one command from each parallel interpreter
	for interpreter in interpreters:
		if interpreter.is_parallel() and not interpreter.is_paused() and not interpreter.is_complete():
			await interpreter._process_command()
			processed_command.emit(current_command, GameManager.interpreter_last_scene_created)
	busy2 = false


# Process a command from an interpreter
func _process_other_interpreter_command(interpreter: Interpreter) -> bool:
	if interpreter.command_index >= interpreter.commands.size():
		return false
		
	current_command = interpreter.commands[interpreter.command_index]
	current_interpreter = interpreter
	await _process_command()
	processed_command.emit(current_command, GameManager.interpreter_last_scene_created)
	return true


# Callback for when an interpreter has finished processing all its commands
func _on_interpreter_done(interpreter: Interpreter) -> void:
	if prints_debugs:
		print("Interpreter finished: ", interpreter)
	interpreters.erase(interpreter)


# Callback when an interpreter has been forced to stop
func _on_interpreter_stopped(interpreter: Interpreter) -> void:
	if interpreter and interpreter.obj:
		for a: Dictionary in current_automatic_events:
			if a.obj == interpreter.obj:
				if prints_debugs:
					print("Interpreter forced to stop: ", interpreter)
				current_automatic_events.erase(a)
				break


# Callback when an interpreter has been processed a "Erase Event" Command
func _on_interpreter_force_deleted(interpreter: Interpreter) -> void:
	pass


func get_parent_and_end_for(code: int) -> Dictionary:
	var result = {
		"begin_code": -1,
		"end_code": -1,
	}
	match code:
		4, 5, 6:
			result.begin_code = 4
			result.end_code = 7
		21, 22:
			result.begin_code = 21
			result.end_code = 23
		24:
			result.begin_code = 24
			result.end_code = 25
		500, 501, 502, 503:
			result.begin_code = 500
			result.end_code = 504
	
	return result


func find_next_command(interpreter: Interpreter) -> Dictionary:
	var index = interpreter.command_index
	var command: RPGEventCommand = interpreter.get_command(index)
	
	if command:
		var parent_and_end_data = get_parent_and_end_for(command.code)
		if parent_and_end_data.end_code != -1:
			var indent = command.indent
			for i in range(index + 1, interpreter.commands.size(), 1):
				var other_command: RPGEventCommand = interpreter.get_command(i)
				if other_command.indent == indent and other_command.code == parent_and_end_data.end_code:
					parent_and_end_data.jump_to_index = i
					
					break
		return parent_and_end_data
	
	return {}


# Process a command
func _process_command() -> void:
	if not current_command or not current_interpreter or current_interpreter.is_complete():
		return
	
	while showing_any_menu:
		await get_tree().process_frame
	
	if prints_debugs:
		print("Processing command %s from interpreter %s" % [current_command, current_interpreter.get_instance_id()])
	
	await _process_function(current_command.code)
	
	current_command = null
	current_interpreter = null


func _process_function(code_id: int, emit_signal_on_fail: bool = true) -> void:
	var func_name = "_command_" + str(code_id).pad_zeros(4)

	# First we try to process the command in the main interpreter
	if has_method(func_name):
		await call(func_name)
	else:
		# If it is not in the main interpreter, we look for it in the handlers
		var command_handled = false
		for handler in command_handler_scripts:
			if handler.has_method(func_name):
				await handler.call(func_name)
				command_handled = true
				break
		
		# If no handler processes the command, we either process nested commands or issue signal
		if not command_handled:
			var command_data = find_next_command(current_interpreter)

			if command_data.has("jump_to_index"):
				current_interpreter.go_to(command_data.jump_to_index)
			else:
				if prints_debugs:
					print("Function for code {%s} not found (%s)." % [current_command.code, func_name])
				if emit_signal_on_fail:
					unprocessed_command.emit(current_interpreter, current_command)


func process_specific_command(parameter_id: int, command_parameters: Dictionary) -> void:
	var _old_current_interpreter = current_interpreter
	var _old_current_command = current_command
	var interpreter_id = "_temp_interpreter"
	current_command = RPGEventCommand.new(parameter_id, -1, command_parameters)
	var commands: Array[RPGEventCommand] = [current_command]
	await start_event(null, commands, false,  interpreter_id)
	#register_interpreter(null, commands, false, interpreter_id)
	#current_interpreter = Interpreter.new(null, [current_command], false, self, interpreter_id)
	#print([current_command, current_interpreter])
	#_process_function(parameter_id, false)
	#current_interpreter = _old_current_interpreter
	#current_command = _old_current_command


# Clear all commands and interpreters
func clear() -> void:
	interpreters.clear()
	current_command = null
	current_interpreter = null
	busy = false
	busy2 = false
	showing_message = false


# Ends and hides a message in process
func end_message() -> void:
	if not current_interpreter:
		GameManager.message.is_new_dialog = false
		GameManager.message.is_multi_dialog = false
		if GameManager.message_container.visible:
			showing_message = false
			GameManager.message.show_close_animation()
			await GameManager.message.all_messages_finished
			GameManager.message.reset()
			GameManager.message.clear_text()
		return
	
	var index = current_interpreter.command_index + 1
	var next_command = current_interpreter.get_command(index)
	showing_message = true
	
	while next_command and (next_command.code == 0 or next_command.code in CustomEditItemList.SUB_CODES):
		index += 1
		next_command = current_interpreter.get_command(index)
	
	if next_command and next_command.code == 2:
		if next_command.parameters.get("is_floating_dialog", false):
			GameManager.message_container.visible = false
			showing_message = false
			return

	if GameManager.message.paragraphs.size() == 0 and (not next_command or not [2, 4, 8, 95].has(next_command.code)):
		GameManager.message.is_new_dialog = false
		GameManager.message.is_multi_dialog = false
		if GameManager.message_container.visible:
			showing_message = false
			current_interpreter.busy = false
			GameManager.message.show_close_animation()
			await GameManager.message.all_messages_finished
			GameManager.message.reset()
			GameManager.message.clear_text()
	if not GameManager.message.dialog_is_paused:
		GameManager.message.is_multi_dialog = false

	if (not next_command or not [2, 4, 8, 95].has(next_command.code)):
		GameManager.message_container.visible = false
		showing_message = false


# Check if the main interpreter or any auto run interpreter is busy
func is_busy() -> bool:
	# Only consider auto run interpreters for busy state
	return GameManager.busy or busy or busy2 or busy3 or showing_message or showing_any_menu or transfer_in_progress or interpreters.any(
		func(interpreter: Interpreter):
			return not interpreter.is_parallel() and interpreter.busy
	)


## Returns the interpreter object associated with the given ID, or null if not found.
func get_interpreter_with_id(interpreter_id: String) -> Interpreter:
	if interpreter_id.is_empty():
		return null
	
	# 1. Search in sequential/temporary interpreters
	for interpreter: Interpreter in _current_interpreters:
		if interpreter.id == interpreter_id and not interpreter.is_complete():
			return interpreter
	
	# 2. Search in registered/parallel interpreters
	for interpreter: Interpreter in interpreters:
		if interpreter.id == interpreter_id and not interpreter.is_complete():
			return interpreter
			
	# 3. Check current automatic running event
	if current_automatic_interpreter and current_automatic_interpreter.id == interpreter_id:
		if not current_automatic_interpreter.is_complete():
			return current_automatic_interpreter
	
	return null


## Checks if an event with a specific ID is currently running.
func is_event_running(interpreter_id: String = "") -> bool:
	return get_interpreter_with_id(interpreter_id) != null


# Register a new interpreter with the main interpreter
func register_interpreter(obj: Variant, commands: Array[RPGEventCommand], is_parallel: bool = false, interpreter_id: String = "") -> void:
	remove_interpreter_by_id(interpreter_id)
	var new_interpreter = Interpreter.new(obj, commands, is_parallel, self, interpreter_id)
	new_interpreter.all_commands_processed.connect(_on_interpreter_done)
	interpreters.append(new_interpreter)
	if prints_debugs:
		print("Registered new %s Interpreter %s with obj %s" % 
			["parallel" if is_parallel else "auto run", new_interpreter.get_instance_id(), obj])


func remove_interpreter(obj: Variant) -> void:
	if not obj: return
	
	for interpreter: Interpreter in interpreters:
		if interpreter.obj == obj:
			interpreter.completed = true
			interpreters.erase(interpreter)
			break
	
	for other_obj: Dictionary in current_automatic_events:
		if other_obj.obj == obj:
			if current_automatic_interpreter and current_automatic_interpreter.obj == obj:
				current_automatic_interpreter.completed = true
			current_automatic_events.erase(other_obj)
			break


func remove_interpreter_by_id(id: String) -> void:
	if id.is_empty(): return
	
	for i in range(interpreters.size()):
		var inter = interpreters[i]
		if inter.id == id:
			inter.end()
	
	for i in range(_current_interpreters.size()):
		var inter = _current_interpreters[i]
		if inter.id == id:
			inter.end()
	
	# 3. Escaneo del automático actual
	if current_automatic_interpreter:
		if current_automatic_interpreter.id == id:
			current_automatic_interpreter.end()
			_on_interpreter_stopped(current_automatic_interpreter)


# Starts a series of events sequentially.
# objs = {obj: Node, commands: Array[RPGEventCommand]}
func auto_start_automatic_events(objs: Array[Dictionary]) -> void:
	for obj_data in objs:
		if obj_data.id not in _pending_automatic_events_ids:
			_pending_automatic_events_ids[obj_data.id] = true
			_pending_automatic_events.append(obj_data)
	
	if busy3:
		return
	
	await _process_automatic_events_queue()


func _process_automatic_events_queue() -> void:
	busy3 = true
	var processed_ids: Array = []
	
	while not _pending_automatic_events.is_empty():
		var element = _pending_automatic_events.pop_front()
		
		busy = true
		if element.obj and "busy" in element.obj:
			element.obj.busy = true
		
		await start_event(element.obj, element.commands, true, element.id)
		
		if element.obj and "busy" in element.obj:
			element.obj.busy = false
		
		processed_ids.append(element.id)
	
	for id in processed_ids:
		_pending_automatic_events_ids.erase(id)
	
	busy = false
	busy3 = false


# Start processing an event using a new temporary interpreter
func start_event(obj: Node, commands: Array[RPGEventCommand], automatic_is_enabled: bool = false, interpreter_id: String = "") -> void:
	remove_interpreter_by_id(interpreter_id)
	
	if not automatic_is_enabled: 
		busy = true
	
	var interpreter = Interpreter.new(obj, commands, false, self, interpreter_id)
	
	if automatic_is_enabled:
		interpreter.force_stop.connect(_on_interpreter_stopped)
		current_automatic_interpreter = interpreter
	
	interpreter.force_delete.connect(_on_interpreter_force_deleted)
	var is_nullable = interpreter.obj == null
	
	_current_interpreters.append(interpreter)
	await get_tree().process_frame
	
	var loop_count = 0
	while not interpreter.is_complete():
		loop_count += 1
		if not is_nullable and not interpreter.is_valid():
			break
		
		var current_idx = interpreter.command_index
		
		await interpreter._process_command()
		
		processed_command.emit(current_command, GameManager.interpreter_last_scene_created)
	
	if _current_interpreters.has(interpreter):
		_current_interpreters.erase(interpreter)
	
	if current_automatic_interpreter == interpreter:
		current_automatic_interpreter = null
		
	if not automatic_is_enabled: 
		busy = false


#region Function used when load game to restore images and scenes
func create_load_interpreter(interpreter_id: String) -> void:
	var interpreter = Interpreter.new(null, [], false, self, interpreter_id)
	_current_interpreters.append(interpreter)

func add_load_command(interpreter_id: String, code: int, params: Dictionary) -> void:
	if _current_interpreters.is_empty(): return 
	var interpreter = _current_interpreters[-1]
	if interpreter.id == interpreter_id:
		var cmd = RPGEventCommand.new(code, -1, params)
		interpreter.commands.append(cmd)

func execute_load_interpreter(interpreter_id: String) -> void:
	if _current_interpreters.is_empty(): return 
	var interpreter = _current_interpreters[-1]
	if interpreter.id != interpreter_id: return
	
	interpreter.force_delete.connect(_on_interpreter_force_deleted)
	var is_nullable = interpreter.obj == null
	
	if not interpreter.commands.is_empty():
		while not interpreter.is_complete():
			if not is_nullable and not is_instance_valid(interpreter.obj):
				break
				
			await interpreter._process_command()
			processed_command.emit(current_command, GameManager.interpreter_last_scene_created)

	_current_interpreters.erase(interpreter)
#endregion


# Start processing a common event using a new temporary interpreter
func start_common_event(obj: Node, commands: Array[RPGEventCommand]) -> void:
	remove_interpreter(obj)
	var interpreter = Interpreter.new(obj, commands, false, self)
	interpreter.is_common_event = true
	while not interpreter.is_complete():
		await interpreter._process_command()
		processed_command.emit(current_command, GameManager.interpreter_last_scene_created)
