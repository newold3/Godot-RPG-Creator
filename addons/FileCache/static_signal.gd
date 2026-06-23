extends Object
class_name StaticSignal

static var signals: Dictionary[String, Array] = {}
static var static_signal_id: int = 0

## Helper class to bridge static signals with Godot's native await system.
class AwaitHelper extends RefCounted:
	signal finished
	var _signal_name: String
	var _callback: Callable


	## Initializes the helper and connects the temporary callback.
	func _init(signal_name: String) -> void:
		_signal_name = signal_name
		_callback = Callable(self, "_on_triggered")
		StaticSignal.connect_static_signal(_signal_name, _callback)


	## Triggered when the static signal is emitted. Safely absorbs up to 5 parameters to avoid callv errors.
	func _on_triggered(p1 = null, p2 = null, p3 = null, p4 = null, p5 = null) -> void:
		finished.emit()
		StaticSignal.disconnect_static_signal(_signal_name, _callback)


#region Signal Management Block
## Registers a new signal name and initializes its callable array if it doesn't exist.
static func create_signal(signal_name: String) -> void:
	if not signals.has(signal_name):
		signals[signal_name] = []


## Creates a unique auto-generated signal name, initializes it, and returns the name.
static func make() -> String:
	var signal_name: String = "StaticSignal-%s" % static_signal_id
	static_signal_id += 1
	
	if not signals.has(signal_name):
		signals[signal_name] = []
	
	return signal_name


## Stores a callable in the array associated with the signal name.
static func connect_static_signal(signal_name: String, method: Callable, _flags: int = 0) -> bool:
	if not signals.has(signal_name):
		signals[signal_name] = []
	
	if not signals[signal_name].has(method):
		signals[signal_name].append(method)
		return true
	
	return false


## Removes a specific callable from the array associated with the signal name.
static func disconnect_static_signal(signal_name: String, method: Callable) -> bool:
	if signals.has(signal_name) and signals[signal_name].has(method):
		signals[signal_name].erase(method)
		return true
	
	return false


## Executes all valid callables associated with the signal name with debug prints.
static func emit(signal_name: String, parameters: Array = []) -> bool:
	if not signals.has(signal_name):
		return false
	
	var callables_to_remove: Array = []
	
	for method in signals[signal_name]:
		if method.is_valid():
			method.callv(parameters)
		else:
			callables_to_remove.append(method)
			
	for invalid_method in callables_to_remove:
		signals[signal_name].erase(invalid_method)
	
	return true


## Checks if a signal name has been registered in the dictionary.
static func exist_static_signal(signal_name: String) -> bool:
	return signals.has(signal_name)


## Checks if a specific callable is currently stored under the given signal name.
static func is_static_signal_connected(signal_name: String, method: Callable) -> bool:
	if signals.has(signal_name):
		return signals[signal_name].has(method)
	
	return false


## Retrieves the array of callables associated with a given signal name.
static func get_static_signal(signal_name: String) -> Array:
	if signals.has(signal_name):
		return signals[signal_name].duplicate()
	
	return []


## Retrieves a duplicate array of all callables connected to the specified signal.
static func get_connections(signal_name: String) -> Array:
	if signals.has(signal_name):
		return signals[signal_name].duplicate()
	
	return []


## Returns an array containing all currently registered signal names.
static func list_signals() -> Array:
	return signals.keys()


## Returns a detailed dictionary with connection counts and callables for all signals.
static func get_signals_info() -> Dictionary:
	var info: Dictionary = {}
	
	for signal_name in signals.keys():
		info[signal_name] = {
			"connections_count": signals[signal_name].size(),
			"connections": signals[signal_name].duplicate()
		}
		
	return info


## Clears all registered signals and resets the auto-generated ID counter.
static func clear_all_signals() -> void:
	signals.clear()
	static_signal_id = 0


## Completely deletes a signal name and its associated array of callables.
static func remove_signal(signal_name: String) -> bool:
	if signals.has(signal_name):
		signals.erase(signal_name)
		return true
	
	return false


static func wait_for(signal_name: String) -> void:
	var helper: AwaitHelper = AwaitHelper.new(signal_name)
	await helper.finished


## Prints a complete overview of all registered signals and their connected callables.
static func debug_info() -> void:
	print("=== StaticSignal Debug Info ===")
	print("Total signals: %d" % signals.size())
	print("Next ID: %d" % static_signal_id)
	
	for signal_name in signals.keys():
		print("Signal: %s - Connections: %d" % [signal_name, signals[signal_name].size()])
		for method in signals[signal_name]:
			print("  -> %s" % method)
			
	print("===============================")
#endregion
