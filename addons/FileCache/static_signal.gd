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
static func connect_static_signal(signal_name: String, method: Callable, flags: int = 0) -> bool:
	if not signals.has(signal_name):
		signals[signal_name] = []
	
	for conn in signals[signal_name]:
		if conn.callable == method:
			return false
			
	signals[signal_name].append({"callable": method, "flags": flags})
	return true


## Removes a specific callable from the array associated with the signal name.
static func disconnect_static_signal(signal_name: String, method: Callable) -> bool:
	if signals.has(signal_name):
		for i in range(signals[signal_name].size()):
			if signals[signal_name][i].callable == method:
				signals[signal_name].remove_at(i)
				return true
	return false


## Executes all valid callables associated with the signal name with debug prints.
static func emit(signal_name: String, parameters: Array = []) -> bool:
	if not signals.has(signal_name):
		return false
	
	var connections = signals[signal_name].duplicate()
	var oneshots_to_remove: Array[Callable] = []
	
	for conn in connections:
		var method: Callable = conn.callable
		var flags: int = conn.flags
		
		if method.is_valid():
			if flags & CONNECT_DEFERRED:
				method.callv.call_deferred(parameters)
			else:
				method.callv(parameters)
				
			if flags & CONNECT_ONE_SHOT:
				oneshots_to_remove.append(method)
		else:
			oneshots_to_remove.append(method)
			
	for method in oneshots_to_remove:
		disconnect_static_signal(signal_name, method)
	
	return true


## Checks if a signal name has been registered in the dictionary.
static func exist_static_signal(signal_name: String) -> bool:
	return signals.has(signal_name)


## Checks if a specific callable is currently stored under the given signal name.
static func is_static_signal_connected(signal_name: String, method: Callable) -> bool:
	if signals.has(signal_name):
		for conn in signals[signal_name]:
			if conn.callable == method:
				return true
	return false


## Retrieves the array of callables associated with a given signal name.
static func get_static_signal(signal_name: String) -> Array:
	if signals.has(signal_name):
		var list = []
		for conn in signals[signal_name]:
			list.append(conn.callable)
		return list
	
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
		for conn in signals[signal_name]:
			print("  -> %s (Flags: %d)" % [conn.callable, conn.flags])
			
	print("===============================")
#endregion
