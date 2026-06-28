@tool
extends EditorPlugin

var main_screen: Control
var overlay: ColorRect
var progress_label: Label
var progress_bar: ProgressBar
var lang_option: OptionButton
var service_option: OptionButton
var token_line: LineEdit
var http_request: HTTPRequest
var btn_cancel: Button
var status_label: Label
var _cancel_requested: bool = false
var _maximum_translations: int = 0 # 0 = translate all texts. > 0 = translate only this many for debugging.

func _enter_tree():
	main_screen = Control.new()
	main_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_screen.add_child(center_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	center_container.add_child(vbox)
	
	var title = Label.new()
	title.text = "RPG Creator Translation Tool"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	var btn_base = Button.new()
	btn_base.text = "Generate Base Translation Files (.po)"
	btn_base.custom_minimum_size = Vector2(300, 40)
	btn_base.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_base.pressed.connect(_on_generate_base_pressed)
	vbox.add_child(btn_base)
	
	vbox.add_child(HSeparator.new())
	
	var hbox_lang = HBoxContainer.new()
	var lbl_lang = Label.new()
	lbl_lang.text = "Target Language:"
	lbl_lang.custom_minimum_size = Vector2(130, 0)
	hbox_lang.add_child(lbl_lang)
	lang_option = OptionButton.new()
	lang_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var langs = {"es": "Spanish", "en": "English", "fr": "French", "de": "German", "it": "Italian", "ja": "Japanese", "ko": "Korean", "zh": "Chinese", "pt": "Portuguese", "ru": "Russian"}
	var i = 0
	for code in langs:
		lang_option.add_item(langs[code] + " (" + code + ")", i)
		lang_option.set_item_metadata(i, code)
		i += 1
	hbox_lang.add_child(lang_option)
	vbox.add_child(hbox_lang)
	
	var hbox_svc = HBoxContainer.new()
	var lbl_svc = Label.new()
	lbl_svc.text = "Translation Service:"
	lbl_svc.custom_minimum_size = Vector2(130, 0)
	hbox_svc.add_child(lbl_svc)
	service_option = OptionButton.new()
	service_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	service_option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	service_option.add_item("Google Translate (Free)")
	service_option.add_item("OpenAI (ChatGPT)")
	service_option.add_item("Google Gemini")
	service_option.item_selected.connect(_on_service_selected)
	hbox_svc.add_child(service_option)
	vbox.add_child(hbox_svc)
	
	token_line = LineEdit.new()
	token_line.placeholder_text = "API Token/Key"
	token_line.secret = true
	token_line.hide()
	vbox.add_child(token_line)
	
	var btn_auto = Button.new()
	btn_auto.text = "Auto-Translate and Generate (.po)"
	btn_auto.custom_minimum_size = Vector2(300, 40)
	btn_auto.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_auto.pressed.connect(_on_generate_auto_pressed)
	vbox.add_child(btn_auto)
	
	status_label = Label.new()
	status_label.text = "Status: Ready"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(status_label)
	
	# Block Overlay
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	
	var overlay_center = CenterContainer.new()
	overlay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(overlay_center)
	
	var overlay_vbox = VBoxContainer.new()
	overlay_vbox.custom_minimum_size = Vector2(400, 0)
	overlay_vbox.add_theme_constant_override("separation", 10)
	overlay_center.add_child(overlay_vbox)
	
	progress_label = Label.new()
	progress_label.text = "Translating: 0 / 0"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_vbox.add_child(progress_label)
	
	progress_bar = ProgressBar.new()
	overlay_vbox.add_child(progress_bar)
	
	btn_cancel = Button.new()
	btn_cancel.text = "Cancel Translation"
	btn_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_cancel.pressed.connect(func(): _cancel_requested = true)
	overlay_vbox.add_child(btn_cancel)
	
	main_screen.add_child(overlay)
	
	http_request = HTTPRequest.new()
	main_screen.add_child(http_request)
	
	get_editor_interface().get_editor_main_screen().add_child(main_screen)
	main_screen.hide()

func _exit_tree():
	if main_screen:
		main_screen.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_screen:
		main_screen.visible = visible

func _get_plugin_name():
	return "Translations"

func _get_plugin_icon():
	return get_editor_interface().get_base_control().get_theme_icon(&"Translation", &"EditorIcons")

func _on_service_selected(idx: int):
	if idx > 0:
		token_line.show()
	else:
		token_line.hide()

func _on_generate_base_pressed():
	status_label.text = "Status: Generating base files, one moment..."
	await get_tree().process_frame
	_process_generation(false)

func _on_generate_auto_pressed():
	if service_option.selected > 0 and token_line.text.strip_edges().is_empty():
		_show_error_dialog("Please enter an API token for the selected service.")
		return
	status_label.text = "Status: Translating and generating files, one moment..."
	await get_tree().process_frame
	_process_generation(true)

func _process_generation(auto_translate: bool):
	var database = RPGSYSTEM.database
	if not database:
		database = DatabaseLoader.load_database()
	if not database:
		_show_error_dialog("Failed to load database. Please save or initialize the database first.")
		return
		
	var db_texts = _extract_db_texts(database)
	var event_texts = _extract_event_texts(database, db_texts)
	var script_texts = _extract_script_texts(db_texts, event_texts)
	
	var translated_dict = {}
	var target_lang = "en"
	
	if auto_translate:
		target_lang = lang_option.get_item_metadata(lang_option.selected)
		var target_lang_name = lang_option.get_item_text(lang_option.selected).split(" ")[0]
		
		var service = service_option.selected
		var token = token_line.text.strip_edges()
		
		var all_keys = []
		for k in db_texts.keys():
			if not all_keys.has(k): all_keys.append(k)
		for k in event_texts.keys():
			if not all_keys.has(k): all_keys.append(k)
		for k in script_texts.keys():
			if not all_keys.has(k): all_keys.append(k)
			
		var total_to_translate = all_keys.size()
		if _maximum_translations > 0 and _maximum_translations < total_to_translate:
			total_to_translate = _maximum_translations
			
		overlay.show()
		progress_bar.max_value = total_to_translate
		progress_bar.value = 0
		progress_label.text = "Translating: 0 / %d" % total_to_translate
		_cancel_requested = false
		
		if service == 0: # Google Free (Batched)
			var current_batch = []
			var current_length = 0
			var processed_count = 0
			
			for i in range(total_to_translate):
				if _cancel_requested:
					break
					
				var text = all_keys[i]
				
				if current_length + text.length() > 3000 or current_batch.size() >= 30:
					var batch_results = await _translate_google_free_batch(current_batch, target_lang)
					for k in batch_results:
						translated_dict[k] = batch_results[k]
					
					processed_count += current_batch.size()
					progress_bar.value = processed_count
					progress_label.text = "Translating: %d / %d" % [processed_count, total_to_translate]
					
					current_batch = []
					current_length = 0
					await get_tree().create_timer(1.0).timeout # Cooldown between batches
					
				current_batch.append(text)
				current_length += text.length()
				
			if not current_batch.is_empty() and not _cancel_requested:
				var batch_results = await _translate_google_free_batch(current_batch, target_lang)
				for k in batch_results:
					translated_dict[k] = batch_results[k]
				processed_count += current_batch.size()
				progress_bar.value = processed_count
				progress_label.text = "Translating: %d / %d" % [processed_count, total_to_translate]
				
		else: # OpenAI / Gemini (Individual)
			for i in range(total_to_translate):
				if _cancel_requested:
					break
					
				var text = all_keys[i]
				var translated = text
				
				if service == 1: # OpenAI
					translated = await _translate_openai(text, target_lang_name, token)
					await get_tree().create_timer(0.1).timeout
				elif service == 2: # Gemini
					translated = await _translate_gemini(text, target_lang_name, token)
					await get_tree().create_timer(0.1).timeout
					
				translated_dict[text] = translated
				
				progress_bar.value = i + 1
				progress_label.text = "Translating: %d / %d" % [i + 1, total_to_translate]
			
		overlay.hide()
		
		if _cancel_requested:
			status_label.text = "Status: Translation cancelled."
			_show_info_dialog("Translation cancelled by user.")
			return
		
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("translations"):
		dir.make_dir("translations")
		
	var suffix = ".po"
	if auto_translate:
		suffix = "." + target_lang + ".po"
		
	_write_po_file("res://translations/database" + suffix, db_texts, translated_dict, target_lang)
	_write_po_file("res://translations/events" + suffix, event_texts, translated_dict, target_lang)
	_write_po_file("res://translations/scripts" + suffix, script_texts, translated_dict, target_lang)
	
	# Automatically register files in Godot Project Settings
	_add_translation_to_project_settings("res://translations/database" + suffix)
	_add_translation_to_project_settings("res://translations/events" + suffix)
	_add_translation_to_project_settings("res://translations/scripts" + suffix)
	
	status_label.text = "Status: Files generated and registered successfully."
	_show_info_dialog("Translation files (" + suffix + ") generated and registered in Project Settings successfully!")

func _translate_google_free(text: String, lang: String) -> String:
	var url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" + lang + "&dt=t&q=" + text.uri_encode()
	http_request.request(url)
	var result = await http_request.request_completed
	if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			var data = json.get_data()
			if data is Array and data.size() > 0 and data[0] is Array:
				var res_text = ""
				for part in data[0]:
					if part is Array and part.size() > 0:
						res_text += str(part[0])
				return res_text
	elif result[1] != 200:
		printerr("Google Translate API Error (", result[1], "): ", result[3].get_string_from_utf8() if result[3] else "")
	return text

func _translate_google_free_batch(batch: Array, lang: String) -> Dictionary:
	var results = {}
	if batch.is_empty(): return results
	
	# Default fallback to original texts
	for text in batch:
		results[text] = text
		
	var separator = "\n###\n"
	var joined_text = separator.join(batch)
	
	var url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" + lang + "&dt=t"
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = "q=" + joined_text.uri_encode()
	
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	var result = await http_request.request_completed
	
	var success = false
	if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			var data = json.get_data()
			if data is Array and data.size() > 0 and data[0] is Array:
				var full_translation = ""
				for part in data[0]:
					if part is Array and part.size() > 0:
						full_translation += str(part[0])
				
				# Split by ###. Strip edges of each part.
				var split_parts = full_translation.split("###")
				
				var cleaned_parts = []
				for p in split_parts:
					cleaned_parts.append(p.strip_edges())
					
				# If we have one extra empty part at the end, pop it
				if cleaned_parts.size() == batch.size() + 1 and cleaned_parts[cleaned_parts.size() - 1] == "":
					cleaned_parts.pop_back()
					
				if cleaned_parts.size() == batch.size():
					for idx in range(batch.size()):
						results[batch[idx]] = cleaned_parts[idx]
					success = true
				else:
					printerr("Google Batch size mismatch: got ", cleaned_parts.size(), ", expected ", batch.size(), ". Falling back to individual. Response: ", full_translation)
	elif result[1] != 200:
		printerr("Google Batch API Error (", result[1], "): ", result[3].get_string_from_utf8() if result[3] else "")
		
	if not success:
		# Fallback: translate individually
		for text in batch:
			if _cancel_requested: break
			var translated = await _translate_google_free(text, lang)
			results[text] = translated
			await get_tree().create_timer(1.0).timeout
			
	return results

func _translate_openai(text: String, lang: String, token: String) -> String:
	var url = "https://api.openai.com/v1/chat/completions"
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + token]
	var body = {
		"model": "gpt-3.5-turbo",
		"messages": [
			{"role": "system", "content": "You are a translation engine. Translate the following text to " + lang + ". Respond ONLY with the translated text without quotes or explanations."},
			{"role": "user", "content": text}
		]
	}
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	var result = await http_request.request_completed
	if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("choices") and data["choices"].size() > 0:
				return data["choices"][0]["message"]["content"].strip_edges()
	return text

func _translate_gemini(text: String, lang: String, token: String) -> String:
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=" + token
	var headers = ["Content-Type: application/json"]
	var body = {
		"contents": [{
			"parts": [{"text": "Translate the following text to " + lang + ". Respond ONLY with the translated text without quotes or explanations. Text:\n" + text}]
		}]
	}
	
	var retries = 3
	while retries > 0:
		http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
		var result = await http_request.request_completed
		if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
			var raw_response = result[3].get_string_from_utf8()
			var json = JSON.new()
			if json.parse(raw_response) == OK:
				var data = json.get_data()
				if data is Dictionary and data.has("candidates") and data["candidates"].size() > 0:
					var candidate = data["candidates"][0]
					if candidate.has("content") and candidate["content"].has("parts") and candidate["content"]["parts"].size() > 0:
						return candidate["content"]["parts"][0]["text"].strip_edges()
					else:
						printerr("Gemini: Missing content/parts in candidate.")
				else:
					printerr("Gemini: Missing candidates or unexpected format.")
			else:
				printerr("Gemini: JSON parse failed.")
			break
		elif result[1] == 503:
			retries -= 1
			printerr("Gemini busy (503), retrying in 2 seconds... (Retries left: ", retries, ")")
			await get_tree().create_timer(2.0).timeout
		else:
			if result[1] != 200:
				printerr("Gemini API Error (", result[1], "): ", result[3].get_string_from_utf8() if result[3] else "")
			break
	return text

func _write_po_file(path: String, unique_texts: Dictionary, translated_dict: Dictionary, lang: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		printerr("Cannot write to file: ", path)
		return
	
	var time = Time.get_datetime_dict_from_system()
	var date_str = "%d-%02d-%02d" % [time.year, time.month, time.day]
	
	file.store_string("msgid \"\"\n")
	file.store_string("msgstr \"\"\n")
	file.store_string("\"Project-Id-Version: Godot RPG Creator\\n\"\n")
	file.store_string("\"POT-Creation-Date: " + date_str + "\\n\"\n")
	file.store_string("\"PO-Revision-Date: \\n\"\n")
	file.store_string("\"Last-Translator: \\n\"\n")
	file.store_string("\"Language-Team: \\n\"\n")
	file.store_string("\"Language: " + lang + "\\n\"\n")
	file.store_string("\"MIME-Version: 1.0\\n\"\n")
	file.store_string("\"Content-Type: text/plain; charset=UTF-8\\n\"\n")
	file.store_string("\"Content-Transfer-Encoding: 8bit\\n\"\n")
	file.store_string("\"X-Source-Language: en\\n\"\n\n")
	
	var sorted_keys = unique_texts.keys()
	sorted_keys.sort()
	
	for text in sorted_keys:
		var contexts = unique_texts[text]
		for ctx in contexts:
			file.store_string("#: " + ctx + "\n")
		var escaped = _escape_po_string(text)
		file.store_string("msgid \"" + escaped + "\"\n")
		
		var msgstr = ""
		if translated_dict.has(text):
			msgstr = _escape_po_string(translated_dict[text])
			
		file.store_string("msgstr \"" + msgstr + "\"\n\n")
	
	file.close()

func _escape_po_string(s: String) -> String:
	s = s.replace("\\", "\\\\")
	s = s.replace("\"", "\\\"")
	s = s.replace("\n", "\\n")
	s = s.replace("\r", "")
	return s

func _show_error_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()

func _show_info_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Success"
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()

func _extract_db_texts(database) -> Dictionary:
	var db_texts = {}
	var add_db_text = func(txt: String, context: String):
		if txt != null and not txt.is_empty():
			if not db_texts.has(txt):
				db_texts[txt] = []
			if not db_texts[txt].has(context):
				db_texts[txt].append(context)
				
	for actor in database.actors:
		if actor:
			var id_str = str(actor.id)
			var act_name = actor.name if not actor.name.is_empty() else "Unnamed"
			add_db_text.call(actor.name, "Database/Actors/%s %s (Name)" % [id_str, act_name])
			add_db_text.call(actor.nickname, "Database/Actors/%s %s (Nickname)" % [id_str, act_name])
			add_db_text.call(actor.profile, "Database/Actors/%s %s (Profile)" % [id_str, act_name])
			
	for cls in database.classes:
		if cls:
			var id_str = str(cls.id)
			var cls_name = cls.name if not cls.name.is_empty() else "Unnamed"
			add_db_text.call(cls.name, "Database/Classes/%s %s (Name)" % [id_str, cls_name])
			add_db_text.call(cls.description, "Database/Classes/%s %s (Description)" % [id_str, cls_name])
			
	for prof in database.professions:
		if prof:
			var id_str = str(prof.id)
			var prof_name = prof.name if not prof.name.is_empty() else "Unnamed"
			add_db_text.call(prof.name, "Database/Professions/%s %s (Name)" % [id_str, prof_name])
			add_db_text.call(prof.description, "Database/Professions/%s %s (Description)" % [id_str, prof_name])
			
	for skill in database.skills:
		if skill:
			var id_str = str(skill.id)
			var skill_name = skill.name if not skill.name.is_empty() else "Unnamed"
			add_db_text.call(skill.name, "Database/Skills/%s %s (Name)" % [id_str, skill_name])
			add_db_text.call(skill.description, "Database/Skills/%s %s (Description)" % [id_str, skill_name])
			add_db_text.call(skill.battle_message, "Database/Skills/%s %s (Battle Message)" % [id_str, skill_name])
			
	for item in database.items:
		if item:
			var id_str = str(item.id)
			var item_name = item.name if not item.name.is_empty() else "Unnamed"
			add_db_text.call(item.name, "Database/Items/%s %s (Name)" % [id_str, item_name])
			add_db_text.call(item.description, "Database/Items/%s %s (Description)" % [id_str, item_name])
			
	for weapon in database.weapons:
		if weapon:
			var id_str = str(weapon.id)
			var weapon_name = weapon.name if not weapon.name.is_empty() else "Unnamed"
			add_db_text.call(weapon.name, "Database/Weapons/%s %s (Name)" % [id_str, weapon_name])
			add_db_text.call(weapon.description, "Database/Weapons/%s %s (Description)" % [id_str, weapon_name])
			
	for armor in database.armors:
		if armor:
			var id_str = str(armor.id)
			var armor_name = armor.name if not armor.name.is_empty() else "Unnamed"
			add_db_text.call(armor.name, "Database/Armors/%s %s (Name)" % [id_str, armor_name])
			add_db_text.call(armor.description, "Database/Armors/%s %s (Description)" % [id_str, armor_name])
			
	for costume in database.costumes:
		if costume:
			var id_str = str(costume.id)
			var costume_name = costume.name if not costume.name.is_empty() else "Unnamed"
			add_db_text.call(costume.name, "Database/Costumes/%s %s (Name)" % [id_str, costume_name])
			add_db_text.call(costume.description, "Database/Costumes/%s %s (Description)" % [id_str, costume_name])
			
	for enemy in database.enemies:
		if enemy:
			var id_str = str(enemy.id)
			var enemy_name = enemy.name if not enemy.name.is_empty() else "Unnamed"
			add_db_text.call(enemy.name, "Database/Enemies/%s %s (Name)" % [id_str, enemy_name])
			add_db_text.call(enemy.description, "Database/Enemies/%s %s (Description)" % [id_str, enemy_name])
			add_db_text.call(enemy.unknown_description, "Database/Enemies/%s %s (Unknown Description)" % [id_str, enemy_name])
			
	for troop in database.troops:
		if troop:
			var id_str = str(troop.id)
			var troop_name = troop.name if not troop.name.is_empty() else "Unnamed"
			add_db_text.call(troop.name, "Database/Troops/%s %s (Name)" % [id_str, troop_name])
			
	for state in database.states:
		if state:
			var id_str = str(state.id)
			var state_name = state.name if not state.name.is_empty() else "Unnamed"
			add_db_text.call(state.name, "Database/States/%s %s (Name)" % [id_str, state_name])
			add_db_text.call(state.description, "Database/States/%s %s (Description)" % [id_str, state_name])
			for msg in state.messages:
				if msg:
					add_db_text.call(msg.message, "Database/States/%s %s/Message %s" % [id_str, state_name, msg.id])
					
	for anim in database.animations:
		if anim:
			var id_str = str(anim.id)
			var anim_name = anim.name if not anim.name.is_empty() else "Unnamed"
			add_db_text.call(anim.name, "Database/Animations/%s %s (Name)" % [id_str, anim_name])
			
	for spk in database.speakers:
		if spk:
			var spk_name = "Unnamed"
			if spk.name is Dictionary and spk.name.get("type", 0) == 0:
				spk_name = spk.name.get("val", "")
				add_db_text.call(spk_name, "Database/Speakers/%s (Constant Name)" % spk_name)
				
	for quest in database.quests:
		if quest:
			var id_str = str(quest.id)
			var quest_name = quest.name if not quest.name.is_empty() else "Unnamed"
			add_db_text.call(quest.name, "Database/Quests/%s %s (Name)" % [id_str, quest_name])
			add_db_text.call(quest.category, "Database/Quests/%s %s (Category)" % [id_str, quest_name])
			add_db_text.call(quest.description, "Database/Quests/%s %s (Description)" % [id_str, quest_name])
			
	for term in database.terms.messages:
		if term:
			add_db_text.call(term.text, "Database/Terms/%s" % term.id)
			
	var process_type_array = func(arr: PackedStringArray, arr_name: String):
		for val in arr:
			add_db_text.call(val, "Database/Types/%s/%s" % [arr_name, val])
			
	process_type_array.call(database.types.element_types, "element_types")
	process_type_array.call(database.types.skill_types, "skill_types")
	process_type_array.call(database.types.weapon_types, "weapon_types")
	process_type_array.call(database.types.weapon_rarity_types, "weapon_rarity_types")
	process_type_array.call(database.types.armor_types, "armor_types")
	process_type_array.call(database.types.tool_types, "tool_types")
	process_type_array.call(database.types.armor_rarity_types, "armor_rarity_types")
	process_type_array.call(database.types.enemy_rarity_types, "enemy_rarity_types")
	process_type_array.call(database.types.item_types, "item_types")
	process_type_array.call(database.types.item_rarity_types, "item_rarity_types")
	process_type_array.call(database.types.gender_types, "gender_types")
	process_type_array.call(database.types.equipment_types, "equipment_types")
	process_type_array.call(database.types.main_parameters, "main_parameters")
	process_type_array.call(database.types.user_stats, "user_stats")

	for user_param in database.types.user_parameters:
		if user_param:
			add_db_text.call(user_param.name, "Database/Types/UserParameter/%s" % user_param.name)
			add_db_text.call(user_param.abbreviation_name, "Database/Types/UserParameter/%s (Abbr)" % user_param.name)

	for ce in database.common_events:
		if ce:
			var ce_name = ce.name if not ce.name.is_empty() else "Unnamed"
			_extract_from_commands(ce.list, db_texts, "Database/CommonEvents/%d %s" % [ce.id, ce_name])
			
	return db_texts

func _extract_event_texts(database, exclude_dict: Dictionary = {}) -> Dictionary:
	var event_texts = {}
	var map_dir = DirAccess.open("res://data/MapEvents/")
	if map_dir:
		map_dir.list_dir_begin()
		var file_name = map_dir.get_next()
		while file_name != "":
			if not map_dir.current_is_dir() and file_name.ends_with("_events.tres"):
				var path = "res://data/MapEvents/" + file_name
				var map_events_res = ResourceLoader.load(path)
				if map_events_res and "events" in map_events_res:
					for event in map_events_res.events:
						if event:
							var ev_name = event.name if not event.name.is_empty() else "Unnamed"
							for p_idx in range(event.pages.size()):
								var page = event.pages[p_idx]
								if page:
									_extract_from_commands(page.list, event_texts, "Map/%s, Event: %s (%d), Page: %d" % [file_name, ev_name, event.id, p_idx], exclude_dict)
			file_name = map_dir.get_next()
		map_dir.list_dir_end()
	return event_texts

func _extract_from_commands(commands: Array, unique_set: Dictionary, ctx_prefix: String, exclude_dict: Dictionary = {}):
	var idx = 0
	while idx < commands.size():
		var cmd = commands[idx]
		if not cmd:
			idx += 1
			continue
		
		var add_event_text = func(txt: String, cmd_idx: int, cmd_info: String):
			if txt != null and not txt.is_empty():
				if exclude_dict.has(txt):
					return
				var full_ctx = "%s, Command %d %s" % [ctx_prefix, cmd_idx, cmd_info]
				if not unique_set.has(txt):
					unique_set[txt] = []
				if not unique_set[txt].has(full_ctx):
					unique_set[txt].append(full_ctx)
					
		if cmd.code == 2:
			var character_data = cmd.parameters.get("character_name")
			if character_data is Dictionary and character_data.get("type", 0) == 0:
				var value = character_data.get("value", "")
				if typeof(value) == TYPE_STRING and not value.is_empty():
					add_event_text.call(value, idx, "(Code 2 Dialog Speaker)")
			
			var dialog_lines = []
			var first_line_idx = idx + 1
			var look_idx = idx + 1
			while look_idx < commands.size():
				var next_cmd = commands[look_idx]
				if not next_cmd:
					look_idx += 1
					continue
				if next_cmd.get("ignore_command"):
					look_idx += 1
					continue
				if next_cmd.code == 3:
					var line = next_cmd.parameters.get("line", "")
					if typeof(line) == TYPE_STRING:
						dialog_lines.append(line)
					look_idx += 1
				else:
					break
					
			if dialog_lines.size() > 0:
				var combined = "\n".join(dialog_lines)
				add_event_text.call(combined, first_line_idx, "(Code 3 Dialog Message)")
			idx = look_idx
			continue
			
		elif cmd.code == 10:
			var scroll_lines = []
			var first_line_idx = idx + 1
			var look_idx = idx + 1
			while look_idx < commands.size():
				var next_cmd = commands[look_idx]
				if not next_cmd:
					look_idx += 1
					continue
				if next_cmd.get("ignore_command"):
					look_idx += 1
					continue
				if next_cmd.code == 11:
					var line = next_cmd.parameters.get("line", "")
					if typeof(line) == TYPE_STRING:
						scroll_lines.append(line)
					look_idx += 1
				else:
					break
					
			if scroll_lines.size() > 0:
				var combined = "\n".join(scroll_lines)
				add_event_text.call(combined, first_line_idx, "(Code 11 Scrolling Message)")
			idx = look_idx
			continue
			
		elif cmd.code == 5:
			var name = cmd.parameters.get("name", "")
			if typeof(name) == TYPE_STRING and not name.is_empty():
				add_event_text.call(name, idx, "(Code 5 Choice Option)")
		elif cmd.code == 3:
			var line = cmd.parameters.get("line", "")
			if typeof(line) == TYPE_STRING and not line.is_empty():
				add_event_text.call(line, idx, "(Code 3 Dialog Message - Ungrouped)")
		elif cmd.code == 11:
			var line = cmd.parameters.get("line", "")
			if typeof(line) == TYPE_STRING and not line.is_empty():
				add_event_text.call(line, idx, "(Code 11 Scrolling Message - Ungrouped)")
				
		idx += 1

func _extract_script_texts(exclude_dict1: Dictionary = {}, exclude_dict2: Dictionary = {}) -> Dictionary:
	var script_texts = {}
	_scan_dir_for_scripts("res://", script_texts, exclude_dict1, exclude_dict2)
	return script_texts

func _scan_dir_for_scripts(dir_path: String, results: Dictionary, exclude_dict1: Dictionary = {}, exclude_dict2: Dictionary = {}) -> void:
	if dir_path.contains("CreateTranslationFiles") or dir_path.contains("SimpleTODO"):
		return
		
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != ".." and not file_name.begins_with("."):
					_scan_dir_for_scripts(dir_path + file_name + "/", results, exclude_dict1, exclude_dict2)
			else:
				if file_name.ends_with(".gd"):
					_scan_file_for_tr(dir_path + file_name, results, exclude_dict1, exclude_dict2)
				elif file_name.ends_with(".tscn"):
					if not dir_path.contains("res://addons/"):
						_scan_scene_file_for_tr(dir_path + file_name, results, exclude_dict1, exclude_dict2)
			file_name = dir.get_next()
		dir.list_dir_end()

func _scan_file_for_tr(file_path: String, results: Dictionary, exclude_dict1: Dictionary = {}, exclude_dict2: Dictionary = {}) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file: return
	
	var line_number = 1
	var regex = RegEx.new()
	regex.compile("tr\\(\\s*&?\\s*(?:\"((?:[^\"\\\\]|\\\\.)*)\"|'((?:[^'\\\\]|\\\\.)*)')\\s*\\)")
	
	while not file.eof_reached():
		var line = file.get_line()
		var matches = regex.search_all(line)
		for m in matches:
			var text = ""
			if m.get_string(1) != "":
				text = m.get_string(1)
			else:
				text = m.get_string(2)
				
			text = text.replace("\\\"", "\"").replace("\\'", "'").replace("\\\\", "\\").replace("\\n", "\n")
			
			if not text.is_empty() and not exclude_dict1.has(text) and not exclude_dict2.has(text):
				if not results.has(text):
					results[text] = []
				var context = "%s:Line %d" % [file_path.get_file(), line_number]
				if not results[text].has(context):
					results[text].append(context)
		line_number += 1
	file.close()

func _add_translation_to_project_settings(path: String) -> void:
	var setting = "locale/translations"
	var list: PackedStringArray = []
	if ProjectSettings.has_setting(setting):
		list = ProjectSettings.get_setting(setting)
	
	if not list.has(path):
		list.append(path)
		ProjectSettings.set_setting(setting, list)
		ProjectSettings.save()
		print("Added translation to project settings: ", path)

func _scan_scene_file_for_tr(file_path: String, results: Dictionary, exclude_dict1: Dictionary = {}, exclude_dict2: Dictionary = {}) -> void:
	var scene = ResourceLoader.load(file_path)
	if not scene is PackedScene: return
	
	var state: SceneState = scene.get_state()
	if not state: return
	
	for node_idx in state.get_node_count():
		for prop_idx in state.get_node_property_count(node_idx):
			var prop_name = state.get_node_property_name(node_idx, prop_idx)
			
			if prop_name == &"text" or prop_name == &"tooltip_text" or prop_name == &"placeholder_text" or prop_name == &"dialog_text" or prop_name == &"title":
				var prop_val = state.get_node_property_value(node_idx, prop_idx)
				if typeof(prop_val) == TYPE_STRING or typeof(prop_val) == TYPE_STRING_NAME:
					var text = str(prop_val).strip_edges()
					if not text.is_empty() and not exclude_dict1.has(text) and not exclude_dict2.has(text):
						if not results.has(text):
							results[text] = []
						var node_name = state.get_node_name(node_idx)
						var context = "%s:Node %s (Prop %s)" % [file_path.get_file(), node_name, prop_name]
						if not results[text].has(context):
							results[text].append(context)
							
			elif prop_name == &"items":
				var prop_val = state.get_node_property_value(node_idx, prop_idx)
				if typeof(prop_val) == TYPE_ARRAY:
					for item in prop_val:
						if typeof(item) == TYPE_STRING or typeof(item) == TYPE_STRING_NAME:
							var text = str(item).strip_edges()
							if not text.is_empty() and not exclude_dict1.has(text) and not exclude_dict2.has(text):
								if not results.has(text):
									results[text] = []
								var node_name = state.get_node_name(node_idx)
								var context = "%s:Node %s (Prop %s)" % [file_path.get_file(), node_name, prop_name]
								if not results[text].has(context):
									results[text].append(context)
