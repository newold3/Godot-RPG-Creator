class_name SafeCallMethods
extends RefCounted

var _method_cache = {}
var print_errors := true

func prints_debug(args: Array) -> void:
	if print_errors:
		print(", ".join(args))

func validate_method_call(target_node: Node, method_name: String, args: Array = []) -> bool:
	# Check if the target node is not null
	if target_node == null:
		prints_debug(["Error: Target node is null"])
		return false
	
	# Check if the method exists in the target node
	if not target_node.has_method(method_name):
		prints_debug(["Error: Method '", method_name, "' does not exist in ", target_node.get_class()])
		return false
	
	# Get method information (with node-specific caching)
	var cache_key = str(target_node.get_instance_id()) + "::" + method_name
	var method_info = get_cached_method_info(target_node, method_name, cache_key)
	if method_info == null:
		prints_debug(["Error: Could not get method information for '", method_name, "' from ", target_node.get_class()])
		return false
	
	# Calculate required and optional arguments
	var total_args = method_info.args.size()
	var required_args = count_required_args(method_info)
	var provided_args = args.size()
	
	# Check that we have at least the required arguments
	if provided_args < required_args:
		prints_debug(["Error: Too few arguments for '", method_name, "' in ", target_node.get_class()])
		prints_debug(["  Minimum required: ", required_args, ", Provided: ", provided_args])
		return false
	
	# Check that we don't have more arguments than the total
	if provided_args > total_args:
		prints_debug(["Error: Too many arguments for '", method_name, "' in ", target_node.get_class()])
		prints_debug(["  Maximum allowed: ", total_args, ", Provided: ", provided_args])
		return false
	
	# Check types of provided arguments
	for i in range(provided_args):
		var arg_info = method_info.args[i]
		var expected_type = arg_info.type
		var actual_type = typeof(args[i])
		
		# TYPE_NIL means variant (accepts any type)
		if expected_type == TYPE_NIL:
			continue
		
		# Check type compatibility
		if not is_type_compatible(actual_type, expected_type):
			prints_debug(["Error: Incompatible type in argument ", i, " of '", method_name, "' in ", target_node.get_class()])
			prints_debug(["  Expected: ", type_to_string(expected_type), ", Received: ", type_to_string(actual_type)])
			prints_debug(["  Argument: ", arg_info.name])
			return false
	
	return true

# Function to count required arguments (without default value)
func count_required_args(method_info) -> int:
	var required = 0
	for arg in method_info.args:
		# If the argument has a default value, it's not required
		if arg.has("default_value"):
			break  # Arguments with defaults always go at the end
		required += 1
	return required

# Function to check type compatibility
func is_type_compatible(actual_type: int, expected_type: int) -> bool:
	# Same type
	if actual_type == expected_type:
		return true
	
	# Common implicit conversions in Godot
	match expected_type:
		TYPE_INT:
			# float can be converted to int (with precision loss)
			return actual_type == TYPE_FLOAT
		TYPE_FLOAT:
			# int can be converted to float automatically
			return actual_type == TYPE_INT
		TYPE_STRING:
			# Many types can be converted to string
			return true
		TYPE_OBJECT:
			# Any object inherits from Object
			return actual_type >= TYPE_OBJECT
		_:
			return false

# Helper function to get method information with caching
func get_cached_method_info(target_node: Node, method_name: String, cache_key: String):
	if not _method_cache.has(cache_key):
		var methods = target_node.get_method_list()
		var method_info = null
		
		for method in methods:
			if method.name == method_name:
				method_info = method
				break
		
		_method_cache[cache_key] = method_info
	
	return _method_cache[cache_key]

# Helper function to convert type to string (for debug)
func type_to_string(type_id: int) -> String:
	match type_id:
		TYPE_NIL: return "variant"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_OBJECT: return "Object"
		_: return "type_" + str(type_id)

# Function to show detailed method information (debug)
func debug_method_info(target_node: Node, method_name: String):
	if target_node == null:
		prints_debug(["Error: Target node is null"])
		return
		
	var cache_key = str(target_node.get_instance_id()) + "::" + method_name
	var method_info = get_cached_method_info(target_node, method_name, cache_key)
	if method_info == null:
		prints_debug(["Method not found: ", method_name, " in ", target_node.get_class()])
		return
	
	prints_debug(["=== Method information: ", method_name, " in ", target_node.get_class(), " ==="])
	prints_debug(["Total arguments: ", method_info.args.size()])
	prints_debug(["Required arguments: ", count_required_args(method_info)])
	prints_debug(["Arguments:"])
	
	for i in range(method_info.args.size()):
		var arg = method_info.args[i]
		var required = not arg.has("default_value")
		var default_val = arg.get("default_value", "N/A")
		
		prints_debug(["  [", i, "] ", arg.name, " (", type_to_string(arg.type), ")"])
		prints_debug(["      Required: ", required])
		if not required:
			prints_debug(["      Default value: ", default_val])

# Convenience function that validates and executes if correct
func safe_call(target_node: Node, method_name: String, args: Array = []):
	if validate_method_call(target_node, method_name, args):
		return target_node.callv(method_name, args)
	else:
		prints_debug(["Call cancelled for '", method_name, "' in ", target_node.get_class(), " due to validation errors"])
		return null

# Function to clear cache for a specific node (useful if the node changes)
func clear_node_cache(target_node: Node):
	var node_id = str(target_node.get_instance_id())
	var keys_to_remove = []
	
	for key in _method_cache.keys():
		if key.begins_with(node_id + "::"):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_method_cache.erase(key)

# Function to clear all cache
func clear_all_cache():
	_method_cache.clear()
