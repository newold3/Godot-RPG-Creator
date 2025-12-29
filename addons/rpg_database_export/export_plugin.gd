@tool
extends EditorExportPlugin

var referenced_files = []


func _export_begin(features, is_debug, path, flags):
	var database = RPGSYSTEM.database
	
	# Get Effekseer files used in animations
	var used_effekseer = get_used_effekseer_from_animations(database)
	
	# Recursively scan the entire database
	scan_resource_deep(database, referenced_files, used_effekseer)


func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	if path.get_extension() == "efkefc" and not path in referenced_files:
		skip()


func get_used_effekseer_from_animations(database) -> Array:
	var used_effects = []

	var animations = database.animations
	for animation: RPGAnimation in animations:
		if animation:
			var filename = animation.filename
			if filename != "" and filename.get_extension().to_lower() == "efkefc":
				if not used_effects.has(filename):
					used_effects.append(filename)
					# Add all subresources used by this Effekseer file
					add_effekseer_subresources(filename, used_effects)
	
	return used_effects

func add_effekseer_subresources(efkefc_path: String, used_effects: Array):
	if ResourceLoader.exists(efkefc_path):
		var effect = load(efkefc_path)
		if effect != null and effect.has_method("get") and effect.get("subresources"):
			var subresources = effect.get("subresources")
			var base_dir = efkefc_path.get_base_dir()
			
			for relative_path in subresources:
				if relative_path is String and relative_path != "":
					# Convert relative path to absolute path
					var absolute_path = base_dir + "/" + relative_path
					# Clean up the path (remove double slashes, etc.)
					absolute_path = absolute_path.simplify_path()
					
					if ResourceLoader.exists(absolute_path) and not used_effects.has(absolute_path):
						used_effects.append(absolute_path)

func is_effekseer_resource(file_path: String) -> bool:
	# Check if this file could be an Effekseer dependency
	var ext = file_path.get_extension().to_lower()
	return ext in ["png", "jpg", "jpeg", "tga", "dds", "wav", "ogg", "mp3"] and file_path.contains("/effects/")

func scan_resource_deep(resource: Resource, referenced_files: Array, used_effekseer: Array, visited: Array = []):
	# Prevent infinite loops
	if resource in visited:
		return
	visited.append(resource)
	
	var property_list = resource.get_property_list()
	
	for property in property_list:
		var property_value = resource.get(property.name)
		
		if property_value is String and property_value != "":
			if ResourceLoader.exists(property_value):
				var ext = property_value.get_extension().to_lower()
				
				# For Effekseer files and their dependencies, only include if in used list
				if ext == "efkefc" or is_effekseer_resource(property_value):
					if used_effekseer.has(property_value) and not referenced_files.has(property_value):
						referenced_files.append(property_value)
				else:
					# All other resources (images, audio, etc. not related to Effekseer)
					if not referenced_files.has(property_value):
						referenced_files.append(property_value)
		
		elif property_value is Resource and property_value != null:
			scan_resource_deep(property_value, referenced_files, used_effekseer, visited)
		
		elif property_value is Array:
			scan_array_deep(property_value, referenced_files, used_effekseer, visited)
		
		elif property_value is Dictionary:
			scan_dictionary_deep(property_value, referenced_files, used_effekseer, visited)

func scan_array_deep(array: Array, referenced_files: Array, used_effekseer: Array, visited: Array):
	for item in array:
		if item is String and item != "":
			if ResourceLoader.exists(item):
				var ext = item.get_extension().to_lower()
				
				if ext == "efkefc" or is_effekseer_resource(item):
					if used_effekseer.has(item) and not referenced_files.has(item):
						referenced_files.append(item)
				else:
					if not referenced_files.has(item):
						referenced_files.append(item)
		
		elif item is Resource and item != null:
			scan_resource_deep(item, referenced_files, used_effekseer, visited)
		
		elif item is Array:
			scan_array_deep(item, referenced_files, used_effekseer, visited)
		
		elif item is Dictionary:
			scan_dictionary_deep(item, referenced_files, used_effekseer, visited)

func scan_dictionary_deep(dict: Dictionary, referenced_files: Array, used_effekseer: Array, visited: Array):
	for key in dict.keys():
		var value = dict[key]
		
		if key is String and key != "":
			if ResourceLoader.exists(key):
				var ext = key.get_extension().to_lower()
				if ext == "efkefc" or is_effekseer_resource(key):
					if used_effekseer.has(key) and not referenced_files.has(key):
						referenced_files.append(key)
				else:
					if not referenced_files.has(key):
						referenced_files.append(key)
		
		if value is String and value != "":
			if ResourceLoader.exists(value):
				var ext = value.get_extension().to_lower()
				if ext == "efkefc" or is_effekseer_resource(value):
					if used_effekseer.has(value) and not referenced_files.has(value):
						referenced_files.append(value)
				else:
					if not referenced_files.has(value):
						referenced_files.append(value)
		
		elif value is Resource and value != null:
			scan_resource_deep(value, referenced_files, used_effekseer, visited)
		
		elif value is Array:
			scan_array_deep(value, referenced_files, used_effekseer, visited)
		
		elif value is Dictionary:
			scan_dictionary_deep(value, referenced_files, used_effekseer, visited)
