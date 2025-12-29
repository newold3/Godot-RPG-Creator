@tool
class_name RPGEventCommandFormat
extends Node

class FormatData:
	var command: RPGEventCommand
	var font: Font
	var font_size: int
	var align: HorizontalAlignment
	var v_separation: int
	var index: int
	var tabs: String
	
	func _init(_command: RPGEventCommand, _font: Font, _font_size: int, _align: HorizontalAlignment, _v_separation: int, _index: int, _tabs: String) -> void:
		command = _command
		font = _font
		font_size = _font_size
		align = _align
		v_separation = _v_separation
		index = _index
		tabs = _tabs
	
	func _to_string() -> String:
		return "<FormatData: %s>" % command


#region Configuration
var color_theme: Dictionary = {}
var default_text_offset_y: int = 3
var odd_line_color: Color = Color("#e4ecf2")
var event_line_color: Color = Color(1, 1, 1)
var default_text: String = "↪️" # ➩ 🔳 🔴 🟡 🔶🔘
var default_no_editable_text: String = "▪️"
var last_offset_setted: float
var backup_text: String
var current_config: Dictionary
var bbcode_regex: RegEx
var VALID_BBCODES = [
	"b", "i", "u", "s", "color", "bgcolor", "font", "font_size", "character",
	"wait", "hide_speaker", "face", "imgfx", "img_remove", "showbox", "hidebox",
	"sound", "no_wait_input", "variable", "actor", "party", "gold", "class",
	"item", "weapon", "profession_name", "profession_level", "armor",
	"enemy", "state",  "show_whole_line", "dialog_shake", "blip",
	"highlight_character", "speaker", "speaker_end", "speaker_entry",
	"speaker_entry_end", "speaker_exit", "freeze"
]
#endregion


#region Public Methods
# Config this script
func set_config(config: Dictionary) -> void:
	color_theme = config.get("color_theme", {})
	default_text_offset_y = config.get("default_text_offset_y", 3)
	odd_line_color = config.get("odd_line_color", Color("#e4ecf2"))
	event_line_color = config.get("event_line_color", Color(1, 1, 1))
	default_text = config.get("default_text", "↪️")
	default_no_editable_text = config.get("default_no_editable_text", "▪️")
	last_offset_setted = config.get("last_offset_setted", 0)
	backup_text = config.get("backup_text", "")

# Main function for retrieving the correct format
func get_formatted_code(command: RPGEventCommand, font: Font, font_size: int, align: HorizontalAlignment, v_separation: int, index: int) -> Dictionary:
	var command_function := "_format_command_%s" % command.code
	
	var sep = "      "
	var tabs: String
	for i in command.indent:
		tabs += sep
	
	if command.indent > 0:
		tabs[-1] = ""
	
	var result: Dictionary
	result["bg_color"] = event_line_color if index % 2 == 0 else odd_line_color
	result["phrases"] = []
	result["offset_y"] = 0
	
	var data = FormatData.new(command, font, font_size, align, v_separation, index, tabs)
	
	if has_method(command_function):
		result["phrases"] = call(command_function, data)
	else:
		result["phrases"] = _get_default_formatted_code(data)
	
	result["total_size"] = Vector2.ZERO
	for phrase in result["phrases"]:
		for obj in phrase.texts:
			obj["size"] = font.get_string_size(obj["text"], align, -1, font_size)
			result["total_size"].x += obj["size"].x
			if result["total_size"].y == 0:
				result["total_size"].y = obj["size"].y
	
	
	return result
#endregion
#region Helpers
func get_item_data(data: Array, id: int) -> Variant:
	return data[id] if id < data.size() else null

func get_item_data_name(data: Array, id: int) -> String:
	return "< %s: %s >" % [id, data[id].name] if id < data.size() else "⚠ Invalid Data"

func get_event_name(id: int) -> String:
	var data = ["Player"]
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene is RPGMap:
		data.append("This Event")
		for ev: RPGEvent in edited_scene.events.get_events():
			data.append("%s: %s" % [ev.id, ev.name])

	return data[id] if id < data.size() else "⚠ Invalid Data"

func get_actor_name(id: int) -> String:
	if id > 0 && RPGSYSTEM.database.actors.size() > id:
		return "< %s: %s >" % [id, RPGSYSTEM.database.actors[id].name]
	return "⚠ Invalid Data"

func get_formated_movement_command(command: RPGMovementCommand) -> String:
	if !command:
		return ""
		
	match command.code:
		1: return "Move Down"
		4: return "Move Left"
		7: return "Move Right"
		10: return "Move Up"
		13: return "Move Southwest"
		16: return "Move Southeast"
		19: return "Move Northwest"
		22: return "Move Northeast"
		25: return "Random Movement"
		28: return "Move To The Player"
		31: return "Move Away From The Player"
		34: return "Step Ahead"
		37: return "Step Backward"
		40: return "Jump to %s" % command.parameters[0]
		43: return "Wait %s Seconds" % command.parameters[0]
		46: return "Z-Index =  %s" % command.parameters[0]
		2: return "Look Down"
		5: return "Look Left"
		8: return "Look Right"
		11: return "Look Up"
		14: return "Turn 90º Left"
		17: return "Turn 90º Right"
		20: return "Turn 180º"
		23: return "Turn 90º Random"
		26: return "Look Random"
		29: return "Look Player"
		32: return "Look Opposite Player"
		35: 
			var id = str(command.parameters[0]).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
			return "Switch ON: %s" % RPGSYSTEM.system.switches.get_item_name(command.parameters[0])
		38: 
			var id = str(command.parameters[0]).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
			return "Switch OFF: %s" % RPGSYSTEM.system.switches.get_item_name(command.parameters[0])
		41: return "Change Speed To %s" % command.parameters[0]
		44: return "Delay Between Motion %s" % command.parameters[0]
		3: return "Walking Animation ON"
		6: return "Walking Animation OFF"
		9: return "Idle Animation ON"
		12: return "Idle Animation OFF"
		15: return "Fix Direction ON"
		18: return "Fix Direction OFF"
		21: return "Walk Through ON"
		24: return "Walk Through OFF"
		27: return "Invisible ON"
		30: return "Invisible OFF"
		33: return "Change Graphic To %s" % command.parameters[0]
		36: return "Change Opacity To %s" % command.parameters[0]
		39: 
			var blend_modes = ["Mix", "Add", "Subtract", "Multiply", "Premult Alpha"]
			return "Change Blend To %s" % blend_modes[command.parameters[0]]
		42: return "Play SE %s" % command.parameters[0].get_file()
		45: return "Script: %s" % command.parameters[0]
		_: return ""

func get_trait_name(item: RPGTrait) -> Array:
	var column = []
	var left = [
		"Element Rate (damage received)", "Debuff Rate", "State Rate", "State Resist",
		"Parameter", "Ex-Parameter", "Sp-Parameter",
		"Attack Element", "Attack State", "Attack Speed", "Attack Times +", "Attack Skill",
		"Add Skill Type", "Seal Skill Type", "Add Skill", "Seal Skill",
		"Equip Weapon", "Equip Armor", "Lock Equip", "Seal Equip", "Slot Type",
		"Action Times +", "Special Flag", "Collapse Effect", "Party Ability", "Skill Special Flag",
		"Element Rate (damage done)", "Add Permanent State"
	]
	column.append(left[item.code - 1])
	
	var database = RPGSYSTEM.database
	
	match item.code:
		1, 27:
			var list = database.types.element_types
			if list.size() > item.data_id:
				column.append("%s * %s %%" % [list[item.data_id], item.value])
		2, 5:
			var params = ["Max HP", "Max MP", "Attack", "Defense", "Magic Attack", 
				"Magic Defense", "Agility", "Luck"]
			column.append("%s * %s %%" % [params[item.data_id], item.value])
		3:
			var list = database.states
			if list.size() > item.data_id:
				column.append("%s * %s %%" % [list[item.data_id].name, item.value])
		4:
			var list = database.states
			if list.size() > item.data_id:
				column.append(list[item.data_id].name)
		6:
			var ex_params = ["Hit Rate", "Evasion Rate", "Critical Rate", "Critical Evasion", 
				"Magic Evasion", "Magic Reflection", "Counter Attack", "HP Regeneration", 
				"MP Regeneration", "TP Regeneration"]
			column.append("%s * %s %%" % [ex_params[item.data_id], item.value])
		7:
			var sp_params = ["Target Rate", "Guard Effect", "Recovery Effect", "Pharmacology", 
				"MP Cost Rate", "TP Charge Rate", "Physical Damage", "Magical Damage", 
				"Floor Damage", "Experience", "Gold"]
			column.append("%s * %s %%" % [sp_params[item.data_id], item.value])
		8:
			var list = database.types.element_types
			column.append(list[item.data_id] if list.size() > item.data_id else "⚠ Invalid Data")
		9:
			var list = database.states
			column.append("%s + %s %%" % [list[item.data_id].name, item.value] if list.size() > item.data_id else "⚠ Invalid Data")
		10, 11, 22:
			column.append(str(item.value) + ("%" if item.code == 22 else ""))
		12, 15, 16:
			var list = database.skills
			column.append(list[item.data_id].name if list.size() > item.data_id else "⚠ Invalid Data")
		13, 14:
			var list = database.types.skill_types
			column.append(list[item.data_id] if list.size() > item.data_id else "⚠ Invalid Data")
		17:
			var list = database.types.weapon_types
			column.append("All Weapon Types" if item.data_id == 0 else list[item.data_id - 1] 
				if list.size() > item.data_id - 1 else "⚠ Invalid Data")
		18:
			var list = database.types.armor_types
			column.append("All Armor Types" if item.data_id == 0 else list[item.data_id - 1] 
				if list.size() > item.data_id - 1 else "⚠ Invalid Data")
		19, 20:
			var list = database.types.equipment_types
			column.append(list[item.data_id] if list.size() > item.data_id else "⚠ Invalid Data")
		21:
			column.append(["Normal", "Dual Wield"][item.data_id])
		23:
			var flags = ["Auto Battle", "Guard", "Substitute", "Preserve TP"]
			column.append(flags[item.data_id] if flags.size() > item.data_id else "⚠ Invalid Data")
		24:
			var effects = ["Normal", "Boss", "Instant", "No Disappear"]
			column.append(effects[item.data_id] if effects.size() > item.data_id else "⚠ Invalid Data")
		25:
			var abilities = ["Encounter Half", "Encounter None", "Cancel Surprise", 
				"Raise Preemptive", "Gold Double", "Drop Item Double"]
			column.append(abilities[item.data_id] if abilities.size() > item.data_id else "⚠ Invalid Data")
		26:
			var specials = ["MP Cost Down", "Double Cast Chance"]
			column.append("%s * %s %%" % [specials[item.data_id], item.value])
	return column

func _get_actor_name_from_actor_type(actor_type: int, actor_id: int) -> String:
	if actor_type == 0:
		if actor_id == 0:
			return "Entire Party"
		if actor_id > 0 and RPGSYSTEM.database.actors.size() > actor_id:
			return "[%s: %s]" % [actor_id, RPGSYSTEM.database.actors[actor_id].name]
		return "[%s: ]" % actor_id
	return "{%s: %s}" % [actor_id, RPGSYSTEM.system.variables.get_item_name(actor_id)]

func _format_change_actor_stat(data: FormatData, stat_name: String, check_level_up: bool = false) -> Array:
	var actor_type = data.command.parameters.get("actor_type", 0)
	var actor_id = data.command.parameters.get("actor_id", 0) if actor_type == 0 else data.command.parameters.get("actor_id", 1)
	var n1 = _get_actor_name_from_actor_type(actor_type, actor_id)
	var n2 = "+" if data.command.parameters.get("operand", 0) == 0 else "-"
	var operand_type = data.command.parameters.get("operand_type", 0)
	var operand_value = data.command.parameters.get("operand_value", 0) if operand_type == 0 else data.command.parameters.get("operand_value", 1)
	var n3 = "{%s: %s}" % [operand_value, RPGSYSTEM.system.variables.get_item_name(operand_value)] if operand_type == 1 else str(operand_value)
	
	var formatted_text = [{
		"texts": [{
			"text": data.tabs + default_text + " Change %s : %s, %s %s" % [stat_name, n1, n2, n3],
			"color": color_theme.get("color5", Color.WHITE)
		}],
		"offset_y": default_text_offset_y
	}]
	
	if check_level_up and data.command.parameters.get("show_level_up", false):
		formatted_text[-1]["texts"].append({
			"text": " (Show Level Up)",
			"color": color_theme.get("color3", Color.WHITE)
		})
	
	return formatted_text

func _get_wait_text(wait: bool) -> String:
	return "" if !wait else ", wait"

func _get_image_command_parameter(data: FormatData) -> Dictionary:
	var result = {}
	var position_type = data.command.parameters.get("position_type", 0)
	var main_parameter: String = ""
	var param_color = color_theme.get("color3", Color.WHITE)

	if data.command.code == 76:
		var pos: String
		var v = data.command.parameters.get("position", Vector2i.ZERO if position_type == 0 else Vector2i.ONE)
		if position_type == 0:
			pos = "p:" + str(v)
		else:
			var id = str(v.x).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
			var v1_name = id + ": " + RPGSYSTEM.system.variables.get_item_name(v.x)
			var id2 = str(v.y).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
			var v2_name = id + ": " + RPGSYSTEM.system.variables.get_item_name(v.y)
			pos = "p:(#%s, #%s)" % [v1_name, v2_name]
		main_parameter = pos
	elif data.command.code == 77:
		main_parameter = str(data.command.parameters.get("rotation", 0)) + "°"
	elif data.command.code == 78:
		var image_scale = data.command.parameters.get("scale", Vector2.ONE) * 100.0
		main_parameter = "(%.2f, %.2f)" % [image_scale.x, image_scale.y]
	else:
		var image_modulate: Color = data.command.parameters.get("modulate", Color.WHITE)
		main_parameter = "#" + image_modulate.to_html()
		param_color = image_modulate

	result["main_parameter"] = main_parameter
	result["param_color"] = param_color
	return result

#endregion


#region Private Methods
# Default format for any code
func _get_default_formatted_code(data: FormatData) -> Array:
	var ini_text = default_text if not data.command.code in CustomEditItemList.NO_EDITABLE_CODES else default_no_editable_text
	var formatted_text = []
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + ini_text + " Command " + str(data.command.code) + ": " + str(data.command.parameters),
				"color": color_theme.get("color100", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	return formatted_text

# Enable insert commands
func _format_command_0(data: FormatData) -> Array:
	var formatted_text = []
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text,
				"color": color_theme.get("color1", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	return formatted_text

# Comando 1: Config Dialog
func _format_command_1(data: FormatData) -> Array:
	var formatted_text = []
	var scene_path = data.command.parameters.get("scene_path", "").get_file()
	var max_width = data.command.parameters.get("max_width", "")
	var max_lines = data.command.parameters.get("max_lines", "")
	var skip_mode = data.command.parameters.get("skip_mode", 0)
	var mode = ["None", "All, Run Commands", "All", "Fast Forward"][skip_mode]
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Dialog Config : ",
				"color": color_theme.get("color2", Color.WHITE)
			},
			{
				"text": "[%s, Max Width %s, Max Lines: %s, Skip Mode %s, ...]" % [
					scene_path,
					max_width,
					max_lines,
					mode
				],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 2: Start Dialog
func _format_command_2(data: FormatData) -> Array:
	var formatted_text = []
	var character_name: String
	var character_data = data.command.parameters.get("character_name", null)
	if character_data is Dictionary:
		var type = character_data.get("type", 0)
		var value = character_data.get("value", 0)
		if type == 0:
			character_name = value
		elif type == 1:
			character_name = "Character ID = " + str(value)
		else:
			character_name = "Enemy ID = " + str(value)
	var pos = "Left" if data.command.parameters.get("position", 0) == 0 else "Right"
	var face =  data.command.parameters.get("face", RPGIcon.new())
	if face is RPGIcon:
		face = face.path
	var face_width = data.command.parameters.get("width", 0)
	if face_width == 0:
		face_width = "W"
	var face_height = data.command.parameters.get("height", 0)
	if face_height == 0:
		face_height = "H"
	var face_size: String = "%sx%s" % [face_width, face_height]
	var is_floating_dialog = data.command.parameters.get("is_floating_dialog", false)
	var is_floating_string: String = "" if not is_floating_dialog else "floating dialog"
	if not is_floating_string.is_empty():
		is_floating_string += " (over #%s)" % data.command.parameters.floating_target
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Text : ",
				"color": color_theme.get("color2", Color.WHITE)
			},
			{
				"text": "[%s, %s Face Size: %s, %s]" % [
					character_name,
					face,
					face_size,
					pos
				],
				"color": color_theme.get("color3", Color.WHITE)
			} if not is_floating_dialog else {
				"text": "[%s]" % is_floating_string,
				"color": color_theme.get("color12", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


func replace_bbcode_with_icon(text: String, icon: String = "⚙️") -> String:
	var regex = RegEx.new()
	var pattern = "\\[/?(?:" + "|".join(VALID_BBCODES) + ")(?:[^\\]]*)?\\]"
	regex.compile(pattern)
	var result = regex.sub(text, icon, true)
	return result


# Comando 3: Dialog Line
func _format_command_3(data: FormatData) -> Array:
	var formatted_text = []
	var line = data.command.parameters.get("line", "")
	
	if not line.is_empty():
		line = replace_bbcode_with_icon(line)

	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + ": ",
				"color": color_theme.get("color2", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text + " Text ", data.align, -1, data.font_size).x,
			},
			{
				"text": line,
				"color": color_theme.get("color4", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text + " Text ", data.align, -1, data.font_size).x,
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 4: Start Choices
func _format_command_4(data: FormatData) -> Array:
	var formatted_text = []
	var pos = [
		"Top Left", "Top Center", "Top Right",
		"Left", "Center", "Right",
		"Bottom Left", "Bottom Center", "Bottom Right"
	][data.command.parameters.get("position", 0)]
	var default = data.command.parameters.get("default", 0)
	default = "none" if default == 0 else "#%s" % default
	var cancel = data.command.parameters.get("cancel", 0)
	cancel = "_" if cancel == 0 or cancel == 1 else "#%s" % cancel
	var max_choices = str(data.command.parameters.get("max_chocies", 4))
	var next_choice = data.command.parameters.get("previous", "next")
	var previous_choice = data.command.parameters.get("next", "previous")
	var scene_path = data.command.parameters.get("scene_path","").get_file()
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Show Choices : ",
				"color": color_theme.get("color2", Color.WHITE)
			},
			{
				"text": "[%s, %s, %s, %s, %s, %s, %s]" % [
					scene_path,
					pos,
					default,
					cancel,
					max_choices,
					next_choice,
					previous_choice
				],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 5: Choices When
func _format_command_5(data: FormatData) -> Array:
	var formatted_text = []
	var choice_name = data.command.parameters.get("name", "")
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + " When ",
				"color": color_theme.get("color2", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text, data.align, -1, data.font_size).x,
			},
			{
				"text": choice_name,
				"color": color_theme.get("color4", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text, data.align, -1, data.font_size).x,
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 6: Choices Cancel
func _format_command_6(data: FormatData) -> Array:
	var formatted_text = []
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + " When ",
				"color": color_theme.get("color2", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text, data.align, -1, data.font_size).x,
			},
			{
				"text": "Cancel",
				"color": color_theme.get("color4", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text, data.align, -1, data.font_size).x,
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 7: Choices End
func _format_command_7(data: FormatData) -> Array:
	var formatted_text = []
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + " End Choices ",
				"color": color_theme.get("color2", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text, data.align, -1, data.font_size).x,
			},
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 8: Input Number
func _format_command_8(data: FormatData) -> Array:
	var formatted_text = []
	var type = data.command.parameters.get("type", 0)
	var variable_id = data.command.parameters.get("variable_id", "")
	var digits = data.command.parameters.get("digits", "")
	var plural = "s" if int(digits) != 1 else ""
	var mode = "Number" if type == 0 else "Text"
	var character = "digit" if type == 0 else "character"
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Input %s : " % mode,
				"color": color_theme.get("color2", Color.WHITE)
			},
			{
				"text": "[#%s, %s %s%s]" % [
					variable_id,
					digits,
					character,
					plural
				],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 9: Select Important Item
func _format_command_9(data: FormatData) -> Array:
	var formatted_text = []
	var variable_id = data.command.parameters.get("variable_id", "")
	var item_type = data.command.parameters.get("item_type", 0)
	var item = [
		"Normal Item", "Key Item", "Hidden Item 1", "Hidden Item 2",
		"Hidden Item 3", "Hidden Item 4", "Hidden Item 5"
	][item_type]
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Select Important Item : ",
				"color": color_theme.get("color2", Color.WHITE)
			},
			{
				"text": "#%s, %s" % [
					variable_id,
					item
				],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 10: Scroll Dialog
func _format_command_10(data: FormatData) -> Array:
	var formatted_text = []
	var scroll_speed = data.command.parameters.get("scroll_speed", 100)
	var scroll_direction = data.command.parameters.get("scroll_direction", 0)
	var direction = "Bottom to Top" if scroll_direction == 0 else "Top to Bottom"
	var scroll_scene = data.command.parameters.get("scroll_scene", "")
	var scene = scroll_scene.get_file() if scroll_scene else "Default"
	var enable_fast_forward = data.command.parameters.get("enable_fast_forward", "")
	var fast_forward = "Use Fast Forward" if enable_fast_forward else "No Fast Forward"
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Text (S) : ",
				"color": color_theme.get("color2", Color.WHITE)
			},
			{
				"text": "%s, %s, %s, %s" % [
					scroll_speed,
					direction,
					scene,
					fast_forward
				],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 11: Dialog Line (Scroll)
func _format_command_11(data: FormatData) -> Array:
	var formatted_text = []
	var line = data.command.parameters.get("line", "")
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + ": ",
				"color": color_theme.get("color2", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text + " Text (S) ", data.align, -1, data.font_size).x,
			},
			{
				"text": line,
				"color": color_theme.get("color4", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text + " Text (S) ", data.align, -1, data.font_size).x,
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 12: Change Gold
func _format_command_12(data: FormatData) -> Array:
	var formatted_text = []
	var operation = "+" if data.command.parameters.get("operation_type", 0) == 0 else "-"
	var value: String = str(int(data.command.parameters.get("value", 1)))
	if data.command.parameters.get("value_type", 0) == 1:
		var variable_id = str(value).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		value = "{#%s}" % variable_id
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Change Gold : %s %s" % [operation, value],
				"color": color_theme.get("color5", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 13: Change Items
func _format_command_13(data: FormatData) -> Array:
	var formatted_text = []
	var operation = "+" if data.command.parameters.get("operation_type", 0) == 0 else "-"
	var value = data.command.parameters.get("value", 1)
	if data.command.parameters.get("value_type", 0) == 1:
		var variable_id = str(value).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		value = "{#%s}" % variable_id
	var item_name = ""
	var item_id = data.command.parameters.get("item_id", 0)
	var items = RPGSYSTEM.database.items
	if items.size() > item_id:
		item_name = "%s: %s" % [
			str(item_id).pad_zeros(str(items.size()).length()),
			items[item_id].name
		]
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Change Items : [%s] %s %s" % [item_name, operation, value],
				"color": color_theme.get("color5", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 14: Change Weapons
func _format_command_14(data: FormatData) -> Array:
	var formatted_text = []
	var operation = "+" if data.command.parameters.get("operation_type", 0) == 0 else "-"
	var value = int(data.command.parameters.get("value", 1))
	var level = int(data.command.parameters.get("level", 1))
	if data.command.parameters.get("value_type", 0) == 1:
		var variable_id = str(value).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		value = "{#%s}" % variable_id
	var item_name = ""
	var item_id = data.command.parameters.get("item_id", 0)
	var items = RPGSYSTEM.database.weapons
	if items.size() > item_id:
		item_name = "%s: %s" % [
			str(item_id).pad_zeros(str(items.size()).length()),
			items[item_id].name
		]
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Change Weapons : [%s - level %s] %s %s " % [item_name, level, operation, value],
				"color": color_theme.get("color5", Color.WHITE)
			},
			{
				"text": "(include equipment)" if data.command.parameters.get("include_equipment", false) else "",
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text


# Comando 15: Change Armors
func _format_command_15(data: FormatData) -> Array:
	var formatted_text = []
	var operation = "+" if data.command.parameters.get("operation_type", 0) == 0 else "-"
	var value = data.command.parameters.get("value", 1)
	var level = int(data.command.parameters.get("level", 1))
	if data.command.parameters.get("value_type", 0) == 1:
		var variable_id = str(value).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		value = "{#%s}" % variable_id
	var item_name = ""
	var item_id = data.command.parameters.get("item_id", 0)
	var items = RPGSYSTEM.database.armors
	if items.size() > item_id:
		item_name = "%s: %s" % [
			str(item_id).pad_zeros(str(items.size()).length()),
			items[item_id].name
		]
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Change Armors : [%s - level %s] %s %s " % [item_name, level, operation, value],
				"color": color_theme.get("color5", Color.WHITE)
			},
			{
				"text": "(include equipment)" if data.command.parameters.get("include_equipment", false) else "",
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Change Party Members
func _format_command_16(data: FormatData) -> Array:
	var formatted_text = []
	var operation = "Add" if data.command.parameters.get("operation_type", 0) == 0 else "Remove"
	var actor_name = ""
	var actor_id = data.command.parameters.get("actor_id", 1)
	var items = RPGSYSTEM.database.actors
	
	if items.size() > actor_id:
		actor_name = "%s: %s" % [
			str(actor_id).pad_zeros(str(items.size()).length()),
			items[actor_id].name
		]
	
	var initialize = " (initialize)" if data.command.parameters.get("initialize", false) and operation == "Add" else ""
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Change Party Member : %s < %s >" % [operation, actor_name],
				"color": color_theme.get("color5", Color.WHITE)
			},
			{
				"text": initialize,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	return formatted_text

# Control Switches
func _format_command_17(data: FormatData) -> Array:
	var formatted_text = []
	var from = data.command.parameters.get("from", 1)
	var to = data.command.parameters.get("to", 1)
	var switch_name
	
	if from == to:
		var id = str(from).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
		switch_name = id + ": " + RPGSYSTEM.system.switches.get_item_name(from)
	else:
		var id1 = str(from).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
		var id2 = str(to).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
		switch_name = "#" + id1 + "..." + id2
	
	var operation = "ON" if data.command.parameters.get("operation_type", 0) == 0 else "OFF"
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Control Switches : [%s] is %s" % [switch_name, operation],
				"color": color_theme.get("color6", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	return formatted_text

# Control Variables
func _format_command_18(data: FormatData) -> Array:
	var formatted_text = []
	var from = int(data.command.parameters.get("from", 1))
	var to = int(data.command.parameters.get("to", 1))
	var variable_name
	
	if from == to:
		var id = str(from).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		variable_name = id + ": " + RPGSYSTEM.system.variables.get_item_name(from)
	else:
		var id1 = str(from).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		var id2 = str(to).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		variable_name = "#" + id1 + "..." + id2
	
	var operation_type = data.command.parameters.get("operation_type", 0)
	var operation = ["=", "+", "-", "*", "/", "%"][operation_type]
	var text = ""
	var operand_type = data.command.parameters.get("operand_type", 0)
	
	match operand_type:
		0: # Constant
			text = data.command.parameters.get("value1", 0)
		1: # Variable
			var target = int(data.command.parameters.get("value1", 0))
			var variable_id = str(target).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
			var variable2_name = variable_id + ": " + RPGSYSTEM.system.variables.get_item_name(target)
			text = "[%s]" % variable2_name
		2: # Random
			var target1 = int(data.command.parameters.get("value1", 0))
			var target2 = int(data.command.parameters.get("value2", 0))
			var id1 = str(target1).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
			var id2 = str(target2).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
			text = id1 + ".." + id2
		3: # Game Data
			var target = int(data.command.parameters.get("value1", 0))
			match target:
				0: # Item
					var items = RPGSYSTEM.database.items
					var id = int(data.command.parameters.get("value2", 0))
					if items.size() > id:
						var item_name = "%s:%s" % [
							str(id).pad_zeros(str(items.size()).length()),
							items[id].name
						]
						text = "Number of the item [%s]" % item_name
					else:
						text = "Number of the ?"
				1: # Weapon
					var items = RPGSYSTEM.database.weapons
					var id = int(data.command.parameters.get("value2", 0))
					if items.size() > id:
						var item_name = "%s:%s" % [
							str(id).pad_zeros(str(items.size()).length()),
							items[id].name
						]
						text = "Number of the weapon [%s]" % item_name
					else:
						text = "Number of the ?"
				2: # Armor
					var items = RPGSYSTEM.database.armors
					var id = int(data.command.parameters.get("value2", 0))
					if items.size() > id:
						var item_name = "%s:%s" % [
							str(id).pad_zeros(str(items.size()).length()),
							items[id].name
						]
						text = "Number of the armor [%s]" % item_name
					else:
						text = "Number of the ?"
				3: # Actor
					var index = data.command.parameters.get("value3", 0)
					var parameter = PackedStringArray(["Level", "Experience"]) + RPGSYSTEM.database.types.main_parameters
					var param_name: String = ""
					if parameter.size() > index:
						param_name = parameter[index]
					elif index > parameter.size():
						var param_id = index - parameter.size() - 1
						var user_parameters = RPGSYSTEM.database.types.user_parameters
						if param_id >= 0 and user_parameters.size() > param_id:
							param_name = "User Parameter " + user_parameters[param_id].name
						else:
							param_name = "User Parameter ?"
					
					var items = RPGSYSTEM.database.actors
					var id = int(data.command.parameters.get("value2", 0))
					if items.size() > id:
						var item_name = "%s:%s" % [
							str(id).pad_zeros(str(items.size()).length()),
							items[id].name
						]
						text = "%s of actor [%s]" % [param_name, item_name]
					else:
						text = "%s of ?" % param_name
				4: # Enemy
					var parameter = [
						"HP", "MP", "Max HP", "Max MP", "Attack", "Defense",
						"Magic Attack", "Magic Defense", "Agility", "Luck", "TP"
					][data.command.parameters.get("value3", 0)]
					var item_name = ["#1", "#2", "#3", "#4", "#5", "#6", "#7", "#8"][data.command.parameters.get("value2", 0)]
					text = "%s of battler enemy [%s]" % [parameter, item_name]
				5: # Character
					var parameter = ["Map X", "Map Y", "Direction", "Screen X", "Screen Y", "Global Position X", "Global Position Y", "Z-Index"][data.command.parameters.get("value3", 0)]
					var item_name = ["Player", "This Event"][data.command.parameters.get("value2", 0)]
					text = "%s of [%s]" % [parameter, item_name]
				6: # Party
					text = "Actor ID of party member #%s" % (data.command.parameters.get("value2", 0) + 1)
				7: # Last
					var option = [
						"Last Used Skill ID", "Last Used Item ID", "Last Actor ID To Act",
						"Last Enemy Index To Act", "Last Target Actor ID", "Last Target Enemy Index"
					][data.command.parameters.get("value2", 0)]
					text = option
				8: # Other
					var index = data.command.parameters.get("value2", 0)
					var option = [
						"Map ID", "Party size", "Amount of gold", "Steps Count", "Play Time",
						"Timer", "Save Count", "Battle Count", "Win Count", "Escape Count",
						"Quests Failed", "Quests in Progress", "Total Completed Quests",
						"Total Enemy Kills", "Total Money Earned", "Total Quest Found",
						"Total Relationships Started", "Total Relationships Maximized",
						"Total Achievements Unlocked", "Global User Parameter"
					][index]
					if index == 19:
						var user_parameters = RPGSYSTEM.database.types.user_parameters
						var param_id = data.command.parameters.get("value3", 0)
						if param_id > 0 and user_parameters.size() > param_id:
							text = option + " < %s >" % user_parameters[param_id].name
						else:
							text = option + " < ? >"
					else:
						text = option
				9: # Profession
					var items = RPGSYSTEM.database.professions
					var id = int(data.command.parameters.get("value2", 0))
					if items.size() > id:
						var item_name = "%s:%s" % [
							str(id).pad_zeros(str(items.size()).length()),
							items[id].name
						]
						text = "Level of the profession [%s]" % item_name
					else:
						text = "Level of the ?"
				10: # Stat
					var value =  data.command.parameters.get("value2", 0)
					var option: String
					var base_options = [
						"steps", "play_time", "enemy_kills", "skills",
						"items_sold", "items_purchased", "items_found",
						"weapons_sold", "weapons_purchased", "weapons_found",
						"armors_sold", "armors_purchased", "armors_found",
						"battles/won", "battles/lost", "battles/drawn", "battles/escaped", "battles/total_played",
						"battles/current_win_streak", "battles/longest_win_streak", "battles/current_lose_streak",
						"battles/longest_lose_streak", "battles/longest_battle_time", "battles/shortest_battle_time",
						"battles/total_combat_turns", "battles/total_time_in_battle", "battles/total_experience_earned",
						"battles/total_damage_received", "battles/total_damage_done",
						"battles/total_used_skills", "battles/total_critiques_performed",
						"extractions/total_items_found", "extractions/total_success", "extractions/total_failure",
						"extractions/total_finished", "extractions/total_unfinished", "extractions/critical_performs",
						"extractions/super_critical_performs", "extractions/resources_interactions",
						"save_count", "game_progress", "total_money_earned", "total_money_spent", "player_deaths", "chests_opened", "secrets_found", "max_level_reached", "dialogues_completed", "rare_items_found",
						"missions/completed", "missions/in_progress", "missions/failed", "missions/total_found"
					]
					if value < base_options.size():
						option = base_options[value]
					else:
						var user_stat_id =  value - base_options.size() - 1
						if user_stat_id >= 0 and RPGSYSTEM.database.types.user_stats.size() > user_stat_id:
							option = RPGSYSTEM.database.types.user_stats[user_stat_id]
						else:
							option = "⚠ Invalid Data"
					
					var extra = tr("Item") + " " if value in [4, 5, 6] \
						else tr("Weapon") + " " if value in [7, 8, 9] \
						else tr("Armor") + " " if value in [10, 11, 12] \
						else tr("Profession") + " " if value in [31] \
						else ""
					if not extra.is_empty():
						text = option + " (%sID = %s)" % [extra, data.command.parameters.get("value3", 1)]
					else:
						text = option
					
		4: # Script
			text = data.command.parameters.get("value1", 0)
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Control Variables : < %s > %s= %s" % [variable_name, operation, text],
				"color": color_theme.get("color6", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	return formatted_text

# Control Self Switches
func _format_command_19(data: FormatData) -> Array:
	var formatted_text = []
	var switch_id = data.command.parameters.get("switch_id", 0)
	var switch_name = ["A", "B", "C", "D", "E", "F", "G", "H"][switch_id]
	var operation = "ON" if data.command.parameters.get("operation_type", 0) == 0 else "OFF"
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Control Self Switch %s is %s" % [switch_name, operation],
				"color": color_theme.get("color6", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	return formatted_text


# Change User Parameter
func _format_command_302(data: FormatData) -> Array:
	var formatted_text = []
	var target_id = data.command.parameters.get("target_id", 0)
	var param_id = data.command.parameters.get("param_id", 0)
	var param_name: String = ""
	if param_id >= 0 and RPGSYSTEM.database.types.user_parameters.size() > param_id:
		var param: RPGUserParameter = RPGSYSTEM.database.types.user_parameters[param_id]
		param_name = "%s = %s" % [param.name, data.command.parameters.get("value", 0)]
	else:
		param_name = "⚠ Invalid Data"
	var target: String
	if target_id >= 0 and RPGSYSTEM.database.actors.size() > target_id:
		if target_id == 0:
			target = "<Global Parameter>"
		else:
			target = "<Actor %s: %s>" % [RPGSYSTEM.database.actors[target_id].id, RPGSYSTEM.database.actors[target_id].name]
	else:
		target = "⚠ Invalid Data"
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Change User Parameter for %s: %s " % [target, param_name],
				"color": color_theme.get("color6", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	return formatted_text


# Change Stat
func _format_command_303(data: FormatData) -> Array:
	var formatted_text = []
	var stat_id = data.command.parameters.get("stat_id", 0)
	var param_name: String = ""
	var default_stats = ["", "chests_opened", "secrets_found", "rare_items_found"]
	if stat_id < default_stats.size():
		param_name = default_stats[stat_id]
		param_name += " += %s" % data.command.parameters.get("value", 0)
	else:
		stat_id -= (default_stats.size() + 1)
		if stat_id >= 0 and RPGSYSTEM.database.types.user_stats.size() > stat_id:
			var stat: String = RPGSYSTEM.database.types.user_stats[stat_id]
			param_name = "%s += %s" % [stat, data.command.parameters.get("value", 0)]
		else:
			param_name = "⚠ Invalid Data"
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Change Stat %s " % param_name,
				"color": color_theme.get("color6", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	return formatted_text


# Control Timer
func _format_command_20(data: FormatData) -> Array:
	var formatted_text = []
	var operation_type = data.command.parameters.get("operation_type", 0)
	var operation = "Start" if operation_type == 0 else "Stop"
	var timer = ""
	var minutes = data.command.parameters.get("minutes", 0)
	var seconds = data.command.parameters.get("seconds", 0)
	var id = int(data.command.parameters.get("timer_id", 0))
	var timer_title = data.command.parameters.get("timer_title", "No Title")
	
	if operation_type == 0:
		timer = "Start Timer #%s: %s, %s min %s sec" % [id, timer_title, minutes, seconds]
	elif operation_type == 1:
		timer = "Stop Timer #%s:" % id
	elif operation_type == 2:
		timer = "Pause Timer #%s" % id
	elif operation_type == 3:
		timer = "Resume Timer #%s" % id
	elif operation_type == 4:
		timer = "Increases The Timer #%s By: %s min %s sec" % [id, minutes, seconds]
	elif operation_type == 5:
		timer = "Decreases The Timer #%s by: %s min %s sec" % [id, minutes, seconds]
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Control Timer: %s" % timer,
				"color": color_theme.get("color6", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	return formatted_text

# Conditional Branch
func _format_command_21(data: FormatData) -> Array:
	var formatted_text = []
	var item_selected = data.command.parameters.get("item_selected", 0)
	var text = ""
	var sub_text = ""
	
	match item_selected:
		0: # Switch
			var switch_id = data.command.parameters.get("value1", 1)
			var str_id = str(switch_id).pad_zeros(str(RPGSYSTEM.system.switches.size()).length())
			var operation = "ON" if data.command.parameters.get("value2", 0) == 0 else "OFF"
			var switch_name = RPGSYSTEM.system.switches.get_item_name(switch_id)
			text = "[" + str_id + ": " + switch_name + "] is " + operation
		1: # Variable
			var variable_id = data.command.parameters.get("value1", 1)
			var str_id = str(variable_id).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
			var condition = ["=", ">=", "<=", ">", "<", "≠"][data.command.parameters.get("value2", 0)]
			var variable_name = RPGSYSTEM.system.variables.get_item_name(variable_id)
			var value = ""
			if data.command.parameters.get("value3", 0) == 0:
				value = str(data.command.parameters.get("value4", 0))
			else:
				var variable2_id = data.command.parameters.get("value4", 1)
				var str2_id = str(variable2_id).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
				var variable2_name = RPGSYSTEM.system.variables.get_item_name(variable2_id)
				value = "[" + str2_id + ": " + variable2_name + "]"
			text = "[" + str_id + ": " + variable_name + "] " + condition + " " + value
		2: # Self Switch
			var switch_id = data.command.parameters.get("value1", 0)
			var switch_name = RPGSYSTEM.system.self_switches.get_self_switch_name(switch_id)
			var operation = "ON" if data.command.parameters.get("value2", 0) == 0 else "OFF"
			text = "Self Switch " + switch_name + " is " + operation
		3: # Timer
			var timer_id = int(data.command.parameters.get("value4", 0))
			var condition = [">=", "<="][data.command.parameters.get("value1", 0)]
			var minutes = str(data.command.parameters.get("value2", 0)) + " min"
			var seconds = str(data.command.parameters.get("value3", 0)) + "sec"
			text = "Timer #%s " % timer_id + condition + " " + minutes + " " + seconds
		4: # Actor
			var actor_id = data.command.parameters.get("value1", 1)
			var actor_name = get_item_data_name(RPGSYSTEM.database.actors, actor_id)
			var actor_condition = data.command.parameters.get("value2", 0)
			match actor_condition:
				0: text = actor_name + " is in the party"
				1: text = "Name of " + actor_name + " is " + data.command.parameters.get("value3", "")
				2:
					var item_id = data.command.parameters.get("value3", 1)
					var item_name = get_item_data_name(RPGSYSTEM.database.classes, item_id)
					text = "Class of " + actor_name + " is " + item_name
				3:
					var item_id = data.command.parameters.get("value3", 1)
					var item_name = get_item_data_name(RPGSYSTEM.database.skills, item_id)
					text = actor_name + " has learned " + item_name
				4:
					var item_id = data.command.parameters.get("value3", 1)
					var item_name = get_item_data_name(RPGSYSTEM.database.weapons, item_id)
					text = actor_name + " has equipped " + item_name
				5:
					var item_id = data.command.parameters.get("value3", 1)
					var item_name = get_item_data_name(RPGSYSTEM.database.armors, item_id)
					text = actor_name + " has equipped " + item_name
				6:
					var item_id = data.command.parameters.get("value3", 1)
					var item_name = get_item_data_name(RPGSYSTEM.database.states, item_id)
					text = actor_name + " is affected by " + item_name
				7:
					var param_id = data.command.parameters.get("value4", 0)
					var condition = ["=", ">=", "<=", ">", "<", "≠"][data.command.parameters.get("value5", 0)]
					var condition_value = data.command.parameters.get("value6", 0)
					var parameters = PackedStringArray(["Level", "Experience"]) + RPGSYSTEM.database.types.main_parameters
					var param_name: String
					if parameters.size() > param_id:
						param_name = parameters[param_id]
					elif param_id >= parameters.size(): # user Parameter
						var user_parameter_id = param_id - parameters.size() - 1
						var user_parameters = RPGSYSTEM.database.types.user_parameters
						if user_parameter_id >= 0 and user_parameters.size() > user_parameter_id:
							param_name = "User Parameter " + user_parameters[user_parameter_id].name
						else:
							param_name = "User Parameter ?"
					var v = " %.2f" % condition_value if int(condition_value) != condition_value else " %s" % int(condition_value)
					text = "( " + param_name + " ) " + condition + v
					
		5: # Enemy
			var enemy_id = str(data.command.parameters.get("value1", 0) + 1)
			var enemy_condition = data.command.parameters.get("value2", 0)
			if enemy_condition == 0:
				text = "Enemy #" + enemy_id + " has appeared"
			else:
				var state_id = data.command.parameters.get("value3", 1)
				var item_name = get_item_data_name(RPGSYSTEM.database.states, state_id)
				text = "Enemy #" + enemy_id + " is affected by " + item_name
		6: # Character
			var character_id = data.command.parameters.get("value1", 0)
			var character_name = get_event_name(character_id)
			var param = [
				"Looking At Down", "Looking At Left", "Looking At Right", "Looking At Up",
				"Is In My Tile", "Is Out Of My Tile", "Is Jumping", "Is Passable", "Is On Vehicle"
			][data.command.parameters.get("value2", 0)]
			text = character_name + " " + param
		7: # Vehicle
			var vehicle_id = data.command.parameters.get("value1", 0)
			var vehicle_name = ["Boat", "Ship", "AirShip"][vehicle_id]
			text = vehicle_name + " is being driven"
		8: # Gold
			var condition = [">=", "<=", "<"][data.command.parameters.get("value1", 0)]
			var value = str(data.command.parameters.get("value2", 0))
			text = "Gold " + condition + " " + value
		9: # Item
			var item_id = data.command.parameters.get("value1", 1)
			var item_name = get_item_data_name(RPGSYSTEM.database.items, item_id)
			text = "Party has " + item_name
		10: # Weapon
			var item_id = data.command.parameters.get("value1", 1)
			var item_name = get_item_data_name(RPGSYSTEM.database.weapons, item_id)
			var equipment = data.command.parameters.get("value2", false)
			var include_equipment = "Include Equipment" if equipment else ""
			text = "Party has " + item_name
			if include_equipment:
				sub_text = "(%s)" % include_equipment
		11: # Armor
			var item_id = data.command.parameters.get("value1", 1)
			var item_name = get_item_data_name(RPGSYSTEM.database.armors, item_id)
			var equipment = data.command.parameters.get("value2", false)
			var include_equipment = "Include Equipment" if equipment else ""
			text = "Party has " + item_name
			if include_equipment:
				sub_text = "(%s)" % include_equipment
		12: # Button
			var button_id = data.command.parameters.get("value1", 0)
			var button_name = [
				"OK", "Cancel", "Shift", "Ctrl", "Up", "Down", "Left",
				"Right", "Next Page", "Previous Page"
			][button_id]
			var button_action_id = data.command.parameters.get("value2", 0)
			var button_action_name = ["pressed", "triggered", "repeated"][button_action_id]
			text = "Button [" + button_name + "] is being " + button_action_name
		13: # Script
			var sc = data.command.parameters.get("value1", "")
			text = "Script : " + sc
		14: # Text Variable
			var variable_id = data.command.parameters.get("value1", 1)
			var str_id = str(variable_id).pad_zeros(str(RPGSYSTEM.system.text_variables.data.size()).length())
			var condition = ["=", ">=", "<=", ">", "<", "≠"][data.command.parameters.get("value2", "")]
			var variable_name = RPGSYSTEM.system.text_variables.get_item_name(variable_id)
			var value = ""
			if data.command.parameters.get("value3", 0) == 0:
				value = str(data.command.parameters.get("value4", ""))
			else:
				var variable2_id = data.command.parameters.get("value4", 1)
				var str2_id = str(variable2_id).pad_zeros(str(RPGSYSTEM.system.text_variables.size()).length())
				var variable2_name = RPGSYSTEM.system.text_variables.get_item_name(variable2_id)
				value = "[" + str2_id + ": " + variable2_name + "]"
			text = "[" + str_id + ": " + variable_name + "] " + condition + " " + value
		15: # Profession
			var variable_id = data.command.parameters.get("value1", 1)
			var str_id = str(variable_id).pad_zeros(str(RPGSYSTEM.database.professions.size()).length())
			var condition = ["=", ">=", "<=", ">", "<", "≠"][data.command.parameters.get("value2", 0)]
			var variable_name = get_item_data_name(RPGSYSTEM.database.professions, variable_id)
			var value = str(data.command.parameters.get("value3", ""))
			text = "[" + str_id + ": " + variable_name + "] " + condition + " " + value
		16: # Relationship
			var condition = ["=", ">=", "<=", ">", "<", "≠"][data.command.parameters.get("value2", 0)]
			var value = str(data.command.parameters.get("value3", ""))
			text = "[relationship] " + condition + " " + value
		17: # Global User Parameter
			var variable_id = data.command.parameters.get("value1", 1)
			var str_id = str(variable_id).pad_zeros(str(RPGSYSTEM.database.types.user_parameters.size()).length())
			var condition = ["=", ">=", "<=", ">", "<", "≠"][data.command.parameters.get("value2", "")]
			var variable_name = RPGSYSTEM.database.types.get_user_parameters_name(variable_id)
			var value = ""
			if data.command.parameters.get("value3", 0) == 0:
				value = str(data.command.parameters.get("value4", ""))
			else:
				var variable2_id = data.command.parameters.get("value4", 0)
				var str2_id = str(variable2_id).pad_zeros(str(RPGSYSTEM.database.types.user_parameters.size()).length())
				var variable2_name = RPGSYSTEM.database.types.get_user_parameters_name(variable2_id)
				value = "[" + str2_id + ": " + variable2_name + "]"
			text = "[" + str_id + ": " + variable_name + "] " + condition + " " + value

	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " If : %s" % text,
				"color": color_theme.get("color7", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	
	if sub_text:
		formatted_text[-1].texts.append(
			{
				"text": " " + sub_text,
				"color": color_theme.get("color3", Color.WHITE)
			}
		)
	
	return formatted_text

# Conditional Branch Else
func _format_command_22(data: FormatData) -> Array:
	var formatted_text = []
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + " Else ",
				"color": color_theme.get("color7", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text, data.align, -1, data.font_size).x,
			},
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Conditional Branch End
func _format_command_23(data: FormatData) -> Array:
	var formatted_text = []
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + " End Conditional Branch ",
				"color": color_theme.get("color7", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text, data.align, -1, data.font_size).x,
			},
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Start Loop
func _format_command_24(data: FormatData) -> Array:
	var formatted_text = []
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Loop ",
				"color": color_theme.get("color7", Color.WHITE)
			},
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Repeat Loop (Loop End)
func _format_command_25(data: FormatData) -> Array:
	var formatted_text = []
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Repeat Above ",
				"color": color_theme.get("color7", Color.WHITE)
			},
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Break Loop
func _format_command_26(data: FormatData) -> Array:
	var formatted_text = []
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Break Loop ",
				"color": color_theme.get("color7", Color.WHITE)
			},
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Exit Event Processing
func _format_command_27(data: FormatData) -> Array:
	var formatted_text = []
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Exit Event Processing ",
				"color": color_theme.get("color7", Color.WHITE)
			},
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Select Common Event
func _format_command_28(data: FormatData) -> Array:
	var formatted_text = []
	var event_id = data.command.parameters.get("id", 1)
	var event_name = get_item_data_name(RPGSYSTEM.database.common_events, event_id)
	var value = data.command.parameters.get("value", 1)
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Call Common Event : < %s >" % [event_name],
				"color": color_theme.get("color7", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Set Label
func _format_command_29(data: FormatData) -> Array:
	var formatted_text = []
	var text = data.command.parameters.get("text", "")
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Label : " + text,
				"color": color_theme.get("color8", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Jump To Label
func _format_command_30(data: FormatData) -> Array:
	var formatted_text = []
	var text = data.command.parameters.get("text", "")
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Jump To Label : " + text,
				"color": color_theme.get("color8", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Comment
func _format_command_31(data: FormatData) -> Array:
	var formatted_text = []
	var first_line = data.command.parameters.get("first_line", "")
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Comment : " + first_line,
				"color": color_theme.get("color9", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Comment Line
func _format_command_32(data: FormatData) -> Array:
	var formatted_text = []
	var line = data.command.parameters.get("line", "")
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + ": " + line,
				"color": color_theme.get("color9", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text + " Comment ", data.align, -1, data.font_size).x,
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Wait
func _format_command_33(data: FormatData) -> Array:
	var formatted_text = []
	var value = data.command.parameters.get("duration", 0)
	var s = "second" + ("s" if value != 1 else "")
	var text = "%s %s" % [value, s]
	var is_local_wait = data.command.parameters.get("is_local", false)
	var w = "" if not is_local_wait else " (local to this event)"
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Wait : " + text + w,
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Instant Text
func _format_command_34(data: FormatData) -> Array:
	var formatted_text = []
	var first_line = data.command.parameters.get("first_line", "")
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Instant Text : ",
				"color": color_theme.get("color2", Color.WHITE)
			},
			{
				"text": first_line,
				"color": color_theme.get("color4", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Instant Text Line
func _format_command_35(data: FormatData) -> Array:
	var formatted_text = []
	var line = data.command.parameters.get("line", "")
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + ": ",
				"color": color_theme.get("color2", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text + " Instant Text ", data.align, -1, data.font_size).x,
			},
			{
				"text": line,
				"color": color_theme.get("color4", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text + " Instant Text ", data.align, -1, data.font_size).x,
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Change Leader
func _format_command_36(data: FormatData) -> Array:
	var formatted_text = []
	var leader_id = data.command.parameters.get("leader_id", -1)
	var is_locked = data.command.parameters.get("is_locked", false)
	var text: String
	
	if RPGSYSTEM.database.actors.size() > leader_id and leader_id != -1:
		text = "[%s: %s]" % [leader_id, RPGSYSTEM.database.actors[leader_id].name]
	else:
		text = "⚠ Invalid Data"
	
	formatted_text.append({
		"texts": [
			{
				"text": data.tabs + default_text + " Set Leader : " + text,
				"color": color_theme.get("color5", Color.WHITE)
			},
			{
				"text": "(locked)" if is_locked else "",
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	})
	return formatted_text

# Change Actor HP
func _format_command_37(data: FormatData) -> Array:
	return _format_change_actor_stat(data, "HP")

# Change Actor MP
func _format_command_38(data: FormatData) -> Array:
	return _format_change_actor_stat(data, "MP")

# Change Actor TP
func _format_command_39(data: FormatData) -> Array:
	return _format_change_actor_stat(data, "TP")

# Change Actor Experience
func _format_command_42(data: FormatData) -> Array:
	return _format_change_actor_stat(data, "Experience", true)

# Change Actor Level
func _format_command_43(data: FormatData) -> Array:
	return _format_change_actor_stat(data, "Level", true)

# Change Actor Parameter
func _format_command_44(data: FormatData) -> Array:
	var parameter_names = [
		"Max HP", "Max MP", "Attack", "Defense", "Magical Attack",
		"Magical Defense", "Agility", "Luck"
	]
	var param_id = data.command.parameters.get("parameter_id", 0)
	var param_name = "Parameter " + parameter_names[param_id]
	return _format_change_actor_stat(data, param_name)

# Change Actor State
func _format_command_40(data: FormatData) -> Array:
	var actor_type = data.command.parameters.get("actor_type", 0)
	var actor_id = data.command.parameters.get("actor_id", 0) if actor_type == 0 else data.command.parameters.get("actor_id", 1)
	var n0 = "State"
	var n1 = _get_actor_name_from_actor_type(actor_type, actor_id)
	var n2 = "Add" if data.command.parameters.get("operand", 0) == 0 else "Remove"
	var state_id = data.command.parameters.get("state_id", 1)
	var n3 = "{%s: %s}" % [state_id, RPGSYSTEM.database.states[state_id].name] if state_id > 0 and RPGSYSTEM.database.states.size() > state_id else "[%s: ]" % state_id

	return [{
		"texts": [{
			"text": data.tabs + default_text + " Change %s : %s, %s %s" % [n0, n1, n2, n3],
			"color": color_theme.get("color5", Color.WHITE)
		}],
		"offset_y": default_text_offset_y
	}]

# Change Actor Skill
func _format_command_45(data: FormatData) -> Array:
	var actor_type = data.command.parameters.get("actor_type", 0)
	var actor_id = data.command.parameters.get("actor_id", 0) if actor_type == 0 else data.command.parameters.get("actor_id", 1)
	var n0 = "Skill"
	var n1 = _get_actor_name_from_actor_type(actor_type, actor_id)
	var n2 = "Learn" if data.command.parameters.get("operand", 0) == 0 else "Forget"
	var skill_id = data.command.parameters.get("skill_id", 1)
	var n3 = "{%s: %s}" % [skill_id, RPGSYSTEM.database.skills[skill_id].name] if skill_id > 0 and RPGSYSTEM.database.skills.size() > skill_id else "[%s: ]" % skill_id

	return [{
		"texts": [{
			"text": data.tabs + default_text + " Change %s : %s, %s %s" % [n0, n1, n2, n3],
			"color": color_theme.get("color5", Color.WHITE)
		}],
		"offset_y": default_text_offset_y
	}]

# Actor Full Recovery
func _format_command_41(data: FormatData) -> Array:
	var actor_type = data.command.parameters.get("actor_type", 0)
	var actor_id = data.command.parameters.get("actor_id", 0) if actor_type == 0 else data.command.parameters.get("actor_id", 1)
	var n1 = _get_actor_name_from_actor_type(actor_type, actor_id)
	
	return [{
		"texts": [{
			"text": data.tabs + default_text + " Recover All : %s" % n1,
			"color": color_theme.get("color5", Color.WHITE)
		}],
		"offset_y": default_text_offset_y
	}]

# Actor Change Equipment
func _format_command_46(data: FormatData) -> Array:
	var actor_id = data.command.parameters.get("actor_id", 0)
	var equipment_type_id = data.command.parameters.get("equipment_type_id", 0)
	var item_id = data.command.parameters.get("item_id", 0)
	
	var n1 = _get_actor_name_from_actor_type(0, actor_id)
	var n2 = RPGSYSTEM.database.types.equipment_types[equipment_type_id] if RPGSYSTEM.database.types.equipment_types.size() > equipment_type_id else ""
	var data_list = RPGSYSTEM.database.weapons if equipment_type_id == 0 else RPGSYSTEM.database.armors
	var n3 = "[%s: %s]" % [item_id, data_list[item_id].name] if item_id > 0 and data_list.size() > item_id else ("none" if item_id == 0 else "[%s: ]" % item_id)
	
	return [{
		"texts": [{
			"text": data.tabs + default_text + " Change Equipment : %s, %s = %s" % [n1, n2, n3],
			"color": color_theme.get("color5", Color.WHITE)
		}],
		"offset_y": default_text_offset_y
	}]

# Actor Change Name
func _format_command_47(data: FormatData) -> Array:
	var actor_id = data.command.parameters.get("actor_id", 0)
	var actor_name = data.command.parameters.get("name", "")
	var n1 = _get_actor_name_from_actor_type(0, actor_id)
	
	return [{
		"texts": [{
			"text": data.tabs + default_text + " Change Name : %s → %s" % [n1, actor_name],
			"color": color_theme.get("color5", Color.WHITE)
		}],
		"offset_y": default_text_offset_y
	}]

# Actor Change Class
func _format_command_48(data: FormatData) -> Array:
	var actor_id = data.command.parameters.get("actor_id", 0)
	var class_id = data.command.parameters.get("class_id", 0)
	var keep_level = data.command.parameters.get("keep_level", false)
	var n1; var n2; var n3;
	if actor_id > 0 and RPGSYSTEM.database.actors.size() > actor_id:
		n1 = "[%s: %s]" % [actor_id, RPGSYSTEM.database.actors[actor_id].name]
	else:
		n1 = "[%s: ]" % actor_id
	if class_id > 0 and RPGSYSTEM.database.classes.size() > class_id:
		n2 = "[%s: %s]" % [class_id, RPGSYSTEM.database.classes[class_id].name]
	else:
		n2 = "[%s: ]" % class_id
	n3 = "keep level" if keep_level else "reset level"

	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change class : %s → %s" % [n1, n2],
				"color": color_theme.get("color5", Color.WHITE)
			},
			{
				"text": " (%s)" % n3,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Profession
func _format_command_300(data: FormatData) -> Array:
	var type = data.command.parameters.get("type", 0)
	var type_str = tr("Remove Profession") if type == 0 else tr("Add Profession")
	var profession_id = data.command.parameters.get("profession_id", 1)
	var profession_name = ""
	if profession_id > 0 and RPGSYSTEM.database.professions.size() > profession_id:
		var profession = RPGSYSTEM.database.professions[profession_id]
		profession_name = "%s: %s" % [profession.id, profession.name]
	var extra_arg: String = ""
	if type == 0:
		extra_arg = "(" + (tr("Reset Level") if data.command.parameters.get("reset_level", false) else tr("Keep Level")) + ")"
	else:
		var action_type = data.command.parameters.get("action_type", 0)
		if action_type == 0:
			extra_arg = "(" + tr("Preserve Level") + ")"
		else:
			var level = tr("Level") + " " + str(int(data.command.parameters.get("level", 1)))
			extra_arg = "(" + level + ")"
	
	
	var level: String
	if data.command.parameters.get("preserve_level", false):
		level = " (" + tr("Preserve Level") + ")"
	else:
		level = " " + tr("Level") + " " + str(data.command.parameters.get("level", 1)) if type == 1 else ""
	var reset_level = tr("Reset Level") if data.command.parameters.get("reset_level", false) else ""

	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " " + type_str + " <" + profession_name + ">",
				"color": color_theme.get("color5", Color.WHITE)
			},
			{
				"text": " %s" % extra_arg,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Upgrade Profession
func _format_command_301(data: FormatData) -> Array:
	var profession_id = data.command.parameters.get("profession_id", 1)
	var prefession_name: String
	if profession_id > 0 and RPGSYSTEM.database.professions.size() > profession_id:
		var profession = RPGSYSTEM.database.professions[profession_id]
		prefession_name = "%s: %s" % [profession_id, profession.name]
	
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Upgrade Profession : < %s >" % prefession_name,
				"color": color_theme.get("color5", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Actor Actor Nickname
func _format_command_49(data: FormatData) -> Array:
	var actor_id = data.command.parameters.get("actor_id", 0)
	var actor_nickname = data.command.parameters.get("nickname", "")
	var n1;
	if actor_id > 0 and RPGSYSTEM.database.actors.size() > actor_id:
		n1 = "[%s: %s]" % [actor_id, RPGSYSTEM.database.actors[actor_id].name]
	else:
		n1 = "[%s: ]" % actor_id

	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Nickname : %s → %s" % [n1, actor_nickname],
				"color": color_theme.get("color5", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Actor Profile (First Line)
func _format_command_50(data: FormatData) -> Array:
	var actor_id = data.command.parameters.get("actor_id", 0)
	var n1;
	if actor_id > 0 and RPGSYSTEM.database.actors.size() > actor_id:
		n1 = "[%s: %s]" % [actor_id, RPGSYSTEM.database.actors[actor_id].name]
	else:
		n1 = "[%s: ]" % actor_id
	
	last_offset_setted = data.font.get_string_size(default_text + " Change Profile ", data.align, -1, data.font_size).x

	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Profile : %s" % n1,
				"color": color_theme.get("color5", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Actor Profile (Other Line)
func _format_command_51(data: FormatData) -> Array:
	var line = data.command.parameters.get("line", "")
	return [{
		"texts": [
			{
				"text": data.tabs + ": ",
				"color": color_theme.get("color5", Color.WHITE),
				"offset_x": last_offset_setted,
			},
			{
				"text": line,
				"color": color_theme.get("color4", Color.WHITE),
				"offset_x": last_offset_setted,
			}
		],
		"offset_y": default_text_offset_y
	}]

# Set Transition Config
func _format_command_52(data: FormatData) -> Array:
	var list = ["Instant", "Fade Out-In", "Fade Out To Color", "Shader Transition", "Custom Scene"]
	var type = max(0, min(data.command.parameters.get("type", 0), list.size() - 1))
	var duration = data.command.parameters.get("duration", 0)
	var transition_color = data.command.parameters.get("transition_color", Color.BLACK)
	var transition_image = data.command.parameters.get("transition_image", "")
	var scene_image = data.command.parameters.get("scene_image", "")

	var contents = ""
	if type > 0:
		contents += ": %s seconds" % duration
		if type == 3:
			contents += ", Image: %s" % transition_image.get_file()
			var invert = tr(", Invert Fade Out") if data.command.parameters.get("invert", false) else ""
			contents += invert
		elif type == 4:
			contents += ", Scene: %s" % scene_image.get_file()
	else:
		contents = "."

	var result = [{
		"texts": [
			{
				"text": data.tabs + default_text + " Set Transition \"%s\"" % list[type],
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": contents,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

	if type == 2:
		result[-1].texts.append({
			"text": ", ",
			"color": color_theme.get("color3", Color.WHITE)
		})
		result[-1].texts.append({
			"text": "Color: #%s" % transition_color.to_html(),
			"color": transition_color
		})

	return result

# Transfer
func _format_command_53(data: FormatData) -> Array:
	var target_id = data.command.parameters.get("target", 0)
	var type = data.command.parameters.get("type", 0)
	var pa = data.command.parameters.get("value", {})
	var target: String
	var value: String

	if target_id == 0:
		target = "Player"
	elif target_id == 1:
		var vehicle_id = data.command.parameters.get("vehicle_id", 0)
		if vehicle_id == 0:
			target = "Land Transport"
		elif vehicle_id == 1:
			target = "Sea Transport"
		elif vehicle_id == 2:
			target = "Air Transport"
	elif target_id == 2:
		var event_id = pa.get("event_id", 0)
		if event_id <= 0:
			target = "This Event"
		else:
			target = "Event " + str(event_id)

	if type == 0:
		var map_id = pa.get("assigned_map_id", 0)
		var x = pa.get("assigned_x", 0)
		var y = pa.get("assigned_y", 0)
		var map_name: String
		var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
		if edited_scene and edited_scene is RPGMap:
			if edited_scene and edited_scene.internal_id == map_id:
				map_name = "Current Map"
			else:
				map_name = RPGMapsInfo.get_map_name_from_id(map_id)
		var pos = Vector2i(x, y)
		value = "%s %s" % [map_name, pos]
	elif type == 1:
		var map_id = pa.get("map_id", 0)
		var x = pa.get("x", 0)
		var y = pa.get("y", 0)
		var variable_name1: String
		if target_id == 2:
			variable_name1 = "Current Map"
		else:
			var id1 = str(map_id).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
			variable_name1 = "Map = " + id1 + ": " + RPGSYSTEM.system.variables.get_item_name(map_id)
		var id2 = str(x).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		var variable_name2 = id2 + ": " + RPGSYSTEM.system.variables.get_item_name(x)
		var id3 = str(y).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		var variable_name3 = id3 + ": " + RPGSYSTEM.system.variables.get_item_name(y)
		value = "%s, x = %s, y = %s" % [variable_name1, variable_name2, variable_name3]
	elif type == 2:
		var swap_event_id = pa.get("swap_event_id", 0)
		value = "Swap position with < event %s >" % [swap_event_id]

	var current_direction = data.command.parameters.get("direction", 0)
	var direction = "Hold direction" if current_direction == 0 else \
		"Look At Up" if current_direction == 1 else \
		"Look At Down" if current_direction == 2 else \
		"Look At Left" if current_direction == 3 else \
		"Look At Right"
	value += ", %s" % direction

	if target_id == 0:
		var delay_transfer = tr("Delay Transfer") if data.command.parameters.get("delay_transfer", false) else ""
		if not delay_transfer.is_empty():
			delay_transfer = " (" + delay_transfer + ")" 
		value += delay_transfer

	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Transfer %s : " % target,
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": value,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Scroll / Zoom Map
func _format_command_54(data: FormatData) -> Array:
	var type = data.command.parameters.get("type", 0)
	var duration = data.command.parameters.get("duration", 0)
	var text: String
	var action_name = "Scroll Map" if type == 0 else "Zoom Map" if type == 1 else "Reset Scroll And Zoom"
	if type == 0:
		var directions = ["UP", "DOWN", "LEFT", "RIGHT"]
		var direction = data.command.parameters.get("direction", 0)
		var amount = data.command.parameters.get("amount", 0)
		if amount == 1:
			text = "Move %s tile to %s" % [amount, directions[direction]]
		else:
			text = "Move %s tiles to %s" % [amount, directions[direction]]
	elif type == 1:
		var zoom = data.command.parameters.get("zoom", 0)
		text = "Set zoom to %s" % zoom
		
	if type != 2:
		text += " in %s seconds" % duration if duration != 1 else " in %s second" % duration
	else:
		text += "Duration: %s seconds" % duration if duration != 1 else "Duration: %s second" % duration
	
	var wait = data.command.parameters.get("wait", true)
	if wait:
		text += ", Wait"
		
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + (" %s : " % action_name) + text,
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Perform Transition
func _format_command_55(data: FormatData) -> Array:
	var transition_type = clamp(data.command.parameters.get("type", 0), 0, 1)
	var str = tr("Transition Out") if transition_type == 0 else "Transition In"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Perform Transition : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": str,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Movement Route (Start Movement Command)
func _format_command_57(data: FormatData) -> Array:
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	var n1: String
	var target = data.command.parameters.get("target", 0)

	if edited_scene and edited_scene is RPGMap:
		if target == -1:
			n1 = "Player"
		elif target == 0:
			n1 = "This Event"
		else:
			var event = edited_scene.events.get_event_by_id(target)
			if event:
				n1 = "[%s: %s]" % [event.id, event.name]
			else:
				n1 = "[]"
	else:
		n1 = "This Event"
	var n2: String = "Repeat" if data.command.parameters.get("loop", false) else "No Repeat"
	var n3: String = "Skippeable" if data.command.parameters.get("skippable", false) else "No Skippeable"
	var n4: String = "Await Move End" if data.command.parameters.get("wait", false) else "No Wait"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Move %s : " % n1,
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "[ %s, %s, %s ]" % [n2, n3, n4],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Movement Command
func _format_command_58(data: FormatData) -> Array:
	var movement_command_name = get_formated_movement_command(data.command.parameters.get("movement_command", null))
	return [{
		"texts": [
			{
				"text": data.tabs + ": " + movement_command_name,
				"color": color_theme.get("color10", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text + " Move %s " % backup_text, data.align, -1, data.font_size).x,
			}
		],
		"offset_y": default_text_offset_y
	}]

# Get in / out Vehicle
func _format_command_59(data: FormatData) -> Array:
	var type = data.command.parameters.get("type", 0)
	var action_name: String = " Board " if type == 0 else " Get out of the transport."
	var text: String = ""
	if type == 0:
		var vehicles = ["a land transport.", "a sea transport.", "an air transport."]
		var transport_id = clamp(data.command.parameters.get("transport_id", 0), 0, vehicles.size() - 1)
		text = vehicles[transport_id]
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + action_name + text,
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change combat experience mode
func _format_command_60(data: FormatData) -> Array:
	var mode = "All Characters" if data.command.parameters.get("type", 0) == 0 else "Only Members In Battle"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Experience Mode : %s" % mode,
				"color": color_theme.get("color5", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Set text variable
func _format_command_61(data: FormatData) -> Array:
	var variable_id = data.command.parameters.get("id", 0)
	var value = data.command.parameters.get("value", "")
	var id = str(variable_id).pad_zeros(str(RPGSYSTEM.system.text_variables.size()).length())
	var variable_name = id + ": " + RPGSYSTEM.system.text_variables.get_item_name(variable_id)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Text Variable %s = %s" % [variable_name, value],
				"color": color_theme.get("color6", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Add or remove actor trait
func _format_command_62(data: FormatData) -> Array:
	var type = data.command.parameters.get("type", 0)
	var current_trait = data.command.parameters.get("trait", 0)
	var trait_name = get_trait_name(current_trait)
	trait_name = "< " + ": ".join(trait_name) + " >"
	var actor_id = data.command.parameters.get("actor_id", 0)
	var actor_name = "Entire Party" if actor_id == 0 else get_actor_name(actor_id)
	var action_name = "Add trait to %s" % actor_name if type == 0 else "Remove trait from %s" % actor_name
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " %s: %s" % [action_name, trait_name],
				"color": color_theme.get("color5", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Fade Out
func _format_command_63(data: FormatData) -> Array:
	var duration = data.command.parameters.get("duration", 0.5)
	var seconds = "seconds" if duration != 1.0 else "second"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " FadeOut in %s %s" % [duration, seconds],
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Fade In
func _format_command_64(data: FormatData) -> Array:
	var duration = data.command.parameters.get("duration", 0.5)
	var seconds = "seconds" if duration != 1.0 else "second"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " FadeIn in %s %s" % [duration, seconds],
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Tint Screen Color
func _format_command_65(data: FormatData) -> Array:
	var color = data.command.parameters.get("color", Color.BLACK)
	var duration = data.command.parameters.get("duration", 0.5)
	var seconds = "seconds" if duration != 1.0 else "second"
	var wait_enabled = data.command.parameters.get("wait", false)
	var remove = data.command.parameters.get("remove", false)
	var t = " Tint Screen in %s %s with " % [duration, seconds] if not remove else " Remove Tint Screen in %s %s with " % [duration, seconds]
	var result = [{
		"texts": [
			{
				"text": data.tabs + default_text + " Tint Screen in %s %s with " % [duration, seconds],
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "color #" + color.to_html(),
				"color": color
			}
		],
		"offset_y": default_text_offset_y
	}]
	if wait_enabled:
		result[-1].texts.append({
			"text": " (wait)",
			"color": color_theme.get("color3", Color.WHITE)
		})
	return result

# Flash Screen
func _format_command_66(data: FormatData) -> Array:
	var color = data.command.parameters.get("color", Color.BLACK)
	var duration = data.command.parameters.get("duration", 0.5)
	var seconds = "seconds" if duration != 1.0 else "second"
	var wait_enabled = data.command.parameters.get("wait", false)
	var result = [{
		"texts": [
			{
				"text": data.tabs + default_text + " Show Flash in %s %s with " % [duration, seconds],
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "color #" + color.to_html(),
				"color": color
			}
		],
		"offset_y": default_text_offset_y
	}]
	if wait_enabled:
		result[-1].texts.append({
			"text": " (wait)",
			"color": color_theme.get("color3", Color.WHITE)
		})
	return result

# Shake Screen
func _format_command_67(data: FormatData) -> Array:
	var duration = data.command.parameters.get("duration", 0.5)
	var seconds = "seconds" if duration != 1.0 else "second"
	var power = data.command.parameters.get("power", 4500)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Shake Screen in %s %s with power %s" % [duration, seconds, power],
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Add Or Remove Weather Scene
func _format_command_68(data: FormatData) -> Array:
	var type = data.command.parameters.get("type", 0)
	var id = data.command.parameters.get("id", 1)
	var scene = data.command.parameters.get("scene", "")
	var command_text = ""
	if type == 0:
		command_text = "Add Weather scene %s with id %s" % [scene.get_file(), id]
	else:
		command_text = "Remove Weather scene with id %s" % id
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " " + command_text,
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Player Transparency
func _format_command_69(data: FormatData) -> Array:
	var transparency = "%.2f%%" % (data.command.parameters.get("value", 1.0) * 100)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change player opacity to " + transparency,
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Player Followers
func _format_command_70(data: FormatData) -> Array:
	var enabled = "Enable" if data.command.parameters.get("value", true) else "Disable"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " %s player followers" % enabled,
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Followers Leader Tracking
func _format_command_71(data: FormatData) -> Array:
	var enabled = "Enabled" if data.command.parameters.get("value", true) else "Disabled"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Party Leader Tracking: %s" % enabled,
				"color": color_theme.get("color10", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Show Animation
func _format_command_72(data: FormatData) -> Array:
	var target_id = data.command.parameters.get("target_id", 0)
	var target_name = get_event_name(target_id)
	var animation_id = data.command.parameters.get("animation_id", 1)
	var animation_name = get_item_data_name(RPGSYSTEM.database.animations, animation_id)
	var wait = data.command.parameters.get("wait", false)
	var wait_text = _get_wait_text(wait)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Show Animation : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "[%s, %s%s]" % [target_name, animation_name, wait_text],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Show Balloon Icon
func _format_command_73(data: FormatData) -> Array:
	var target_id = data.command.parameters.get("target_id", 0)
	var target_name = get_event_name(target_id)
	var path = data.command.parameters.get("path", "")
	var wait = data.command.parameters.get("wait", false)
	var wait_text = _get_wait_text(wait)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Show Balloon Icon : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "[%s, %s%s]" % [target_name, path.get_file(), wait_text],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Do Player Action
func _format_command_74(data: FormatData) -> Array:
	var action_index = data.command.parameters.get("index", 0)
	var animation_names = ["To Attack", "To Cast", "To Fish", "To Water"]
	var action_name = animation_names[action_index] if animation_names.size() > action_index else "⚠ Invalid Data"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Do Player Action : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": action_name,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Show Image
func _format_command_75(data: FormatData) -> Array:
	var image_index = data.command.parameters.get("index", 1)
	var path = data.command.parameters.get("path", "").get_file()
	var image_type = max(0, min(1, data.command.parameters.get("image_type", 0)))
	var type = ["Map Image", "Screen Image"][image_type]
	var origin_index = max(0, min(1, data.command.parameters.get("origin", 0)))
	var origin = ["Center", "Top Left"][origin_index]
	var position_type = data.command.parameters.get("position_type", 0)
	var pos: String
	var v = data.command.parameters.get("position", Vector2i.ZERO if position_type == 0 else Vector2i.ONE)
	if position_type == 0:
		pos = "p:" + str(v)
	else:
		var id = str(v.x).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		var v1_name = id + ": " + RPGSYSTEM.system.variables.get_item_name(v.x)
		var id2 = str(v.y).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		var v2_name = id + ": " + RPGSYSTEM.system.variables.get_item_name(v.y)
		pos = "p:(#%s, #%s)" % [v1_name, v2_name]
	var image_scale = data.command.parameters.get("scale", 0) * 100
	var image_scale_name = "s:(%.2f%%, %.2f%%)" % [image_scale.x, image_scale.y]
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Show Image : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "ID #%s (%s) - %s, %s, %s, %s" % [image_index, type, path, origin, pos, image_scale_name],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Move Image
func _format_command_76(data: FormatData) -> Array:
	var image_index = data.command.parameters.get("index", 1)
	var duration = data.command.parameters.get("duration", 0)
	var duration_name = "%.2f seconds" % duration if duration != 1 else "%.2f second" % duration
	var wait = data.command.parameters.get("wait", false)
	var wait_text = _get_wait_text(wait)
	var params = _get_image_command_parameter(data)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Move Image : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "ID %s, " % image_index,
				"color": color_theme.get("color3", Color.WHITE)
			},
			{
				"text": "%s, " % params["main_parameter"],
				"color": params["param_color"]
			},
			{
				"text": "%s%s" % [duration_name, wait_text],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Rotate Image
func _format_command_77(data: FormatData) -> Array:
	var image_index = data.command.parameters.get("index", 1)
	var duration = data.command.parameters.get("duration", 0)
	var duration_name = "%.2f seconds" % duration if duration != 1 else "%.2f second" % duration
	var wait = data.command.parameters.get("wait", false)
	var wait_text = _get_wait_text(wait)
	var params = _get_image_command_parameter(data)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Rotate Image : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "ID %s, " % image_index,
				"color": color_theme.get("color3", Color.WHITE)
			},
			{
				"text": "%s, " % params["main_parameter"],
				"color": params["param_color"]
			},
			{
				"text": "%s%s" % [duration_name, wait_text],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Scale Image
func _format_command_78(data: FormatData) -> Array:
	var image_index = data.command.parameters.get("index", 1)
	var duration = data.command.parameters.get("duration", 0)
	var duration_name = "%.2f seconds" % duration if duration != 1 else "%.2f second" % duration
	var wait = data.command.parameters.get("wait", false)
	var wait_text = _get_wait_text(wait)
	var params = _get_image_command_parameter(data)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Scale Image : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "ID %s, " % image_index,
				"color": color_theme.get("color3", Color.WHITE)
			},
			{
				"text": "%s, " % params["main_parameter"],
				"color": params["param_color"]
			},
			{
				"text": "%s%s" % [duration_name, wait_text],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Tint Image
func _format_command_79(data: FormatData) -> Array:
	var image_index = data.command.parameters.get("index", 1)
	var duration = data.command.parameters.get("duration", 0)
	var duration_name = "%.2f seconds" % duration if duration != 1 else "%.2f second" % duration
	var wait = data.command.parameters.get("wait", false)
	var wait_text = _get_wait_text(wait)
	var params = _get_image_command_parameter(data)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Tint Image : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "ID %s, " % image_index,
				"color": color_theme.get("color3", Color.WHITE)
			},
			{
				"text": "%s, " % params["main_parameter"],
				"color": params["param_color"]
			},
			{
				"text": "%s%s" % [duration_name, wait_text],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Erase Image
func _format_command_80(data: FormatData) -> Array:
	var image_index = data.command.parameters.get("index", 1)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Erase Image : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "ID %s" % image_index,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Add Scene
func _format_command_81(data: FormatData) -> Array:
	var scene_index = int(data.command.parameters.get("index", 1))
	var scene_path = data.command.parameters.get("path", "").get_file()
	var wait = data.command.parameters.get("wait", false)
	var wait_text = _get_wait_text(wait)
	var is_map_scene = data.command.parameters.get("is_map_scene", false)
	var is_map_scene_str = "" if not is_map_scene else " (map scene)"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Add Scene : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "ID %s, %s%s%s" % [scene_index, scene_path, wait_text, is_map_scene_str],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Manipulate_scene
# index, function_name, wait, params
func _format_command_124(data: FormatData) -> Array:
	var scene_index = data.command.parameters.get("index", 1)
	var func_name = data.command.parameters.get("func_name", 1)
	var params = data.command.parameters.get("params", [])
	var wait = data.command.parameters.get("wait", false)
	var wait_text = _get_wait_text(wait)
	
	var func_str = func_name + "("
	var add_comma = false
	for param: Dictionary in params:
		if add_comma:
			func_str += ", "
		match param.type:
			0, 1, 2:
				func_str += param.name + " = " + str(param.value)
			3:
				func_str += param.name + " = Switch #" + str(param.value)
			4:
				func_str += param.name + " = Numeric Variable #" + str(param.value)
			5:
				func_str += param.name + " = Text Variable #" + str(param.value)
		add_comma = true
	func_str += ")"
	
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Call Function in Scene : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "ID %s, " % scene_index,
				"color": color_theme.get("color3", Color.WHITE)
			},
			{
				"text": func_str,
				"color": color_theme.get("color2", Color.WHITE)
			},
			{
				"text": wait_text,
				"color": color_theme.get("color3", Color.WHITE)
			},
		],
		"offset_y": default_text_offset_y
	}]


# Erase Scene
func _format_command_82(data: FormatData) -> Array:
	var image_index = data.command.parameters.get("index", 0)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Erase Scene : ",
				"color": color_theme.get("color10", Color.WHITE)
			},
			{
				"text": "ID %s" % image_index,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Play BGM
func _format_command_83(data: FormatData) -> Array:
	var path = data.command.parameters.get("path", "").get_file()
	var volume = data.command.parameters.get("volume", 0.0)
	var pitch = data.command.parameters.get("pitch", 1.0)
	var fadein = data.command.parameters.get("fadein", 0.0)
	var fade_in_name = "" if fadein == 0.0 else ", fade in %.2f" % fadein
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Play BGM ",
				"color": color_theme.get("color11", Color.WHITE)
			},
			{
				"text": "%s, volume %s, pitch %s%s" % [path, volume, pitch, fade_in_name],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Stop BGM
func _format_command_84(data: FormatData) -> Array:
	var fade_out = data.command.parameters.get("duration", 0.0)
	var seconds = "second" if fade_out == 1.0 else "seconds"
	var fade_out_name = "fade out %.2f %s" % [fade_out, seconds]
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Stop BGM ",
				"color": color_theme.get("color11", Color.WHITE)
			},
			{
				"text": fade_out_name,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Save BGM
func _format_command_85(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Save BGM ",
				"color": color_theme.get("color11", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Resume BGM
func _format_command_86(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Resume BGM ",
				"color": color_theme.get("color11", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Play BGS
func _format_command_87(data: FormatData) -> Array:
	var path = data.command.parameters.get("path", "").get_file()
	var volume = data.command.parameters.get("volume", 0.0)
	var pitch = data.command.parameters.get("pitch", 1.0)
	var fadein = data.command.parameters.get("fadein", 0.0)
	var fade_in_name = "" if fadein == 0.0 else ", fade in %.2f" % fadein
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Play BGS ",
				"color": color_theme.get("color11", Color.WHITE)
			},
			{
				"text": "%s, volume %s, pitch %s%s" % [path, volume, pitch, fade_in_name],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Stop BGS
func _format_command_88(data: FormatData) -> Array:
	var fade_out = data.command.parameters.get("duration", 0.0)
	var seconds = "second" if fade_out == 1.0 else "seconds"
	var fade_out_name = "fade out %.2f %s" % [fade_out, seconds]
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Stop BGS ",
				"color": color_theme.get("color11", Color.WHITE)
			},
			{
				"text": fade_out_name,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Play ME
func _format_command_89(data: FormatData) -> Array:
	var path = data.command.parameters.get("path", "").get_file()
	var volume = data.command.parameters.get("volume", 0.0)
	var pitch = data.command.parameters.get("pitch", 1.0)
	var pitch_str = str(pitch)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Play ME ",
				"color": color_theme.get("color11", Color.WHITE)
			},
			{
				"text": "%s, volume %s, pitch %s" % [path, volume, pitch_str],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Play SE
func _format_command_90(data: FormatData) -> Array:
	var path = data.command.parameters.get("path", "").get_file()
	var volume = data.command.parameters.get("volume", 0.0)
	var pitch = data.command.parameters.get("pitch", 1.0)
	var pitch2 = data.command.parameters.get("pitch2", 0.0)
	var pitch_str = str(pitch) if pitch == pitch2 else "%s~%s" % [pitch, pitch2]
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Play SE ",
				"color": color_theme.get("color11", Color.WHITE)
			},
			{
				"text": "%s, volume %s, pitch %s" % [path, volume, pitch_str],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Stop SE
func _format_command_91(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Stop SE ",
				"color": color_theme.get("color11", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Play Video
func _format_command_92(data: FormatData) -> Array:
	var video_path = data.command.parameters.get("path", "").get_file()
	var wait = data.command.parameters.get("wait", false)
	var wait_text = _get_wait_text(wait)
	var loop = data.command.parameters.get("loop", false)
	var loop_text = " (loop)" if loop else ""
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Play Movie ",
				"color": color_theme.get("color11", Color.WHITE)
			},
			{
				"text": "%s%s%s" % [video_path, wait_text, loop_text],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Stop Video
func _format_command_93(data: FormatData) -> Array:
	var fade_out = data.command.parameters.get("duration", 0.0)
	var seconds = "second" if fade_out == 1.0 else "seconds"
	var fade_out_name = "fade out %.2f %s" % [fade_out, seconds]
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Stop Movie ",
				"color": color_theme.get("color11", Color.WHITE)
			},
			{
				"text": fade_out_name,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Manage Camera Targets
func _format_command_123(data: FormatData) -> Array:
	var targets = data.command.parameters.get("targets", [])
	var targets_str = ""
	if targets.has(0):
		targets_str += "player"
	for target in targets:
		if target != 0:
			targets_str += ", ev #%s" % target
	
	var target_color = color_theme.get("color3", Color.WHITE)
	if targets_str.is_empty():
		targets_str = tr("Remove all targets")
		target_color = color_theme.get("color10", Color.WHITE)
	else:
		targets_str = "[ " + targets_str + " ]"
		
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Camera Targets: ",
				"color": color_theme.get("color12", Color.WHITE)
			},
			{
				"text": targets_str,
				"color": target_color
			}
		],
		"offset_y": default_text_offset_y
	}]


# Erase Event
func _format_command_94(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Erase Event ",
				"color": color_theme.get("color12", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Resume Dialog
func _format_command_95(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Resume Text Dialog ",
				"color": color_theme.get("color2", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Show Shop
func _format_command_96(data: FormatData) -> Array:
	var modes = [
		tr("Allows Selling Everything"),
		tr("Does Not Allow Selling Anything"),
		tr("Allows Selling Items"),
		tr("Allows Selling Weapons"),
		tr("Allows Selling Armor"),
		tr("Allows Selling Specific Objects") 
	]
	var sales_mode = clamp(data.command.parameters.get("sales_mode", 0), 0, modes.size() - 1)
	var sales_ratio = data.command.parameters.get("sales_ratio", 0) if sales_mode != 1 else ""
	var purchase_ratio = data.command.parameters.get("purchase_ratio", 0)
	var sales_ratio_str = tr("Sales Ratio:") +  " %s%%" % sales_ratio if sales_ratio else ""
	var sales_ratio_final_str = " , %s" % sales_ratio_str if sales_mode != 1 else ""
	var purchase_ratio_str = tr("Purchase Ratio:") +  " %s%%" % purchase_ratio if purchase_ratio else ""
	var shop_name = data.command.parameters.get("shop_name", "")
	var shop_name_formatted = "" if shop_name.is_empty() else " <%s>" % shop_name
	backup_text = shop_name_formatted
	
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Show Shop%s: " % shop_name_formatted,
				"color": color_theme.get("color13", Color.WHITE)
			},
			{
				"text": "[%s, %s%s]" % [modes[sales_mode], purchase_ratio_str, sales_ratio_final_str],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Open Blacksmith Shop
func _format_command_200(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Open Blacksmith Shop",
				"color": color_theme.get("color13", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Class Upgrade Shop
func _format_command_201(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Class Upgrade Shop",
				"color": color_theme.get("color13", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Item Sold in the Store
func _format_command_97(data: FormatData) -> Array:
	var item_type = data.command.parameters.get("type", 0)
	var item_id = data.command.parameters.get("item_id", 1)
	var quantity: int = data.command.parameters.get("quantity", 0)
	var quantity_str = str(quantity) if quantity > 0 else "∞"
	var price_mode = data.command.parameters.get("price_mode", 0)
	var item_data = RPGSYSTEM.database.items if item_type == 0 \
					else RPGSYSTEM.database.weapons if item_type == 1 \
					else RPGSYSTEM.database.armors
	var item = get_item_data(item_data, item_id)
	var item_name = "" if not item else item.name
	var price: int = data.command.parameters.get("price", 0) if price_mode == 1 else item.price if item else 0
	var plural = "s" if quantity != 1 else ""
	return [{
		"texts": [
			{
				"text": data.tabs + ": Selling %s item%s < %s > at %s each" % [quantity_str, plural, item_name, price],
				"color": color_theme.get("color14", Color.WHITE),
				"offset_x": data.font.get_string_size(default_text + " Show Shop%s" % backup_text, data.align, -1, data.font_size).x,
			}
		],
		"offset_y": default_text_offset_y
	}]

# Input Change Actor Name
func _format_command_98(data: FormatData) -> Array:
	var actor_id = data.command.parameters.get("actor_id", 1)
	var actor_name = str(actor_id) + ": " + get_actor_name(actor_id)
	var max_letters = data.command.parameters.get("max_letters", 0)
	var max_letters_str = str(max_letters) if max_letters > 0 else "∞"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Show Change Actor Name Scene : ",
				"color": color_theme.get("color13", Color.WHITE)
			},
			{
				"text": "Actor: %s, Max Characters: %s" % [actor_name, max_letters_str],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Show Menu Scene
func _format_command_99(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Show Menu Scene",
				"color": color_theme.get("color13", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Show Save Scene
func _format_command_100(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Show Save Scene",
				"color": color_theme.get("color13", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Show Game Over Scene
func _format_command_101(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Show Game Over Scene",
				"color": color_theme.get("color13", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Show Title Scene
func _format_command_102(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Show Title Scene",
				"color": color_theme.get("color13", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Map Name Display
func _format_command_103(data: FormatData) -> Array:
	var is_selected = "Display" if data.command.parameters.get("selected", false) else "No Display"
	return [{
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Change Map Name Display : ",
				"color": color_theme.get("color13", Color.WHITE)
			},
			{
				"text": "%s" % is_selected,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Select Battle Background
func _format_command_104(data: FormatData) -> Array:
	var path = data.command.parameters.get("path", "").get_file()
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Select Battle Background : ",
				"color": color_theme.get("color13", Color.WHITE)
			},
			{
				"text": "%s" % path,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Select Map Parallax
func _format_command_105(data: FormatData) -> Array:
	var path = data.command.parameters.get("path", "").get_file()
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Select Map Parallax : ",
				"color": color_theme.get("color13", Color.WHITE)
			},
			{
				"text": "%s" % path,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Get Location Info
func _format_command_106(data: FormatData) -> Array:
	var variable_type = data.command.parameters.get("variable_type", 0)
	var variable_id = data.command.parameters.get("variable_id", 0)
	var location_type = data.command.parameters.get("location_type", 0)
	var cell = data.command.parameters.get("cell", Vector2.ZERO)
	var variable_name: String
	var info: String
	var options: Array
	if variable_type == 0:
		var id = str(variable_id).pad_zeros(str(RPGSYSTEM.system.variables.size()).length())
		variable_name = "<V " + id + ": " + RPGSYSTEM.system.variables.get_item_name(variable_id) + " >"
		options = ["Is Flipped Horizontally", "Is Flipped Vertically", "Terrain ID",
		"Terrain Set ID", "Y Sort Origin", "Z-Index", "Is Transpose"]
	else:
		var id = str(variable_id).pad_zeros(str(RPGSYSTEM.system.text_variables.size()).length())
		variable_name = "<T " + id + ": " + RPGSYSTEM.system.text_variables.get_item_name(variable_id) + " >"
		options = ["Terrain Name", "Texture Name"]
		var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
		if edited_scene and edited_scene is RPGMap:
			var custom_layers: PackedStringArray = edited_scene.get_custom_data_layer_names()
			for layer in custom_layers:
				options.append("Get data from custom data layer < %s >" % layer)
	info = options[location_type] if options.size() > location_type else "⚠ Invalid Data"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Get Location Info : ",
				"color": color_theme.get("color13", Color.WHITE),
			},
			{
				"text": "\"%s\" from cell %s, store in %s" % [info, cell, variable_name],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Tileset
func _format_command_202(data: FormatData) -> Array:
	var path: String = data.command.parameters.get("path", "").get_file()
	if path.is_empty():
		path = "Erase Current Tileset"
	var layer: int = data.command.parameters.get("layer", 0)
	var layers: Array = []
	var layer_str: String
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene is RPGMap:
		for child in edited_scene.get_children():
			if child is TileMapLayer:
				layers.append(child.name)
	layer_str = "%s: %s" % [layer, layers[layer]] if layers.size() > layer else "⚠ Invalid Data"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Tileset : ",
				"color": color_theme.get("color13", Color.WHITE),
			},
			{
				"text": "Layer \"%s\", New tileset \"%s\"" % [layer_str, path],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]


# Change Tile/s State
func _format_command_125(data: FormatData) -> Array:
	var layer: int = data.command.parameters.get("layer", 0)
	var layers: Array = []
	var layer_str: String
	var edited_scene = RPGSYSTEM.editor_interface.get_edited_scene_root()
	if edited_scene and edited_scene is RPGMap:
		for child in edited_scene.get_children():
			if child is TileMapLayer:
				layers.append(child.name)
	var use_all_layers = data.command.parameters.get("use_all_layers", false)
	if not use_all_layers:
		layer_str = "%s: %s" % [layer, layers[layer]] if layers.size() > layer else "⚠ Invalid Data"
	else:
		layer_str = "All Layers"
	var state = data.command.parameters.get("state", false)
	var tiles = data.command.parameters.get("tiles", [])
	var str_tile = ""
	if tiles.size() > 0:
		if tiles.size() == 1:
			str_tile = " %s" % tiles[0]
		else:
			str_tile = " From %s To %s" % [tiles[0],  tiles[-1]]
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Tile State : ",
				"color": color_theme.get("color13", Color.WHITE),
			},
			{
				"text": "Tile%s in layer [%s] = %s" % [str_tile, layer_str, state],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]


# Change Battle BGM
func _format_command_110(data: FormatData) -> Array:
	var path: String = data.command.parameters.get("path", "").get_file()
	var volume: float = data.command.parameters.get("volume", 0.0)
	var pitch: float = data.command.parameters.get("pitch", 1.0)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Battle BGM : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "%s, volume %s, pitch %s" % [path, volume, pitch],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Victory ME
func _format_command_111(data: FormatData) -> Array:
	var path: String = data.command.parameters.get("path", "").get_file()
	var volume: float = data.command.parameters.get("volume", 0.0)
	var pitch: float = data.command.parameters.get("pitch", 1.0)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Victory ME : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "%s, volume %s, pitch %s" % [path, volume, pitch],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Defeat ME
func _format_command_112(data: FormatData) -> Array:
	var path: String = data.command.parameters.get("path", "").get_file()
	var volume: float = data.command.parameters.get("volume", 0.0)
	var pitch: float = data.command.parameters.get("pitch", 1.0)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Defeat ME : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "%s, volume %s, pitch %s" % [path, volume, pitch],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Save Access
func _format_command_113(data: FormatData) -> Array:
	var value: bool = data.command.parameters.get("selected", false)
	var str = "Enabled" if value else "Disabled"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Save Access : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "%s" % str,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Menu Access
func _format_command_114(data: FormatData) -> Array:
	var value: bool = data.command.parameters.get("selected", false)
	var str = "Enabled" if value else "Disabled"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Menu Access : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "%s" % str,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Formation Access
func _format_command_116(data: FormatData) -> Array:
	var value: bool = data.command.parameters.get("selected", false)
	var str = "Enabled" if value else "Disabled"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Formation Access : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "%s" % str,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Auto-Save Access
func _format_command_210(data: FormatData) -> Array:
	var value: bool = data.command.parameters.get("selected", false)
	var str = "Enabled" if value else "Disabled"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Auto-Save Access : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "%s" % str,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Post Battle Summary Access
func _format_command_211(data: FormatData) -> Array:
	var value: bool = data.command.parameters.get("selected", false)
	var str = "Enabled" if value else "Disabled"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " CChange Post Battle Summary Access : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "%s" % str,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Vehicle BGM
func _format_command_121(data: FormatData) -> Array:
	var vehicle_id: int = clamp(data.command.parameters.get("vehicle_id", 0), 0, 2)
	var path: String = data.command.parameters.get("path", "").get_file()
	var volume: float = data.command.parameters.get("volume", 0.0)
	var pitch: float = data.command.parameters.get("pitch", 1.0)
	var vehicle_str = ["Land Transport", "Sea Transport", "Air Transport"][vehicle_id]
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Vehicle < %s > BGM : " % vehicle_str,
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "%s, volume %s, pitch %s" % [path, volume, pitch],
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Encounter Rate
func _format_command_115(data: FormatData) -> Array:
	var value = data.command.parameters.get("value", 0)
	var value_str: String
	if value == 0:
		value_str = "Disabled Encounters"
	else:
		value_str = "Base Rates x %s%%" % value
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Encounter Rate : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": value_str,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Game Speed
func _format_command_117(data: FormatData) -> Array:
	var value = data.command.parameters.get("value", 0)
	var value_str = str(value)
	if value < 0.4:
		value_str += " (Ultra Slow Motion)"
	elif value < 0.7:
		value_str += " (Slow Motion)"
	elif value == 1.0:
		value_str += " (Default Speed)"
	elif value < 1.2:
		value_str += " Moderate Speed"
	elif value <= 2.0:
		value_str += " (Fast Speed)"
	elif value <= 3.0:
		value_str += " (Very Fast Speed)"
	elif value <= 3.5:
		value_str += " (Extreme Speed)"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Game Speed : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": value_str,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Actor Scene
func _format_command_118(data: FormatData) -> Array:
	var index = data.command.parameters.get("index", 0)
	var path = data.command.parameters.get("path", "").get_file()
	var new_scene: String
	if path.is_empty():
		new_scene = "Nothing"
	else:
		new_scene = path
	var actor_name = get_actor_name(index)
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Actor %s Scene : " % actor_name,
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "New Scene < %s >" % new_scene,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Vehicle Scene
func _format_command_119(data: FormatData) -> Array:
	var index = clamp(data.command.parameters.get("index", 0), 0, 2)
	var path = data.command.parameters.get("path", "").get_file()
	var new_scene: String
	if path.is_empty():
		new_scene = "Nothing"
	else:
		new_scene = path
	var vehicle_name = [tr("Land Transport"), tr("Sea Transport"), tr("Air Transport")][index]
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change < %s > Scene : " % vehicle_name,
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": "New Scene < %s >" % new_scene,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Change Language
func _format_command_120(data: FormatData) -> Array:
	var locale = data.command.parameters.get("locale", "")
	if locale.is_empty():
		locale = "en"
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Change Language : ",
				"color": color_theme.get("color15", Color.WHITE)
			},
			{
				"text": TranslationServer.get_language_name(locale),
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# Start Battle
func _format_command_500(data: FormatData) -> Array:
	var type = data.command.parameters.get("type", 0)
	var value = data.command.parameters.get("value", 1)
	var value_str: String = ""

	if type == 0:
		var troop_name = "<%s: %s>" % [
			RPGSYSTEM.database.troops[value].id,
			RPGSYSTEM.database.troops[value].name
		] if RPGSYSTEM.database.troops.size() > value else "⚠ Invalid Data"
		value_str = tr("Troop") + " %s" % troop_name
	elif type == 1:
		var variable_name = "<%s: %s>" % [
			value,
			RPGSYSTEM.system.variables.get_item_name(value)
		] if RPGSYSTEM.system.variables.size() > value else "⚠ Invalid Data"
		value_str = tr("Variable") + " %s" % variable_name
	else:
		value_str = tr("Select Random Troop")

	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Start Battle : ",
				"color": color_theme.get("color500", Color.WHITE)
			},
			{
				"text": value_str,
				"color": color_theme.get("color3", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# When Win Battle
func _format_command_501(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " When Win : ",
				"color": color_theme.get("color500", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# When Lost Battle
func _format_command_502(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " When Lost : ",
				"color": color_theme.get("color500", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# When Retreat From Battle
func _format_command_503(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " When Retreat : ",
				"color": color_theme.get("color500", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]

# End Start Battle Command
func _format_command_504(data: FormatData) -> Array:
	return [{
		"texts": [
			{
				"text": data.tabs + default_text + " Battle End",
				"color": color_theme.get("color500", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]


# Execuite Script Command
func _format_command_5000(data: FormatData) -> Array:
	var contents: String = data.command.parameters.get("script", "").replace("\n", "; ")
	var max_characteres = 26
	if contents.length() > max_characteres:
		contents = contents.left(max_characteres) + "..."
	return [{
		"texts": [
			{
				"text": data.tabs + default_no_editable_text + " Execute Script : ",
				"color": color_theme.get("color13", Color.WHITE)
			},
			{
				"text": contents,
				"color": color_theme.get("color4", Color.WHITE)
			}
		],
		"offset_y": default_text_offset_y
	}]


#endregion
