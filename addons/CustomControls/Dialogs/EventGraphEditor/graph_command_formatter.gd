@tool
class_name GraphCommandFormatter
extends RefCounted

static var _formatter: Node = null

static func get_formatter() -> Node:
	var ml = Engine.get_main_loop()
	if not (ml and ml is SceneTree and ml.root and ml.root.has_node("RPGSYSTEM")):
		return null
		
	if not _formatter or not is_instance_valid(_formatter):
		var sc = load("res://addons/CustomControls/formatter.gd")
		if sc:
			_formatter = sc.new()
			_formatter.set_config({
				"default_text": "",
				"default_no_editable_text": ""
			})
	return _formatter


static func get_formatted_text(command: RPGEventCommand, sub_commands: Array[RPGEventCommand] = []) -> String:
	if not command:
		return ""
		
	var fmt = get_formatter()
	if not fmt:
		return _fallback_summary(command, sub_commands)
		
	var out_text = ""
	
	# Execute code_format with isolated indentation
	var dummy = command.duplicate()
	dummy.indent = 0
	
	# Safe call in case database or RPGSYSTEM is uninitialized
	var code_res = {}
	if fmt.has_method("get_formatted_code"):
		code_res = fmt.get_formatted_code(dummy, ThemeDB.fallback_font, 11, HORIZONTAL_ALIGNMENT_LEFT, 0, 0)
		
	if code_res.has("phrases") and not code_res.phrases.is_empty():
		for phrase in code_res.phrases:
			for t in phrase.get("texts", []):
				out_text += t.get("text", "")
				
	out_text = out_text.strip_edges()
	if out_text.begins_with("↪️") or out_text.begins_with("▪️"):
		out_text = out_text.substr(2).strip_edges()
		
	if out_text.is_empty():
		return _fallback_summary(command, sub_commands)
		
	return out_text


static func get_header_for_text_command(command: RPGEventCommand) -> String:
	if not command: return "Dialog Text:"
	var p = command.parameters
	var char_name = ""
	var cdata = p.get("character_name", null)
	if cdata is Dictionary:
		char_name = str(cdata.get("value", ""))
	elif cdata != null:
		char_name = str(cdata)
		
	var face = p.get("face", null)
	var face_name = ""
	if face is RPGIcon and not face.path.is_empty():
		face_name = face.path.get_file()
	elif face is Dictionary and face.has("path") and not str(face.path).is_empty():
		face_name = str(face.path).get_file()
		
	var parts = []
	if not char_name.is_empty():
		parts.append("Name: " + char_name)
	if not face_name.is_empty():
		parts.append("Face: " + face_name)
	var pos = "Left" if p.get("position", 0) == 0 else "Right"
	parts.append("Pos: " + pos)
	
	if p.get("is_floating_dialog", false):
		parts.append("Floating")
		
	return "Dialog [%s]:" % ", ".join(parts)


static func _fallback_summary(command: RPGEventCommand, sub_commands: Array[RPGEventCommand] = []) -> String:
	var code = command.code
	var p = command.parameters
	match code:
		2:
			var txt = ""
			for sub in sub_commands:
				if sub.code == 3:
					txt += sub.parameters.get("line", "") + "\n"
			return "Text:\n" + txt.strip_edges()
		17:
			var state = "ON" if p.get("operation_type", 0) == 0 else "OFF"
			return "Switch [%d] = %s" % [p.get("from", 1), state]
		18:
			var ops = ["=", "+=", "-=", "*=", "/=", "%="]
			var op = ops[min(p.get("operation_type", 0), 5)]
			return "Var [%d] %s %s" % [p.get("from", 1), op, p.get("value1", 0)]
		21:
			var item_sel = p.get("item_selected", 0)
			match item_sel:
				0:
					var state = "ON" if p.get("value2", 0) == 0 else "OFF"
					return "If Switch [%s] is %s" % [p.get("value1", 1), state]
				1:
					var conds = ["==", ">=", "<=", ">", "<", "!="]
					var c_idx = min(p.get("value2", 0), 5)
					return "If Var [%s] %s %s" % [p.get("value1", 1), conds[c_idx], p.get("value4", 0)]
				2:
					var sw_names = ["A", "B", "C", "D"]
					var sw_name = sw_names[min(p.get("value1", 0), 3)]
					var state = "ON" if p.get("value2", 0) == 0 else "OFF"
					return "If Local Switch [%s] is %s" % [sw_name, state]
				_:
					return "If Condition (Type %d)" % item_sel
		33:
			return "Wait: %d frames" % p.get("duration", 60)
		_:
			return "Command %d" % code
