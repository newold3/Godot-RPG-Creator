@tool
class_name AdvancedTextEditor
extends Window

var busy: bool = false
var message_initial_config = {}
var chain_size: bool = true
var dialog_mode = 0 # 0 = Commad Show Dialog, 1 = Command Scrolling Text Dialog

var preview_message_dialog: Window
var bussy: bool = false

var parameters: Array[RPGEventCommand]

var showing_preview_window: bool = false

var preview_main_config: Dictionary = {}
var preview_need_refresh: bool = false

var old_text: String

var fast_text_enabled: bool = false

static var highlighter_commands_disabled: bool = false


static var cache : Dictionary = {
	"font_name": "",
	"font_size": 0,
	"text_color": Color.BLACK,
	"text_background_color": Color.WHITE,
	"last_function_used": 0,
	"text_edit_font_size": 18,
	"image": {},
	"sound": {},
	"blip": {},
	"image_effect": {},
	"size_and_position": null,
	"wait_time": 0.5,
	"autowarp": true,
	"message_config": {},
	"chain_size": true
}

signal command_changed(commands: Array[RPGEventCommand])
signal fast_text_changed(text: String)
signal cancel()


func _ready() -> void:
	if !cache.font_size:
		cache.font_size = get_theme_font_size("normal")
	if cache.get("chain_size", true):
		%ChainSize.set_pressed(true)
	%TextEdit.set("theme_override_font_sizes/font_size", cache.text_edit_font_size)
	close_requested.connect(_on_cancel_button_pressed)
	tree_exiting.connect(_save_size_and_position)
	%TextEdit.disabled_expand_icon()
	await get_tree().process_frame
	%TextEdit.grab_focus()
	if "size_and_position" in cache and cache.size_and_position:
		size = cache.size_and_position[0]
		position = cache.size_and_position[1]
	if "autowarp" in cache:
		%WordWrapText.set_pressed(cache.autowarp)
	else:
		%WordWrapText.set_pressed(true)
		
	%TextEdit.syntax_highlighter.remove_color_region("[")
	var highlight_color = Color("#52f400f7")
	%TextEdit.syntax_highlighter.add_color_region("[", "]", highlight_color)
	
	%TextEdit.draw.connect(_draw_text_edit_horizontal_limit)
	
	#focus_exited.connect(
		#func():
			#if preview_message_dialog:
				#var window_id = preview_message_dialog.get_window_id()
				#if !DisplayServer.window_is_focused(window_id):
					#showing_preview_window = true
					#preview_message_dialog.hide()
	#)
	
	focus_entered.connect(_on_focus_entered)
	
	%HighlightCommands.set_pressed_no_signal(highlighter_commands_disabled)
	
	%Timer.start()


func _on_focus_entered() -> void:
	if preview_message_dialog and is_instance_valid(preview_message_dialog) and preview_message_dialog.mode == Window.MODE_MINIMIZED and not busy:
		busy = true
		preview_message_dialog.queue_free.call_deferred()
		await get_tree().process_frame
		%PreviewConfig.pressed.emit()
		await get_tree().process_frame
		busy = false


#func grab_focus() -> void:
	#return 
	#if DisplayServer.window_get_active_popup() != -1:
		#return
		#
	#var window = preview_message_dialog
	#if window and is_instance_valid(window) and window.visible:
		#var rect = Rect2(
			#Vector2(-36, -36),
			#window.size + Vector2i(72, 72)
		#)
		#if rect.has_point(window.get_mouse_position()):
			#if not window.has_focus():
				#window.grab_focus()
		#elif not has_focus():
			#super()


func set_events(events: Array) -> void:
	var node: OptionButton = %Target
	
	node.set_item_metadata(0, -1)
	
	for i in range(2, node.get_item_count(), 1):
		node.remove_item(2)
	
	for event: RPGEvent in events:
		node.add_item("%s: %s" % [event.id, event.name])
		node.set_item_metadata(-1, event.id)


func set_scroll_mode_dialog() -> void:
	var buttons = [%Image, %ImageEffect, %RemoveImage, %ShowNameBox, %RemoveNameBox, %Sound, %ShakeMessage, %PauseText, %ShowWholeLine, %DontWaitPlayerInput, %NewParagraph, %PreviewText, %EnterSpeaker, %ExitSpeaker, %ChangeBlipFx]
	for b in buttons:
		b.visible = false
	%PreviewScrollText.visible = true
	%InitialConfigContainer.visible = false
	%ScrollConfigContainer.visible = true
	title = TranslationManager.tr("Scrolling Text Editor")
	dialog_mode = 1


func set_instant_text_mode_dialog() -> void:
	var buttons = [%ImageEffect, %RemoveImage, %ShowNameBox, %RemoveNameBox, %Sound, %ShakeMessage, %PauseText, %ShowWholeLine, %DontWaitPlayerInput, %NewParagraph, %PreviewText, %EnterSpeaker, %ExitSpeaker, %ChangeBlipFx]
	for b in buttons:
		b.visible = false
	title = TranslationManager.tr("Instant Text Editor")
	%BottomButtonContainer.visible = false
	dialog_mode = 2


func _save_size_and_position() -> void:
	cache.size_and_position = [size, position]


func set_fast_edit_text(text: String) -> void:
	fast_text_enabled = true
	set_text(text)
	%BottomButtonContainer.visible = false
	%DisplayAsFloatingDialog.visible = false
	%Target.visible = false
	%InstantText.visible = false
	%NowaitForInput.visible = false


func set_parameters(_parameters: Array[RPGEventCommand]) -> void:
	parameters = _parameters

	var text: String = ""
	if dialog_mode == 2:
		text = parameters[0].parameters.get("first_line", "")
	if parameters:
		for i in range(1, parameters.size()):
			var t = parameters[i].parameters.get("line", "")
			if text:
				text += "\n" + t
			else:
				text = t
				
	if parameters.size() > 0:
		set_config(parameters[0].parameters)
	else:
		set_config({})
	set_text(text)


func set_text(text: String) -> void:
	%TextEdit.text = text


func set_main_config(config: Dictionary) -> void:
	preview_main_config = config


func set_config(config: Dictionary):
	busy = true
	message_initial_config = config.duplicate()
	
	if dialog_mode == 0:
		if !message_initial_config:
			message_initial_config.merge(cache.message_config)
		if not "face" in message_initial_config or message_initial_config.face.is_empty():
			message_initial_config.face = RPGIcon.new()
		cache.message_config = message_initial_config
		var pos = message_initial_config.get("position", 0)
		message_initial_config.position = pos
		%InitialPosition.select(clamp(pos, 0, 1))
		var face = message_initial_config.get("face", RPGIcon.new())
		message_initial_config.face = face
		%InitialFace.set_icon(face.path, face.region)
		var character_name = message_initial_config.get("character_name", {"type": 0, "value": ""})
		message_initial_config.character_name = character_name
		var type = character_name.get("type", 0)
		#message_initial_config.type = type
		var value = character_name.get("value", "")
		#message_initial_config.value = value
		if type == 0:
			%InitialName.text = value
		elif type == 1:
			%InitialName.text = TranslationManager.tr("Character ID = ") + str(value)
		else:
			%InitialName.text = TranslationManager.tr("Enemy ID = ") + str(value)
		%Width.value = message_initial_config.get("width", 0)
		message_initial_config.width = %Width.value
		%Height.value = message_initial_config.get("height", 0)
		message_initial_config.height = %Height.value
		
		%DisplayAsFloatingDialog.set_visible(true)
		%InstantText.set_visible(true)
		%DisplayAsFloatingDialog.set_pressed(message_initial_config.get("is_floating_dialog", false))
		%InstantText.set_pressed(message_initial_config.get("ignore_letter_by_letter", false))
		%NowaitForInput.set_pressed(message_initial_config.get("no_wait_for_input", false))
		message_initial_config.is_floating_dialog = %DisplayAsFloatingDialog.is_pressed()
		%Target.visible = %DisplayAsFloatingDialog.is_pressed()
		var target_selected = message_initial_config.get("floating_target", 0)
		%Target.select(0)
		for i in %Target.get_item_count():
			if %Target.is_item_disabled(i): continue
			var real_index = %Target.get_item_metadata(i)
			if real_index == target_selected:
				%Target.select(i)
				break
	else:
		%ScrollSpeed.value = message_initial_config.get("scroll_speed", 100)
		message_initial_config.scroll_speed = %ScrollSpeed.value
		%ScrollType.select(clamp(message_initial_config.get("scroll_direction", 0), 0, %ScrollType.get_item_count() - 1))
		message_initial_config.scroll_direction = %ScrollType.get_selected_id()
		var scene_path = message_initial_config.get("scroll_scene", "")
		message_initial_config.scroll_scene = scene_path
		%ScenePath.text = scene_path.get_file() if scene_path else TranslationManager.tr("Default")
		%FastForward.set_pressed(message_initial_config.get("enable_fast_forward", false))
		message_initial_config.enable_fast_forward = %FastForward.is_pressed()
		%MultiplySpeed.value = message_initial_config.get("multiply_value", 2.5)
		%MultiplySpeed.set_disabled(!%FastForward.is_pressed())
		
		%DisplayAsFloatingDialog.set_visible(false)
		%InstantText.set_visible(false)
		%NowaitForInput.set_visible(false)
		%Target.visible = false
		
	busy = false


func _on_ok_button_pressed() -> void:
	busy = true
	propagate_call("apply")
	busy = false
	if not fast_text_enabled:
		var commands: Array[RPGEventCommand] = build_command_list()
		command_changed.emit(commands)
	else:
		fast_text_changed.emit(%TextEdit.text.strip_edges())
		
	if preview_message_dialog and is_instance_valid(preview_message_dialog):
		preview_message_dialog.queue_free()
		await get_tree().process_frame
		
	queue_free()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = []
	
	var text = %TextEdit.text.strip_edges()
	var lines = text.split("\n")
	# Dialog lines command
	var min_line = -1 if dialog_mode != 2 else 0
	for i in range(lines.size() - 1, min_line, -1):
		var line = lines[i]
		var command = RPGEventCommand.new()
		command.code = 3 if dialog_mode == 0 else 11 if dialog_mode == 1 else 35
		command.parameters = {"line": line}
		command.indent = parameters[0].indent
		commands.append(command)
	# Dialog command
	var command = RPGEventCommand.new()
	command.code = 2 if dialog_mode == 0 else 10 if dialog_mode == 1 else 34
	if dialog_mode != 2:
		command.parameters = message_initial_config.duplicate()
	else:
		command.parameters.first_line = lines[0]
	command.indent = parameters[0].indent
	commands.append(command)
	
	return commands


func _on_cancel_button_pressed() -> void:
	cancel.emit()
	queue_free()


func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_double_click():
					try_select_command()
			elif event.is_ctrl_pressed():
				if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					var s = max(%TextEdit.get("theme_override_font_sizes/font_size") - 1, 8)
					%TextEdit.set("theme_override_font_sizes/font_size", s)
					cache.text_edit_font_size = s
					get_viewport().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
					var s = min(%TextEdit.get("theme_override_font_sizes/font_size") + 1, 120)
					%TextEdit.set("theme_override_font_sizes/font_size", s)
					cache.text_edit_font_size = s
					get_viewport().set_input_as_handled()


func select_command(start_index: int, end_index: int, command_data: Dictionary) -> void:
	# prints(start_index, end_index, command_data)
	if start_index == -1 or end_index == -1:
		return
	
	var node: TextEdit = %TextEdit
	var text = node.text
	
	# --- 1. Map absolute index to Line/Column ---
	var new_start_line = 0
	var new_start_column = 0
	var new_end_line = 0
	var new_end_column = 0
	
	var current_line = 0
	var current_column = 0
	
	for j in range(text.length() + 1):
		if j == start_index:
			new_start_line = current_line
			new_start_column = current_column
		if j == end_index:
			new_end_line = current_line
			new_end_column = current_column
			break 
		
		if j < text.length():
			if text[j] == "\n":
				current_line += 1
				current_column = 0
			else:
				current_column += 1

	# --- 2. Select text ---
	node.select(new_start_line, new_start_column, new_end_line, new_end_column)
	
	# --- 3. Extract content (Logic fixed for speaker) ---
	var selected_text = node.get_selected_text()
	var closing_tag_standard = "[/%s]" % command_data.command_name
	
	if selected_text.ends_with(closing_tag_standard):
		# Standard Dual Tag: [img]...[/img]
		command_data.command_end = closing_tag_standard
		
		var start_length = command_data.command_start.length()
		var end_length = closing_tag_standard.length()
		
		if selected_text.length() >= start_length + end_length:
			command_data.text = selected_text.substr(start_length, selected_text.length() - (start_length + end_length))
		else:
			command_data.text = ""
			
	elif command_data.command_name == "speaker":
		# Special Case: [speaker ...]...[speaker_end ...]
		# We look for the start of the closing tag inside the selection
		var last_tag_index = selected_text.rfind("[speaker_end")
		
		if last_tag_index != -1:
			# Capture the full closing tag (e.g., "[speaker_end index=1]")
			command_data.command_end = selected_text.substr(last_tag_index)
			
			var start_length = command_data.command_start.length()
			
			# Content is everything between the first tag and the last tag
			if last_tag_index >= start_length:
				command_data.text = selected_text.substr(start_length, last_tag_index - start_length)
			else:
				command_data.text = ""
	else:
		# Single Tag or selection failed to include closing tag
		command_data.text = ""

	edit_command(command_data)


func try_select_command() -> void:
	var node: TextEdit = %TextEdit
	var text = node.text
	
	# 1. Obtener posición absoluta del cursor
	var column = node.get_caret_column()
	var line = node.get_caret_line()
	
	var cursor_pos = 0
	var current_l = 0
	var current_c = 0
	
	if line == 0 and column == 0:
		cursor_pos = 0
	else:
		for i in text.length():
			if current_l == line and current_c == column:
				cursor_pos = i
				break
			if text[i] == "\n":
				current_l += 1
				current_c = 0
			else:
				current_c += 1
			if i == text.length() - 1:
				cursor_pos = text.length()

	# 2. Buscar límites [ ] alrededor del cursor
	var open_bracket_pos = -1
	var close_bracket_pos = -1
	
	var i = cursor_pos
	while i >= 0:
		if i < text.length() and text[i] == "[":
			open_bracket_pos = i
			break
		if i < text.length() and text[i] == "]" and i != cursor_pos: 
			break 
		i -= 1
		
	i = cursor_pos
	while i < text.length():
		if text[i] == "]":
			close_bracket_pos = i
			break
		if text[i] == "[": 
			break
		i += 1
		
	if open_bracket_pos == -1 or close_bracket_pos == -1:
		return 

	var command_str = text.substr(open_bracket_pos, close_bracket_pos - open_bracket_pos + 1)
	var command_data = get_command_selected(command_str)
	
	var selection_start = open_bracket_pos
	var selection_end = close_bracket_pos + 1
	
	if command_data.command_name:
		# MODIFICACIÓN AQUÍ: Añadimos 'speaker_end' como etiqueta de cierre válida
		if command_data.command_start.begins_with("[/") or command_data.command_name == "speaker_end":
			
			# --- CASO 1: Clic en etiqueta de CIERRE ---
			var opener_name = ""
			
			# Definimos quién es la pareja de apertura
			if command_data.command_name == "speaker_end":
				opener_name = "speaker"
			else:
				opener_name = command_data.command_name
				
			var nesting = 0
			var j = open_bracket_pos - 1
			
			# Buscamos hacia atrás
			while j >= 0:
				if text[j] == "[":
					var k = text.find("]", j)
					if k != -1:
						var t_str = text.substr(j, k - j + 1)
						var t_data = get_command_selected(t_str)
						
						# Verificamos si es la etiqueta de APERTURA que buscamos
						# Nota: Para etiquetas normales, t_data.command_name es igual (ej: img), 
						# pero no debe empezar por [/
						if t_data.command_name == opener_name and not t_str.begins_with("[/"):
							if nesting == 0:
								# ¡Encontrado! Actualizamos datos con la apertura
								command_data = t_data
								selection_start = j
								break
							else:
								nesting -= 1
						
						# Verificamos si es otra etiqueta de CIERRE igual (anidada)
						# Esto ocurre si es [/tag] o [speaker_end]
						elif (opener_name == "speaker" and t_data.command_name == "speaker_end") or \
							 (t_data.command_name == opener_name and t_str.begins_with("[/")):
							nesting += 1
				j -= 1
				
		else:
			# --- CASO 2: Clic en etiqueta de APERTURA ---
			var dual_tags = ["img", "b", "i", "u", "s", "center", "left", "right", "fill", 
							"font", "font_size", "color", "bgcolor", "url", "wave", "tornado", 
							"shake", "fade", "rainbow", "speaker", "p"] 
			
			if command_data.command_name in dual_tags:
				var search_close = "[/%s]" % command_data.command_name
				if command_data.command_name == "speaker":
					search_close = "[speaker_end" 
				
				var nesting = 0
				var j = close_bracket_pos + 1
				while j < text.length():
					if text[j] == "[":
						var k = text.find("]", j)
						if k != -1:
							var t_str = text.substr(j, k - j + 1)
							
							var is_match = false
							if command_data.command_name == "speaker":
								is_match = t_str.begins_with(search_close)
							else:
								is_match = (t_str == search_close)
							
							if is_match:
								if nesting == 0:
									selection_end = k + 1
									command_data.command_end = t_str
									break
								else:
									nesting -= 1
							elif get_command_selected(t_str).command_name == command_data.command_name and not t_str.begins_with("[/"):
								nesting += 1
					j += 1

	select_command(selection_start, selection_end, command_data)
	get_viewport().set_input_as_handled()


func click_on_command_font_size(command: Dictionary) -> void:
	_on_font_size_pressed(int(command.args))


func click_on_command_image(command: Dictionary) -> void:
	var img : Dictionary = {}
	var regex = RegEx.new()
	if command.command_name.to_lower() == "face":
		img.image_type = 0
		var rex = "([^\\s]+)\\s*=\\s*(\"[^\"]+\"|[^\\s\\]]+)"
		regex.compile(rex)
		var matches = regex.search_all(command.args)
		for m in matches:
			if m.get_string(1).to_lower() == "path":
				img.path = m.get_string(2).replace("\"", "")
			elif m.get_string(1).to_lower() == "region":
				var region = m.get_string(2).split(",")
				img.region = Rect2(int(region[0]), int(region[1]), int(region[2]), int(region[3]))
			elif m.get_string(0).to_lower().begins_with("position="):
				var pos = max(0, int(m.get_string(2)))
				img.face_position = pos
			elif m.get_string(0).to_lower().begins_with("trans_type="):
				img.trans_type = int(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("trans_time="):
				img.trans_time = float(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("trans_wait="):
				img.trans_wait = int(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("size="):
				var value = m.get_string(2)
				if value.find("x") != -1:
					img.width = int(value.get_slice("x", 0))
					img.height = int(value.get_slice("x", 1))
				else:
					img.width = int(value)
	elif command.command_name.to_lower() == "character":
		img.image_type = 1
		var rex = "([^\\s]+)\\s*=\\s*(\"[^\"]+\"|[^\\s\\]]+)"
		regex.compile(rex)
		var matches = regex.search_all(command.args)
		for m in matches:
			if m.get_string(1).to_lower() == "path":
				img.path = m.get_string(2).replace("\"", "")
			elif m.get_string(0).to_lower().begins_with("id="):
				img.image_id = int(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("idle_animation="):
				img.idle_animation = int(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("position="):
				var id = m.get_string(2).to_lower().replace("\"", "")
				var pos = max(0, [
					"left", "center", "right",
				"bottom_left_screen", "bottom_center_screen", "bottom_right_screen",
				"top_left_screen", "top_center_screen", "top_right_screen",
				"left_screen",  "right_screen", "custom"
				].find(id))
				img.start_position = pos
			elif m.get_string(0).to_lower().begins_with("trans_type="):
				img.trans_type = int(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("trans_type_end="):
				img.trans_type_end = int(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("trans_end_time="):
				img.trans_end_time = int(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("trans_time="):
				img.trans_time = float(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("trans_wait="):
				img.trans_wait = int(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("character_linked_to="):
				img.character_linked_to = int(m.get_string(2))
			elif m.get_string(0).to_lower().begins_with("size="):
				var value = m.get_string(2)
				if value.find("x") != -1:
					img.width = int(value.get_slice("x", 0))
					img.height = int(value.get_slice("x", 1))
				else:
					img.width = int(value)
			elif m.get_string(0).to_lower().begins_with("image_offset="):
				var value = m.get_string(2).split("x")
				if value.size() == 2:
					img.image_offset = Vector2i(int(value[0]), int(value[1]))
				else:
					img.image_offset = Vector2i.ZERO
			elif m.get_string(0).to_lower().begins_with("flip_h"):
				var value = m.get_string(2)
				img.flip_h = int(value)
			elif m.get_string(0).to_lower().begins_with("flip_v"):
				var value = m.get_string(2)
				img.flip_v = int(value)
	elif command.command_name.to_lower() == "img":
		img.image_type = 2
		img.path = command.text
		if command.args:
			if command.args.find("x") != -1:
				img.width = int(command.args.get_slice("x", 0))
				img.height = int(command.args.get_slice("x", 1))
			else:
				img.width = int(command.args)
	
	var icon = RPGIcon.new(img.get("path", ""), img.get("region", Rect2()))
	img.path = icon
	_on_image_pressed(img, command.command_name.to_lower() == "face")


func click_on_command_sound(command: Dictionary) -> void:
	var regex = RegEx.new()
	regex.compile("path\\s*=\\s*[\"']*([^\"']+)['\"]|volume\\s*=\\s*([0-9\\.-]+)|pitch\\s*=\\s*([0-9\\.-]+)")
	var matches = regex.search_all(command.args)
	var arg1 = ""
	var arg2 = 0.0
	var arg3 = 1.0
	for m in matches:
		if m.get_string(0).to_lower().begins_with("path="):
			arg1 = m.get_string(1) if m.get_string(1) else ""
		elif m.get_string(0).to_lower().begins_with("volume="):
			arg2 = float(m.get_string(2)) if m.get_string(2) else 0.0
		elif m.get_string(0).to_lower().begins_with("pitch="):
			arg3 = float(m.get_string(3)) if m.get_string(3) else 1.0
	if arg1:
		_on_sound_pressed(arg1, arg2, arg3)


func click_on_command_blip(command: Dictionary) -> void:
	var regex = RegEx.new()
	regex.compile("path\\s*=\\s*[\"']*([^\"']+)['\"]|volume\\s*=\\s*([0-9\\.-]+)|pitch\\s*=\\s*([0-9\\.-]+)|pitch2\\s*=\\s*([0-9\\.-]+)")
	var matches = regex.search_all(command.args)
	var arg1 = ""
	var arg2 = 0.0
	var arg3 = 1.0
	var arg4 = 1.0
	for m in matches:
		if m.get_string(0).to_lower().begins_with("path="):
			arg1 = m.get_string(1) if m.get_string(1) else ""
		elif m.get_string(0).to_lower().begins_with("volume="):
			arg2 = float(m.get_string(2)) if m.get_string(2) else 0.0
		elif m.get_string(0).to_lower().begins_with("pitch="):
			arg3 = float(m.get_string(3)) if m.get_string(3) else 1.0
		elif m.get_string(0).to_lower().begins_with("pitch2="):
			arg4 = float(m.get_string(3)) if m.get_string(3) else 1.0
	if arg1:
		_on_change_blip_fx_pressed(arg1, arg2, arg3, arg4)


func click_on_command_imgfx(command: Dictionary) -> void:
	var effect = {}
	var regex = RegEx.new()
	#regex.compile("(\\w+)=([^=,\\s]+)(?:,([^=,\\s]+))?") # shortten, no capture command="text with spaces"
	regex.compile("(\\w+)=((?:\"[^\"]*\"|[^=,\\s]+))(?:,([^=,\\s]+))?")
	var matches = regex.search_all(command.args)
	for m in matches:
		if m.get_string(1).to_lower() == "type":
			effect.image_type = int(m.get_string(2))
		elif m.get_string(1).to_lower() == "id":
			effect.image_id = int(m.get_string(2))
		elif m.get_string(1).to_lower() == "face_position":
			effect.face_position = int(m.get_string(2))
		elif m.get_string(1).to_lower() == "wait":
			effect.wait = m.get_string(2).to_lower() == "true"
		elif m.get_string(1).to_lower() == "duration":
			effect.duration = float(m.get_string(2))
		elif m.get_string(1).to_lower() == "move":
			effect.move_selected = true
			effect.move_x = int(m.get_string(2))
			effect.move_y = int(m.get_string(3))
		elif m.get_string(1).to_lower() == "rotate":
			effect.rotate_selected = true
			effect.rotation = float(m.get_string(2))
		elif m.get_string(1).to_lower() == "zoom":
			effect.scale_selected = true
			effect.zoom = float(m.get_string(2))
		elif m.get_string(1).to_lower() == "transition_type":
			effect.transition_selected = true
			effect.transition_type = int(m.get_string(2))
		elif m.get_string(1).to_lower() == "color":
			effect.modulate_selected = true
			effect.modulate = Color.from_string(m.get_string(2), Color.BLACK)
		elif m.get_string(1).to_lower() == "shake":
			effect.shake_selected = true
			effect.shake_amplitude = float(m.get_string(2))
			effect.shake_frequency = float(m.get_string(3)) if m.get_string(3).length() > 0 else 10
		elif m.get_string(1).to_lower().begins_with("idle_animation"):
			effect.idle_animation = int(m.get_string(2))
		elif m.get_string(1).to_lower() == "ease_type":
			effect.ease_type = int(m.get_string(2))
		elif m.get_string(1).to_lower() == "ease_transition":
			effect.ease_transition = int(m.get_string(2))
	_on_image_effect_pressed(effect)


func click_on_command_color(command: Dictionary) -> void:
	_on_text_color_pressed(Color(command.args.replace("=", "").strip_edges()))


func click_on_command_bgcolor(command: Dictionary) -> void:
	_on_background_text_color_pressed(Color(command.args.replace("=", "").strip_edges()))


func click_on_command_img_remove(command: Dictionary) -> void:
	var regex = RegEx.new()
	regex.compile("(\\w+)=(\"[^\"]+\"|[^=,\\s\\]]+)(?:,([^=,\\s\\]]+))?")
	var matches = regex.search_all(command.args)
	var type = 0
	var id = 0
	for m in matches:
		if m.get_string(1).to_lower() == "type":
			type = int(m.get_string(2))
		elif m.get_string(1).to_lower() == "id":
			id = int(m.get_string(2))
	_on_remove_image_pressed(type, id)


func click_on_command_font(command: Dictionary) -> void:
	_on_font_name_pressed(command.args.replace("=", "").strip_edges())


func click_on_command_wait(command: Dictionary) -> void:
	var regex = RegEx.new()
	regex.compile("(\\w+)=(\"[^\"]+\"|[^=,\\s\\]]+)(?:,([^=,\\s\\]]+))?")
	var matches = regex.search_all(command.args)
	var type = 0
	var seconds = 0
	for m in matches:
		if m.get_string(1).to_lower() == "type":
			type = int(m.get_string(2))
		elif m.get_string(1).to_lower() == "seconds":
			seconds = float(m.get_string(2))
	_on_pause_text_pressed(type, seconds)


func click_on_command_show_whole_line(command: Dictionary) -> void:
	_on_show_whole_line_pressed(int(command.args))


func click_on_command_no_wait_input(command: Dictionary) -> void:
	var regex = RegEx.new()
	regex.compile("(\\w+)=(\"[^\"]+\"|[^=,\\s\\]]+)(?:,([^=,\\s\\]]+))?")
	var matches = regex.search_all(command.args)
	var a = true
	var b = 0.0
	for m in matches:
		if m.get_string(1).to_lower() == "enabled":
			a = bool(int(m.get_string(2)))
		elif m.get_string(1).to_lower() == "time":
			b = float(m.get_string(2))
		
	_on_dont_wait_player_input_pressed(a, b)


func click_on_command_text_fx(command: Dictionary) -> void:
	var regex = RegEx.new()
	regex.compile("(\\w+)=(\"[^\"]+\"|[^=,\\s\\]]+)(?:,([^=,\\s\\]]+))?")
	var matches = regex.search_all(command.args)
	var args: Array = []
	var index = ["pulse", "wave", "tornado", "shake", "fade", "rainbow", "ghost", "colormod", "cuss", "heart", "jump", "l33t", "nervous", "number", "rain", "sparkle", "uwu", "woo", "learn"].find(command.command_name)
	for m in matches:
		var value = m.get_string(1)
		if value in ["start", "length", "connected", "var", "use_var"]:
			args.append(int(m.get_string(2)))
		elif value in ["freq", "ease", "amp", "radius", "rate", "level", "sat", "val", "span", "scale", "angle", "progress"]:
			args.append(float(m.get_string(2)))
		elif value in ["color", "c1", "c2", "c3"]:
			args.append(Color.from_string(m.get_string(2), Color.WHITE))
	
	_on_fx_pressed(index, args)


func click_on_other_command(command: Dictionary) -> void:
	var regex = RegEx.new()
	regex.compile("(\\w+)=(\"[^\"]+\"|[^=,\\s\\]]+)(?:,([^=,\\s\\]]+))?")
	var matches = regex.search_all(command.args)
	var index = ["variable", "actor", "party", "gold", "class", "item", "weapon", "armor", "enemy", "state", "profession_name", "profession_level"].find(command.command_name)
	var value = 1
	var show_icon_pressed = true
	var show_icon_pressed2 = false
	var width = 26
	var height = 26
	for m in matches:
		var v = m.get_string(1)
		if v == "id":
			value = int(m.get_string(2))
		elif v == "icon" or v == "extra":
			show_icon_pressed = (m.get_string(2) == "1")
		elif v == "extra2":
			show_icon_pressed2 = (m.get_string(2) == "1")
		elif v == "size":
			if m.get_string(2).find("x") != -1:
				width = int(m.get_string(2).get_slice("x", 0))
				height = int(m.get_string(2).get_slice("x", 1))
			else:
				width = int(m.get_string(2))
				height = width
				
	_on_others_pressed(index, value, show_icon_pressed, width, height, show_icon_pressed2)


func click_on_command_showbox(command: Dictionary) -> void:
	var regex = RegEx.new()
	regex.compile("(\\w+)=(\"[^\"]+\"|[^=,\\s\\]]+)(?:,([^=,\\s\\]]+))?")
	var matches = regex.search_all(command.args)
	var args: Array = []
	var type = 0
	var val = ""
	var pos = 0
	for m in matches:
		var value = m.get_string(1)
		if value == "type":
			type = int(m.get_string(2))
		elif value == "val":
			val = m.get_string(2)
		elif value == "pos":
			pos = int(m.get_string(2))
	
	val = val.replace("\"", "")
	_on_show_name_box_pressed(type, val, pos)


func click_on_command_hidebox(command) -> void:
	_on_remove_name_box_pressed(int(command.args.replace("=", "").strip_edges()))


func click_on_command_dialog_shake(command) -> void:
	var magnitude: float = 1.1
	var frequency: float = 10
	var duration: float = 0.25
	var wait: bool = false
	var regex = RegEx.new()
	regex.compile("(\\w+)=(\"[^\"]+\"|[^=,\\s\\]]+)(?:,([^=,\\s\\]]+))?")
	var matches = regex.search_all(command.args)
	for m in matches:
		var value = m.get_string(1)
		if value == "magnitude": magnitude = float(m.get_string(2))
		elif value == "frequency": frequency = float(m.get_string(2))
		elif value == "duration": duration = float(m.get_string(2))
		elif value == "wait": wait = int(m.get_string(2))
	_on_shake_message_pressed(magnitude, frequency, duration, wait)


func edit_command(command: Dictionary) -> void:
	if command.command_name == "font_size":
		click_on_command_font_size(command)
	elif command.command_name in ["img", "face", "character"]:
		click_on_command_image(command)
	elif command.command_name == "sound":
		click_on_command_sound(command)
	elif command.command_name == "blip":
		click_on_command_blip(command)
	elif command.command_name == "imgfx":
		click_on_command_imgfx(command)
	elif command.command_name == "color":
		click_on_command_color(command)
	elif command.command_name == "bgcolor":
		click_on_command_bgcolor(command)
	elif command.command_name == "img_remove":
		click_on_command_img_remove(command)
	elif command.command_name == "font":
		click_on_command_font(command)
	elif command.command_name == "wait":
		click_on_command_wait(command)
	elif command.command_name == "show_whole_line":
		click_on_command_show_whole_line(command)
	elif command.command_name == "no_wait_input":
		click_on_command_no_wait_input(command)
	elif command.command_name in ["pulse", "wave", "tornado", "shake", "fade", "rainbow", "ghost", "colormod", "cuss", "heart", "jump", "l33t", "nervous", "number", "rain", "sparkle", "uwu", "woo", "learn"]:
		click_on_command_text_fx(command)
	elif command.command_name in ["variable", "actor", "party", "gold", "class", "item", "weapon", "armor", "enemy", "state", "profession_name", "profession_level"]:
		click_on_other_command(command)
	elif command.command_name == "showbox":
		click_on_command_showbox(command)
	elif command.command_name == "hidebox":
		click_on_command_hidebox(command)
	elif command.command_name == "dialog_shake":
		click_on_command_dialog_shake(command)
	elif command.command_name == "speaker":
		click_on_command_show_speaker_dialog(command)
	elif command.command_name == "hide_speaker":
		click_on_command_hide_speaker_dialog(command)
	elif command.command_name == "highlight_character":
		_on_change_speaker_active_pressed(command)


func get_command_selected(selection: String) -> Dictionary:
	var result: Dictionary = {}
	
	var regex = RegEx.new()
	regex.compile("^\\[(\\w+)([^\\]]*)\\]|\\[\\W*\\/(\\w+)\\]$")
	var matches: Array[RegExMatch] = regex.search_all(selection)
	if matches.size() == 2:
		if matches[0].get_string(1) == matches[1].get_string(3):
			var xi = matches[0].get_string(0).length()
			var xf = selection.length() - matches[1].get_string(0).length() - xi
			result = {
				"command_name": matches[0].get_string(1),
				"args": matches[0].get_string(2),
				"text": selection.substr(xi, xf),
				"command_start": matches[0].get_string(0),
				"command_end": matches[1].get_string(0)
			}
	elif matches.size() == 1:
		var xi = matches[0].get_string(0).length()
		var xf = selection.length() - xi
		result = {
			"command_name": matches[0].get_string(1),
			"args": matches[0].get_string(2),
			"text": selection.substr(xi, xf),
			"command_start": matches[0].get_string(0),
			"command_end": ""
		}
		
	return result


func get_selection() -> Dictionary:
	var node: TextEdit = %TextEdit as TextEdit
	var result = {}
	result.column = node.get_caret_column()
	result.line = node.get_caret_line()
	result.selection = {}
	if node.has_selection():
		result.selection.start_column = node.get_selection_from_column()
		result.selection.start_line = node.get_selection_from_line()
		result.selection.end_column = node.get_selection_to_column()
		result.selection.end_line = node.get_selection_to_column()
		result.selection.text = node.get_selected_text()
		result.selection.command_selected = get_command_selected(result.selection.text)
		pass
	
	return result


# Format numbers in a string to 2 decimals if the number is a decimal.
func format_floats(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\b\\d+\\.\\d+\\b")
	var formatted_text = text
	var matches = regex.search_all(text)
	
	for m in matches:
		var num = float(m.get_string())
		var formatted_num
		if num == floor(num):
			formatted_num = str(int(num))
		else:
			formatted_num = "%.2f" % num
		formatted_text = formatted_text.replace(m.get_string(), formatted_num)
	
	return formatted_text


func insert_or_replace_text(text: String) -> void:
	if busy: return
	busy = true
	text = format_floats(text)
	var node: TextEdit = %TextEdit as TextEdit
	var selection_data = get_selection()
	if selection_data.selection:
		node.cut()
		node.insert_text_at_caret(text)
	else:
		node.insert_text_at_caret(text)
	busy = false


func insert_command(start_command: String, end_command: String) -> void:
	if busy: return
	busy = true
	
	var node: TextEdit = %TextEdit as TextEdit
	var selection_data = get_selection()

	var current_command_data = get_command_selected(start_command)
	
	if selection_data.selection:
		node.cut()
		
		var selection_copy: String
		
		if selection_data.selection.command_selected:
			if selection_data.selection.command_selected.command_name == current_command_data.command_name:
				if (
					(current_command_data.args and
					current_command_data.args != selection_data.selection.command_selected.args) or
					(current_command_data.command_name in ["pulse", "wave", "tornado", "shake", "fade",
					"rainbow", "ghost", "colormod", "cuss", "heart", "jump", "l33t", "nervous", "number",
					"rain", "sparkle", "uwu", "woo", "learn"])
				):
					var n = selection_data.selection.command_selected.text
					selection_copy = start_command + n + end_command
				else:
					var n = selection_data.selection.command_selected.text
					selection_copy = n
			else:
				var n = selection_data.selection.text
				selection_copy = start_command + n + end_command
		else:
			var n = selection_data.selection.text
			selection_copy = start_command + n + end_command
		
		node.insert_text_at_caret(format_floats(selection_copy))
		
		var n_lines = selection_copy.count("\n")
		var new_start_line = selection_data.selection.start_line
		var new_start_column = selection_data.selection.start_column
		var new_end_line = selection_data.selection.start_line + n_lines
		var new_end_column
		if n_lines == 0:
			var length = new_start_column + selection_copy.length()
			new_end_column = length
			var closing_bracket_pos = node.text.rfind("]", new_end_column)
			if closing_bracket_pos != -1:
				new_end_column = closing_bracket_pos + 1
		else:
			var length = selection_copy.get_slice("\n", n_lines).length()
			new_end_column = length
		node.select(new_start_line, new_start_column, new_end_line, new_end_column)
	else:
		var selection_copy = start_command + end_command
		node.insert_text_at_caret(format_floats(selection_copy))
		node.set_caret_column(selection_data.column + start_command.length())
	
	busy = false


func _on_bold_pressed() -> void:
	insert_command("[b]", "[/b]")


func _on_italic_pressed() -> void:
	insert_command("[i]", "[/i]")


func _on_underline_pressed() -> void:
	insert_command("[u]", "[/u]")


func _on_strike_pressed() -> void:
	insert_command("[s]", "[/s]")


func _on_left_align_pressed() -> void:
	insert_command("[left]", "[/left]")


func _on_center_align_pressed() -> void:
	insert_command("[center]", "[/center]")


func _on_right_align_pressed() -> void:
	insert_command("[right]", "[/right]")


func _on_justified_text_pressed() -> void:
	insert_command("[fill]", "[/fill]")


func _on_emote_pressed() -> void:
	var path: String = "res://addons/CustomControls/Dialogs/select_emote_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.emote_selected.connect(_on_emote_selected)


func _on_emote_selected(emote: String) -> void:
	insert_or_replace_text(emote)


func _on_font_size_pressed(font_size: int = -1) -> void:
	var path: String = "res://addons/CustomControls/Dialogs/select_number_value_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Font Size")
	dialog.set_min_max_values(8, 500)
	if font_size != -1:
		dialog.set_value(font_size)
	else:
		dialog.set_value(cache.font_size)
	dialog.selected_value.connect(_on_font_size_selected)


func _on_font_size_selected(value: int) -> void:
	insert_command("[font_size=%s]" % value, "[/font_size]")
	cache.font_size = value


func _on_image_pressed(img: Dictionary = {}, hide_size: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_dialog_text_image.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if !img:
		img = cache["image"]
	dialog.set_data(img)
	if hide_size:
		dialog.hide_size()
	dialog.image_selected.connect(_on_image_selected)


func _on_image_selected(img: Dictionary) -> void:
	if img.path:
		var bbcode: String = ""
		if img.image_type == 0: # face
			var arg1 = "" if img.trans_type == 0 else " trans_type=%s" % img.trans_type
			var arg2 = "" if !arg1 else " trans_time=%s" % img.trans_time
			var arg3 = "" if !arg1 else " trans_wait=%s" % img.trans_wait
			var arg4 = "" if img.width == 0 and img.height == 0 else " size=%s" % img.width
			var arg5 = "" if img.height == 0 else "x%s" % img.height
			var face: RPGIcon = img.path
			var arg6 = "" if not face.region else " region=%s,%s,%s,%s" % [
				int(face.region.position.x),
				int(face.region.position.y),
				int(face.region.size.x),
				int(face.region.size.y)
			]
			if img.face_position == 0:
				bbcode = "[face path=\"%s\"%s" % [face.path, arg6]
			else:
				bbcode = "[face path=\"%s\"%s position=1" % [img.path, arg6]
			bbcode += arg1 + arg2 + arg3 + arg4 + arg5 + "]"
		elif img.image_type == 1: # Background Character
			var character: RPGIcon = img.path
			var arg1 = "path=\"%s\"" % character.path
			var arg2 = "" if img.image_id == 0 else " id=%s" % img.image_id
			var dir = [
				"left", "center", "right",
				"bottom_left_screen", "bottom_center_screen", "bottom_right_screen",
				"top_left_screen", "top_center_screen", "top_right_screen",
				"left_screen",  "right_screen", "custom"
			][img.start_position]
			var arg3 = "" if img.start_position == 0 else " position=\"%s\"" % dir
			var arg4 = "" if img.trans_type == 0 else " trans_type=%s" % img.trans_type
			var arg5 = "" if !arg4 else " trans_time=%s" % img.trans_time
			var arg6 = "" if !arg4 else " trans_wait=%s" % img.trans_wait
			var arg7 = "" if img.width == 0 and img.height == 0 else " size=%s" % img.width
			var arg8 = "" if img.height == 0 else "x%s" % img.height
			var arg9 = "" if img.idle_animation == 0 else " idle_animation=%s" % img.idle_animation
			var offset = img.get("image_offset", Vector2i())
			var arg10 = "" if offset == Vector2i.ZERO else " image_offset=%s" % "%sx%s" % [offset.x, offset.y]
			var arg11 = "" if img.flip_h == 0 else " flip_h=1"
			var arg12 = "" if img.flip_v == 0 else " flip_v=1"
			var arg13 = "" if img.trans_type_end == 0 else " trans_type_end=%s" % img.trans_type_end
			var arg15 = "" if img.trans_end_time == 0 else " trans_end_time=%s" % img.trans_end_time
			var arg16 = "" if img.character_linked_to == 0 else " character_linked_to=%s" % img.character_linked_to
			bbcode = "[character %s%s%s%s%s%s%s%s%s%s%s%s%s%s%s]" % [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10,arg11, arg12, arg13, arg15, arg16]
		else: # Inline Image
			var icon: RPGIcon = img.path
			var arg1 = icon.path
			if img.height != 0 and img.width == 0:
				img.width = 1
			var arg2 = "" if img.width == 0 and img.height == 0 else "%s" % img.width
			var arg3 = "" if img.height == 0 else "x%s" % img.height
			if arg2:
				bbcode = "[img=%s%s]%s[/img]" % [arg2, arg3, arg1]
			else:
				bbcode = "[img]%s[/img]" % arg1
		
		if bbcode:
			insert_or_replace_text(bbcode)
			
	img.path = ""
	img.width = 0
	img.height = 0
	cache["image"] = img


func _on_sound_pressed(file_selected: String = "", volume: float = 0.0, pitch: float = 1.0) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if volume == 0.0 and pitch == 1.0 and "sound" in cache and cache["sound"]:
		volume = cache["sound"].volume
		pitch = cache["sound"].pitch
	
	var commands: Array[RPGEventCommand]
	var command = RPGEventCommand.new(0, 0, {"path": file_selected, "volume": volume, "pitch": pitch})
	commands.append(command)
	dialog.set_parameters(commands)
	dialog.set_data()
	dialog.command_changed.connect(_on_sound_selected)


func _on_sound_selected(commands: Array[RPGEventCommand]) -> void:
	if commands.size() > 0:
		var command_data = commands[0].parameters
		var path = command_data.get("path", "")
		var volume = command_data.get("volume", 0)
		var pitch = command_data.get("pitch", 1)
		if path:
			var arg1 = "path=\"%s\"" % path
			var arg2 = "" if volume == 0.0 else " volume=%s" % volume
			var arg3 = "" if pitch == 1.0 else " pitch=%s" % pitch
			var bbcode = "[sound %s%s%s]" % [arg1, arg2, arg3]
			cache["sound"] = {
				"volume": volume,
				"pitch": pitch
			}
			insert_or_replace_text(bbcode)


func _on_text_color_pressed(color: Color = Color.WHITE) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Text Color")
	dialog.color_selected.connect(_on_text_color_selected)
	dialog.set_color(color)


func _on_text_color_selected(color: Color) -> void:
	if color == RPGDialogFunctions.get_current_dialog().original_color:
		return
	insert_command("[color=#%s]" % color.to_html(), "[/color]")


func _on_background_text_color_pressed(color: Color = Color.WHITE) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.title = TranslationManager.tr("Select Background Text Color")
	dialog.color_selected.connect(_on_background_text_color_selected)
	dialog.set_color(color)


func _on_background_text_color_selected(color: Color) -> void:
	if color == RPGDialogFunctions.get_current_dialog().original_color:
		return
	insert_command("[bgcolor=#%s]" % color.to_html(), "[/bgcolor]")


func _on_font_name_pressed(font_file: String = "") -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _on_font_selected
	dialog.set_dialog_mode(0)
	
	if font_file:
		dialog.set_file_selected(font_file)
	
	dialog.fill_files("fonts")


func _on_font_selected(path: String) -> void:
	if path:
		insert_command("[font=%s]" % path, "[/font]")


func _on_image_effect_pressed(effect: Dictionary = {}) -> void:
	var path = "res://addons/CustomControls/Dialogs/text_image_animation.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if !effect and "image_effect" in cache:
		effect = cache["image_effect"]
	dialog.set_data(effect)
	dialog.effect_selected.connect(_on_image_effect_selected)


func _on_image_effect_selected(effect: Dictionary) -> void:
	cache["image_effect"] = effect
	
	var bbcode: String = ""

	var effect_setted: bool = false

	if effect.wait:
		bbcode += " wait=true"
	
	if effect.move_selected and (effect.move_x or effect.move_y):
		bbcode += " move=%s,%s" % [effect.move_x, effect.move_y]
		effect_setted = true
		
	if effect.rotate_selected and effect.rotation:
		bbcode += " rotate=%s" % (round(float(effect.rotation) * 100) / 100.0)
		effect_setted = true
	
	if effect.scale_selected and effect.zoom:
		bbcode += " zoom=%s" % (round(float(effect.zoom) * 100) / 100.0)
		effect_setted = true
	
	if effect.transition_selected:
		bbcode += " transition_type=%s" % effect.transition_type
		effect_setted = true
	
	if effect.modulate_selected:
		bbcode += " color=#%s" % effect.modulate.to_html()
		effect_setted = true
	
	if effect.shake_selected and effect.shake_amplitude:
		bbcode += " shake=%s,%s" % [effect.shake_amplitude, effect.shake_frequency]
		effect_setted = true
	
	if effect.ease_type != 0:
		bbcode += " ease_type=%s" % effect.ease_type
	
	if effect.ease_transition != 0:
		bbcode += " ease_transition=%s" % effect.ease_transition
	
	if effect_setted:
		if effect.image_type == 0:
			bbcode = bbcode.insert(0, "[imgfx type=0 duration=%s" % effect.duration)
		else:
			bbcode = bbcode.insert(0, "[imgfx type=1 id=%s duration=%s idle_animation=%s" % [
				effect.image_id,
				effect.duration,
				effect.idle_animation
			])
	elif effect.image_type == 1:
		bbcode = "[imgfx type=1 id=%s idle_animation=%s" % [
			effect.image_id,
			effect.idle_animation
		]
		effect_setted = true
	
	if effect_setted:
		bbcode += "]"
		insert_or_replace_text(bbcode)


func _on_remove_image_pressed(type: int = 0, id: int = 0) -> void:
	var path = "res://addons/CustomControls/Dialogs/remove_text_image.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_data(type, id)
	dialog.remove_image.connect(_on_remove_image)


func _on_remove_image(type: int, id: int) -> void:
	var bbcode: String = "[img_remove type=%s id=%s]" % [type, id]
	
	insert_or_replace_text(bbcode)


func _on_pause_text_pressed(type: int = 0, seconds: float = -1) -> void:
	var path = "res://addons/CustomControls/Dialogs/pause_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if seconds == -1:
		seconds = cache.wait_time
	
	dialog.set_data(type, seconds)
	dialog.command_selected.connect(_on_wait_command_selected)


func _on_wait_command_selected(type: int = 0, seconds: float = 0.0) -> void:
	var bbcode: String
	if type == 0 and seconds > 0:
		bbcode = "[wait type=%s seconds=%s]" % [type, seconds]
		cache.wait_time = seconds
	elif type == 1:
		bbcode = "[wait type=%s]" % type
	
	if bbcode:
		insert_or_replace_text(bbcode)


func _on_show_whole_line_pressed(id: int = 1) -> void:
	var path = "res://addons/CustomControls/Dialogs/change_flow_text_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_data(id)
	dialog.command_selected.connect(_on_whole_line_command_selected)


func _on_whole_line_command_selected(id: int) -> void:
	var bbcode: String = "[show_whole_line=%s]" % id
	var length: int = %TextEdit.get_selected_text().length()
	if length > 0:
		if id == 1:
			insert_command("[show_whole_line=1]", "[show_whole_line=0]")
		else:
			insert_command("", "[show_whole_line=0]")
	else:
		insert_or_replace_text(bbcode)


func _on_dont_wait_player_input_pressed(enabled: bool = true, time: float = 1.0) -> void:
	var path = "res://addons/CustomControls/Dialogs/no_wait_for_input_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.set_data(enabled, time)
	dialog.command_selected.connect(_on_dont_wait_player_input_command_selected)


func _on_dont_wait_player_input_command_selected(enabled: bool, time: float = 1.0) -> void:
	var time_str = "" if time <= 0 or !enabled else " time=%s" % time
	var bbcode: String = "[no_wait_input enabled=%s%s]" % [(0 if !enabled else 1), time_str]
	insert_or_replace_text(bbcode)


func _on_fx_pressed(index: int = -1, args: Array = []) -> void:
	var path = "res://addons/CustomControls/Dialogs/text_effects_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_data(index, args)
	dialog.command_selected.connect(_on_text_effect_selected)


func _on_text_effect_selected(command: String, args: String) -> void:
	var open_command: String
	var close_command: String = "[/%s]" % command
	if args:
		open_command = "[" + command + " " + args + "]"
	else:
		open_command = "[" + command + "]"
	
	insert_command(open_command, close_command)


func _on_highlight_commands_toggled(value: bool) -> void:
	highlighter_commands_disabled = value
	%TextEdit.syntax_highlighter.remove_color_region("[")
	if value:
		%TextEdit.syntax_highlighter.add_color_region("[", "]", Color(1, 1, 1, 0.36))
	else:
		var highlight_color = Color("#52f400f7")
		%TextEdit.syntax_highlighter.add_color_region("[", "]", highlight_color)
		highlighter_commands_disabled = false
	
	var syntax_highlighter = %TextEdit.syntax_highlighter
	%TextEdit.syntax_highlighter = null
	%TextEdit.syntax_highlighter = syntax_highlighter


func _on_others_pressed(selected_comand_id: int = -1, value: int = 1, show_icon_pressed: bool = true, width: int = 0, height: int = 0, show_icon_pressed2: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/other_command_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_data(selected_comand_id, value, show_icon_pressed, width, height, show_icon_pressed2)
	dialog.command_selected.connect(_on_other_command_selected)


func _on_other_command_selected(command: String) -> void:
	insert_or_replace_text(command)


func _on_show_name_box_pressed(type: int = 0, value: String = "", pos: int = 0) -> void:
	var path = "res://addons/CustomControls/Dialogs/show_name_box.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	dialog.set_data(type, value, pos)
	dialog.command_selected.connect(_on_name_box_selected)


func _on_name_box_selected(type: int, value: Variant, pos: int) -> void:
	var command = "[showbox type=%s val=\"%s\" pos=%s]" % [type, value, pos]
	insert_or_replace_text(command)


func _on_remove_name_box_pressed(item_selected: int = 0) -> void:
	var path = "res://addons/CustomControls/Dialogs/hide_name_box.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.set_data(item_selected)
	dialog.command_selected.connect(_on_hide_name_box_selected)


func _on_hide_name_box_selected(item_selected: int) -> void:
	var command = "[hidebox=%s]" % item_selected
	insert_or_replace_text(command)


func _on_preview_text_pressed() -> void:
	propagate_call("apply")
	if !preview_message_dialog:
		showing_preview_window = true
		var path = "res://addons/CustomControls/Dialogs/message_preview_dialog.tscn"
		preview_message_dialog = load(path).instantiate()
		preview_message_dialog.close_requested.connect(
			func():
				preview_message_dialog = null
				showing_preview_window = false
		)
		preview_message_dialog.visible = false
		add_child(preview_message_dialog)
		preview_message_dialog.position = position - Vector2i(preview_message_dialog.size.x, 0)
		preview_message_dialog.position.x = max(10, preview_message_dialog.position.x)
		#preview_message_dialog.hide()
		#await get_tree().process_frame
		#preview_message_dialog.show()
		if not preview_message_dialog.visible:
			preview_message_dialog.show()
	else:
		if not preview_message_dialog.visible:
			preview_message_dialog.show()
		#preview_message_dialog.hide()
		#await get_tree().process_frame
		#preview_message_dialog.show()
	
	
	
	var text = %TextEdit.text
	var config = preview_main_config.duplicate()
	if not config.has("ignore_letter_by_letter"):
		config.ignore_letter_by_letter = %InstantText.is_pressed()
	if not config.has("is_floating_dialog"):
		config.is_floating_dialog = %DisplayAsFloatingDialog.is_pressed()
	preview_message_dialog.set_main_config(config)
	await get_tree().process_frame
	preview_message_dialog.set_text(text, message_initial_config)
	grab_focus()


func _on_shake_message_pressed(magnitude: float = 1.1, frequency: float = 10, duration: float = 0.6, wait: bool = false) -> void:
	var path = "res://addons/CustomControls/Dialogs/shake_message_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.command_changed.connect(_on_dialog_wait_command_created)
	dialog.set_data(magnitude, frequency, duration, wait)


func _on_dialog_wait_command_created(command: String) -> void:
	insert_or_replace_text(command)


func _on_new_paragraph_pressed() -> void:
	insert_or_replace_text("[p]")


func _on_word_warp_text_toggled(toggled_on: bool) -> void:
	cache.autowarp = toggled_on
	if toggled_on:
		%TextEdit.wrap_mode = %TextEdit.LINE_WRAPPING_BOUNDARY
	else:
		%TextEdit.wrap_mode = %TextEdit.LINE_WRAPPING_NONE


func _on_initial_face_clicked() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_icon_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	var file_selected = message_initial_config.get("face", RPGIcon.new())
	dialog.set_data(file_selected)
	
	dialog.icon_changed.connect(_on_select_initial_face)
	#var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	#var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	#await get_tree().process_frame
	#
	#dialog.destroy_on_hide = true
	#dialog.target_callable = _on_select_initial_face
	#dialog.set_dialog_mode(0)
	#
	#var file_selected_path = message_initial_config.get("face", "")
	#if file_selected_path:
		#dialog.set_file_selected(file_selected_path)
	#
	#dialog.fill_files("images")


func _on_select_initial_face() -> void:
	if !%InitialConfigContainer.visible: return
	%InitialFace.set_icon(message_initial_config.face.path, message_initial_config.face.region)
	preview_need_refresh = true


func _on_initial_face_remove_requested() -> void:
	if !%InitialConfigContainer.visible: return
	message_initial_config.face.clear()
	%InitialFace.set_icon("")
	preview_need_refresh = true


func _on_initial_name_middle_click_pressed() -> void:
	if !%InitialConfigContainer.visible: return
	message_initial_config.character_name = {
		"type": 0,
		"value": ""
	}
	%InitialName.text = ""
	preview_need_refresh = true


func _on_initial_name_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/show_name_box.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.hide_box_position(true)
	var data = message_initial_config.get("character_name", {"type": 0, "value": ""})
	dialog.set_data(data.type, str(data.value), 0)
	dialog.command_selected.connect(_on_initial_name_box_selected)


func _on_initial_name_box_selected(type: int, value: Variant, _pos: int) -> void:
	if !%InitialConfigContainer.visible: return
	message_initial_config.character_name = {
		"type": type,
		"value": value
	}
	if type == 0:
		%InitialName.text = value
	elif type == 1:
		%InitialName.text = TranslationManager.tr("Character ID = ") + str(value)
	else:
		%InitialName.text = TranslationManager.tr("Enemy ID = ") + str(value)
		
	preview_need_refresh = true


func _on_initial_position_item_selected(index: int) -> void:
	if !%InitialConfigContainer.visible: return
	message_initial_config.position = index
	preview_need_refresh = true


func _draw_text_edit_horizontal_limit() -> void:
	if dialog_mode != 0:
		return
	var margin = 47 * 2 + 68
	var x = 800 - margin
	var h = %TextEdit.size.y
	var multiline: PackedVector2Array = []
	var dashed_length = 5
	var top_margin = 4
	for i in range(0, h, dashed_length):
		var y = min(i * dashed_length + top_margin, h - top_margin)
		multiline.append(Vector2(x, y))
		y = min(i * dashed_length + dashed_length + top_margin, h - top_margin)
		multiline.append(Vector2(x, y))
	%TextEdit.draw_multiline(multiline, Color("#3b3b3b"), 2)


func _on_chain_size_toggled(toggled_on: bool) -> void:
	chain_size = toggled_on
	cache.chain_size = chain_size


func _on_width_value_updated(old_value: float, new_value: float) -> void:
	if !%InitialConfigContainer.visible: return
	if busy: return
	
	if chain_size:
		busy = true
		if old_value != 0 and %Height.value != 0:
			var ratio: float = new_value / old_value
			%Height.value = %Height.value * ratio
		elif %Height.value == 0:
			%Height.value = %Width.value
		busy = false
	
	message_initial_config.width = %Width.value
	message_initial_config.height = %Height.value
	preview_need_refresh = true


func _on_height_value_updated(old_value: float, new_value: float) -> void:
	if !%InitialConfigContainer.visible: return
	if busy: return
	
	if chain_size:
		busy = true
		if old_value != 0 and %Width.value != 0:
			var ratio: float = new_value / old_value
			%Width.value = %Width.value * ratio
		elif %Width.value == 0:
			%Width.value = %Height.value
		busy = false
	
	message_initial_config.width = %Width.value
	message_initial_config.height = %Height.value
	preview_need_refresh = true


func _on_scroll_speed_value_changed(value: float) -> void:
	if !%ScrollConfigContainer.visible: return
	message_initial_config.scroll_speed = value
	preview_need_refresh = true


func _on_scroll_type_item_selected(index: int) -> void:
	if !%ScrollConfigContainer.visible: return
	message_initial_config.scroll_direction = index
	preview_need_refresh = true


func _on_scene_path_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	dialog.target_callable = _on_select_scroll_scene
	dialog.set_dialog_mode(0)
	
	var file_selected_path = message_initial_config.get("scroll_scene", "")
	if file_selected_path:
		dialog.set_file_selected(file_selected_path)
	
	dialog.fill_files("scroll_scenes")


func _on_select_scroll_scene(path: String) -> void:
	if !%ScrollConfigContainer.visible: return
	message_initial_config.scroll_scene = path
	%ScenePath.text = path.get_file()
	preview_need_refresh = true


func _on_scene_path_middle_click_pressed() -> void:
	if !%ScrollConfigContainer.visible: return
	message_initial_config.scroll_scene = ""
	%ScenePath.text = TranslationManager.tr("Default")
	preview_need_refresh = true


func _on_fast_forward_toggled(toggled_on: bool) -> void:
	if !%ScrollConfigContainer.visible: return
	message_initial_config.enable_fast_forward = toggled_on
	%MultiplySpeed.set_disabled(!toggled_on)
	preview_need_refresh = true


func _on_preview_scroll_text_pressed() -> void:
	propagate_call("apply")

	if !preview_message_dialog:
		var path = "res://addons/CustomControls/Dialogs/preview_scroll_scene_dialog.tscn"
		showing_preview_window = true
		preview_message_dialog = load(path).instantiate()
		preview_message_dialog.tree_exited.connect(
			func():
				preview_message_dialog = null
				showing_preview_window = false
		)
		preview_message_dialog.visible = false
		add_child(preview_message_dialog)
		await get_tree().process_frame
		preview_message_dialog.hide()
		preview_message_dialog.show()
	else:
		await get_tree().process_frame
		preview_message_dialog.hide()
		preview_message_dialog.show()
	
	var text = %TextEdit.text
	preview_message_dialog.set_data(text, message_initial_config)


func convert_to_simple_text_edit() -> void:
	%TopButtonContainer.propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	%TopButtonContainer.visible = false
	%BottomButtonContainer.propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	%BottomButtonContainer.visible = false


func _on_timer_timeout() -> void:
	var node = %TextEdit
	if preview_message_dialog and node:
		var text = node.text
		if text == old_text: 
			return
		old_text = text
		if dialog_mode == 0:
			preview_message_dialog.set_text(text, message_initial_config)
		else:
			preview_message_dialog.set_data(text, message_initial_config)
			


func _on_multiply_speed_value_changed(value: float) -> void:
	message_initial_config.multiply_speed = value
	preview_need_refresh = true


func _on_change_blip_fx_pressed(file_selected: String = "", volume: float = 0.0, pitch: float = 1.0, pitch2: float = 1.0) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	if volume == 0.0 and pitch == 1.0 and "blip" in cache and cache["blip"]:
		volume = cache["blip"].get("volume", 0.0)
		pitch = cache["blip"].get("pitch", 1.0)
		pitch2 = cache["blip"].get("pitch2", 1.0)
		
	var commands: Array[RPGEventCommand]
	var command = RPGEventCommand.new(0, 0, {"path": file_selected, "volume": volume, "pitch": pitch, "pitch2": pitch2})
	commands.append(command)
	dialog.enable_random_pitch()
	dialog.set_parameters(commands)
	dialog.set_data()
	dialog.command_changed.connect(_on_blip_fx_selected)


func _on_blip_fx_selected(commands: Array[RPGEventCommand]) -> void:
	if commands.size() > 0:
		var command_data = commands[0].parameters
		var path = command_data.get("path", "")
		var volume = command_data.get("volume", 0)
		var pitch = command_data.get("pitch", 1)
		var pitch2 = command_data.get("pitch2", 1)
		if path:
			var arg1 = "path=\"%s\"" % path
			var arg2 = "" if volume == 0.0 else " volume=%s" % volume
			var arg3 = "" if pitch == 1.0 else " pitch=%s" % pitch
			var arg4 = "" if pitch2 == 1.0 else " pitch2=%s" % pitch2
			var bbcode = "[blip %s%s%s%s]" % [arg1, arg2, arg3, arg4]
			cache["blip"] = {
				"volume": volume,
				"pitch": pitch,
				"pitch2": pitch2,
			}
			insert_or_replace_text(bbcode)


func click_on_command_show_speaker_dialog(command: Dictionary = {}) -> void:
	var path = "res://addons/CustomControls/Dialogs/show_speaker_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_selected(int(command.get("args", 1)))
	dialog.speaker_selected.connect(
		func(index: int):
			var selection_data = get_selection()
			var text_selected: String = ""
			if "command_selected" in selection_data.selection and \
				not selection_data.selection.command_selected.is_empty():
					text_selected = selection_data.selection.command_selected.text
			elif "text" in selection_data.selection:
				text_selected = selection_data.selection.text
			var regex = RegEx.new()
			regex.compile("\\[([^\\[\\]]*)\\](?=[^\\[\\]]*$)")
			text_selected = regex.sub(text_selected, "", true)
			var bbcode = "[speaker index=%s]%s[speaker_end index=%s]" % [index, text_selected, index]
			insert_or_replace_text(bbcode)
			if text_selected.is_empty():
				var l = "[speaker index=%s]" % index
				%TextEdit.set_caret_column(selection_data.column + l.length())
				
	)


func click_on_command_hide_speaker_dialog(command: Dictionary = {}) -> void:
	var path = "res://addons/CustomControls/Dialogs/show_speaker_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_selected(int(command.get("args", 1)))
	dialog.speaker_selected.connect(
		func(index: int):
			var bbcode = "[hide_speaker index=%s]" % index
			insert_or_replace_text(bbcode)
	)


func _on_reset_config_pressed() -> void:
	insert_or_replace_text("[r]")


func _on_pause_dialog_pressed() -> void:
	insert_or_replace_text("[freeze]")


func _on_display_as_floating_dialog_toggled(toggled_on: bool) -> void:
	message_initial_config.is_floating_dialog = toggled_on
	%Target.visible = toggled_on


func _on_instant_text_toggled(toggled_on: bool) -> void:
	message_initial_config.ignore_letter_by_letter = toggled_on


func _on_targets_item_selected(index: int) -> void:
	var node: OptionButton = %Target
	var real_index = int(node.get_item_metadata(index))
	message_initial_config.floating_target = real_index


func _on_change_speaker_active_pressed(command: Dictionary = {}) -> void:
	var path = "res://addons/CustomControls/Dialogs/highlight_character_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_data(command)
	dialog.command_selected.connect(
		func(new_command_mode: int, new_pos: int):
			var bbcode = "[highlight_character mode=%s pos=%s]" % [new_command_mode, new_pos]
			insert_or_replace_text(bbcode)
	)


func _on_nowait_for_input_toggled(toggled_on: bool) -> void:
	message_initial_config.no_wait_for_input = toggled_on


func _on_new_line_pressed() -> void:
	insert_or_replace_text("[newline]")
