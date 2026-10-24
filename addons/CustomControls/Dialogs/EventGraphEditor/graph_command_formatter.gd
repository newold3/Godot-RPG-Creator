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
		code_res = fmt.get_formatted_code(dummy, ThemeDB.fallback_font, 16, HORIZONTAL_ALIGNMENT_LEFT, 0, 0)
		
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
		50:
			var lines: Array[String] = []
			for sub in sub_commands:
				if sub.code == 51:
					lines.append(sub.parameters.get("line", ""))
			return "Profile (Actor #%s):\n%s" % [p.get("actor_id", 1), "\n".join(lines).strip_edges()]
		53:
			var target_id = p.get("target", 0)
			var type = p.get("type", 0)
			var val = p.get("value", {})
			var dest_str = ""
			if type == 0:
				var m_id = val.get("assigned_map_id", 0)
				var x = val.get("assigned_x", 0)
				var y = val.get("assigned_y", 0)
				dest_str = "Map #%d (%d, %d)" % [m_id, x, y] if m_id != 0 else "(Not configured)"
			elif type == 1:
				dest_str = "Variables [Map: %s, X: %s, Y: %s]" % [val.get("map_id", 1), val.get("x", 1), val.get("y", 1)]
			elif type == 2:
				dest_str = "Swap with Event #%s" % val.get("swap_event_id", 0)
			var tgt = "Player" if target_id == 0 else ("Vehicle" if target_id == 1 else "Event")
			return "Transfer %s ➔ %s" % [tgt, dest_str]
		57:
			var target = p.get("target", 0)
			var tgt_name = "Player" if target == -1 else ("This Event" if target == 0 else "Event #%d" % target)
			return "Move Route (%s) - %d step(s)" % [tgt_name, sub_commands.size()]
		96:
			var s_name = p.get("shop_name", "")
			var name_str = "<%s> " % s_name if not s_name.is_empty() else ""
			return "Shop %s- %d item(s)" % [name_str, sub_commands.size()]
		201:
			return "Class Shop - %d item(s)" % sub_commands.size()
		_:
			return "Command %d" % code
