extends RefCounted



enum MessageTypes {USER, INFO, DEBUG}


const OUTPUT_TEMPLATE := "[color=palegreen]TileBitTools:[/color] %s"
const COLOR_TEMPLATE := "[color={color}]{msg}[/color]"

const ERROR_TEXT_TEMPLATE := "{error_text} (ERR {error})"
const ERROR_CODE_TEMPLATE := "(ERR {error})"
const OK_CODE_TEMPLATE := "(OK)"

const MESSAGE_ERROR_TEMPLATE := "{msg} ({error_string})"

const DEFAULT_ERROR_TEXT := "An error occurred"
const ERROR_COLOR := "salmon"
const WARNING_COLOR := "yellow"
const OK_COLOR := "palegreen"

const G := preload("res://addons/tile_bit_tools/core/globals.gd")

var texts := preload("res://addons/tile_bit_tools/core/texts.gd").new()


var message_type_settings := {
	MessageTypes.USER: G.Settings.output_show_user.path,
	MessageTypes.INFO: G.Settings.output_show_info.path,
	MessageTypes.DEBUG: G.Settings.output_show_debug.path,
}

var message_type_text_color := {
	MessageTypes.INFO: "webgray",
	MessageTypes.DEBUG: "palegoldenrod",
}


func user(msg, p_error := G.Errors.NULL_ERROR) -> void:
	_print_msg(msg, p_error, MessageTypes.USER)


func info(msg : String, p_error := G.Errors.NULL_ERROR) -> void:
	_print_msg(msg, p_error, MessageTypes.INFO)


func debug(msg : String, p_error := G.Errors.NULL_ERROR) -> void:
	_print_msg(msg, p_error, MessageTypes.DEBUG)


func error(msg : String, p_error : int = G.Errors.NULL_ERROR) -> void:
	if p_error != G.Errors.NULL_ERROR:
		msg = ERROR_TEXT_TEMPLATE.format({
			"error_text": msg,
			"error": error,
		})
	msg = COLOR_TEMPLATE.format({
		"color": ERROR_COLOR,
		"msg": msg,
	})

	_print_msg(msg, G.Errors.NULL_ERROR, MessageTypes.DEBUG)


func warning(msg : String, p_error : int = G.Errors.NULL_ERROR) -> void:
	if p_error != G.Errors.NULL_ERROR:
		msg = ERROR_TEXT_TEMPLATE.format({
			"error_text": msg,
			"error": error,
		})
	msg = COLOR_TEMPLATE.format({
		"color": WARNING_COLOR,
		"msg": msg,
	})

	_print_msg(msg, G.Errors.NULL_ERROR, MessageTypes.DEBUG)





func _print_msg(msg, p_error : G.Errors, msg_type : MessageTypes) -> void:
	if !_is_message_type_enabled(msg_type):
		return

	if msg is G.Errors:
		_print_error(msg, msg_type)
		return

	if p_error != G.Errors.NULL_ERROR:
		msg = MESSAGE_ERROR_TEMPLATE.format({
			"msg": msg,
			"error_string": _get_error_string(p_error, true),
		})

	_format_and_print(msg, msg_type)



func _print_error(p_error : G.Errors, msg_type : MessageTypes) -> void:
	var msg := _get_error_string(p_error)
	_format_and_print(msg, msg_type)


func _format_and_print(msg : String, msg_type : MessageTypes) -> void:
	msg = _format_color(msg, msg_type)
	print_rich(OUTPUT_TEMPLATE % msg)


func _format_color(msg : String, msg_type : MessageTypes) -> String:
	if message_type_text_color.has(msg_type):
		msg = COLOR_TEMPLATE.format({
			"color": message_type_text_color[msg_type],
			"msg": msg,
		})

	return msg


func _format_error(msg : String, p_error : G.Errors) -> String:
	msg = "TileBitTools: %s" % msg
	msg = msg + "(ERR %s)" % p_error if p_error != -1 else msg
	return msg


func _is_message_type_enabled(msg_type : MessageTypes) -> bool:
	var value = ProjectSettings.get_setting(message_type_settings[msg_type])
	if value == null:
		return false
	return value


func _get_error_string(p_error : G.Errors, skip_text_if_null := false) -> String:
	var error_text : String
	if skip_text_if_null:
		error_text = texts.ERROR_TEXTS.get(error, "")
	else:
		error_text = texts.ERROR_TEXTS.get(error, DEFAULT_ERROR_TEXT)

	var error_template : String
	if error_text == "":
		error_template = ERROR_CODE_TEMPLATE
	else:
		error_template = ERROR_TEXT_TEMPLATE

	var s := error_template.format({
		"error_text": error_text,
		"error": error,
	})

	var error_color : String
	if p_error == G.Errors.OK:
		error_color = OK_COLOR
	else:
		error_color = ERROR_COLOR

	return COLOR_TEMPLATE.format({
		"color": error_color,
		"msg": s,
	})
