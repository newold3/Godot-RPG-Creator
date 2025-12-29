@tool
extends AutoTranslation

## Generate PO File
@export var generate_po_file: bool:
	set(value):
		if value:
			_on_extract_button_pressed()

## Translate Scene Texts
@export var translate_scenes: bool = true:
	set(value):
		translate_scenes = value
		notify_property_list_changed()

## Regex Used To Find Texts In Scenes
@export var scene_text_regexs: Array:
	set(value):
		for i in value.size():
			if !value[i]:
				value[i] = {"name": "", "regex": "", "is_array": false}
		scene_text_regexs = value

## Translate Texts in scripts (tr(text))
@export var translate_scripts: bool = true

## Directory where PO file will be saved
@export_dir var output_directory: String = "res://translations"

## Po file filename
@export var filename: String = "translations"

## Auto Translate Empty Msgstr Using Google API
@export var auto_translate_enabled: bool = false


const SCENE_PATH = "res://"
const SCRIPT_PATH = "res://"

func _ready() -> void:
	super()
	if !scene_text_regexs:
		scene_text_regexs.append({
			"name": "Scene (text): ",
			"regex": '(?m)^text\\s*=\\s*"((?:[^"\\\\]|\\\\.)*)"',
			"is_array": false
		})
		scene_text_regexs.append({
			"name": "Scene (tooltip): ",
			"regex": '(?m)^tooltip_text\\s*=\\s*"((?:[^"\\\\]|\\\\.)*)"',
			"is_array": false
		})

func _validate_property(property):
	if property.name == "scene_text_regexs":
		property.usage &= ~PROPERTY_USAGE_EDITOR if !translate_scenes else PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE

func _load_existing_translations() -> Dictionary:
	var texts: Dictionary = {}
	
	var po_file_path = output_directory.path_join(filename + ".po")
	if FileAccess.file_exists(po_file_path):
		var file = FileAccess.open(po_file_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var msgid_regex = RegEx.new()
			msgid_regex.compile('(?s)msgid\\s+"([^"]*(?:""[^"]*)*)"\\s*msgstr\\s+"([^"]*(?:""[^"]*)*)"')

			for match in msgid_regex.search_all(content):
				var msgid = match.get_string(1).c_unescape() # .replace('\\"', '"')
				var msgstr = match.get_string(2).c_unescape() # .replace('\\"', '"')
				texts[msgid] = msgstr
	
	return texts

func _on_extract_button_pressed():
	var start_time = Time.get_ticks_msec()
	var texts = {}
	
	if translate_scenes: _extract_from_scenes(SCENE_PATH, texts)
	if translate_scripts: _extract_from_scripts(SCRIPT_PATH, texts)
	await _generate_po_file(texts)
	
	var end_time = Time.get_ticks_msec()
	var duration = (end_time - start_time) / 1000.0
	
	print("Extraction completed. .po file generated in ", output_directory.path_join(filename + ".po"), " in %.2f seconds." % duration)

func _extract_from_scenes(path: String, texts: Dictionary):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				_extract_from_scenes(path.path_join(file_name), texts)
			elif file_name.ends_with(".tscn"):
				_process_scene_file(path.path_join(file_name), texts)
			file_name = dir.get_next()

func _process_scene_file(file_path: String, texts: Dictionary):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var line_starts = calculate_line_starts(content)
		
		for pattern in scene_text_regexs:
			var text_regex = RegEx.new()
			text_regex.compile(pattern.regex)
			
			for result in text_regex.search_all(content):
				var line_number = get_line_number(line_starts, result.get_start())
				
				if pattern.is_array:
					var array_str = result.get_string(1)
					var array_items = array_str.split(",")
					for item in array_items:
						var cleaned_item = item.c_escape()
						if not cleaned_item in texts:
							texts[cleaned_item] = []
						texts[cleaned_item].append(pattern.name + file_path + " (line " + str(line_number) + ")")
				else:
					var text = result.get_string(1).c_escape()
					if not text in texts:
						texts[text] = []
					texts[text].append(pattern.name + file_path + " (line " + str(line_number) + ")")

func calculate_line_starts(content: String) -> Array:
	var line_starts = [0]  # First line always starts at index 0
	var position = 0
	while true:
		position = content.find("\n", position)
		if position == -1:
			break
		position += 1  # Move past the newline
		line_starts.append(position)
	return line_starts

func get_line_number(line_starts: Array, position: int) -> int:
	var left = 0
	var right = line_starts.size() - 1
	
	while left <= right:
		var mid = (left + right) / 2
		if line_starts[mid] <= position and (mid == right or line_starts[mid + 1] > position):
			return mid + 1  # +1 because line numbers are 1-indexed
		elif line_starts[mid] > position:
			right = mid - 1
		else:
			left = mid + 1
	
	return left  # This should never happen if the input is valid

func _extract_from_scripts(path: String, texts: Dictionary, script_regex: RegEx = RegEx.new()):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		script_regex.compile("[\\s\\[\\(=]TranslationManager\\.tr\\s*\\([\"']([\\s\\S]*?)[\"']\\)")
		while file_name != "":
			if dir.current_is_dir():
				_extract_from_scripts(path.path_join(file_name), texts, script_regex)
			elif file_name.ends_with(".gd"):
				_process_script_file(path.path_join(file_name), texts, script_regex)
			file_name = dir.get_next()

func _process_script_file(file_path: String, texts: Dictionary, script_regex):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var line_starts = calculate_line_starts(content)
		
		for result in script_regex.search_all(content):
			var line_number = get_line_number(line_starts, result.get_start())
			var text = result.get_string(1).c_escape()
			if not text in texts:
				texts[text] = []
			texts[text].append("Script: " + file_path + " (line " + str(line_number) + ")")

func _generate_po_file(texts: Dictionary):
	var other = _load_existing_translations()
	var path = output_directory.path_join(filename + ".po")

	var project_name = ProjectSettings.get_setting("application/config/name")
	
	var used_keys = {}
	var current_entry = 0
	var lines = []
	var keys = texts.keys()
	var regex = RegEx.new()
	regex.compile("[a-zA-Z]")
	
	for i in keys.size():
		print("Traduciendo %d/%d" % [i + 1, keys.size()])
		var original_text = keys[i]
		if (
			!original_text or
			original_text in used_keys or
			original_text.length() == 1 or
			regex.search_all(original_text).size() < 2
		):
			continue
		used_keys[original_text] = true
		for source in texts[original_text]:
			lines.append('#. ' + source)
		lines.append('msgid "' + original_text + '"')
		var msgstr: String = 'msgstr "'
		if other.has(original_text):
			msgstr += other[original_text]
		elif auto_translate_enabled:
			var translated_text = await translate(original_text)
			var end_characters = [".", " ", "\n", ":", ",", "!", "?", ";"]
			for character in end_characters:
				if original_text.ends_with(character) and !translated_text.ends_with(character):
					translated_text += character
					break
				elif !original_text.ends_with(character) and translated_text.ends_with(character):
					translated_text = translated_text.substr(0, translated_text.length() - 1)
					break
			if original_text.begins_with(" ") and !translated_text.begins_with(" "):
				translated_text = translated_text.insert(0, " ")
			msgstr += translated_text
			current_entry += 1
		else:
			msgstr += original_text
		msgstr += '"'
		lines.append(msgstr)
		lines.append('')
		if current_entry > 1 and current_entry % 250 == 0:
			await get_tree().process_frame
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_line('msgid ""')
	file.store_line('msgstr ""')
	file.store_line('"Project-Id-Version: ' + project_name + '\\n"')
	file.store_line('"POT-Creation-Date: ' + Time.get_date_string_from_system() + '\\n"')
	file.store_line('"PO-Revision-Date: \\n"')
	file.store_line('"Last-Translator: \\n"')
	file.store_line('"Language-Team: \\n"')
	file.store_line('"Language: ' + target_language + '\\n"')
	file.store_line('"X-Source-Language: ' + source_language + '\\n"')
	file.store_line('"MIME-Version: 1.0\\n"')
	file.store_line('"Content-Type: text/plain; charset=UTF-8\\n"')
	file.store_line('"Content-Transfer-Encoding: 8bit\\n"')
	file.store_line('')
	
	for line in lines:
		file.store_line(line)
