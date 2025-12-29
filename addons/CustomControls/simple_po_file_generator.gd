class_name SimplePoFileGenerator
extends Node


# Changed to store both translation and origin
var po_entries = {}  # { msgid: { "msgstr": String, "source": String } }


# Ex: setup(RPGSYSTEM.database, "RPGDatabase", "res://translations/file.po"
func setup(resource: Resource, source: String, file_path: String) -> void:
	extract_texts_from_resource(resource, source)
	generate_po_file(file_path)


func extract_texts_from_resource(resource: Resource, source_path: String = "") -> void:
	# Process all resource properties
	for property in resource.get_property_list():
		var property_name = property["name"]
		var value = resource.get(property_name)
		
		# Ignore system properties
		if property_name.begins_with("_"):
			continue
			
		# Create the source path for this property
		var current_source = source_path + ("." if source_path else "") + property_name
		process_value(value, current_source)


func process_value(value, source: String) -> void:
	match typeof(value):
		TYPE_STRING:
			# Adding strings to the PO file
			if value.strip_edges() != "":
				add_po_entry(value, source)
				
		TYPE_ARRAY:
			# Process arrays recursively
			for i in range(value.size()):
				process_value(value[i], source + "[" + str(i) + "]")
				
		TYPE_DICTIONARY:
			# Process only dictionary values
			for key in value:
				process_value(value[key], source + "[" + str(key) + "]")
				
		TYPE_OBJECT:
			# If it is a resource, process it recursively
			if value is Resource:
				extract_texts_from_resource(value, source)


func add_po_entry(text: String, source: String) -> void:
	if not po_entries.has(text):
		po_entries[text] = {
			"msgstr": "",
			"source": source
		}
	else:
		# If the text already exists, we add the new font to the existing ones.
		if not po_entries[text]["source"].contains(source):
			po_entries[text]["source"] += "\n" + source


func parse_existing_po(file_path: String) -> Dictionary:
	var existing_translations = {}
	var current_msgid = ""
	var current_msgstr = ""
	var current_source = ""
	var reading_comment = false
	
	if not FileAccess.file_exists(file_path):
		return {}
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
		
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		if line.begins_with("#:"):
			# Read source commentary
			current_source = line.substr(2).strip_edges()
			reading_comment = true
			
		elif line.begins_with("msgid "):
			# Save the previous translation if it exists
			if current_msgid != "" and current_msgid != '""':
				existing_translations[unquote_string(current_msgid)] = {
					"msgstr": unquote_string(current_msgstr),
					"source": current_source
				}
			
			current_msgid = line.substr(6)
			current_msgstr = ""
			if not reading_comment:
				current_source = ""
			reading_comment = false
			
		elif line.begins_with("msgstr "):
			current_msgstr = line.substr(7)
			
		elif line.begins_with('"') and line.ends_with('"'):
			# Continuation of a previous line
			if current_msgstr != "":
				current_msgstr += unquote_string(line)
			else:
				current_msgid += unquote_string(line)
	
	# Do not forget the last entry
	if current_msgid != "" and current_msgid != '""':
		existing_translations[unquote_string(current_msgid)] = {
			"msgstr": unquote_string(current_msgstr),
			"source": current_source
		}
	
	file.close()
	return existing_translations


func unquote_string(text: String) -> String:
	# Removes quotation marks at the beginning and end and processes escapes
	if text.begins_with('"') and text.ends_with('"'):
		return text.substr(1, text.length() - 2).replace('\\"', '"')
	return text


func generate_po_file(output_path: String) -> void:
	# Load existing translations
	var existing_translations = parse_existing_po(output_path)
	
	# Update existing translations in our current entries
	for msgid in po_entries.keys():
		if existing_translations.has(msgid):
			po_entries[msgid]["msgstr"] = existing_translations[msgid]["msgstr"]
	
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file:
		# Write PO file header
		file.store_string('msgid ""\n')
		file.store_string('msgstr ""\n')
		file.store_string('"Project-Id-Version: \\n"\n')
		file.store_string('"POT-Creation-Date: ' + Time.get_datetime_string_from_system() + '\\n"\n')
		file.store_string('"MIME-Version: 1.0\\n"\n')
		file.store_string('"Content-Type: text/plain; charset=UTF-8\\n"\n')
		file.store_string('"Content-Transfer-Encoding: 8bit\\n"\n')
		file.store_string('"Language: es\\n"\n\n')
		
		# Write each entry
		for msgid in po_entries:
			var escaped_msgid = msgid.replace('"', '\\"')
			var escaped_msgstr = po_entries[msgid]["msgstr"].replace('"', '\\"')
			
			# Write the comment with the origin
			file.store_string('#: ' + po_entries[msgid]["source"] + '\n')
			file.store_string('msgid "' + escaped_msgid + '"\n')
			file.store_string('msgstr "' + escaped_msgstr + '"\n\n')
		
		file.close()
	else:
		push_error("PO file could not be created")
