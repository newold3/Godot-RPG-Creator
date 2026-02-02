class_name DependencyScanner
extends RefCounted


## Scans a list of resource paths and returns all unique dependencies recursively.
## Converts UID paths back to RES paths to ensure valid file export.
static func get_all_dependencies(root_paths: Array) -> PackedStringArray:
	var to_scan: Array = root_paths.duplicate()
	var found_paths: Dictionary = {}

	for path in root_paths:
		found_paths[path] = true

	while to_scan.size() > 0:
		var current_path = to_scan.pop_back()
		
		# Get dependencies (some might be uid://, some res://)
		var deps = ResourceLoader.get_dependencies(current_path)

		for dep in deps:
			# 1. Clean internal resource separator (::)
			var clean_path = dep.split("::")[0]
			
			# 2. CONVERT UID TO RES://
			if clean_path.begins_with("uid://"):
				var uid_val = ResourceUID.text_to_id(clean_path)
				# Only convert if the ID is valid in the current registry
				if ResourceUID.has_id(uid_val):
					clean_path = ResourceUID.get_id_path(uid_val)
			
			# 3. Check validity and uniqueness
			if not found_paths.has(clean_path) and FileAccess.file_exists(clean_path):
				found_paths[clean_path] = true
				to_scan.append(clean_path)

	return PackedStringArray(found_paths.keys())
