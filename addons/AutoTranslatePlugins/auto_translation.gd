@tool
class_name AutoTranslation
extends Node


## Original language
@export var source_language: String = "en"

## Target language for translation
@export var target_language: String = "es"


var http_request: HTTPRequest
var po_file_path = "res://translations/translations.po"  # Ajusta esto a la ruta de tu archivo PO
var output_file_path = "res://translations/translations_tr.po"  # Ruta del archivo de salida

var current_line = 0
var total_lines = 0
var po_lines = []
var translated_lines = []

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	
	#translate_po_file()

func translate_po_file():
	http_request.request_completed.connect(_on_request_completed)
	var file = FileAccess.open(po_file_path, FileAccess.READ)
	if file == null:
		print("No se pudo abrir el archivo PO")
		return
	
	while not file.eof_reached():
		var line = file.get_line()
		po_lines.append(line)
	
	file.close()
	
	total_lines = po_lines.size()
	process_next_line()

func process_next_line():
	if current_line >= total_lines:
		save_translated_file()
		http_request.request_completed.disconnect(_on_request_completed)
		return
	
	var line = po_lines[current_line]
	if line.begins_with("msgid "):
		var msgid = line.substr(7, line.length() - 8)  # Elimina las comillas
		translate_text(msgid)
	else:
		translated_lines.append(line)
		current_line += 1
		process_next_line()

func translate_text(text: String):
	var url = "https://translate.googleapis.com/translate_a/single"
	var headers = PackedStringArray(["User-Agent: Godot", "Accept: */*"])
	var query = "client=gtx&sl=en&tl=%s&dt=t&q=%s" % [target_language, text.uri_encode()] # en -> auto
	var full_url = "%s?%s" % [url, query]
	
	http_request.request(full_url, headers, HTTPClient.METHOD_GET)

func translate(text: String) -> String:
	var translated_text = [""]
	http_request.request_completed.connect(
		func(result, response_code, headers, body):
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json != null and json is Array and json.size() > 0:
				translated_text[0] = text_from_json(json)
	, CONNECT_ONE_SHOT)
	
	translate_text(text)
	await http_request.request_completed
	
	return translated_text[0]


func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json != null and json is Array and json.size() > 0:
		var translated_text = text_from_json(json)
		if translated_text:
			translated_lines.append('msgid "%s"' % po_lines[current_line].substr(7, po_lines[current_line].length() - 8))
			translated_lines.append('msgstr "%s"' % translated_text)
			
			print("Traducido %d/%d: %s" % [current_line + 1, total_lines, translated_text])
		else:
			print("No se pudo obtener la traducción para la línea %d" % (current_line + 1))
			translated_lines.append(po_lines[current_line])
			translated_lines.append('msgstr ""')
		
		current_line += 1
		while current_line < total_lines and not po_lines[current_line].begins_with("msgid "):
			current_line += 1
		
		process_next_line()
	else:
		print("Error en la traducción para la línea %d" % (current_line + 1))
		translated_lines.append(po_lines[current_line])
		translated_lines.append('msgstr ""')
		current_line += 1
		process_next_line()

func text_from_json(json):
	# Verifica si el JSON tiene el formato esperado
	if json.size() > 0 and json[0] is Array and json[0].size() > 0:
		if json[0][0] is Array and json[0][0].size() > 0:
			var translation = ""
			
			# Itera sobre los subarreglos dentro de json[0][0]
			for i in range(json[0].size()):
				translation += json[0][i][0]  # Concatenamos solo el texto traducido (posición 0)
					
			return translation  # Retorna la traducción completa
	print("Estructura JSON no reconocida: ", json)
	return ""

func save_translated_file():
	var file = FileAccess.open(output_file_path, FileAccess.WRITE)
	if file == null:
		print("No se pudo crear el archivo de salida")
		return
	
	for line in translated_lines:
		file.store_line(line)
	
	file.close()
	print("Traducción completada. Archivo guardado como: " + output_file_path)
