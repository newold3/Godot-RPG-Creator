@tool
extends Window

var timer: Timer

enum EntryType {AUTOLOAD, OBJECT, VARIABLE, FUNCTION, ARRAY, DICTIONARY, VECTOR2, RECT2, GLOBAL_CLASS, INNER_CLASS}

@onready var code_edit: CodeEdit = %CodeEdit

const CODE_FUNCTION_FUNC = preload("res://addons/CustomControls/Images/code_function_icon.png")
const CODE_FUNCTION_VAR = preload("res://addons/CustomControls/Images/code_function_var.png")
const CODE_FUNCTION_OBJ = preload("res://addons/CustomControls/Images/code_function_obj.png")
const CODE_FUNCTION_ARRAY = preload("res://addons/CustomControls/Images/code_function_obj.png")

# Cache para métodos y propiedades de clases
var class_cache = {}


# Dictionary to track variable references and source chains
var variable_references = {}

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.timeout.connect(_request_code_completion)
	add_child(timer)
	
	close_requested.connect(queue_free)
	code_edit.text_changed.connect(_on_text_changed)
	code_edit.set_code_completion_enabled(true)
	code_edit.set_auto_brace_completion_enabled(true)
	code_edit.set_highlight_matching_braces_enabled(true)
	code_edit.set_auto_indent_enabled(true)
	code_edit.set_code_completion_prefixes(["."])


func _on_text_changed() -> void:
	if not timer.is_stopped():
		timer.stop()
	timer.start()


func _request_code_completion() -> void:
	var cursor_line = code_edit.get_caret_line()
	var cursor_column = code_edit.get_caret_column()
	var current_line = code_edit.get_line(cursor_line)
	
	var current_word = ""
	var i = cursor_column - 1
	while i >= 0:
		var char = current_line[i]
		if char == " ":
			break
		current_word = char + current_word
		i -= 1
	
	var suggestions = get_suggestions(current_word)

	var filter_suggestion = []
	
	for suggestion in suggestions:
		code_edit.add_code_completion_option(CodeEdit.KIND_VARIABLE, suggestion, suggestion, Color.DEEP_PINK, null)
	
	code_edit.update_code_completion_options(true)
	if suggestions.size() > 0:
		code_edit.request_code_completion(true)


func _get_autoloads(filter: String) -> Array:
	var found_instances: Array = []
	var filter_lower = filter.to_lower()
	for property_info in ProjectSettings.get_property_list():
		if property_info.name.begins_with("autoload/"):
			var autoload_name = property_info.name.get_slice("/", 1)
			if filter_lower in autoload_name.to_lower():
				var autoload_node = get_tree().root.get_node(autoload_name)
				if autoload_node:
					found_instances.append({
						"name": autoload_name,
						"instance": autoload_node
					})
	
	return found_instances


func _get_inner_classes(filter: String) -> Array:
	var found_instances: Array = []
	var filter_lower = filter.to_lower()
	for inner_class_name in ClassDB.get_class_list():
		if filter_lower in inner_class_name.to_lower() and filter != inner_class_name:
			found_instances.append(inner_class_name)
	
	return found_instances


func _get_global_classes(filter: String) -> Array:
	var found_instances: Array = []
	var filter_lower = filter.to_lower()
	var global_classes = ProjectSettings.get_global_class_list()
	for c: Dictionary in global_classes:
		if filter_lower in c.class.to_lower() and filter != c.class:
			found_instances.append(c)
	
	return found_instances


func _get_inner_variables(filter: String) -> Array:
	var variables: Array = []
	var filter_lower = filter.to_lower()
	var text = code_edit.text
	# TODO get all variables in text
	
	return variables


func _get_autoload_struct(autoloads: Array, filter: String) -> Dictionary:
	var struct: Dictionary = {"variables": [], "methods": []}
	
	var filter_lower = filter.to_lower()
	for autoload: Dictionary in autoloads:
		var methods = autoload.instance.get_method_list()
		for method in methods:
			if method.name.begins_with("_"): continue
			if (filter.is_empty() or filter_lower in method.name.to_lower()) and method.name != filter:
				struct.methods.append(method)
		var properties = autoload.instance.get_property_list()
		for property in properties:
			if property.name.begins_with("_"): continue
			if (filter.is_empty() or filter_lower in property.name.to_lower()) and property.name != filter and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				struct.variables.append(property)
	
	return struct


func _get_inner_class_struct(classes: Array, filter: String) -> Dictionary:
	var struct: Dictionary = {"variables": [], "methods": []}
	
	var filter_lower = filter.to_lower()
	for c: Dictionary in classes:
		var methods = ClassDB.class_get_method_list(c.name)
		for method in methods:
			if (filter.is_empty() or filter_lower in method.name.to_lower()) and method.name != filter:
				struct.methods.append(method)
		var properties = ClassDB.class_get_property_list(c.name)
		for property in properties:
			if property.name.begins_with("_"): continue
			if (filter.is_empty() or filter_lower in property.name.to_lower()) and property.name != filter and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				struct.variables.append(property)
	
	return struct


func _get_global_class_struct(classes: Array, filter: String) -> Dictionary:
	var struct: Dictionary = {"variables": [], "methods": []}
	
	var filter_lower = filter.to_lower()
	for c: Dictionary in classes:
		var instance = load(c.path)
		var methods = instance.class_get_method_list(c.class)
		for method in methods:
			if (filter.is_empty() or filter_lower in method.name.to_lower()) and method.name != filter:
				struct.methods.append(method)
		var properties = instance.class_get_property_list(c.class)
		for property in properties:
			if property.name.begins_with("_"): continue
			if (filter.is_empty() or filter_lower in property.name.to_lower()) and property.name != filter and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				struct.variables.append(property)
	
	return struct


func _resolve_type(parts: Array,  inner_classes: Array, autoloads: Array, global_classes: Array, inner_variables: Array) -> Variant:
	var resolve_chain = parts.slice(0, parts.size() - 1)
	var filter = parts[-1]
	
	var current_suggestions = []
	
	# Obtain the possible members in the autoloads.
	var struct = _get_autoload_struct(autoloads, filter)
	for v in struct.variables:
		current_suggestions.append({
			"type": EntryType.VARIABLE,
			"struct": v
		})
	for m in struct.methods:
		current_suggestions.append({
			"type": EntryType.FUNCTION,
			"struct": m
		})
	
	# Obtain the possible members in the inner_classes.
	struct = _get_inner_class_struct(inner_classes, filter)
	for v in struct.variables:
		current_suggestions.append({
			"type": EntryType.VARIABLE,
			"struct": v
		})
	for m in struct.methods:
		current_suggestions.append({
			"type": EntryType.FUNCTION,
			"struct": m
		})
	
	# Obtain the possible members in the global_classes.
	struct = _get_global_class_struct(global_classes, filter)
	for v in struct.variables:
		current_suggestions.append({
			"type": EntryType.VARIABLE,
			"struct": v
		})
	for m in struct.methods:
		current_suggestions.append({
			"type": EntryType.FUNCTION,
			"struct": m
		})
	
	
	
	#var property_list: Array = []
	#var method_list: Array = []
	#for obj: Dictionary in autoloads:
		#property_list.append_array(obj.instance.get_property_list())
		#method_list.append_array(obj.instance.get_method_list())
	#print(method_list)
	return null


func get_suggestions(query: String) -> Array:
	
	
	var parts = query.split(".")
	if parts.is_empty():
		return []

	var current_filter = parts[0]
	var inner_classes = _get_inner_classes(current_filter)
	var autoloads = _get_autoloads(current_filter)
	var global_classes = _get_global_classes(current_filter)
	var inner_variables = _get_inner_variables(current_filter)

	var found_instances = []
	
	if parts.size() == 1:
		# Funciona Bien
		found_instances += inner_classes
		found_instances += autoloads.map(func(x): return x.name)
		found_instances += global_classes.map(func(x): return x.class)
		found_instances += inner_variables
	#elif parts.size() == 2:
		## Funciona Bien
		#var autoload_struct = _get_autoload_struct(autoloads, parts[1])
		#var inner_class_struct = _get_inner_class_struct(inner_classes, parts[1])
		#for obj in autoload_struct.methods:
			#found_instances.append({"name": obj.name})
		#for obj in autoload_struct.variables:
			#found_instances.append({"name": obj.name})
	else:
		var instance = _resolve_type(parts, inner_classes, autoloads, global_classes, inner_variables)
		pass

	return found_instances
