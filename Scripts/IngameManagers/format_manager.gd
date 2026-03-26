class_name FormatManager
extends Node



func get_number_formatted(number: float, decimals: int = 0, prefix: String = "", suffix: String = "", force_zero_decimal: bool = false) -> String:
	var options = RPGSYSTEM.database.system.options
	var use_thousands_separator = options.get("use_thousands_separator", true)
	var show_abbreviated = options.get("show_abbreviated_in_battle", true) if GameManager.is_on_battle else options.get("show_abbreviated_in_menu", true)
	
	if show_abbreviated:
		return prefix + _format_compact_number(number, decimals, force_zero_decimal) + suffix
	elif use_thousands_separator:
		return prefix + _format_number(number, decimals, "", force_zero_decimal) + suffix
	
	var format_string = "%." + str(decimals) + "f"
	return prefix + (format_string % number) + suffix


func _format_compact_number(number: float, decimals: int = 0, force_zero_decimal: bool = false) -> String:
	if number == 0: return "0"
	
	var abs_number: float = abs(number)
	
	var suffixes = [
		{"value": 1000000000000000.0, "suffix": "Q"},
		{"value": 1000000000000.0, "suffix": "T"},
		{"value": 1000000000.0, "suffix": "B"},
		{"value": 1000000.0, "suffix": "M"},
		{"value": 1000.0, "suffix": "k"}
	]
	
	for suffix_data in suffixes:
		if abs_number >= suffix_data.value:
			var value = abs_number / suffix_data.value
			
			if value >= 1000.0:
				continue
			
			var format_string = "%." + str(decimals) + "f"
			var formatted_value = format_string % value
			
			if decimals == 0 and value == int(value):
				return str(int(value)) + suffix_data.suffix
			
			return formatted_value + suffix_data.suffix
	
	if decimals == 0 or (force_zero_decimal and number == int(number)):
		return str(int(abs_number))
	else:
		var format_string = "%." + str(decimals) + "f"
		return format_string % abs_number


func _format_number(number: float, decimals: int = 0, separator: String = "", force_zero_decimal: bool = false) -> String:
	if number == 0: return "0"
	
	if separator == "":
		separator = _get_thousands_separator_by_language()
	
	var format_string = "%." + str(decimals) + "f"
	var num_str = format_string % number
	
	var parts = num_str.split(".")
	var integer_part = parts[0]
	var decimal_part = parts[1] if parts.size() > 1 else ""
	
	var regex = RegEx.new()
	regex.compile("(\\d)(?=(\\d{3})+(?!\\d))")
	var formatted_integer = regex.sub(integer_part, "$1" + separator, true)
	
	if decimals == 0 or (force_zero_decimal and number == int(number)):
		return formatted_integer
	else:
		return formatted_integer + "." + decimal_part


func _get_thousands_separator_by_language() -> String:
	var locale = OS.get_locale()
	var language = locale.split("_")[0]
	
	match language:
		"es", "de", "pt", "it", "fr", "nl", "pl", "ru", "sv", "da", "no":
			return "."
		"en", "ja", "ko", "zh", "th", "hi":
			return ","
		_:
			return "."


func format_time(total_seconds: float) -> String:
	var int_seconds = int(total_seconds)
	var hours: int = int(int_seconds / 3600.0)
	var minutes: int = int((int_seconds % 3600) / 60.0)
	var seconds: int = int(int_seconds % 60)
	
	var time_str: String
	if hours >= 1:
		time_str = "%sh %sm" % [_format_number(hours), minutes]
	elif total_seconds > 60:
		time_str = "%sm %ss" % [minutes, seconds]
	else:
		time_str = "%.1fs" % total_seconds
	
	return time_str


func format_game_time(seconds: int, colon_visible: bool = true) -> String:
	var h: int = seconds / 3600.0
	var m: int = (seconds % 3600) / 60.0
	var s: int = seconds % 60
	
	if seconds < 60:
		var second_text = tr("Second") if s == 1 else tr("Seconds")
		return "%02d %s" % [s, second_text]
	
	var colon = ":" if colon_visible else " "
	
	if seconds < 3600:
		return "%02dM%s%02dS" % [m, colon, s]
	
	else:
		return "%02dH%s%02dM%s%02dS" % [h, colon, m, colon, s]
