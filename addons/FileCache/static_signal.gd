extends Object
class_name StaticSignal

static var instance: StaticSignal
static var signals: Dictionary[String, Signal] = {}
static var static_signal_id: int = 0


static func create_signal(signal_name: String) -> Signal:
	if not instance:
		instance = StaticSignal.new()
	
	if not signals.has(signal_name):
		instance.add_user_signal(signal_name)
		
		var new_signal = Signal(instance, signal_name)
		signals[signal_name] = new_signal
	
	return signals[signal_name]


static func make() -> Signal:
	var signal_name: String = "StaticSignal-%s" % static_signal_id
	static_signal_id += 1
	
	if not instance:
		instance = StaticSignal.new()
	
	instance.add_user_signal(signal_name)
	var new_signal = Signal(instance, signal_name)
	
	return new_signal


static func connect_static_signal(signal_name: String, method: Callable, flags: int = 0) -> bool:
	if not signals.has(signal_name):
		return false
	
	if is_static_signal_connected(signal_name, method):
		return false
	
	var signal_obj: Signal = create_signal(signal_name)
	var result = signal_obj.connect(method, flags)
	
	return result == OK


static func disconnect_static_signal(signal_name: String, method: Callable) -> bool:
	if not signals.has(signal_name):
		return false
	
	var signal_obj = signals[signal_name]
	
	if signal_obj and signal_obj.is_connected(method):
		signal_obj.disconnect(method)
		return true

	return false


static func emit(signal_name: String, parameters: Array = []) -> bool:
	if not signals.has(signal_name):
		return false
	
	var signal_obj = signals[signal_name]
	signal_obj.callv("emit", parameters)
	
	return true


static func exist_static_signal(signal_name: String) -> bool:
	return signals.has(signal_name)


static func get_static_signal(signal_name: String) -> Signal:
	if signals.has(signal_name):
		return signals[signal_name]

	return Signal()


static func is_static_signal_connected(signal_name: String, method: Callable) -> bool:
	if not signals.has(signal_name):
		return false
	
	return signals[signal_name].is_connected(method)


static func get_connections(signal_name: String) -> Array:
	if not signals.has(signal_name):
		return []
	
	return signals[signal_name].get_connections()


static func list_signals() -> Array:
	return signals.keys()


static func get_signals_info() -> Dictionary:
	var info = {}
	for signal_name in signals.keys():
		var connections = get_connections(signal_name)
		info[signal_name] = {
			"connections_count": connections.size(),
			"connections": connections
		}
	return info


static func clear_all_signals() -> void:
	for signal_name in signals.keys():
		var signal_obj = signals[signal_name]
		for connection in signal_obj.get_connections():
			signal_obj.disconnect(connection["callable"])
	
	signals.clear()
	static_signal_id = 0


static func remove_signal(signal_name: String) -> bool:
	if not signals.has(signal_name):
		return false
	
	var signal_obj = signals[signal_name]
	for connection in signal_obj.get_connections():
		signal_obj.disconnect(connection["callable"])
	
	signals.erase(signal_name)
	return true


static func debug_info() -> void:
	print("=== StaticSignal Debug Info ===")
	print("Total signals: %d" % signals.size())
	print("Next ID: %d" % static_signal_id)
	
	for signal_name in signals.keys():
		var connections = get_connections(signal_name)
		print("Signal: %s - Connections: %d" % [signal_name, connections.size()])
		for connection in connections:
			print("  -> %s" % connection)
	print("===============================")
